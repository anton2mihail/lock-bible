import SwiftUI
import JohnCore

struct DestinationView: View {
    let route: AppRoute
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences

    var body: some View {
        switch route {
        case .search:
            SearchView()
        case .passage(let passage):
            ReaderDestination(passage: passage)
        case .daily(let value):
            if value.contains(":") {
                ReaderDestination(reference: value)
            } else {
                CompanionPage(title: "Today’s readings", eyebrow: value, subtitle: "Read the passages for this day.") {
                    Button("Open John 1:1") { open("John 1:1") }
                }
            }
        case .sunday:
            CompanionPage(title: "Sunday", eyebrow: "Prepare", subtitle: "Read, reflect, return.") { MutedText(text: "Your Sunday reading plan is ready.") }
        case .rosaryGuide(let id):
            CompanionPage(title: "The Rosary", eyebrow: id.capitalized, subtitle: "Pray through the mysteries.") { MutedText(text: "Begin with the Apostles’ Creed.") }
        case .prayer(let id):
            CompanionPage(title: id.capitalized, eyebrow: "Prayer", subtitle: "Take a quiet moment.") { MutedText(text: "Read slowly. Pause where a word stays with you.") }
        case .novena(let id):
            CompanionPage(title: "Novena", eyebrow: id, subtitle: "Continue your prayer.") { MutedText(text: "Your prayer is ready.") }
        case .verseMoment:
            CompanionPage(title: "Verse & widget", eyebrow: "Share", subtitle: "Keep a verse close.") { MutedText(text: "Widget setup will be available here.") }
        case .learn:
            CompanionPage(title: "Explore the faith", eyebrow: "Learn", subtitle: "Scripture alongside the Catechism.") { MutedText(text: "Learning guides will appear here.") }
        case .confession:
            CompanionPage(title: "Prepare for Confession", eyebrow: "Return to mercy", subtitle: "A gentle guide.") { MutedText(text: "Take this guide one step at a time.") }
        }
    }

    private func open(_ reference: String) {
        Task {
            if let passage = await runtime.passage(reference: reference, translation: preferences.translation) {
                router.openReader(passage: passage)
            }
        }
    }
}

private struct SearchView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @State private var query = ""
    @State private var message = "Enter a reference, such as John 1:1."

    var body: some View {
        CompanionPage(title: "Search", eyebrow: "Scripture", subtitle: "Find a passage by reference.") {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("John 1:1", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("search-reference-input")
                    Button("Open passage") {
                        Task {
                            if let passage = await runtime.passage(reference: query, translation: preferences.translation) {
                                router.openReader(passage: passage)
                            } else { message = "No passage matched this reference." }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Text(message).font(JohnTypography.sans(14))
                }
            }
        }
    }
}

struct ReaderDestination: View {
    @Environment(JohnRuntime.self) private var runtime
    let reference: String
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @State private var passage: PassageSelection?

    init(passage: PassageSelection) {
        reference = "\(passage.bookName) \(passage.chapter):\(passage.startVerse.rawValue)"
        _passage = State(initialValue: passage)
    }

    init(reference: String) {
        self.reference = reference
    }

    var body: some View {
        CompanionPage(title: passage.map { "\($0.bookName) \($0.chapter)" } ?? "Reader", eyebrow: passage?.translationID.rawValue.uppercased(), subtitle: reference) {
            if let passage {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(passage.verses, id: \.index) { verse in
                            Text("\(verse.verse.rawValue)  \(verse.text)")
                                .font(readerFont)
                                .lineSpacing(readerLineSpacing)
                                .accessibilityIdentifier("reader-verse-\(verse.verse.rawValue)")
                        }
                        Button("Aa  Reader appearance") { router.sheet = .readerAppearance }
                            .accessibilityIdentifier("reader-appearance-button")
                    }
                }
            } else {
                ProgressView().task { passage = await runtime.passage(reference: reference, translation: preferences.translation) }
            }
        }
        .sheet(isPresented: Binding(get: { router.sheet == .readerAppearance }, set: { if !$0 { router.sheet = nil } })) {
            NavigationStack {
                SettingsControls()
                    .padding()
                    .navigationTitle("Reader appearance")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { router.sheet = nil }
                                .accessibilityIdentifier("reader-appearance-close")
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }

    private var readerFont: Font {
        let size: CGFloat
        switch preferences.reading.textSize {
        case .small: size = 18
        case .medium: size = 21
        case .large: size = 25
        case .extraLarge: size = 29
        }
        return preferences.reading.typeface == .serif ? JohnTypography.serif(size) : JohnTypography.sans(size)
    }

    private var readerLineSpacing: CGFloat {
        switch preferences.reading.lineSpacing {
        case .compact: 3
        case .comfortable: 7
        case .relaxed: 11
        }
    }
}
