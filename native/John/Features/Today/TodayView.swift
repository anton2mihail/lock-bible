import SwiftUI
import UIKit
import JohnCore

struct TodayView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var novenaProgress: [String: Int] = [:]

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var model: TodayModel { runtime.today }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.dateLine)
                        .font(JohnTypography.sans(11, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(colors.tint)
                        .accessibilityIdentifier("today-date")
                    Text("A little closer to God.")
                        .font(JohnTypography.title(36))
                        .tracking(-0.8)
                        .foregroundStyle(colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("today-title")
                        .accessibilityAddTraits(.isHeader)
                    Text("Scripture for your day. Space for your soul.")
                        .font(JohnTypography.sans(17))
                        .foregroundStyle(colors.textDim)
                }

                Button {
                    router.push(.daily(model.dateKey))
                } label: {
                    VStack(spacing: 0) {
                        artwork(model.season.artworkName)
                            .aspectRatio(1.7, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .clipped()
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.heroTitle)
                                    .font(JohnTypography.serif(24))
                                    .foregroundStyle(colors.text)
                                    .multilineTextAlignment(.leading)
                                Text("\(model.season.title) · Today’s readings")
                                    .font(JohnTypography.sans(14))
                                    .foregroundStyle(colors.textDim)
                            }
                            Spacer(minLength: 0)
                            FeatherIcon(name: "arrow-up-right", size: 21, color: colors.tint)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colors.card)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("today-readings-card")
                .accessibilityLabel("\(model.heroTitle). \(model.season.title), Today’s readings")

                Text("United States · Roman Rite")
                    .font(JohnTypography.sans(16))
                    .foregroundStyle(colors.textDim)
                    .padding(.top, -4)
                    .accessibilityIdentifier("today-calendar-label")

                VStack(alignment: .leading, spacing: 16) {
                    SectionHeading(title: "Make room for prayer")
                    ActionRow(title: "Pray the Rosary", subtitle: model.suggestedRosary.title, image: "mary.jpg") {
                        router.push(.rosaryGuide(model.suggestedRosary.id))
                    }
                    ActionRow(title: model.prayerTitle, subtitle: model.prayerSubtitle, image: "prayer.jpg") {
                        let id = Calendar.current.component(.hour, from: model.now) < 17 ? "morning" : "evening"
                        router.push(.prayer(id))
                    }
                    ForEach(novenaProgress.sorted(by: { $0.key < $1.key }), id: \.key) { id, day in
                        ActionRow(title: novenaName(id), subtitle: "Continue with day \(day)") {
                            router.push(.novena(id))
                        }
                    }
                }

                if let verse = model.verse {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("A WORD TO CARRY WITH YOU")
                                .font(JohnTypography.sans(11, weight: .medium))
                                .tracking(2)
                                .foregroundStyle(colors.tint)
                            Text(verse.text)
                                .font(JohnTypography.serif(24))
                                .lineSpacing(8)
                                .foregroundStyle(colors.text)
                                .textSelection(.enabled)
                            Text("\(verse.reference) · \(preferences.translation.rawValue.uppercased())")
                                .font(JohnTypography.sans(14))
                                .foregroundStyle(colors.textDim)
                            Button("Pray with this passage") {
                                openVerse(verse)
                            }
                            .font(JohnTypography.sans(15, weight: .semibold))
                            .foregroundStyle(colors.card)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(colors.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            ActionRow(title: "Verse & lock screen widget", subtitle: "Read in context, share, or set up your widget") {
                                router.push(.verseMoment(VerseMomentSelection(verse: verse, translation: preferences.translation)))
                            }
                        }
                    }
                    .accessibilityIdentifier("today-verse-card")
                }

                Button {
                    router.push(.sunday)
                } label: {
                    VStack(spacing: 0) {
                        artwork("scripture.jpg")
                            .aspectRatio(1.7, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .clipped()
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Come ready for Sunday")
                                    .font(JohnTypography.serif(24))
                                    .foregroundStyle(colors.text)
                                Text(model.sundaySubtitle)
                                    .font(JohnTypography.sans(14))
                                    .foregroundStyle(colors.textDim)
                            }
                            Spacer(minLength: 0)
                            FeatherIcon(name: "arrow-up-right", size: 21, color: colors.tint)
                        }
                        .padding(20)
                        .background(colors.card)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(spacing: 0) {
                    ActionRow(title: "Explore the Catholic faith", subtitle: "Scripture alongside the Catechism") {
                        router.push(.learn)
                    }
                    ActionRow(title: "Prepare for Confession", subtitle: "A gentle guide to returning to mercy") {
                        router.push(.confession)
                    }
                }

                Text("Your Bible, prayers, and reflections stay close. No account needed.")
                    .font(JohnTypography.sans(14))
                    .foregroundStyle(colors.textDim)
            }
            .frame(maxWidth: 740, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 42)
            .frame(maxWidth: .infinity)
        }
        .background(colors.background)
        .task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
        .onChange(of: preferences.translation) { _, _ in Task { await refresh() } }
        .onChange(of: preferences.scope) { _, _ in Task { await refresh() } }
        .onChange(of: preferences.intervalMinutes) { _, _ in Task { await refresh() } }
    }

    private func refresh() async {
        await model.refresh(translation: preferences.translation, scope: preferences.scope, intervalMinutes: preferences.intervalMinutes)
    }

    @ViewBuilder private func artwork(_ name: String) -> some View {
        if let url = model.artworkURL(name), let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Image(systemName: "book.closed").resizable().scaledToFit()
        }
    }

    private func openVerse(_ verse: RotatingVerse) {
        Task {
            guard let translation = TranslationID(rawValue: preferences.translation.rawValue),
                  let passage = await runtime.passage(translation: translation, bookCode: verse.bookCode,
                                                      chapter: verse.chapter, startVerse: verse.verseLabel,
                                                      endVerse: verse.verseLabel) else { return }
            router.openReader(passage: passage)
        }
    }

    private func novenaName(_ id: String) -> String { runtime.novenaNames[id] ?? id }
}

private struct ActionRow: View {
    let title: String
    let subtitle: String?
    var image: String? = nil
    let action: () -> Void
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if let image, let url = Bundle.main.resourceURL?.appendingPathComponent("App/Artwork/\(image)"),
                   let imageValue = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: imageValue)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(JohnTypography.sans(16, weight: .medium))
                        .foregroundStyle(colors.text)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(JohnTypography.sans(14))
                            .foregroundStyle(colors.textDim)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                FeatherIcon(name: "arrow-up-right", size: 19, color: colors.tint)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(colors.separator).frame(height: 0.5) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("action-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        .accessibilityLabel(subtitle.map { "\(title). \($0)" } ?? title)
    }
}
