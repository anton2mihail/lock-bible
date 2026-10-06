import SwiftUI
import JohnCore

struct RosaryReminderView: View {
    let initialSettings: RosaryReminderSettings
    let onSave: @MainActor (RosaryReminderSettings) async throws -> RosaryReminderSettings
    let readCommittedSettings: @MainActor () -> RosaryReminderSettings

    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var settings: RosaryReminderSettings
    @State private var saving = false
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var saveGeneration = 0
    @State private var routeGeneration = 0

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var errorColor: Color { colorScheme == .dark ? Color(hex: 0xF4876B) : Color(hex: 0xC03403) }
    private var time: Date { featureTime(hour: settings.hour, minute: settings.minute) }
    private let weekdays: [(value: Int, short: String, long: String)] = [
        (1, "Sun", "Sunday"), (2, "Mon", "Monday"), (3, "Tue", "Tuesday"),
        (4, "Wed", "Wednesday"), (5, "Thu", "Thursday"), (6, "Fri", "Friday"), (7, "Sat", "Saturday"),
    ]

    init(initialSettings: RosaryReminderSettings,
         onSave: @escaping @MainActor (RosaryReminderSettings) async throws -> RosaryReminderSettings,
         readCommittedSettings: @escaping @MainActor () -> RosaryReminderSettings) {
        self.initialSettings = initialSettings
        self.onSave = onSave
        self.readCommittedSettings = readCommittedSettings
        _settings = State(initialValue: initialSettings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PRAYER RHYTHM").font(JohnTypography.sans(12, weight: .semibold)).tracking(1.5).foregroundStyle(colors.tint)
                    Text("Rosary reminder").font(JohnTypography.sans(36, weight: .bold)).foregroundStyle(colors.text).accessibilityAddTraits(.isHeader)
                    Text("Your phone schedules this reminder locally. It works without an account, server, or internet connection.")
                        .font(JohnTypography.sans(16)).foregroundStyle(colors.textDim)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Remind me to pray").font(JohnTypography.sans(16, weight: .semibold)).foregroundStyle(colors.text)
                            Text(settings.enabled ? "Reminder will repeat until turned off" : "No notifications scheduled")
                                .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                        }
                        Spacer()
                        Toggle("Enable Rosary reminder", isOn: Binding(
                            get: { settings.enabled },
                            set: { value in update { $0 = RosaryReminderSettings(enabled: value, frequency: settings.frequency, hour: settings.hour, minute: settings.minute, weekday: settings.weekday, notificationID: settings.notificationID) } }
                        ))
                        .labelsHidden().tint(colors.tint).disabled(saving)
                        .accessibilityLabel("Enable Rosary reminder")
                        .accessibilityIdentifier("rosary-reminder-enabled")
                    }
                    .frame(minHeight: 76).padding(.vertical, 12)
                    separator

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Repeat").font(JohnTypography.sans(14, weight: .semibold)).foregroundStyle(colors.text)
                        HStack(spacing: 8) {
                            frequencyButton("Every day", value: "daily")
                            frequencyButton("Once a week", value: "weekly")
                        }
                        .padding(4)
                        .background(colors.background, in: RoundedRectangle(cornerRadius: 12))
                    }.padding(.vertical, 16)

                    if settings.frequency == "weekly" {
                        separator
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Day").font(JohnTypography.sans(14, weight: .semibold)).foregroundStyle(colors.text)
                            HStack(spacing: 4) {
                                ForEach(weekdays, id: \.value) { day in
                                    let selected = settings.weekday == day.value
                                    Button { update { $0 = RosaryReminderSettings(enabled: settings.enabled, frequency: settings.frequency, hour: settings.hour, minute: settings.minute, weekday: day.value, notificationID: settings.notificationID) } } label: {
                                        Text(String(day.short.prefix(1))).font(JohnTypography.sans(14, weight: .semibold))
                                            .foregroundStyle(selected ? colors.card : colors.text)
                                            .frame(maxWidth: .infinity, minHeight: 40)
                                            .aspectRatio(1, contentMode: .fit)
                                            .frame(maxHeight: 44)
                                            .background(selected ? colors.tint : colors.background, in: Circle())
                                    }
                                    .buttonStyle(RosaryReminderPressStyle()).disabled(saving)
                                    .accessibilityLabel(day.long).accessibilityAddTraits(selected ? .isSelected : [])
                                    .accessibilityIdentifier("rosary-reminder-weekday-\(day.value)")
                                }
                            }
                            Text(weekdays.first(where: { $0.value == settings.weekday })?.long ?? "Monday")
                                .font(JohnTypography.sans(12)).foregroundStyle(colors.textDim)
                        }.padding(.vertical, 16)
                    }

                    separator
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Time").font(JohnTypography.sans(14, weight: .semibold)).foregroundStyle(colors.text)
                            Text("Uses your device’s current time zone").font(JohnTypography.sans(12)).foregroundStyle(colors.textDim)
                        }
                        Spacer(minLength: 8)
                        FeatureTimePicker(date: Binding(get: { time }, set: { value in
                            let parts = featureTimeParts(value)
                            update { $0 = RosaryReminderSettings(enabled: settings.enabled, frequency: settings.frequency, hour: parts.hour, minute: parts.minute, weekday: settings.weekday, notificationID: settings.notificationID) }
                        }), style: .compact, minuteInterval: 5, accessibilityLabel: "Rosary reminder time")
                            .disabled(saving)
                            .accessibilityIdentifier("rosary-reminder-time")
                    }
                    .frame(minHeight: 76).padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
                .background(colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("ON-DEVICE REMINDER").font(JohnTypography.sans(12, weight: .semibold)).tracking(1.5).foregroundStyle(colors.tint)
                    Text("The operating system stores and delivers the schedule. The app does not upload the time or require push-notification tokens.")
                        .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                }
                .padding(.leading, 16)
                .overlay(alignment: .leading) { Rectangle().fill(colors.tint).frame(width: 3) }

                if let message { Text(message).font(JohnTypography.sans(14, weight: .semibold)).foregroundStyle(colors.tint).frame(maxWidth: .infinity).multilineTextAlignment(.center).contentAnnouncement(message) }
                if let errorMessage { Text(errorMessage).font(JohnTypography.sans(14)).foregroundStyle(errorColor).frame(maxWidth: .infinity).multilineTextAlignment(.center).contentAnnouncement(errorMessage) }

                Button(action: save) {
                    Text(saving ? "Saving…" : settings.enabled ? "Save reminder" : "Turn reminder off")
                        .font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.card)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(colors.text, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain).disabled(saving).accessibilityIdentifier("rosary-reminder-save")
            }
            .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 48)
        }
        .background(colors.background)
        .onDisappear { routeGeneration &+= 1 }
    }

    private var separator: some View { Rectangle().fill(colors.separator).frame(height: 1) }

    private func frequencyButton(_ title: String, value: String) -> some View {
        let selected = settings.frequency == value
        return Button { update { $0 = RosaryReminderSettings(enabled: settings.enabled, frequency: value, hour: settings.hour, minute: settings.minute, weekday: settings.weekday, notificationID: settings.notificationID) } } label: {
            Text(title).font(JohnTypography.sans(14, weight: .semibold)).foregroundStyle(selected ? colors.card : colors.text)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(selected ? colors.tint : .clear, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(RosaryReminderPressStyle()).disabled(saving).accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("rosary-reminder-frequency-\(value)")
    }

    private func update(_ change: (inout RosaryReminderSettings) -> Void) {
        guard !saving else { return }
        var next = settings
        change(&next)
        settings = next
        message = nil
        errorMessage = nil
    }

    private func save() {
        guard !saving else { return }
        saving = true
        message = nil
        errorMessage = nil
        saveGeneration &+= 1
        let saveID = saveGeneration
        let routeID = routeGeneration
        let requested = settings
        Task { @MainActor in
            do {
                let committed = try await onSave(requested)
                guard routeID == routeGeneration, saveID == saveGeneration else { return }
                settings = committed
                message = committed.enabled ? "Saved · \(summary(committed))" : "Reminder turned off"
            } catch {
                guard routeID == routeGeneration, saveID == saveGeneration else { return }
                settings = readCommittedSettings()
                errorMessage = error.localizedDescription.isEmpty ? "The reminder could not be saved." : error.localizedDescription
            }
            if routeID == routeGeneration { saving = false }
        }
    }

    private func summary(_ value: RosaryReminderSettings) -> String {
        let date = featureTime(hour: value.hour, minute: value.minute)
        let time = date.formatted(date: .omitted, time: .shortened)
        if value.frequency == "daily" { return "Every day at \(time)" }
        let day = weekdays.first(where: { $0.value == value.weekday })?.long ?? "Monday"
        return "Every \(day) at \(time)"
    }
}

private struct RosaryReminderPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}
