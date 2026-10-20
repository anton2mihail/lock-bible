import SwiftUI
import UIKit
import JohnCore

struct MySaintsView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @State private var saints: [PersonalSaint] = []
    @State private var query = ""
    @State private var error: String?
    private var saved: [PersonalSaint] { saints.filter { runtime.committedNativeState?.mySaints.profiles[$0.id]?.saved == true } }

    var body: some View {
        ContentPage(title: "My Saints", eyebrow: nil, subtitle: "Return to the saints you have chosen.") {
            if let error { ContentMutedText(text: error) }
            if saved.isEmpty {
                ContentMutedText(text: "Choose a saint you would like to know. Keep their prayers, story, and feast day together.")
            } else {
                ForEach(saved) { saint in
                    ContentActionRow(title: saint.name, subtitle: saint.subtitle, imageName: saint.artwork) { open(saint) }
                }
            }
            ContentSectionTitle(title: "Find a saint")
            ContentInputField(placeholder: "Search by name", text: $query, accessibilityLabel: "Find a personal saint")
            ForEach(saints.filter { query.isEmpty || $0.name.localizedStandardContains(query) }) { saint in
                ContentActionRow(title: saint.name, subtitle: saint.subtitle, imageName: saint.artwork) { open(saint) }
            }
            ContentMutedText(text: "These personal pages use reviewed links to the existing calendars. More saints are available in Saints & feast days.")
            ContentButton(title: "Browse saints & feast days") { router.push(.companion(.saints)) }
            ContentButton(title: "My Saint widget") { router.push(.companion(.saintWidget)) }
        }
        .task {
            do { saints = try await runtime.companionRepository?.personalSaints() ?? [] }
            catch { self.error = "The saints could not be loaded. Open this page again to retry." }
        }
    }
    private func open(_ saint: PersonalSaint) { router.push(.companion(.saint(id: saint.id))) }
}

struct MySaintsTodaySection: View {
    let onNavigate: (CompanionRoute) -> Void
    @Environment(JohnRuntime.self) private var runtime
    @State private var saints: [PersonalSaint] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContentActionRow(title: "My Saints", subtitle: "A saint to return to") { onNavigate(.mySaints) }
            ForEach(saints.filter { runtime.committedNativeState?.mySaints.profiles[$0.id]?.saved == true }) { saint in
                ContentActionRow(title: saint.name, subtitle: saint.subtitle, imageName: saint.artwork) { onNavigate(.saint(id: saint.id)) }
            }
            ForEach(saints.filter {
                guard let profile = runtime.committedNativeState?.mySaints.profiles[$0.id] else { return false }
                return SaintDates.planIsDue(profile, now: runtime.featureNow(), timeZone: runtime.featureTimeZone)
            }) { saint in
                if let id = saint.novenaID {
                    ContentActionRow(title: "Pray with \(saint.name)", subtitle: "Your planned novena is ready") { onNavigate(.novena(id: id)) }
                }
            }
        }
        .task { saints = (try? await runtime.companionRepository?.personalSaints()) ?? [] }
    }
}

private struct PersonalSaintHost<Content: View>: View {
    let id: String
    @ViewBuilder var content: (PersonalSaint) -> Content
    @Environment(JohnRuntime.self) private var runtime
    @State private var saints: [PersonalSaint]?
    @State private var failed = false
    var body: some View {
        Group {
            if let saint = saints?.first(where: { $0.id == id }) { content(saint) }
            else {
                ContentPage(title: "My Saints", eyebrow: nil, subtitle: nil) {
                    if failed || saints != nil { ContentMutedText(text: "This personal saint page is not available. Return to My Saints to choose another.") }
                    else { ProgressView() }
                }
            }
        }.task(id: id) {
            do { saints = try await runtime.companionRepository?.personalSaints() ?? [] }
            catch { failed = true }
        }
    }
}

struct PersonalSaintView: View {
    let id: String
    var body: some View { PersonalSaintHost(id: id) { SaintPersonalPage(saint: $0) } }
}

