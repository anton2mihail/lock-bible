import Foundation
import Observation
import SwiftUI
import JohnCore

@MainActor @Observable final class SharedPreferencesModel {
    var reading = ReadingPreferences.sourceDefaults
    var translation: TranslationID = .webCE
    var scope: RotationScope = .full
    var intervalMinutes = NativePersistentState().rotationIntervalMinutes
    var appearance: AppearanceMode = .system

    static func projectedAppearance(for theme: String?) -> AppearanceMode {
        guard let theme, !theme.isEmpty else { return .system }
        return theme == "dark" ? .dark : .light
    }

    func project(_ state: NativePersistentState) {
        reading = state.readingPreferences
        translation = TranslationID(rawValue: state.translationID) ?? .webCE
        scope = state.verseScope
        intervalMinutes = state.rotationIntervalMinutes
        appearance = Self.projectedAppearance(for: state.themeScheme)
    }

    func colors(for colorScheme: ColorScheme) -> JohnColors {
        switch appearance { case .light: .light; case .dark: .dark; case .system: colorScheme == .dark ? .dark : .light }
    }
    var preferredColorScheme: ColorScheme? {
        switch appearance { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable, Hashable {
    case system, light, dark
    var id: String { rawValue }
}

@MainActor @Observable final class JohnRuntime {
    let preferences = SharedPreferencesModel()
    let reader = ReaderModel()
    let readerScreen = ReaderScreenModel()
    let today: TodayModel
    let novenaNames: [String: String] = [:]
    private(set) var startupStatus = "Loading saved data."
    private(set) var nativeStateCapability: String?
    private(set) var libraryCapability: String?
    private(set) var settingSaveUncertain = false
    private(set) var startupComplete = false
    private(set) var hasNativeState = false
    private(set) var committedStateRevision: Int64?
    @ObservationIgnored private let stateStore: NativeStateStore?
    @ObservationIgnored private var startupURLs: [URL] = []
    @ObservationIgnored private var isDrainingStartupURLs = false
    @ObservationIgnored private let appResourceRoot: URL?
    @ObservationIgnored private let bible: BundledBibleRepository?
    @ObservationIgnored private let works: SQLiteWorksRepository?
    @ObservationIgnored private let rotation: IndexedRotationRepository?

    init(bundle: Bundle = .main) {
        let root = bundle.resourceURL?.appendingPathComponent("App", isDirectory: true)
        appResourceRoot = root
        if let root {
            let roots = ResourceRoots(app: root)
            let bibleRepository = BundledBibleRepository(roots: roots)
            let rotationRepository = IndexedRotationRepository(roots: roots)
            bible = bibleRepository
            rotation = rotationRepository
            works = SQLiteWorksRepository(roots: roots)
            today = TodayModel(appResources: root, rotation: rotationRepository)
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            if let documents, let applicationSupport {
                let libraryURL = documents.appendingPathComponent("SQLite/user-library.db", isDirectory: false)
                let legacyRoot = documents.appendingPathComponent("mmkv", isDirectory: true)
                stateStore = NativeStateStore(applicationSupportURL: applicationSupport,
                                              libraryURL: libraryURL,
                                              roots: roots,
                                              legacyReader: LegacyMMKVReader(rootURL: legacyRoot))
            } else {
                stateStore = nil
                startupStatus = "The app cannot find its saved-data folders."
            }
        } else {
            stateStore = nil
            bible = nil
            rotation = nil
            works = nil
            today = TodayModel(appResources: nil, rotation: nil)
            startupStatus = "App resources are missing."
        }
    }

    func start() async {
        guard !startupComplete else { return }
        #if DEBUG
        await runScenarioFromLaunchArguments()
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-L04TestStartupDelaySeconds"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1),
           let seconds = Double(ProcessInfo.processInfo.arguments[index + 1]),
           seconds > 0 {
            let boundedSeconds = min(seconds, 20)
            NSLog("John startup test delay begins; committedEnvelope=0 seconds=%.1f", boundedSeconds)
            try? await Task.sleep(for: .seconds(boundedSeconds))
        }
        #endif
        guard let stateStore else {
            startupStatus = "Saved data is not available. Restart the app after you restore its folders."
            startupComplete = true
            return
        }
        let result = await stateStore.loadOrImport()
        libraryCapability = result.libraryCapability
        nativeStateCapability = result.nativeStateCapability
        #if DEBUG
        NSLog("John startup capabilities: library=%@ state=%@",
              result.libraryCapability ?? "available", result.nativeStateCapability ?? "available")
        #endif
        guard let envelope = result.envelope else {
            startupStatus = "The app could not load saved settings. Restart the app to try again."
            startupComplete = true
            return
        }
        hasNativeState = true
        preferences.project(envelope.state)
        committedStateRevision = envelope.revision
        startupStatus = result.nativeStateCapability ?? result.libraryCapability ?? "Ready"
        startupComplete = true
        #if DEBUG
        NSLog("John startup committed envelope revision=%lld textSize=%@", envelope.revision, envelope.state.readingPreferences.textSize.rawValue)
        #endif
    }

    func apply(_ mutation: NativeStateMutation) async {
        guard startupComplete, hasNativeState, let stateStore else { return }
        do {
            let envelope = try await stateStore.update(mutation)
            preferences.project(envelope.state)
            committedStateRevision = envelope.revision
            nativeStateCapability = nil
            settingSaveUncertain = false
            #if DEBUG
            NSLog("John preference commit revision=%lld textSize=%@", envelope.revision, envelope.state.readingPreferences.textSize.rawValue)
            #endif
        } catch {
            nativeStateCapability = "The app cannot confirm that the setting was saved. Restart the app before you change saved settings."
            settingSaveUncertain = true
        }
    }

    func enqueueExternalURL(_ url: URL, using router: AppRouter) {
        startupURLs.append(url)
        #if DEBUG
        NSLog("John URL queued startupComplete=%d committedEnvelope=%d pending=%d",
              startupComplete ? 1 : 0, hasNativeState ? 1 : 0, startupURLs.count)
        #endif
        guard startupComplete, hasNativeState, !isDrainingStartupURLs else { return }
        Task { await drainExternalURLs(using: router) }
    }

    func drainExternalURLs(using router: AppRouter) async {
        guard startupComplete, hasNativeState, !isDrainingStartupURLs else { return }
        isDrainingStartupURLs = true
        defer { isDrainingStartupURLs = false }
        #if DEBUG
        NSLog("John URL drain starts committedRevision=%lld pending=%d",
              committedStateRevision ?? -1, startupURLs.count)
        #endif
        while !startupURLs.isEmpty {
            let url = startupURLs.removeFirst()
            await router.receive(url, using: self)
            #if DEBUG
            NSLog("John URL delivered committedRevision=%lld pending=%d",
                  committedStateRevision ?? -1, startupURLs.count)
            #endif
        }
    }

    #if DEBUG
    private func runScenarioFromLaunchArguments() async {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-L04RepositoryRunner") {
            await runRepositoryRunnerFromLaunchArguments(arguments)
            return
        }
        if arguments.contains("-L04SQLiteProbeOnly") {
            await runSQLiteOpenProbeFromLaunchArguments(arguments)
            return
        }
        if arguments.contains("-L04RecoveryResumeExisting") {
            await runRecoveryResumeExistingFromLaunchArguments(arguments)
            return
        }
        if arguments.contains("-L04RecoveryResumeBeforeCommit") {
            await runRecoveryResumeBeforeCommitFromLaunchArguments(arguments)
            return
        }
        if let recoveryIndex = arguments.firstIndex(of: "-L04RecoveryScenario"),
           arguments.indices.contains(recoveryIndex + 1),
           let scenario = L04RecoveryScenarios.Scenario(rawValue: arguments[recoveryIndex + 1]) {
            await runRecoveryScenarioFromLaunchArguments(arguments, scenario: scenario)
            return
        }
        guard let scenarioIndex = arguments.firstIndex(of: "-L04Scenario"),
              arguments.indices.contains(scenarioIndex + 1),
              let scenario = L04ScenarioRunner.Scenario(rawValue: arguments[scenarioIndex + 1]),
              let fixtureIndex = arguments.firstIndex(of: "-L04FixtureRelativePath"),
              arguments.indices.contains(fixtureIndex + 1),
              let outputIndex = arguments.firstIndex(of: "-L04OutputRelativePath"),
              arguments.indices.contains(outputIndex + 1),
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let resourceRoot = appResourceRoot else { return }
        let fixtureRelativePath = arguments[fixtureIndex + 1]
        let outputRelativePath = arguments[outputIndex + 1]
        guard let fixtureRoot = debugScenarioURL(fixtureRelativePath, under: documents),
              let outputRoot = debugScenarioURL(outputRelativePath, under: documents) else {
            NSLog("John L04 rejected paths outside the process Documents folder.")
            return
        }
        let pauseAtCheckpoint: String? = arguments.firstIndex(of: "-L04PauseAtCheckpoint")
            .flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        NSLog("John L04 process bundle=%@ home=%@ documents=%@ support=%@ fixture=%@ output=%@",
              Bundle.main.bundleIdentifier ?? "unknown", NSHomeDirectory(), documents.path,
              support?.path ?? "unavailable", fixtureRoot.path, outputRoot.path)
        do {
            let result = try await L04ScenarioRunner.runRecording(
                scenario,
                fixtureRoot: fixtureRoot,
                outputRoot: outputRoot,
                roots: ResourceRoots(app: resourceRoot),
                legacyReaderFactory: { LegacyMMKVReader(rootURL: $0) },
                checkpoint: {
                    NSLog("John L04 checkpoint: %@", $0.rawValue)
                    if $0.rawValue == pauseAtCheckpoint {
                        NSLog("John L04 checkpoint pause reached: %@", $0.rawValue)
                        DispatchSemaphore(value: 0).wait()
                    }
                },
                failureInjector: { point in
                    guard scenario == .afterRenameFailure else { return false }
                    if case .afterPrimaryRename = point { return true }
                    return false
                }
            )
            let themeCases: [(String, String, AppearanceMode)] = [
                ("missing", "<missing>", .system),
                ("empty", "", .system),
                ("dark", "dark", .dark),
                ("unknown", "sepia", .light)
            ]
            let themeReport = themeCases.map { name, raw, expected in
                let value = name == "missing" ? nil : raw
                let actual = SharedPreferencesModel.projectedAppearance(for: value)
                return "\(name)\t\(raw)\t\(expected.rawValue)\t\(actual.rawValue)\t\(actual == expected ? "pass" : "fail")"
            }.joined(separator: "\n") + "\n"
            try Data(themeReport.utf8).write(to: outputRoot.appendingPathComponent("theme-projection.tsv"), options: .atomic)
            NSLog("John L04 scenario %@ passed=%d output=%@", scenario.rawValue, result.passed ? 1 : 0, outputRoot.path)
        } catch {
            NSLog("John L04 scenario %@ failed: %@", scenario.rawValue, String(describing: error))
        }
    }

    private func runRepositoryRunnerFromLaunchArguments(_ arguments: [String]) async {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let resourceRoot = appResourceRoot,
              let widgetExtension = Bundle.main.builtInPlugInsURL?.appendingPathComponent("JohnWidget.appex", isDirectory: true),
              let widgetRoot = Bundle(url: widgetExtension)?.resourceURL?.appendingPathComponent("Widget", isDirectory: true),
              let closedIndex = arguments.firstIndex(of: "-L04RepoClosedDatabaseRelativePath"),
              arguments.indices.contains(closedIndex + 1),
              let recoveryIndex = arguments.firstIndex(of: "-L04RepoRecoveryRelativePath"),
              arguments.indices.contains(recoveryIndex + 1),
              let bibleIndex = arguments.firstIndex(of: "-L04RepoBibleFixtureRelativePath"),
              arguments.indices.contains(bibleIndex + 1),
              let rotationIndex = arguments.firstIndex(of: "-L04RepoRotationFixtureRelativePath"),
              arguments.indices.contains(rotationIndex + 1),
              let schemaIndex = arguments.firstIndex(of: "-L04RepoSchema77RelativePath"),
              arguments.indices.contains(schemaIndex + 1),
              let damagedIndex = arguments.firstIndex(of: "-L04RepoDamagedDatabaseRelativePath"),
              arguments.indices.contains(damagedIndex + 1),
              let outputIndex = arguments.firstIndex(of: "-L04RepoOutputRelativePath"),
              arguments.indices.contains(outputIndex + 1),
              let databaseURL = debugScenarioURL(arguments[closedIndex + 1], under: documents),
              let recoveryURL = debugScenarioURL(arguments[recoveryIndex + 1], under: documents),
              let bibleURL = debugScenarioURL(arguments[bibleIndex + 1], under: documents),
              let rotationURL = debugScenarioURL(arguments[rotationIndex + 1], under: documents),
              let schemaURL = debugScenarioURL(arguments[schemaIndex + 1], under: documents),
              let damagedURL = debugScenarioURL(arguments[damagedIndex + 1], under: documents),
              let outputURL = debugScenarioURL(arguments[outputIndex + 1], under: documents) else {
            NSLog("John L04 repository runner rejected paths outside the process Documents folder.")
            return
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        NSLog("John L04 repository process bundle=%@ home=%@ documents=%@ support=%@",
              Bundle.main.bundleIdentifier ?? "unknown", NSHomeDirectory(), documents.path, support?.path ?? "unavailable")
        do {
            try await L04RepositoryRunner.run(
                roots: ResourceRoots(app: resourceRoot, widget: widgetRoot),
                databaseURL: databaseURL,
                expectedClosedSourceSHA256: "8d78ca482d4720783ecabfcd17f88e72d5d2393eabc358ef03c5398f2cd43ed9",
                recoveryDirectory: recoveryURL,
                bibleFixtureURL: bibleURL,
                rotationFixtureURL: rotationURL,
                unsupportedSchemaURL: schemaURL,
                expectedUnsupportedSchemaSHA256: "bac7204a9fac7818b4ae8b8c51692827a9b0af80cbc7b095d3ea643c82f60605",
                damagedDatabaseURL: damagedURL,
                expectedDamagedDatabaseSHA256: "a0e6cc8d5e829bc4926a3bef982be9c7449325c99f34894681e208b06dd44a8a",
                outputURL: outputURL
            )
            NSLog("John L04 repository checks passed output=%@", outputURL.path)
        } catch {
            NSLog("John L04 repository checks failed: %@", String(describing: error))
        }
    }

    private func runRecoveryResumeExistingFromLaunchArguments(_ arguments: [String]) async {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let roots = appResourceRoot,
              let rootIndex = arguments.firstIndex(of: "-L04ResumeSourceRelativePath"),
              arguments.indices.contains(rootIndex + 1),
              let outputIndex = arguments.firstIndex(of: "-L04ResumeOutputRelativePath"),
              arguments.indices.contains(outputIndex + 1),
              let sourceRoot = debugScenarioURL(arguments[rootIndex + 1], under: documents),
              let outputRoot = debugScenarioURL(arguments[outputIndex + 1], under: documents) else {
            NSLog("John L04 rejected recovery paths outside the process Documents folder.")
            return
        }
        let support = sourceRoot.appendingPathComponent("Application Support", isDirectory: true)
        let library = sourceRoot.appendingPathComponent("Documents/SQLite/user-library.db")
        NSLog("John L04 recovery resume bundle=%@ home=%@ documents=%@ source=%@ output=%@",
              Bundle.main.bundleIdentifier ?? "unknown", NSHomeDirectory(), documents.path,
              sourceRoot.path, outputRoot.path)
        do {
            let result = try await L04RecoveryScenarios.resumeExistingRoot(
                applicationSupportURL: support, libraryURL: library,
                roots: ResourceRoots(app: roots), outputRoot: outputRoot
            )
            NSLog("John L04 recovery resume existing passed=%d revision=%lld output=%@",
                  result.passed ? 1 : 0, result.revision ?? -1, outputRoot.path)
        } catch {
            NSLog("John L04 recovery resume existing failed: %@", String(describing: error))
        }
    }

    private func runRecoveryResumeBeforeCommitFromLaunchArguments(_ arguments: [String]) async {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let roots = appResourceRoot,
              let rootIndex = arguments.firstIndex(of: "-L04ResumeSourceRelativePath"),
              arguments.indices.contains(rootIndex + 1),
              let fixtureIndex = arguments.firstIndex(of: "-L04FixtureRelativePath"),
              arguments.indices.contains(fixtureIndex + 1),
              let outputIndex = arguments.firstIndex(of: "-L04ResumeOutputRelativePath"),
              arguments.indices.contains(outputIndex + 1),
              let sourceRoot = debugScenarioURL(arguments[rootIndex + 1], under: documents),
              let fixtureRoot = debugScenarioURL(arguments[fixtureIndex + 1], under: documents),
              let outputRoot = debugScenarioURL(arguments[outputIndex + 1], under: documents) else {
            NSLog("John L04 rejected recovery paths outside the process Documents folder.")
            return
        }
        let support = sourceRoot.appendingPathComponent("Application Support", isDirectory: true)
        let library = sourceRoot.appendingPathComponent("Documents/SQLite/user-library.db")
        let legacyRoot = fixtureRoot.appendingPathComponent("input/legacy/mmkv", isDirectory: true)
        NSLog("John L04 recovery retry bundle=%@ home=%@ documents=%@ source=%@ fixture=%@ output=%@",
              Bundle.main.bundleIdentifier ?? "unknown", NSHomeDirectory(), documents.path,
              sourceRoot.path, fixtureRoot.path, outputRoot.path)
        do {
            let result = try await L04RecoveryScenarios.resumeBeforeCommit(
                fixtureRoot: fixtureRoot, applicationSupportURL: support, libraryURL: library,
                roots: ResourceRoots(app: roots), legacyReader: LegacyMMKVReader(rootURL: legacyRoot),
                outputRoot: outputRoot
            )
            NSLog("John L04 recovery resume before commit passed=%d revision=%lld output=%@",
                  result.passed ? 1 : 0, result.revision ?? -1, outputRoot.path)
        } catch {
            NSLog("John L04 recovery resume before commit failed: %@", String(describing: error))
        }
    }

    private func runRecoveryScenarioFromLaunchArguments(_ arguments: [String], scenario: L04RecoveryScenarios.Scenario) async {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let roots = appResourceRoot,
              let outputIndex = arguments.firstIndex(of: "-L04OutputRelativePath"),
              arguments.indices.contains(outputIndex + 1),
              let outputRoot = debugScenarioURL(arguments[outputIndex + 1], under: documents) else {
            NSLog("John L04 rejected recovery output outside the process Documents folder.")
            return
        }
        do {
            let result = try await L04RecoveryScenarios.run(scenario, outputRoot: outputRoot, roots: ResourceRoots(app: roots))
            try L04RecoveryScenarios.write(result, to: outputRoot)
            NSLog("John L04 recovery scenario %@ passed=%d output=%@", scenario.rawValue, result.passed ? 1 : 0, outputRoot.path)
        } catch {
            NSLog("John L04 recovery scenario %@ failed: %@", scenario.rawValue, String(describing: error))
        }
    }

    private func debugScenarioURL(_ relativePath: String, under documents: URL) -> URL? {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains("..") else { return nil }
        let root = documents.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = documents.appendingPathComponent(relativePath, isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        guard candidate.path.hasPrefix(root.path + "/") else { return nil }
        return candidate
    }

    private func runSQLiteOpenProbeFromLaunchArguments(_ arguments: [String]) async {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let walIndex = arguments.firstIndex(of: "-L04SQLiteProbeWALRelativePath"),
              arguments.indices.contains(walIndex + 1),
              let backupIndex = arguments.firstIndex(of: "-L04SQLiteProbeBackupRelativePath"),
              arguments.indices.contains(backupIndex + 1),
              let freshIndex = arguments.firstIndex(of: "-L04SQLiteProbeFreshRelativePath"),
              arguments.indices.contains(freshIndex + 1),
              let outputIndex = arguments.firstIndex(of: "-L04SQLiteProbeOutputRelativePath"),
              arguments.indices.contains(outputIndex + 1),
              let walDatabase = debugScenarioURL(arguments[walIndex + 1], under: documents),
              let backupDatabase = debugScenarioURL(arguments[backupIndex + 1], under: documents),
              let freshDatabase = debugScenarioURL(arguments[freshIndex + 1], under: documents),
              let outputRoot = debugScenarioURL(arguments[outputIndex + 1], under: documents) else {
            NSLog("John L04 SQLite probe rejected paths outside the process Documents folder.")
            return
        }
        do {
            try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: false)
            let controlDatabase = outputRoot.appendingPathComponent("delete-mode-control.db", isDirectory: false)
            let openProbes = [
                SQLiteOpenProbe.run(url: walDatabase, mode: .readOnly),
                SQLiteOpenProbe.run(url: controlDatabase, mode: .deleteModeControl),
                SQLiteOpenProbe.run(url: controlDatabase, mode: .readOnly),
            ]
            let readTransactions = [
                SQLiteOpenProbe.runLibraryReadTransaction(url: walDatabase),
                SQLiteOpenProbe.runLibraryReadTransaction(url: backupDatabase),
                SQLiteOpenProbe.runLibraryReadTransaction(url: freshDatabase),
            ]
            let data = try JSONSerialization.data(withJSONObject: [
                "openProbes": try JSONSerialization.jsonObject(with: JSONEncoder().encode(openProbes)),
                "readTransactions": try JSONSerialization.jsonObject(with: JSONEncoder().encode(readTransactions)),
            ], options: [.prettyPrinted, .sortedKeys])
            try data.write(to: outputRoot.appendingPathComponent("sqlite-open-probes.json"), options: .atomic)
            NSLog("John L04 SQLite probe bundle=%@ home=%@ documents=%@ wal=%@ backup=%@ fresh=%@ output=%@",
                  Bundle.main.bundleIdentifier ?? "unknown", NSHomeDirectory(), documents.path,
                  walDatabase.path, backupDatabase.path, freshDatabase.path, outputRoot.path)
        } catch {
            NSLog("John L04 SQLite probe failed: %@", String(describing: error))
        }
    }
    #endif

    func passage(translation: TranslationID, bookCode: String, chapter number: Int,
                 startVerse: String, endVerse: String) async -> PassageSelection? {
        guard let bible, let code = BookCode(rawValue: bookCode),
              let start = VerseLabel(rawValue: startVerse), let end = VerseLabel(rawValue: endVerse) else { return nil }
        do {
            let chapter = try await bible.chapter(translation: translation, book: code, chapter: number)
            guard let firstIndex = chapter.verses.firstIndex(where: { $0.label == startVerse }),
                  let lastIndex = chapter.verses.firstIndex(where: { $0.label == endVerse }), firstIndex <= lastIndex else { return nil }
            let id = try PassageID(translationID: translation, bookCode: code, chapter: number, startVerse: start, endVerse: end)
            return try await bible.passage(id: id, startIndex: firstIndex, endIndex: lastIndex)
        } catch { return nil }
    }

    func passage(reference: String, translation: TranslationID) async -> PassageSelection? {
        guard let (book, chapter, first, last) = ReferenceParser.parse(reference), let bible else { return nil }
        do {
            let manifest = try await bible.manifest(for: translation)
            let normalized = book.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            guard let descriptor = manifest.first(where: {
                [$0.name, $0.longName, $0.code].contains { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == normalized }
            }) else { return nil }
            return await passage(translation: translation, bookCode: descriptor.code, chapter: chapter, startVerse: first, endVerse: last)
        } catch { return nil }
    }

    func books(translation: TranslationID) async -> [BibleBookDescriptor] {
        guard let bible else { return [] }
        return (try? await bible.manifest(for: translation)) ?? []
    }

    func chapter(translation: TranslationID, bookCode: String, number: Int) async -> BibleChapter? {
        guard let bible, let code = BookCode(rawValue: bookCode) else { return nil }
        return try? await bible.chapter(translation: translation, book: code, chapter: number)
    }
}

private enum ReferenceParser {
    static func parse(_ text: String) -> (String, Int, String, String)? {
        let pattern = #"^\s*(.+?)\s+(\d+)\s*:\s*([\p{L}\p{N}]+)(?:\s*[-–]\s*([\p{L}\p{N}]+))?\s*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let bookRange = Range(match.range(at: 1), in: text), let chapterRange = Range(match.range(at: 2), in: text),
              let firstRange = Range(match.range(at: 3), in: text) else { return nil }
        let lastRange = Range(match.range(at: 4), in: text)
        guard let chapter = Int(text[chapterRange]) else { return nil }
        let first = String(text[firstRange])
        return (String(text[bookRange]), chapter, first, lastRange.map { String(text[$0]) } ?? first)
    }
}
