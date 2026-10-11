import SwiftUI

/// Settings section for optional iCloud sync (E21). It is off by default.
struct CloudSyncSettings: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        let sync = runtime.cloudSync
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(get: { sync.isEnabled }, set: { sync.setEnabled($0) })) {
                Text("Sync with iCloud").font(JohnTypography.sans(16)).foregroundStyle(colors.text)
            }
            .tint(colors.tint)
            .accessibilityIdentifier("settings-icloud-sync-toggle")
            Text("Copies your notes, bookmarks, highlights, tags and reading progress to your private iCloud. Other people cannot see them. Sync never deletes data on this device, and it never replaces newer data with older data. If you turn it off, your data stays here and in iCloud.")
                .font(JohnTypography.sans(13)).foregroundStyle(colors.textDim)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline) {
                Text(sync.statusText)
                    .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings-icloud-sync-status")
                Spacer(minLength: 8)
                if sync.isEnabled {
                    Button("Sync now") { sync.syncNow() }
                        .font(JohnTypography.sans(14, weight: .medium)).foregroundStyle(colors.tint)
                        .accessibilityIdentifier("settings-icloud-sync-now")
                }
            }
        }
        .padding(.vertical, 12)
    }
}
