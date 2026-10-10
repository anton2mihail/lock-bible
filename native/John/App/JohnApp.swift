import SwiftUI
import UIKit
import TipKit
import CoreSpotlight
@preconcurrency import UserNotifications

@main
struct JohnApp: App {
    @UIApplicationDelegateAdaptor(JohnNotificationDelegate.self) private var appDelegate
    @State private var runtime = JohnRuntime()
    @State private var router = AppRouter()

    init() { JohnTips.configure() }

    var body: some Scene {
        WindowGroup {
            JohnRootView()
                .environment(runtime)
                .environment(router)
                .environment(runtime.preferences)
                .preferredColorScheme(runtime.preferences.preferredColorScheme)
                .onOpenURL { url in
                    runtime.enqueueExternalURL(url, using: router)
                }
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
                }
                #endif
        }
    }
}

private struct JohnRootView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var todayZoom

    var body: some View {
        VStack(spacing: 0) {
            if runtime.hasNativeState && (runtime.nativeStateCapability != nil || runtime.libraryCapability != nil) {
                savedDataBanner
            }
            Group {
                if runtime.startupComplete && runtime.hasNativeState {
                    tabShell
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
            await runtime.drainExternalURLs(using: router)
        }
        .task(id: runtime.startupComplete && runtime.hasNativeState ? preferences.translation.rawValue : "") {
            guard runtime.startupComplete, runtime.hasNativeState else { return }
            await runtime.refreshSpotlightAll()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
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
        // Keep the five-tab bar on iPad. The sidebar style would add a second navigation model.
        .tabViewStyle(.tabBarOnly)
        // Only the Reader is long continuous reading. Other tabs keep the full bar for direct tab changes.
        .tabBarMinimizeBehavior(router.selectedTab == .read ? Self.readerMinimizeBehavior : .never)
        .tint(preferences.colors(for: colorScheme).tint)
    }

    private func tab(_ tab: AppTab) -> some TabContent<AppTab> {
        Tab(value: tab) {
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
        return true
    }

    static func bind(runtime: JohnRuntime, router: AppRouter) {
        self.runtime = runtime
        self.router = router
        UNUserNotificationCenter.current().delegate = shared
    }

    private static let shared = JohnNotificationDelegate()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
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
        completionHandler([.banner, .sound])
    }

    nonisolated private static func routeURL(_ rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        if rawValue == "/pray/rosary" { return URL(string: "nrsv://pray/rosary") }
        guard rawValue.hasPrefix("/daily?date=") else { return nil }
        let query = rawValue.dropFirst("/daily".count)
        guard let url = URL(string: "nrsv://daily\(query)"),
              let parsed = ExternalRouteParser.parse(url),
              case .daily = parsed else { return nil }
        return url
    }
}