private struct SaintPersonalPage: View {
    let saint: PersonalSaint
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var scheme
    @State private var section = "His life"
    @State private var editor: String?
    @State private var draft = ""
    @State private var busy = false
    @State private var message: String?
    @State private var confirmRemove = false
    private var colors: JohnColors { preferences.colors(for: scheme) }
    private var profile: SaintProfile { runtime.committedNativeState?.mySaints.profiles[saint.id] ?? SaintProfile() }
    private var observance: SaintObservance? { saint.observance(for: profile) }
    private var lifeTitle: String { ["st-therese", "st-anne", "st-monica"].contains(saint.id) ? "Her life" : "His life" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let art = saint.artwork {
                    ContentArtwork(name: art).scaledToFill().frame(height: 186).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityHidden(true)
                    if let credit = saint.artworkCredit { ContentMutedText(text: credit) }
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(saint.name).font(JohnTypography.serif(32)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button {
                        if profile.saved && profile.reminderEnabled { confirmRemove = true }
                        else { changeSaved() }
                    } label: { Image(systemName: profile.saved ? "heart.fill" : "heart").frame(width: 44, height: 44) }
                        .foregroundStyle(colors.tint).disabled(busy)
                        .accessibilityLabel(profile.saved ? "Remove from My Saints" : "Save to My Saints")
                        .accessibilityIdentifier("saint-save")
                }
                ContentMutedText(text: saint.subtitle)
                if let id = saint.novenaID {
                    SaintPrimaryButton(title: "Pray with \(saint.name)") { router.push(.companion(.novena(id: id))) }
                }
                HStack(spacing: 22) {
                    ForEach(["His life", "Prayers", "My notes"], id: \.self) { item in
                        Button { section = item } label: {
                            Text(item == "His life" ? lifeTitle : item)
                                .font(JohnTypography.sans(14, weight: section == item ? .semibold : .regular))
                                .foregroundStyle(section == item ? colors.text : colors.textDim)
                                .padding(.vertical, 12)
                                .overlay(alignment: .bottom) {
                                    if section == item { Rectangle().fill(colors.tint).frame(height: 2) }
                                }
                        }.buttonStyle(.plain).accessibilityAddTraits(section == item ? .isSelected : [])
                    }
                    Spacer(minLength: 0)
                }.overlay(alignment: .bottom) { Rectangle().fill(colors.separator).frame(height: 0.5) }
                if section == "His life" {
                    if let observance {
                        Text(observance.displayAccount.isEmpty ? "The source has no short life account." : observance.displayAccount)
                            .font(JohnTypography.sans(16)).lineSpacing(5).textSelection(.enabled)
                        ContentMutedText(text: observance.displayIsSummary ? "English summary · \(observance.calendarName)" : "Excerpt · \(observance.calendarName)")
                        if let url = URL(string: observance.sourceURL) { Link("Read the full life account ↗", destination: url).foregroundStyle(colors.tint).frame(minHeight: 44) }
                        feastRow(observance)
                    }
                    reasonSection
                } else if section == "Prayers" {
                    if let id = saint.novenaID {
                        ContentActionRow(title: "Novena to \(saint.name)", subtitle: "Nine days of prayer · Available offline") { router.push(.companion(.novena(id: id))) }
                    } else { ContentMutedText(text: "There is no prayer linked to this saint in the current library.") }
                    ContentButton(title: "Open the prayer library") { router.push(.companion(.prayers)) }
                    if let observance { feastRow(observance) }
                } else {
                    reasonSection
                    ContentButton(title: "Add an intention or thanks") { draft = ""; editor = "Intention or thanks" }
                    ForEach(profile.notes.sorted { $0.createdAt > $1.createdAt }) { note in
                        ContentPanel {
                            ContentMutedText(text: note.createdAt.formatted(date: .abbreviated, time: .omitted))
                            Text(note.text).font(JohnTypography.sans(16)).textSelection(.enabled)
                            ContentButton(title: "Delete note") {
                                var next = profile; next.notes.removeAll { $0.id == note.id }; save(next)
                            }
                        }
                    }
                    ContentMutedText(text: "Notes stay on this device. They do not appear in widgets or notifications.")
                }
                if let message { ContentMutedText(text: message).accessibilityIdentifier("saint-message") }
            }.foregroundStyle(colors.text).padding(24).frame(maxWidth: 740).frame(maxWidth: .infinity)
        }.background(colors.background)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Widget") { router.push(.companion(.saintWidget)) } } }
        .confirmationDialog("Remove from My Saints?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove saint") { changeSaved() }
        } message: { Text("Your notes and feast reminder will remain. You can turn off the reminder on the feast page.") }
        .sheet(isPresented: Binding(get: { editor != nil }, set: { if !$0 { editor = nil } })) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stored only on this device.").font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                    TextEditor(text: $draft).font(JohnTypography.sans(16)).frame(minHeight: 180)
                        .accessibilityLabel("Saint note").accessibilityIdentifier("saint-note-input")
                    if let message { Text(message) }
                    Spacer()
                }.padding(24).background(colors.background)
                .navigationTitle(editor == "Reason" ? "Why I chose \(saint.name)" : "An intention or thanks")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editor = nil }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            var next = profile
                            if editor == "Reason" { next.reason = draft.trimmingCharacters(in: .whitespacesAndNewlines) }
                            else { next.notes.append(SaintNote(kind: "intention-or-thanks", text: draft.trimmingCharacters(in: .whitespacesAndNewlines))) }
                            save(next, close: true)
                        }.disabled(busy || (editor != "Reason" && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    }
                }
            }.interactiveDismissDisabled(busy)
        }
    }
    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContentSectionTitle(title: "Why I chose \(saint.name)")
            if !profile.reason.isEmpty { Text(profile.reason).font(JohnTypography.serif(17)).textSelection(.enabled) }
            ContentButton(title: profile.reason.isEmpty ? "Add a private note" : "Edit my note") { draft = profile.reason; editor = "Reason" }
        }
    }
    private func feastRow(_ observance: SaintObservance) -> some View {
        ContentActionRow(title: "Prepare for the feast", subtitle: "\(saintMonthDay(observance.monthDay)) · \(observance.calendarName)") { router.push(.companion(.saintFeast(id: saint.id))) }
    }
    private func changeSaved() { var next = profile; next.saved.toggle(); save(next) }
    private func save(_ value: SaintProfile, close: Bool = false) {
        busy = true
        Task { @MainActor in
            let success = await runtime.applyWithResult(.setSaintProfile(id: saint.id, value: value))
            busy = false; message = success ? nil : "Your change could not be saved. Please try again."
            if success && close { editor = nil }
        }
    }
}

