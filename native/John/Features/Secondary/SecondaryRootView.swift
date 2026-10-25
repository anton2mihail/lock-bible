import SwiftUI
import JohnCore

struct SecondaryRootView: View {
    let tab: AppTab
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        switch tab {
        case .read:
            ReaderView()
        case .saved:
            SavedView()
        case .pray:
            PrayerHomeView(timeZone: runtime.featureTimeZone, clock: { runtime.featureNow() },
                           onNavigate: { router.push(.companion($0)) })
        case .settings:
            FullSettingsView(onOpenCalendarNotifications: { router.push(.calendarNotifications) },
                             onOpenPage: { router.push(.settingsPage($0)) })
        case .today:
            CompanionTodayView(clock: { runtime.featureNow() }, onNavigate: { router.push(.companion($0)) },
                               onOpenVerseMoment: {
                                   router.push(.verseMoment(VerseMomentSelection(verse: $0, translation: preferences.translation)))
                               })
        }
    }
}

private struct ActionLink: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(JohnTypography.serif(21))
                    Text(subtitle).font(JohnTypography.sans(14)).foregroundStyle(preferences.colors(for: colorScheme).textDim)
                }
                Spacer()
                RowChevron(color: preferences.colors(for: colorScheme).tint)
            }
            .padding(18)
            .background(preferences.colors(for: colorScheme).card, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
