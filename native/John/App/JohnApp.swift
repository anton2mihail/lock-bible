import SwiftUI
import UIKit
import TipKit
import CoreSpotlight
import JohnCore
@preconcurrency import UserNotifications

@main
struct JohnApp: App {
    @UIApplicationDelegateAdaptor(JohnNotificationDelegate.self) private var appDelegate
    @State private var runtime = JohnRuntime()
    @State private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    init() { JohnTips.configure() }

    var body: some Scene {
        WindowGroup {
            JohnRootView()
                .environment(runtime)
                .environment(router)
                .environment(runtime.preferences)
                .preferredColorScheme(runtime.preferences.preferredColorScheme)
                .onChange(of: router.selectedTab) { _, tab in IntentDonor.donate(tab: tab) }
                .onOpenURL { url in
                    runtime.enqueueExternalURL(url, using: router)
                }
                .onContinueUserActivity(JohnActivity.reading) { activity in
                    if let url = JohnActivity.url(from: activity) { runtime.enqueueExternalURL(url, using: router) }
                }
                .onContinueUserActivity(JohnActivity.saved) { activity in
                    if let url = JohnActivity.url(from: activity) { runtime.enqueueExternalURL(url, using: router) }
                }
                .task { runtime.cloudSync.attach(runtime) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        runtime.cloudSync.syncNow()
                        ReviewPrompt.recordOpen()
                        Task { await runtime.fathers.refresh() }
                    }
                }
                .task { ReviewPrompt.recordOpen(); runtime.fathers.start() }
                .onChange(of: runtime.savedRevision) { _, _ in runtime.cloudSync.localDataChanged() }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                          let url = SpotlightIndexer.route(forIdentifier: identifier) else { return }
                    runtime.enqueueExternalURL(url, using: router)
                }
                #if DEBUG
                .task {
                    // UI test hook: the launch argument -JohnSpotlightIdentifier <id> takes the same route as a Spotlight tap.
                    if let identifier = UserDefaults.standard.string(forKey: "JohnSpotlightIdentifier"),
                       let url = SpotlightIndexer.route(forIdentifier: identifier) {
                        runtime.enqueueExternalURL(url, using: router)
                    }
                    // UI test hook: -JohnOpenURL <url> takes the same route as an App Intent.
                    if let raw = UserDefaults.standard.string(forKey: "JohnOpenURL"), let url = URL(string: raw) {
                        runtime.enqueueExternalURL(url, using: router)
                    }
                }
                #endif
        }
        .commands { JohnCommands(runtime: runtime, router: router) }
    }
}

/// Reader actions that the menu bar and the keyboard call (E30). The visible Reader publishes them as a focused scene value.
struct ReaderCommandActions {
    var goTo: () -> Void
    var markRead: (() -> Void)?
    var readAloud: (() -> Void)?
}

extension FocusedValues {
    @Entry var readerCommands: ReaderCommandActions?
}

/// Menu-bar commands (E30). The app keeps one window: `UIApplicationSupportsMultipleScenes` stays false.
/// Runtime, router and the persistence store are single shared objects, so a second scene would share one tab selection and one
/// push path. That would break the saved-anchor logic. Multiple windows are not supported.
struct JohnCommands: Commands {
    let runtime: JohnRuntime
    let router: AppRouter
    @FocusedValue(\.readerCommands) private var reader

    private static let sizes: [ReaderTextSize] = [.small, .medium, .large, .extraLarge]

