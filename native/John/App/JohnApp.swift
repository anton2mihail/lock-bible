import SwiftUI
import UIKit
@preconcurrency import UserNotifications

@main
struct JohnApp: App {
    @UIApplicationDelegateAdaptor(JohnNotificationDelegate.self) private var appDelegate
    @State private var runtime = JohnRuntime()
    @State private var router = AppRouter()

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
        }
    }
}

private struct JohnRootView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            if runtime.hasNativeState && (runtime.nativeStateCapability != nil || runtime.libraryCapability != nil) {
                savedDataBanner
            }
            Group {
                if runtime.startupComplete && runtime.hasNativeState {
                    VStack(spacing: 0) {
                        NavigationStack(path: Binding(
                            get: { router.path(for: router.selectedTab) },
                            set: { router.setPath($0, for: router.selectedTab) }
                        )) {
                            root(for: router.selectedTab)
                                .toolbar(.hidden, for: .navigationBar)
                                .navigationDestination(for: AppRoute.self) { route in
                                    DestinationView(route: route)
                                }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        FlatTabBar(selection: $router.selectedTab, colors: preferences.colors(for: colorScheme))
                    }
                    .tint(preferences.colors(for: colorScheme).tint)
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

    @ViewBuilder private func root(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            CompanionTodayView(clock: { runtime.featureNow() },
                               fixedTimeZone: runtime.featureTimeZone,
                               onNavigate: { router.push(.companion($0)) },
                               onClose: {},
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
