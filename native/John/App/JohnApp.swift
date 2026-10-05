import SwiftUI

@main
struct JohnApp: App {
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
                    Task { await router.receive(url, using: runtime) }
                }
        }
    }
}

private struct JohnRootView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var router = router
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FlatTabBar(selection: $router.selectedTab, colors: preferences.colors(for: colorScheme))
        }
        .tint(preferences.colors(for: colorScheme).tint)
        .task {
            for url in StartupURLQueue.shared.drain() {
                await router.receive(url, using: runtime)
            }
        }
        .onChange(of: router.latestPassageRequest?.id) { _, _ in
            if let request = router.latestPassageRequest { runtime.reader.accept(request) }
        }
    }

    @ViewBuilder private func root(for tab: AppTab) -> some View {
        switch tab {
        case .today: TodayView()
        case .read: SecondaryRootView(tab: .read)
        case .saved: SecondaryRootView(tab: .saved)
        case .pray: SecondaryRootView(tab: .pray)
        case .settings: SecondaryRootView(tab: .settings)
        }
    }
}