    private func stepTextSize(_ delta: Int) {
        let current = runtime.preferences.reading.textSize
        guard let index = Self.sizes.firstIndex(of: current) else { return }
        let target = Self.sizes[min(max(index + delta, 0), Self.sizes.count - 1)]
        guard target != current else { return }
        Task { _ = await runtime.applyWithResult(.setReaderTextSize(target)) }
    }

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Search") {
                if router.path(for: router.selectedTab).last != .search { router.push(.search) }
            }
            .keyboardShortcut("f", modifiers: .command)
        }
        CommandMenu("Reader") {
            Button("Go To…") { reader?.goTo() }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(reader == nil)
            Button("Mark Chapter Read") { reader?.markRead?() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(reader?.markRead == nil)
            Button("Read Aloud") { reader?.readAloud?() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(reader?.readAloud == nil)
            Divider()
            Button("Increase Text Size") { stepTextSize(1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Decrease Text Size") { stepTextSize(-1) }
                .keyboardShortcut("-", modifiers: .command)
        }
        CommandGroup(after: .sidebar) {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                Button(tab.rawValue) { router.select(tab) }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
        }
    }
}

private struct JohnRootView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var splitVisibility: NavigationSplitViewVisibility = .all
    @Namespace private var todayZoom
    @Namespace private var readerZoom

    var body: some View {
        VStack(spacing: 0) {
            if runtime.hasNativeState && (runtime.nativeStateCapability != nil || runtime.libraryCapability != nil) {
                savedDataBanner
            }
            Group {
                if runtime.startupComplete && runtime.hasNativeState {
                    // E31: iPad at regular width uses a sidebar. The iPhone, including a landscape Max, keeps the TabView.
                    if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
                        splitShell
                    } else {
                        tabShell
                    }
                } else if runtime.startupComplete {
                    VStack(spacing: 14) {
                        Text("Saved data needs attention")
                            .font(JohnTypography.serif(24))
                        Text(runtime.startupStatus)
                            .font(JohnTypography.sans(15))
                            .multilineTextAlignment(.center)
                        #if DEBUG
                        if let library = runtime.libraryCapability {
                            Text(library)
                                .font(JohnTypography.sans(14))
                                .multilineTextAlignment(.center)
                        }
                        #endif
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(preferences.colors(for: colorScheme).background)
                } else {
                    ProgressView(runtime.startupStatus)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            JohnNotificationDelegate.bind(runtime: runtime, router: router)
            for url in StartupURLQueue.shared.drain() {
                runtime.enqueueExternalURL(url, using: router)
            }
            await runtime.start()
            await runtime.consumeHandoff(using: router)
            await runtime.drainExternalURLs(using: router)
        }
        .task(id: runtime.startupComplete && runtime.hasNativeState ? preferences.translation.rawValue : "") {
            guard runtime.startupComplete, runtime.hasNativeState else { return }
            await runtime.refreshSpotlightAll()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await runtime.consumeHandoff(using: router)
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(3_600)) }
                catch { return }
                await runtime.refreshLocalNotifications()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await runtime.refreshLocalNotifications() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await runtime.refreshLocalNotifications() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task { await runtime.refreshLocalNotifications() }
        }
        .onChange(of: router.latestPassageRequest?.id) { _, _ in
            if let request = router.latestPassageRequest { runtime.reader.accept(request) }
        }
        .onChange(of: router.latestChapterRequest?.id) { _, _ in
            if let request = router.latestChapterRequest { runtime.reader.accept(request) }
        }
        #if DEBUG
        .onChange(of: router.sheet) { _, sheet in
            NSLog("John sheet state changed: %@", sheet?.rawValue ?? "none")
        }
        #endif
    }

    private var savedDataBanner: some View {
        VStack(spacing: 3) {
            Text(runtime.settingSaveUncertain
                 ? "The app cannot confirm that the setting was saved. Restart the app before you change saved settings."
                 : runtime.nativeStateCapability != nil
                     ? "Some settings need recovery. Your saved values remain protected."
                     : "Some saved items are not available.")
            #if DEBUG
            Text(runtime.nativeStateCapability ?? runtime.libraryCapability ?? "")
                .font(.system(size: 9, design: .monospaced))
                .accessibilityIdentifier("saved-data-debug-detail")
            #endif
        }
        .font(JohnTypography.sans(13))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(preferences.colors(for: colorScheme).card, in: Capsule())
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .accessibilityIdentifier("saved-data-status")
    }

    /// The system tab bar (Liquid Glass on iOS 26). AppRouter owns the selection and each tab's push path.
    private var tabShell: some View {
        // A tap on the selected tab also calls `set` with the same value. The router then pops that tab to its root.
        TabView(selection: Binding(get: { router.selectedTab }, set: { router.selectFromTabBar($0) })) {
            tab(.today)
            tab(.read)
            tab(.saved)
            tab(.pray)
            tab(.settings)
        }
        // Compact width keeps the five-tab bar. Regular iPad width uses the split shell (E31).
        .tabViewStyle(.tabBarOnly)
        // Only the Reader is long continuous reading. Other tabs keep the full bar for direct tab changes.
        .tabBarMinimizeBehavior(router.selectedTab == .read ? Self.readerMinimizeBehavior : .never)
        // E27: the mini-player shows only while audio is active. It has no entrance animation.
        .modifier(AudioMiniPlayerAccessory(isActive: AudioMiniPlayer.isActive(in: runtime)))
        .transaction(value: AudioMiniPlayer.isActive(in: runtime)) { $0.disablesAnimations = true }
        .tint(preferences.colors(for: colorScheme).tint)
    }

    /// E31: sidebar (the five tabs) and detail. The detail is the same per-tab NavigationStack as in the TabView,
    /// so the router paths, the zoom namespaces and the Reader/Saved pushes work in both layouts.
    private var splitShell: some View {
        NavigationSplitView(columnVisibility: $splitVisibility) {
            List(selection: Binding(get: { Optional(router.selectedTab) }, set: { if let tab = $0 { router.select(tab) } })) {
                ForEach(AppTab.allCases) { tab in
                    Label { Text(tab.rawValue) } icon: { tabIcon(tab) }
                        .tag(tab)
                        .frame(minHeight: 44)
                        .hoverEffect()
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier(tab.identifier)
                }
            }
            .navigationTitle("John")
            .accessibilityIdentifier("ipad-sidebar")
        } detail: {
            tabStack(router.selectedTab)
                .id(router.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if AudioMiniPlayer.isActive(in: runtime) { AudioMiniPlayer().padding(.horizontal, 12).padding(.bottom, 6) }
        }
        .transaction(value: AudioMiniPlayer.isActive(in: runtime)) { $0.disablesAnimations = true }
        .tint(preferences.colors(for: colorScheme).tint)
    }

    private func tabStack(_ tab: AppTab) -> some View {
        NavigationStack(path: Binding(
            get: { router.path(for: tab) },
            set: { router.setPath($0, for: tab) }
        )) {
            tabRoot(tab)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppRoute.self) { route in
                    DestinationView(route: route)
                        .todayZoomDestination(route)
                }
        }
        // Only the Today tab has zoom sources: its art cards open their pages with a zoom (audit B7).
        .environment(\.todayZoomNamespace, tab == .today ? todayZoom : nil)
        .environment(\.readerZoomNamespace, readerZoom)
    }

    private func tab(_ tab: AppTab) -> some TabContent<AppTab> {
        Tab(value: tab) {
            tabStack(tab)
            // Scroll content goes under the floating bar with the default (automatic) bottom scroll edge effect.
        } label: {
            Label {
                Text(tab.rawValue)
            } icon: {
                tabIcon(tab)
            }
        }
        .accessibilityIdentifier(tab.identifier)
    }

    @ViewBuilder private func tabRoot(_ tab: AppTab) -> some View {
        if tab == .read {
            // A new Reader root on each Read-tab entry, as with the flat bar (see AppRouter.readEntryID).
            root(for: tab).id(router.readEntryID)
        } else {
            root(for: tab)
        }
    }

    @ViewBuilder private func tabIcon(_ tab: AppTab) -> some View {
        if let image = Self.tabImages[tab] {
            Image(uiImage: image).renderingMode(.template)
        } else {
            Image(systemName: tab.fallbackSystemImage)
        }
    }

    /// The brand Feather glyphs, drawn once at the size of the old flat bar (25 pt).
    private static let tabImages: [AppTab: UIImage] = AppTab.allCases.reduce(into: [:]) { images, tab in
        images[tab] = FeatherIcon.templateImage(tab.featherIcon, size: 25)
    }

    private static let readerMinimizeBehavior: TabBarMinimizeBehavior = {
        #if DEBUG
        // UI tests can keep the full bar: `-JohnTabBarMinimize never`.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-JohnTabBarMinimize"), arguments.indices.contains(index + 1),
           arguments[index + 1] == "never" {
            return .never
        }
        #endif
        return .onScrollDown
    }()

    @ViewBuilder private func root(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            CompanionTodayView(clock: { runtime.featureNow() },
                               fixedTimeZone: runtime.featureTimeZone,
                               onNavigate: { router.push(.companion($0)) },
                               onOpenVerseMoment: {
                                   router.push(.verseMoment(VerseMomentSelection(verse: $0, translation: preferences.translation)))
                               })
        case .read: SecondaryRootView(tab: .read)
        case .saved: SecondaryRootView(tab: .saved)
        case .pray: SecondaryRootView(tab: .pray)
        case .settings: SecondaryRootView(tab: .settings)
        }
    }
}

