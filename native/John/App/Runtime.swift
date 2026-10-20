import Foundation
import Observation
import SwiftUI
import WidgetKit
import JohnCore
import JohnSharedResources
#if DEBUG
import CryptoKit
#endif

@MainActor @Observable final class SharedPreferencesModel {
    var reading = ReadingPreferences.sourceDefaults
    var translation: TranslationID = .webCE
    var scope: RotationScope = .full
    var intervalMinutes = NativePersistentState().rotationIntervalMinutes
    var appearance: AppearanceMode = .system
    var readerLocation: ReaderLocation?
    var selectionHintDismissed = false

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
        readerLocation = state.readerLocation
        selectionHintDismissed = state.selectionHintDismissed
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
    /// Read-aloud for the Reader (E8). The mini-player (E27) shows its state.
    let readAloud = ReadAloudController()
    /// The Media model that keeps playing audio after its page closes.
    var mediaAudio: RosaryMediaModel?
    /// Media audio that is loaded and in audio mode. Nil when no audio is active.
    var activeMediaAudio: RosaryMediaModel? {
        guard let mediaAudio, mediaAudio.mode == .audio, mediaAudio.state == .ready else { return nil }
        return mediaAudio
    }
    let today: TodayModel
    let novenaNames: [String: String] = [:]
    private(set) var startupStatus = "Loading saved data."
    private(set) var nativeStateCapability: String?
    private(set) var libraryCapability: String?
    /// Increases after undo, redo, import, or tag changes. Views reload saved data when it changes.
    var savedRevision = 0
    /// Optional iCloud sync (E21). Off until the user turns it on in Settings.
    let cloudSync = CloudSyncModel()
    let tagStore: SavedTagStore?
    /// Reading progress and plan (E7). A separate file keeps older data valid.
    let progressStore: ReadingProgressStore?
    /// Increases after any progress change. Views reload progress when it changes.
    var progressRevision = 0
    private var spotlightRefreshTask: Task<Void, Never>?
    private var spotlightRefreshWanted = false
    private(set) var settingSaveUncertain = false
    private(set) var startupComplete = false
    private(set) var hasNativeState = false
    private(set) var committedStateRevision: Int64?
    private(set) var committedNativeState: NativePersistentState?
    @ObservationIgnored private let stateStore: NativeStateStore?
    @ObservationIgnored private var startupURLs: [URL] = []
    @ObservationIgnored private var isDrainingStartupURLs = false
    @ObservationIgnored private var mutationOutcomeSequence: UInt64 = 0
    @ObservationIgnored private var noticeService: LocalNoticeService?
#if DEBUG
    @ObservationIgnored private var noticeSnapshotSequence: UInt64 = 0
    @ObservationIgnored private var noticeSnapshotTask: Task<Void, Never>?
#endif
    @ObservationIgnored private var featureClock: () -> Date = Date.init
    @ObservationIgnored private var featureZone: TimeZone = .autoupdatingCurrent
    @ObservationIgnored private let appResourceRoot: URL?
    @ObservationIgnored private let bible: BundledBibleRepository?
    @ObservationIgnored private let works: SQLiteWorksRepository?
    @ObservationIgnored private let rotation: IndexedRotationRepository?
    @ObservationIgnored private let library: SQLiteLibraryRepository?
    @ObservationIgnored private let searchRepository: SQLiteSearchRepository?
    @ObservationIgnored let companionRepository: BundledCompanionRepository?
    /// Devotional data read once before the first screen shows. Screens use it in their first frame, so no spinner swaps in later.
    @ObservationIgnored private(set) var warmDevotionalCatalog: DevotionalCatalog?
    @ObservationIgnored private(set) var warmRosaryHome: RosaryHomeCatalog?
    @ObservationIgnored private(set) var warmRosarySessions: [RosaryGuideSession] = []
    @ObservationIgnored private(set) var warmArtCredits: [String: String] = [:]