struct SaintFeastView: View {
    let id: String
    var body: some View { PersonalSaintHost(id: id) { SaintFeastPage(saint: $0) } }
}

private struct SaintFeastPage: View {
    let saint: PersonalSaint
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @State private var selection = ""
    @State private var enabled = false
    @State private var time = Date()
    @State private var busy = false
    @State private var message: String?
    private var profile: SaintProfile { runtime.committedNativeState?.mySaints.profiles[saint.id] ?? SaintProfile() }
    private var observance: SaintObservance? { saint.commemorations.first { $0.id == selection } ?? saint.observance(for: profile) }
    private var feast: Date? { observance.flatMap { SaintDates.nextOccurrence(monthDay: $0.monthDay, from: runtime.featureNow(), timeZone: runtime.featureTimeZone) } }
    private var today: Bool { feast.map { CompanionCalendar.dateKey($0, timeZone: runtime.featureTimeZone) == CompanionCalendar.dateKey(runtime.featureNow(), timeZone: runtime.featureTimeZone) } ?? false }

    var body: some View {
        SaintScrollPage {
            HStack(spacing: 12) {
                if let artwork = saint.artwork {
                    ContentArtwork(name: artwork).scaledToFill().frame(width: 52, height: 52).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(saint.name).font(JohnTypography.sans(16, weight: .semibold))
                    if let observance { ContentMutedText(text: observance.calendarName) }
                }
            }
            Text(today ? "Remember \(saint.name) today." : "Prepare for the feast.")
                .font(JohnTypography.serif(32)).accessibilityAddTraits(.isHeader)
            if let observance, let feast {
                Picker("Commemoration", selection: $selection) {
                    ForEach(saint.commemorations) { item in Text("\(saintMonthDay(item.monthDay)) · \(item.calendarName)").tag(item.id) }
                }.pickerStyle(.menu)
                HStack(spacing: 18) {
                    Text(feast.formatted(.dateTime.day())).font(JohnTypography.serif(50))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feast.formatted(.dateTime.month(.wide).year())).font(JohnTypography.sans(17, weight: .semibold))
                        ContentMutedText(text: today ? "Today" : feast.formatted(.dateTime.weekday(.wide)))
                    }
                }
                ContentMutedText(text: observance.name)
                if let note = observance.observanceNote { ContentMutedText(text: note) }
                if today {
                    if let id = saint.novenaID { SaintPrimaryButton(title: "Pray with \(saint.name)") { router.push(.companion(.novena(id: id))) } }
                    ContentButton(title: "Open the saint’s life and notes") { router.push(.companion(.saint(id: saint.id))) }
                } else if let id = saint.novenaID {
                    ContentPanel {
                        ContentSectionTitle(title: "Nine days of prayer")
                        let start = SaintDates.novenaStart(feast: feast, timeZone: runtime.featureTimeZone)
                        ContentMutedText(text: "\(start.formatted(date: .abbreviated, time: .omitted)) – \(CompanionCalendar.addDays(feast, -1, timeZone: runtime.featureTimeZone).formatted(date: .abbreviated, time: .omitted))")
                        if runtime.committedNativeState?.novenaProgress[id].map({ !$0.completedDays.isEmpty || !$0.intention.isEmpty }) == true {
                            SaintPrimaryButton(title: "Continue novena") { router.push(.companion(.novena(id: id))) }
                        } else if start <= runtime.featureNow() {
                            ContentMutedText(text: "You can begin today. Missed days are not marked as prayed.")
                            SaintPrimaryButton(title: "Begin novena") { router.push(.companion(.novena(id: id))) }
                        } else {
                            let key = CompanionCalendar.dateKey(feast, timeZone: runtime.featureTimeZone)
                            let planned = profile.plannedFeastDate == key && profile.observanceID == observance.id
                            SaintPrimaryButton(title: planned ? "Cancel novena plan" : "Plan this novena") {
                                var next = profile; next.observanceID = observance.id; next.plannedFeastDate = planned ? nil : key
                                save(next, reminder: profile.reminderEnabled)
                            }
                            if planned { ContentMutedText(text: "This novena will appear on Today when it is due.") }
                        }
                    }
                } else { ContentMutedText(text: "No sourced novena is linked to this saint. Return to the life account and prayer library.") }
                Toggle("Remind me on the feast day", isOn: $enabled)
                if enabled { DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute) }
                if selection != profile.observanceID && profile.plannedFeastDate != nil {
                    ContentMutedText(text: "Changing the commemoration cancels the existing novena plan.")
                }
                SaintPrimaryButton(title: busy ? "Saving…" : "Save feast settings") {
                    var next = profile
                    if next.observanceID != observance.id { next.plannedFeastDate = nil }
                    next.observanceID = observance.id; next.reminderEnabled = enabled
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                    next.reminderHour = parts.hour ?? 8; next.reminderMinute = parts.minute ?? 0
                    save(next, reminder: true)
                }
                if profile.reminderEnabled,
                   let date = SaintDates.reminderDate(monthDay: saint.observance(for: profile)?.monthDay ?? observance.monthDay,
                     hour: profile.reminderHour, minute: profile.reminderMinute, after: runtime.featureNow(), timeZone: runtime.featureTimeZone) {
                    ContentMutedText(text: "Next reminder: \(date.formatted(date: .abbreviated, time: .shortened))")
                }
                if let message { ContentMutedText(text: message) }
                ContentButton(title: "Notification settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                ContentMutedText(text: "Date from \(observance.calendarName). Your parish may observe a different date. An alert at the same time replaces the general calendar alert.")
                if let url = URL(string: observance.calendarURL) { Link("View calendar source ↗", destination: url) }
            }
        }.disabled(busy)
        .task(id: saint.id) {
            selection = saint.observance(for: profile)?.id ?? ""; enabled = profile.reminderEnabled
            time = Calendar.current.date(bySettingHour: profile.reminderHour, minute: profile.reminderMinute, second: 0, of: Date()) ?? Date()
        }
    }
    private func save(_ value: SaintProfile, reminder: Bool) {
        busy = true; message = nil
        Task { @MainActor in
            do {
                if reminder { try await runtime.saveSaintReminder(id: saint.id, profile: value) }
                else if !(await runtime.applyWithResult(.setSaintProfile(id: saint.id, value: value))) { throw CoreError.invalidResource("The plan could not be saved.") }
                message = "Saved."
            } catch { message = error.localizedDescription }
            busy = false
        }
    }
}