private extension AppTab {
    var featherIcon: String {
        switch self {
        case .today: "sun"
        case .read: "book-open"
        case .saved: "bookmark"
        case .pray: "heart"
        case .settings: "settings"
        }
    }

    /// Used only if the Feather font cannot draw the glyph.
    var fallbackSystemImage: String {
        switch self {
        case .today: "sun.max"
        case .read: "book"
        case .saved: "bookmark"
        case .pray: "heart"
        case .settings: "gearshape"
        }
    }
}

@MainActor
private final class JohnNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static weak var runtime: JohnRuntime?
    private static weak var router: AppRouter?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = Self.shared
        Self.registerCategories()
        PrayerActivityController.shared.endStale()
        return true
    }

    static func bind(runtime: JohnRuntime, router: AppRouter) {
        self.runtime = runtime
        self.router = router
        UNUserNotificationCenter.current().delegate = shared
    }

    private static let shared = JohnNotificationDelegate()

    /// The reading reminder has three actions: Mark read, Snooze 1 h, and Open.
    private static func registerCategories() {
        let mark = UNNotificationAction(identifier: ReadingNoticeAction.markRead, title: "Mark read", options: [])
        let snooze = UNNotificationAction(identifier: ReadingNoticeAction.snooze, title: "Snooze 1 h", options: [])
        let open = UNNotificationAction(identifier: ReadingNoticeAction.open, title: "Open", options: [.foreground])
        let category = UNNotificationCategory(identifier: ReadingNoticeAction.category, actions: [mark, snooze, open],
                                              intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    nonisolated private static func scheduleSnooze(from content: UNNotificationContent) async {
        let snoozed = UNMutableNotificationContent()
        snoozed.title = content.title
        snoozed.body = content.body
        snoozed.userInfo = content.userInfo
        snoozed.sound = .default
        snoozed.categoryIdentifier = ReadingNoticeAction.category
        snoozed.threadIdentifier = "john.reading"
        snoozed.interruptionLevel = content.interruptionLevel
        let request = UNNotificationRequest(
            identifier: ReadingNoticeAction.snoozeIdentifier, content: snoozed,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: ReadingNoticeAction.snoozeSeconds, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        if action == ReadingNoticeAction.snooze {
            let content = response.notification.request.content
            nonisolated(unsafe) let finish = completionHandler
            Task {
                await Self.scheduleSnooze(from: content)
                finish()
            }
            return
        }
        if action == ReadingNoticeAction.markRead {
            if let defaults = WidgetHandoff.defaults {
                let today = defaults.array(forKey: WidgetHandoff.todayKey) as? [Int] ?? []
                let pending = defaults.array(forKey: WidgetHandoff.pendingDoneKey) as? [Int] ?? []
                defaults.set(Array(Set(pending + today)).sorted(), forKey: WidgetHandoff.pendingDoneKey)
            }
            completionHandler()
            Task { @MainActor in
                if let runtime = Self.runtime, let router = Self.router { await runtime.consumeHandoff(using: router) }
            }
            return
        }
        let route = Self.routeURL(response.notification.request.content.userInfo["url"] as? String)
        completionHandler()
        guard let route else { return }
        Task { @MainActor in
            if let runtime = Self.runtime, let router = Self.router {
                runtime.enqueueExternalURL(route, using: router)
            } else {
                StartupURLQueue.shared.enqueue(route)
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(FocusQuiet.muteReminders ? [] : [.banner, .sound])
    }

    nonisolated private static func routeURL(_ rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        if let url = URL(string: rawValue), let route = ExternalRouteParser.parse(url),
           case .saint = route { return url }
        if rawValue == "/pray/rosary" { return URL(string: "nrsv://pray/rosary") }
        if rawValue == "/read/john" { return URL(string: "nrsv://read?book=JHN") }
        guard rawValue.hasPrefix("/daily?date=") else { return nil }
        let query = rawValue.dropFirst("/daily".count)
        guard let url = URL(string: "nrsv://daily\(query)"),
              let parsed = ExternalRouteParser.parse(url),
              case .daily = parsed else { return nil }
        return url
    }
}