    init(bundle: Bundle = .main) {
        let root = bundle.resourceURL?.appendingPathComponent("App", isDirectory: true)
        appResourceRoot = root
        if let root {
            let roots = ResourceRoots(app: root)
            let bibleRepository = BundledBibleRepository(roots: roots)
            let rotationRepository = SharedResources.rotationDirectory.map { IndexedRotationRepository(rotationDirectory: $0) }
            bible = bibleRepository
            rotation = rotationRepository
            works = SQLiteWorksRepository(roots: roots)
            searchRepository = SQLiteSearchRepository(
                databaseURL: root.appendingPathComponent("Databases/bible-search.db", isDirectory: false),
                resourceRoots: roots
            )
            companionRepository = BundledCompanionRepository(roots: roots)
            today = TodayModel(appResources: root, rotation: rotationRepository)
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            if let documents, let applicationSupport {
                let libraryURL = documents.appendingPathComponent("SQLite/user-library.db", isDirectory: false)
                #if DEBUG
                // UI tests pass `-JohnResetNativeState` to start from the default native state (test isolation).
                if ProcessInfo.processInfo.arguments.contains("-JohnResetNativeState") {
                    let stateDirectory = applicationSupport.appendingPathComponent("John", isDirectory: true)
                    for name in ["native-state-v1.json", "native-state-v1.previous.json", "reading-progress-v1.json"] {
                        try? FileManager.default.removeItem(at: stateDirectory.appendingPathComponent(name))
                    }
                }
                #endif
                let legacyRoot = documents.appendingPathComponent("mmkv", isDirectory: true)
                let recoveryDirectory = applicationSupport.appendingPathComponent("John/recovery", isDirectory: true)
                stateStore = NativeStateStore(applicationSupportURL: applicationSupport,
                                              libraryURL: libraryURL,
                                              roots: roots,
                                              legacyReader: LegacyMMKVReader(rootURL: legacyRoot))
                library = SQLiteLibraryRepository(databaseURL: libraryURL, recoveryDirectory: recoveryDirectory)
                tagStore = SavedTagStore(url: applicationSupport.appendingPathComponent("John/saved-tags-v1.json", isDirectory: false))
                progressStore = ReadingProgressStore(url: applicationSupport.appendingPathComponent("John/reading-progress-v1.json", isDirectory: false))
            } else {
                stateStore = nil
                tagStore = nil
                progressStore = nil
                library = nil
                startupStatus = "The app cannot find its saved-data folders."
            }
        } else {
            stateStore = nil
            tagStore = nil
            progressStore = nil
            library = nil
            searchRepository = nil
            bible = nil
            rotation = nil
            works = nil
            companionRepository = nil
            today = TodayModel(appResources: nil, rotation: nil)
            startupStatus = "App resources are missing."
        }
        readAloud.otherAudioActive = { [weak self] in self?.mediaAudio != nil }
        configureNoticeService()
        #if DEBUG
        configureFeatureClockFromArguments()
        #endif
    }

    func featureNow() -> Date { featureClock() }
    var featureTimeZone: TimeZone { featureZone }

