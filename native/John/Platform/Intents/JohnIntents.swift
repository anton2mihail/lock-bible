import AppIntents
import Foundation

/// App Intents for Siri, Shortcuts, Spotlight, and the Action Button.
/// Each intent opens the app with an `nrsv://` URL. `AppRouter.receive` handles the URL.

struct ReadTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Read today's reading"
    static let description = IntentDescription("Opens the readings for today.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(IntentRoutes.today))
    }
}

struct OpenRosaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Open the Rosary"
    static let description = IntentDescription("Opens the Rosary guide.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(IntentRoutes.rosary))
    }
}

struct OpenJohnChapterIntent: AppIntent {
    static let title: LocalizedStringResource = "Open John chapter"
    static let description = IntentDescription("Opens a chapter of the Gospel of John.")

    @Parameter(title: "Chapter", default: 1, inclusiveRange: (1, 21))
    var chapter: Int

    static var parameterSummary: some ParameterSummary { Summary("Open John chapter \(\.$chapter)") }

    init() {}
    init(chapter: Int) { self.chapter = chapter }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(IntentRoutes.john(chapter: chapter)))
    }
}

struct ReadAloudIntent: AppIntent {
    static let title: LocalizedStringResource = "Read aloud"
    static let description = IntentDescription("Opens the chapter you read last and starts to read it aloud.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(IntentRoutes.readAloud))
    }
}

struct AddNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a note"
    static let description = IntentDescription("Opens a new note on the first verse of the Gospel of John.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(IntentRoutes.note))
    }
}

enum IntentRoutes {
    static let today = URL(string: "nrsv://daily")!
    static let rosary = URL(string: "nrsv://pray/rosary")!
    static let readAloud = URL(string: "nrsv://readaloud")!
    static let note = URL(string: "nrsv://note")!
    static func john(chapter: Int) -> URL {
        URL(string: "nrsv://read?book=JHN&chapter=\(min(max(chapter, 1), 21))")!
    }
}

struct JohnShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ReadTodayIntent(),
                    phrases: ["Read today's reading in \(.applicationName)",
                              "Today's reading in \(.applicationName)"],
                    shortTitle: "Today's reading", systemImageName: "book")
        AppShortcut(intent: OpenRosaryIntent(),
                    phrases: ["Open the Rosary in \(.applicationName)",
                              "Pray the Rosary with \(.applicationName)"],
                    shortTitle: "Rosary", systemImageName: "circle.dotted")
        AppShortcut(intent: OpenJohnChapterIntent(),
                    phrases: ["Open John chapter in \(.applicationName)",
                              "Open a John chapter in \(.applicationName)"],
                    shortTitle: "John chapter", systemImageName: "text.book.closed")
        AppShortcut(intent: ReadAloudIntent(),
                    phrases: ["Read aloud in \(.applicationName)",
                              "Read to me with \(.applicationName)"],
                    shortTitle: "Read aloud", systemImageName: "speaker.wave.2")
        AppShortcut(intent: AddNoteIntent(),
                    phrases: ["Add a note in \(.applicationName)",
                              "Write a note in \(.applicationName)"],
                    shortTitle: "Add a note", systemImageName: "square.and.pencil")
    }
}

// MARK: - Focus filter

/// The two settings that a Focus filter changes. The notification delegate and the tips read them.
enum FocusQuiet {
    static let muteKey = "john.focus.muteReminders"
    static let tipsKey = "john.focus.hideTips"
    static var muteReminders: Bool { UserDefaults.standard.bool(forKey: muteKey) }
    static var hideTips: Bool { UserDefaults.standard.bool(forKey: tipsKey) }
    static func set(muteReminders: Bool, hideTips: Bool) {
        UserDefaults.standard.set(muteReminders, forKey: muteKey)
        UserDefaults.standard.set(hideTips, forKey: tipsKey)
    }
}

struct JohnFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Quiet the app"
    static let description = IntentDescription("Mutes reminders and hides tips while this Focus is on.")

    @Parameter(title: "Mute reminders", default: true) var muteReminders: Bool
    @Parameter(title: "Hide tips", default: true) var hideTips: Bool

    var displayRepresentation: DisplayRepresentation {
        var parts: [String] = []
        if muteReminders { parts.append(String(localized: "Reminders muted")) }
        if hideTips { parts.append(String(localized: "Tips hidden")) }
        return DisplayRepresentation(title: "Quiet the app",
                                     subtitle: LocalizedStringResource(stringLiteral: parts.joined(separator: ", ")))
    }

    func perform() async throws -> some IntentResult {
        FocusQuiet.set(muteReminders: muteReminders, hideTips: hideTips)
        await MainActor.run { JohnTips.applyFocus() }
        return .result()
    }
}

// MARK: - Donation

enum IntentDonor {
    /// Tells the system that the user did this action. Siri and Shortcuts use the history for suggestions.
    @MainActor static func donate(tab: AppTab) {
        Task {
            switch tab {
            case .today: _ = try? await ReadTodayIntent().donate()
            case .pray: _ = try? await OpenRosaryIntent().donate()
            case .read: _ = try? await OpenJohnChapterIntent(chapter: 1).donate()
            default: break
            }
        }
    }
}
