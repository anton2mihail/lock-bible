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

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            if runtime.hasNativeState && (runtime.nativeStateCapability != nil || runtime.libraryCapability != nil) {
                savedDataBanner
            }
            Group {
                if runtime.startupComplete && runtime.hasNativeState {
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
            await runtime.start()
            await runtime.drainExternalURLs(using: router)
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
        case .today: TodayView()
        case .read: SecondaryRootView(tab: .read)
        case .saved: SecondaryRootView(tab: .saved)
        case .pray: SecondaryRootView(tab: .pray)
        case .settings: SecondaryRootView(tab: .settings)
        }
    }
}