    #if DEBUG
    private func configureFeatureClockFromArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let dateIndex = arguments.firstIndex(of: "-L14FeatureDate"),
              arguments.indices.contains(dateIndex + 1),
              let zoneIndex = arguments.firstIndex(of: "-L14FeatureTimeZone"),
              arguments.indices.contains(zoneIndex + 1),
              let zone = TimeZone(identifier: arguments[zoneIndex + 1]) else { return }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: arguments[dateIndex + 1]) else { return }
        featureClock = { date }
        featureZone = zone
        NSLog("John feature test clock configured zone=%@", zone.identifier)
    }
    #endif

    private func warmDevotionalData() async {
        guard let companionRepository, let catalog = try? await companionRepository.devotionalCatalog() else { return }
        warmDevotionalCatalog = catalog
        warmRosaryHome = try? RosaryCatalogAdapter.decode(catalog.rosary)
        let rosary = catalog.rosary
        let resourceURL = Bundle.main.resourceURL
        let (sessions, credits) = await Task.detached(priority: .userInitiated) {
            var sessions: [RosaryGuideSession]?
            if let data = try? JSONEncoder().encode(rosary),
               let decoded = try? JSONDecoder().decode(RosarySourceCatalog.self, from: data) {
                sessions = decoded.sessions
            }
            var credits: [String: String]?
            if let url = resourceURL?.appendingPathComponent("App/Artwork/credits.json"),
               let data = try? Data(contentsOf: url) {
                credits = try? JSONDecoder().decode([String: String].self, from: data)
            }
            return (sessions, credits)
        }.value
        if let sessions { warmRosarySessions = sessions }
        if let credits { warmArtCredits = credits }
    }

    func start() async {
        guard !startupComplete else { return }
        await warmDevotionalData()
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
        committedNativeState = envelope.state
        committedStateRevision = envelope.revision
        await writeWidgetProjection(envelope.state, reload: true)
        startupStatus = result.nativeStateCapability ?? result.libraryCapability ?? "Ready"
        startupComplete = true
        #if DEBUG
        NSLog("John startup committed envelope revision=%lld textSize=%@", envelope.revision, envelope.state.readingPreferences.textSize.rawValue)
        #endif
#if DEBUG
        await captureSystemNoticeSnapshot(phase: "startup", outcome: "loaded")
        exportSharedContainerProbe()
#endif
        await refreshLocalNotifications()
    }

    func apply(_ mutation: NativeStateMutation) async {
        _ = await applyWithResult(mutation)
    }

    func applyWithResult(_ mutation: NativeStateMutation) async -> Bool {
        guard startupComplete, hasNativeState, let stateStore else { return false }
        mutationOutcomeSequence &+= 1
        let outcomeSequence = mutationOutcomeSequence
        do {
            let envelope = try await stateStore.update(mutation)
            let previousState = committedNativeState
            if envelope.revision >= (committedStateRevision ?? 0) {
                preferences.project(envelope.state)
                committedNativeState = envelope.state
                committedStateRevision = envelope.revision
            }
            if outcomeSequence == mutationOutcomeSequence {
                let projectionState = committedNativeState ?? envelope.state
                await writeWidgetProjection(
                    projectionState,
                    reload: previousState.map {
                        $0.translationID != projectionState.translationID ||
                        $0.verseScope != projectionState.verseScope ||
                        $0.rotationIntervalMinutes != projectionState.rotationIntervalMinutes
                    } ?? true
                )
            }
            if outcomeSequence == mutationOutcomeSequence {
                nativeStateCapability = nil
                settingSaveUncertain = false
            }
            #if DEBUG
            NSLog("John preference commit revision=%lld textSize=%@", envelope.revision, envelope.state.readingPreferences.textSize.rawValue)
            #endif
            return true
        } catch {
            if outcomeSequence == mutationOutcomeSequence {
                nativeStateCapability = "The app cannot confirm that the setting was saved. Restart the app before you change saved settings."
                settingSaveUncertain = true
            }
            return false
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
    private struct SystemNoticeRuntimeStage: Codable {
        let schemaVersion: Int
        let bundleIdentifier: String
        let processIdentifier: Int32
        let sequence: UInt64
        let phase: String
        let outcome: String
        let capturedAtUTC: String
        let committedStateRevision: Int64?
        let nativeEnvelopeBase64: String?
        let nativeEnvelopeSHA256: String?
        let nativeEnvelopeError: String?
        let systemSnapshot: SystemNoticeSnapshot.Report?
        let systemSnapshotError: String?
    }

    private func captureSystemNoticeSnapshot(phase: String, outcome: String) async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-L22NoticeSnapshotRelativePath"),
              arguments.indices.contains(index + 1),
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let outputRoot = debugScenarioURL(arguments[index + 1], under: documents) else { return }

        noticeSnapshotSequence &+= 1
        let sequence = noticeSnapshotSequence
        let previous = noticeSnapshotTask
        let next = Task { @MainActor [weak self] in
            await previous?.value
            await self?.writeSystemNoticeSnapshot(
                to: outputRoot,
                sequence: sequence,
                phase: phase,
                outcome: outcome
            )
        }
        noticeSnapshotTask = next
        await next.value
    }

    private func writeSystemNoticeSnapshot(
        to outputRoot: URL,
        sequence: UInt64,
        phase: String,
        outcome: String
    ) async {
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        var snapshot: SystemNoticeSnapshot.Report?
        var snapshotError: String?
        do {
            snapshot = try await SystemNoticeSnapshot.capture()
        } catch {
            snapshotError = error.localizedDescription
        }

        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let envelopeURL = applicationSupport?.appendingPathComponent("John/native-state-v1.json", isDirectory: false)
        var envelopeBytes: Data?
        var envelopeError: String?
        do {
            guard let envelopeURL else { throw CoreError.missingResource("native state envelope path") }
            envelopeBytes = try Data(contentsOf: envelopeURL)
        } catch {
            envelopeError = error.localizedDescription
        }

        let stage = SystemNoticeRuntimeStage(
            schemaVersion: 1,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
            processIdentifier: getpid(),
            sequence: sequence,
            phase: phase,
            outcome: outcome,
            capturedAtUTC: capturedAt,
            committedStateRevision: committedStateRevision,
            nativeEnvelopeBase64: envelopeBytes?.base64EncodedString(),
            nativeEnvelopeSHA256: envelopeBytes.map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() },
            nativeEnvelopeError: envelopeError,
            systemSnapshot: snapshot,
            systemSnapshotError: snapshotError
        )
        do {
            try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(stage)
            let safePhase = phase.replacingOccurrences(of: "/", with: "-")
            let safeOutcome = outcome.replacingOccurrences(of: "/", with: "-")
            let filename = String(format: "%03llu-%@-%@-p%d.json", sequence, safePhase, safeOutcome, getpid())
            let outputURL = outputRoot.appendingPathComponent(filename, isDirectory: false)
            guard !FileManager.default.fileExists(atPath: outputURL.path) else {
                throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: outputURL.path])
            }
            try data.write(to: outputURL, options: .atomic)
            NSLog("John L22 system notice snapshot phase=%@ outcome=%@ pid=%d revision=%lld output=%@",
                  phase, outcome, getpid(), committedStateRevision ?? -1, outputURL.path)
        } catch {
            NSLog("John L22 system notice snapshot failed phase=%@ outcome=%@ error=%@",
                  phase, outcome, error.localizedDescription)
        }
    }

    private func runScenarioFromLaunchArguments() async {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-L22ServiceComparison") {
            await runL22ServiceComparison(arguments)
            return
        }
        if arguments.contains("-L09FixtureComparison") {
            await runL09FixtureComparison(arguments)
            return
        }
        if arguments.contains("-L10L11FixtureComparison") {
            await runL10L11FixtureComparison(arguments)
            return
        }
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
              let rotationDirectory = SharedResources.rotationDirectory,
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
                roots: ResourceRoots(app: resourceRoot),
                rotationDirectory: rotationDirectory,
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

    private func runL22ServiceComparison(_ arguments: [String]) async {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let fixtureIndex = arguments.firstIndex(of: "-L22FixtureRelativePath"),
              arguments.indices.contains(fixtureIndex + 1),
              let outputIndex = arguments.firstIndex(of: "-L22OutputRelativePath"),
              arguments.indices.contains(outputIndex + 1),
              let fixtureURL = debugScenarioURL(arguments[fixtureIndex + 1], under: documents),
              let outputURL = debugScenarioURL(arguments[outputIndex + 1], under: documents) else {
            NSLog("John L22 comparison rejected paths outside the process Documents folder.")
            return
        }
        guard let repository = companionRepository else {
            NSLog("John L22 comparison cannot read bundled calendar resources.")
            return
        }
        NSLog("John L22 process bundle=%@ home=%@ documents=%@ fixture=%@ output=%@",
              Bundle.main.bundleIdentifier ?? "unknown", NSHomeDirectory(), documents.path,
              fixtureURL.path, outputURL.path)
        do {
            let report = try await L22ServiceComparison.run(sourceFixtureURL: fixtureURL) {
                async let readings = repository.readings()
                async let celebrations = repository.celebrations()
                return try await (readings, celebrations)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: outputURL, options: .atomic)
            NSLog("John L22 comparison passed=%d observations=%lu output=%@",
                  report.passed ? 1 : 0, report.observations.count, outputURL.path)
        } catch {
            NSLog("John L22 comparison failed: %@", String(describing: error))
        }
    }

    private func runL09FixtureComparison(_ arguments: [String]) async {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let appRoot = appResourceRoot,
              let fixtureIndex = arguments.firstIndex(of: "-L09FixtureRelativePath"),
              arguments.indices.contains(fixtureIndex + 1),
              let outputIndex = arguments.firstIndex(of: "-L09OutputRelativePath"),
              arguments.indices.contains(outputIndex + 1),
              let fixtureURL = debugScenarioURL(arguments[fixtureIndex + 1], under: documents),
              let outputURL = debugScenarioURL(arguments[outputIndex + 1], under: documents) else {
            NSLog("John L09 comparison rejected paths outside the process Documents folder.")
            return
        }
        let databaseURL = appRoot.appendingPathComponent("Databases/bible-search.db", isDirectory: false)
        NSLog("John L09 process bundle=%@ home=%@ documents=%@ fixture=%@ output=%@",
              Bundle.main.bundleIdentifier ?? "unknown", NSHomeDirectory(), documents.path,
              fixtureURL.path, outputURL.path)
        do {
            _ = try await L09FixtureComparison.run(fixtureURL: fixtureURL, appRoot: appRoot,
                                                   databaseURL: databaseURL, outputURL: outputURL)
            NSLog("John L09 comparison completed.")
        } catch {
            NSLog("John L09 comparison failed: %@", String(describing: error))
        }
    }

    private func runL10L11FixtureComparison(_ arguments: [String]) async {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let fixtureIndex = arguments.firstIndex(of: "-L10FixtureRelativePath"),
              arguments.indices.contains(fixtureIndex + 1),
              let databaseIndex = arguments.firstIndex(of: "-L10DatabaseRelativePath"),
              arguments.indices.contains(databaseIndex + 1),
              let recoveryIndex = arguments.firstIndex(of: "-L10RecoveryRelativePath"),
              arguments.indices.contains(recoveryIndex + 1),
              let outputIndex = arguments.firstIndex(of: "-L10OutputRelativePath"),
              arguments.indices.contains(outputIndex + 1),
              let fixtureURL = debugScenarioURL(arguments[fixtureIndex + 1], under: documents),
              let databaseURL = debugScenarioURL(arguments[databaseIndex + 1], under: documents),
              let recoveryURL = debugScenarioURL(arguments[recoveryIndex + 1], under: documents),
              let outputURL = debugScenarioURL(arguments[outputIndex + 1], under: documents) else {
            NSLog("John L10 comparison rejected paths outside the process Documents folder.")
            return
        }
        NSLog("John L10 process bundle=%@ home=%@ documents=%@ fixture=%@ database=%@ recovery=%@ output=%@",
              Bundle.main.bundleIdentifier ?? "unknown", NSHomeDirectory(), documents.path,
              fixtureURL.path, databaseURL.path, recoveryURL.path, outputURL.path)
        do {
            _ = try await L10L11FixtureComparison.run(fixtureURL: fixtureURL, databaseURL: databaseURL,
                                                       recoveryDirectory: recoveryURL, outputURL: outputURL)
            NSLog("John L10/L11 comparison completed.")
        } catch {
            NSLog("John L10/L11 comparison failed: %@", String(describing: error))
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

    /// Step 7: -L29SharedProbeRelativePath <path below Documents>. It writes one JSON file and never overwrites a file.
    /// It reads the group only from Info.plist. With no group it records `"appGroup": "missing"` and touches no group data.
    func exportSharedContainerProbe(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard let index = arguments.firstIndex(of: "-L29SharedProbeRelativePath"),
              arguments.indices.contains(index + 1),
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let confined = debugScenarioURL(arguments[index + 1], under: documents) else { return }
        let target = URL(fileURLWithPath: confined.path, isDirectory: false)
        var record: [String: String] = ["appTime": ISO8601DateFormatter().string(from: Date())]
        if let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String, !group.isEmpty {
            let defaults = UserDefaults(suiteName: group)
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            var widgetFile = "nil"
            if let container, let data = try? Data(contentsOf: container.appendingPathComponent("l29-widget-probe.json")) {
                widgetFile = String(data: data, encoding: .utf8) ?? "unreadable"
            }
            record["appGroup"] = group
            record["defaultsAvailable"] = defaults == nil ? "false" : "true"
            record["containerPath"] = container?.path ?? "nil"
            record["translationId"] = defaults?.string(forKey: "translationId") ?? "nil"
            record["scope"] = defaults?.string(forKey: "scope") ?? "nil"
            record["intervalMinutes"] = String(defaults?.integer(forKey: "intervalMinutes") ?? -1)
            record["widgetProbeDefaults"] = defaults?.string(forKey: "l29.widgetProbe") ?? "nil"
            record["widgetProbeFile"] = widgetFile
        } else {
            record["appGroup"] = "missing"
        }
        do {
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys, .prettyPrinted])
            // The probe never replaces an earlier record. Foundation traps on `.atomic` with `.withoutOverwriting`.
            guard !FileManager.default.fileExists(atPath: target.path) else {
                throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: target.path])
            }
            try data.write(to: target, options: .atomic)
        } catch {
            NSLog("John L29 shared probe not written: %@", String(describing: error))
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

    func worksCatalog() async -> WorkCatalog? {
        guard let works else { return nil }
        return try? await works.catalog()
    }

    func workSection(workID: String, index: Int) async throws -> WorkSection {
        guard let works else { throw CoreError.missingResource("Works database") }
        return try await works.section(workID: workID, index: index)
    }

    func workSectionSummaries(workID: String) async throws -> [WorkSectionSummary] {
        guard let works else { throw CoreError.missingResource("Works database") }
        return try await works.sectionSummaries(workID: workID)
    }

    func translationMetadata(_ translation: TranslationID) async -> BibleTranslationMetadata? {
        guard let bible else { return nil }
        return try? await bible.metadata(for: translation)
    }

    func installedCalendarCoverage() async -> CalendarCoverage? {
        guard let companionRepository,
              let readings = try? await companionRepository.readings() else { return nil }
        return CompanionCalendar.coverage(readings.dates)
    }

    func search(_ request: BibleSearchRequest) async throws -> BibleSearchResponse {
        guard let searchRepository else { throw CoreError.missingResource("search database") }
        return try await searchRepository.search(request)
    }

    /// Rebuilds the Spotlight entries for saved bookmarks and notes. It runs after each change to saved data.
    func refreshSpotlightSaved() {
        guard library != nil else { return }
        spotlightRefreshWanted = true
        guard spotlightRefreshTask == nil else { return }
        spotlightRefreshTask = Task { [weak self] in
            // One task runs at a time. A change during a run sets the flag, so the loop reads the list again.
            // Each pass reads the list after the last change, so no stale result reaches the index.
            while let self, self.spotlightRefreshWanted {
                self.spotlightRefreshWanted = false
                let saved = try? await self.library?.listSavedItems(filter: .all)
                // A failed pass is not retried at once. The next saved change runs a new refresh.
                _ = await SpotlightIndexer.replaceSaved(saved)
            }
            self?.spotlightRefreshTask = nil
        }
    }

    /// Indexes books and chapters of the current edition, and the saved items. Called after startup.
    func refreshSpotlightAll() async {
        let translation = preferences.translation
        await SpotlightIndexer.indexBible(translation: translation, books: await books(translation: translation))
        refreshSpotlightSaved()
    }

    func savedItems(filter: SavedFilter = .all) async throws -> [SavedItem] {
        guard let library else { throw CoreError.unreadableLibrary("saved items unavailable") }
        return try await library.listSavedItems(filter: filter)
    }

    func deleteSavedItem(_ item: SavedItem) async throws {
        guard let library else { throw CoreError.unreadableLibrary("saved items unavailable") }
        try await library.delete(item)
        refreshSpotlightSaved()
    }

    func restoreSavedItem(_ item: SavedItem) async throws {
        guard let library else { throw CoreError.unreadableLibrary("saved items unavailable") }
        try await library.restore(item)
        refreshSpotlightSaved()
    }

    func note(for passage: PassageID) async throws -> String {
        guard let library else { throw CoreError.unreadableLibrary("saved notes unavailable") }
        return try await library.note(for: passage)
    }

    func saveNote(_ passage: PassageSelection, text: String) async throws {
        guard let library else { throw CoreError.unreadableLibrary("saved notes unavailable") }
        try await library.saveNote(passage, text: text)
        refreshSpotlightSaved()
    }

    func deleteNote(for passage: PassageSelection) async throws {
        guard let library else { throw CoreError.unreadableLibrary("saved notes unavailable") }
        try await library.saveNote(passage, text: "")
        refreshSpotlightSaved()
    }

    func isBookmarked(_ passage: PassageID) async throws -> Bool {
        guard let library else { throw CoreError.unreadableLibrary("bookmarks unavailable") }
        return try await library.isBookmarked(passage)
    }

    func toggleBookmark(_ passage: PassageSelection) async throws -> Bool {
        guard let library else { throw CoreError.unreadableLibrary("bookmarks unavailable") }
        let marked = try await library.toggleBookmark(passage)
        refreshSpotlightSaved()
        return marked
    }

    func applyHighlight(_ passage: PassageSelection, color: HighlightColor) async throws {
        guard let library else { throw CoreError.unreadableLibrary("highlights unavailable") }
        try await library.applyHighlight(passage, color: color)
        refreshSpotlightSaved()
    }

    func clearHighlight(_ passage: PassageSelection) async throws {
        guard let library else { throw CoreError.unreadableLibrary("highlights unavailable") }
        try await library.clearHighlight(passage)
        refreshSpotlightSaved()
    }

    func chapterHighlights(translation: TranslationID, bookCode: String, chapter: Int) async -> [String: HighlightColor] {
        guard let library else { return [:] }
        do {
            let values = try await library.chapterHighlights(
                translationID: translation.rawValue,
                bookCode: bookCode,
                chapter: chapter
            )
            return Dictionary(values.map { ($0.verse, $0.color) }, uniquingKeysWith: { _, newest in newest })
        } catch {
            return [:]
        }
    }

    func saveReaderLocation(bookCode: String, chapter: Int, scrollY: Double,
                            anchor: ReaderAnchor? = nil) async {
        guard let code = BookCode(rawValue: bookCode),
              let location = try? ReaderLocation(
                bookCode: code,
                chapter: chapter,
                scrollY: scrollY,
                updatedAt: Int64(Date().timeIntervalSince1970 * 1_000),
                anchor: anchor
              ) else { return }
        await apply(.setReaderLocation(location))
    }

    func translationAttribution(_ translation: TranslationID) async -> String {
        guard let bible else { return "" }
        return (try? await bible.metadata(for: translation).attribution) ?? ""
    }

    func translationAbbreviation(_ translation: TranslationID) async -> String {
        guard let bible else { return "" }
        return (try? await bible.metadata(for: translation).abbreviation) ?? ""
    }

    func saveCalendarNotifications(_ requested: CalendarNotificationSettings) async throws -> CalendarNotificationSettings {
        guard let noticeService else { throw CoreError.missingResource("notification service") }
        do {
            let saved = try await noticeService.saveCalendar(requested)
#if DEBUG
            await captureSystemNoticeSnapshot(phase: "calendar-save", outcome: "success")
#endif
            return saved
        } catch {
#if DEBUG
            await captureSystemNoticeSnapshot(phase: "calendar-save", outcome: "failure")
#endif
            throw error
        }
    }

    func saveRosaryReminder(_ requested: RosaryReminderSettings) async throws -> RosaryReminderSettings {
        guard let noticeService else { throw CoreError.missingResource("notification service") }
        do {
            let saved = try await noticeService.saveRosary(requested)
#if DEBUG
            await captureSystemNoticeSnapshot(phase: "rosary-save", outcome: "success")
#endif
            return saved
        } catch {
#if DEBUG
            await captureSystemNoticeSnapshot(phase: "rosary-save", outcome: "failure")
#endif
            throw error
        }
    }

    // MARK: Reading progress (E7)

    func readingProgress() async -> ReadingProgressData {
        await progressStore?.data() ?? ReadingProgressData()
    }

    func setChapterRead(_ isRead: Bool, book: String, chapter: Int) async {
        guard let progressStore else { return }
        do { try await progressStore.setRead(isRead, book: book, chapter: chapter) } catch { return }
        progressRevision += 1
        await mirrorProgressToWidgets()
    }

    func startReadingPlan(_ id: String?, now: Date = Date(), timeZone: TimeZone = .autoupdatingCurrent) async {
        guard let progressStore else { return }
        let key = ReadingProgressMath.dayKey(now, timeZone: timeZone)
        do { try await progressStore.startPlan(id, startKey: key) } catch { return }
        progressRevision += 1
        await mirrorProgressToWidgets()
    }

    func resetReadingProgress() async {
        guard let progressStore else { return }
        do { try await progressStore.reset() } catch { return }
        progressRevision += 1
        await mirrorProgressToWidgets()
    }

    func saveReadingReminder(_ requested: ReadingReminderSettings) async throws -> ReadingReminderSettings {
        guard let noticeService, let progressStore else { throw CoreError.missingResource("notification service") }
        let saved = try await noticeService.saveReadingReminder(requested)
        try await progressStore.setReminder(saved)
        progressRevision += 1
        return saved
    }

    // MARK: Widget and notification hand-off (B4b)

    private static let progressTotal = 21

    /// The next unread chapters for today. A plan gives the chapters of its day. With no plan, the next unread chapter.
    private func todayChapters(_ data: ReadingProgressData) -> [Int] {
        let read = data.readChapters("JHN")
        if let id = data.planID, let plan = ReadingPlan.plan(id: id), let key = data.planStartKey {
            let day = ReadingProgressMath.dayIndex(startKey: key, today: featureNow(), timeZone: featureTimeZone)
            return plan.chapters(forDay: day).filter { !read.contains($0) }
        }
        return (1...Self.progressTotal).first { !read.contains($0) }.map { [$0] } ?? []
    }

    /// A short scripture excerpt for the reading reminder: verse 1 of the first chapter for today.
    func readingExcerpt() async -> String? {
        let data = await readingProgress()
        let chapter = todayChapters(data).first ?? 1
        guard let passage = await passage(translation: preferences.translation, bookCode: "JHN", chapter: chapter,
                                          startVerse: "1", endVerse: "1") else { return nil }
        return "John \(chapter):1 — \(passage.scriptureText)"
    }

    /// Copies a small summary to the app group. The widgets read it. Old keys stay as they are.
    func mirrorProgressToWidgets() async {
        guard let defaults = UserDefaults(suiteName: widgetGroup) else { return }
        let data = await readingProgress()
        defaults.set(data.readChapters("JHN").count, forKey: WidgetHandoff.readKey)
        defaults.set(Self.progressTotal, forKey: WidgetHandoff.totalKey)
        defaults.set(todayChapters(data), forKey: WidgetHandoff.todayKey)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetHandoff.progressWidgetKind)
    }

    private var widgetGroup: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.nrsv.verse"
    }

    /// Applies what the widget, a control, or a notification action saved while the app was closed.
    func consumeHandoff(using router: AppRouter) async {
        if let defaults = UserDefaults(suiteName: widgetGroup) {
            let done = defaults.array(forKey: WidgetHandoff.pendingDoneKey) as? [Int] ?? []
            if !done.isEmpty {
                defaults.removeObject(forKey: WidgetHandoff.pendingDoneKey)
                for chapter in done where (1...Self.progressTotal).contains(chapter) {
                    await setChapterRead(true, book: "JHN", chapter: chapter)
                }
            }
            if let route = defaults.string(forKey: WidgetHandoff.pendingRouteKey) {
                defaults.removeObject(forKey: WidgetHandoff.pendingRouteKey)
                if let url = URL(string: route) { enqueueExternalURL(url, using: router) }
            }
        }
        await mirrorProgressToWidgets()
    }

    func refreshLocalNotifications() async {
        guard let noticeService, startupComplete, hasNativeState, !settingSaveUncertain else { return }
        do {
            try await noticeService.refresh()
        } catch {
            #if DEBUG
            NSLog("John notification refresh failed: %@", error.localizedDescription)
            #endif
        }
    }

    func notificationPermissionStatus() async -> NoticeAuthorizationStatus {
        guard let noticeService else { return .notDetermined }
        return await noticeService.permissionStatus()
    }

    private func configureNoticeService() {
        noticeService = LocalNoticeService(
            center: SystemNoticeCenter(),
            now: { Date() },
            timeZone: { .autoupdatingCurrent },
            readCommitted: { [weak self] in
                guard let self, self.startupComplete, let state = self.committedNativeState,
                      !self.settingSaveUncertain else {
                    throw LocalNoticeError.transactionFailed(
                        operation: "Reading saved notification settings",
                        cause: "Restart John before you change notification settings.",
                        rollbackFailures: []
                    )
                }
                return state
            },
            readCalendars: { [weak self] in
                guard let repository = self?.companionRepository else {
                    throw CoreError.missingResource("calendar resources")
                }
                async let readings = repository.readings()
                async let celebrations = repository.celebrations()
                return try await (readings, celebrations)
            },
            commit: { [weak self] mutation in
                guard let self, await self.applyWithResult(mutation) else {
                    throw LocalNoticeError.transactionFailed(
                        operation: "Saving notification settings",
                        cause: "The setting could not be saved.",
                        rollbackFailures: []
                    )
                }
            },
            readReadingReminder: { [weak self] in await self?.progressStore?.data().reminder },
            readExcerpt: { [weak self] in await self?.readingExcerpt() },
            readSaints: { [weak self] in
                guard let repository = self?.companionRepository else {
                    throw CoreError.missingResource("saints calendars")
                }
                return try await repository.saintsCalendars()
            }
        )
    }

    func rotatingVerse(at instant: Date, timeZone: TimeZone, translation: TranslationID,
                       scope: RotationScope, intervalMinutes: Int) async -> RotatingVerse? {
        guard let rotation,
              let count = try? await rotation.poolCount(translation: translation, scope: scope),
              let slot = try? RotationMath.slot(at: instant,
                                                utcOffsetSeconds: timeZone.secondsFromGMT(for: instant),
                                                intervalMinutes: intervalMinutes),
              let index = try? RotationMath.index(for: slot, count: count) else { return nil }
        return try? await rotation.verse(translation: translation, scope: scope, at: index)
    }

    private func writeWidgetProjection(_ state: NativePersistentState, reload: Bool) async {
        let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.nrsv.verse"
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        let translation = TranslationID(rawValue: state.translationID) ?? .webCE
        let abbreviation = await translationAbbreviation(translation)
        let attribution = await translationAttribution(translation)
        if defaults.string(forKey: "widgetSchemaVersion") != "2" {
            defaults.removeObject(forKey: "verses")
        }
        defaults.set("2", forKey: "widgetSchemaVersion")
        defaults.set(state.rotationIntervalMinutes, forKey: "intervalMinutes")
        defaults.set(state.verseScope.rawValue, forKey: "scope")
        defaults.set(state.translationID, forKey: "translationId")
        defaults.set(abbreviation, forKey: "abbreviation")
        defaults.set(attribution, forKey: "attribution")
        guard reload else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: "VerseWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "VerseTimerWidget")
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