struct SaintWidgetSetupView: View {
    @Environment(JohnRuntime.self) private var runtime
    @State private var saints: [PersonalSaint] = []
    @State private var selected = ""
    @State private var quiet = false
    @State private var message: String?
    var body: some View {
        ContentPage(title: "My Saint widget", eyebrow: nil, subtitle: "Keep one saint in view.") {
            Picker("Saint", selection: $selected) {
                Text("Choose a saint").tag("")
                ForEach(saints) { Text($0.name).tag($0.id) }
            }
            Toggle("Artwork and name only", isOn: $quiet)
            if let saint = saints.first(where: { $0.id == selected }) {
                ContentPanel {
                    if let art = saint.artwork { ContentArtwork(name: art).scaledToFill().frame(height: 160).clipped().clipShape(RoundedRectangle(cornerRadius: 18)) }
                    Text(saint.name).font(JohnTypography.serif(28))
                    if !quiet, let observance = saint.observance(for: runtime.committedNativeState?.mySaints.profiles[saint.id] ?? SaintProfile()) {
                        Text(SaintWidgetContent(saint: saint, observance: observance).text).font(JohnTypography.serif(17)).lineLimit(4)
                    }
                }
            }
            SaintPrimaryButton(title: "Save widget choice") {
                Task { message = await runtime.applyWithResult(.setSaintWidget(id: selected.isEmpty ? nil : selected, quiet: quiet)) ? "Widget choice saved." : "The choice could not be saved. Try again." }
            }
            if let message { ContentMutedText(text: message) }
            ContentSectionTitle(title: "Add to your Home Screen")
            ContentMutedText(text: "1. Touch and hold the Home Screen.\n2. Open Edit, then Add Widget.\n3. Choose John 1:1, then My Saint.\n4. Choose a size and add the widget.")
            ContentMutedText(text: "For the Lock Screen, touch and hold it, choose Customize, and add the My Saint widget. You can edit each widget to choose a different saint.")
            ContentMutedText(text: "Personal notes and intentions never appear in this widget.")
        }.task {
            saints = (try? await runtime.companionRepository?.personalSaints()) ?? []
            selected = runtime.committedNativeState?.mySaints.widgetSaintID ?? ""
            quiet = runtime.committedNativeState?.mySaints.widgetQuiet ?? false
        }
    }
}

private func saintMonthDay(_ value: String) -> String {
    let date = CompanionCalendar.parseDate("2024-\(value)", fallback: Date(), timeZone: .gmt)
    let formatter = DateFormatter(); formatter.timeZone = .gmt; formatter.dateFormat = "MMMM d"
    return formatter.string(from: date)
}

private struct SaintPrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let colors = preferences.colors(for: scheme)
        Button(action: action) {
            Text(title).font(JohnTypography.sans(16, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 12)
                .foregroundStyle(colors.card).background(colors.tint, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}
private struct SaintScrollPage<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let colors = preferences.colors(for: scheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .padding(24).frame(maxWidth: 740).frame(maxWidth: .infinity)
        }.background(colors.background).foregroundStyle(colors.text).tint(colors.tint)
    }
}
