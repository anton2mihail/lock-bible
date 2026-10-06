import SwiftUI
import JohnCore

struct CalendarNotificationsView: View {
    let initialSettings: CalendarNotificationSettings
    let onClose: @MainActor () -> Void
    let onSave: @MainActor (CalendarNotificationSettings) async throws -> CalendarNotificationSettings
    let onOpenSystemSettings: @MainActor () async throws -> Void

    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var settings: CalendarNotificationSettings
    @State private var showTime = false
    @State private var saving = false
    @State private var message: String?
    @State private var saveGeneration = 0
    @State private var routeGeneration = 0

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var time: Date { featureTime(hour: settings.hour, minute: settings.minute) }

    init(initialSettings: CalendarNotificationSettings,
         onClose: @escaping @MainActor () -> Void,
         onSave: @escaping @MainActor (CalendarNotificationSettings) async throws -> CalendarNotificationSettings,
         onOpenSystemSettings: @escaping @MainActor () async throws -> Void) {
        self.initialSettings = initialSettings
        self.onClose = onClose
        self.onSave = onSave
        self.onOpenSystemSettings = onOpenSystemSettings
        _settings = State(initialValue: initialSettings)
    }

    var body: some View {
        ContentPage(title: "A day in the Church", eyebrow: "Calendar notifications",
                    subtitle: "A gentle morning notice for today’s saint, feast, or liturgical observance, with the Gospel reference when available.",
                    onClose: onClose) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Notify me each day").font(JohnTypography.sans(20, weight: .medium)).foregroundStyle(colors.text)
                Toggle("Enable calendar notifications", isOn: Binding(
                    get: { settings.enabled },
                    set: { value in update { $0 = CalendarNotificationSettings(enabled: value, hour: settings.hour, minute: settings.minute) } }
                ))
                .labelsHidden()
                .tint(colors.tint)
                .disabled(saving)
                .accessibilityLabel("Enable calendar notifications")
                .accessibilityIdentifier("calendar-notifications-enabled")

                Button {
                    guard !saving else { return }
                    showTime = true
                    message = nil
                } label: {
                    HStack(spacing: 16) {
                        FeatherIcon(name: "clock", size: 20, color: colors.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Delivery time").font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.text)
                            Text(time.formatted(date: .omitted, time: .shortened)).font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                        }
                        Spacer()
                        Text(showTime ? "⌃" : "⌄").font(JohnTypography.sans(20)).foregroundStyle(colors.tint)
                    }
                    .padding(.vertical, 12)
                    .frame(minHeight: 72)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(saving)
                .accessibilityIdentifier("calendar-notifications-delivery-time")

                if showTime {
                    FeatureTimePicker(date: Binding(get: { time }, set: { value in
                        let parts = featureTimeParts(value)
                        update { $0 = CalendarNotificationSettings(enabled: settings.enabled, hour: parts.hour, minute: parts.minute) }
                    }), style: .spinner, accessibilityLabel: "Calendar notification time")
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .disabled(saving)
                        .accessibilityIdentifier("calendar-notifications-time-picker")
                }

                Text("United States · Roman Rite. Parish calendars and transferred feasts can differ. Each notice opens that date’s readings.")
                    .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                Text("Notices are scheduled on your phone up to a month ahead. Open John 1:1 at least monthly to keep them coming, and after changing time zones to update the delivery time.")
                    .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)

                if let message {
                    Text(message).font(JohnTypography.sans(16)).foregroundStyle(colors.text)
                        .contentAnnouncement(message)
                }

                Button(action: save) {
                    Text(saving ? "Saving…" : "Save notifications")
                        .font(JohnTypography.sans(16, weight: .medium))
                        .foregroundStyle(colors.text)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(colors.card, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(saving)
                .accessibilityIdentifier("calendar-notifications-save")

                Button {
                    let routeID = routeGeneration
                    Task {
                        do {
                            try await onOpenSystemSettings()
                            guard routeID == routeGeneration else { return }
                        } catch {
                            guard routeID == routeGeneration else { return }
                            showMessage("Open your device’s Settings app to manage notification permissions.")
                        }
                    }
                } label: {
                    Text("Device notification settings").font(JohnTypography.sans(16, weight: .medium))
                        .foregroundStyle(colors.text).frame(maxWidth: .infinity, minHeight: 56)
                        .background(colors.card, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(saving)
                .accessibilityIdentifier("calendar-notifications-system-settings")
            }
        }
        .onDisappear { routeGeneration &+= 1 }
    }

    private func update(_ change: (inout CalendarNotificationSettings) -> Void) {
        guard !saving else { return }
        var next = settings
        change(&next)
        settings = next
        message = nil
    }

    private func save() {
        guard !saving else { return }
        saving = true
        message = nil
        saveGeneration &+= 1
        let saveID = saveGeneration
        let routeID = routeGeneration
        let requested = settings
        Task { @MainActor in
            do {
                let committed = try await onSave(requested)
                guard routeID == routeGeneration, saveID == saveGeneration else { return }
                settings = committed
                showMessage(committed.enabled ? "Calendar notifications are on." : "Calendar notifications are off.")
            } catch {
                guard routeID == routeGeneration, saveID == saveGeneration else { return }
                showMessage(error.localizedDescription.isEmpty ? "Could not update notifications. Please try again." : error.localizedDescription)
            }
            if routeID == routeGeneration { saving = false }
        }
    }

    private func showMessage(_ value: String) {
        saveGeneration &+= 1
        message = value
    }
}
