import SwiftUI
import JohnCore

struct WorksChapterCommentaryView: View {
    let bookCode: String?
    let chapter: Int?
    let bookName: String
    let onOpenWork: (String, Int?) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var catalog: WorkCatalog?
    @State private var failed = false

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var entries: [CommentaryEntry] {
        guard let bookCode, let chapter else { return [] }
        return catalog?.commentary[bookCode]?[String(chapter)] ?? []
    }
    private var groups: [(collection: WorkCollection?, entries: [CommentaryEntry])] {
        var order: [String] = []
        var grouped: [String: [CommentaryEntry]] = [:]
        for entry in entries {
            if grouped[entry.collectionID] == nil { order.append(entry.collectionID) }
            grouped[entry.collectionID, default: []].append(entry)
        }
        return order.map { id in (catalog?.collections.first { $0.id == id }, grouped[id] ?? []) }
    }

    var body: some View {
        WorksPage {
            if failed {
                missing("No readings on this chapter", canRetry: true)
            } else if let catalog, entries.isEmpty {
                missing("No readings on this chapter", canRetry: false)
            } else if catalog != nil {
                VStack(alignment: .leading, spacing: 8) {
                    WorksEyebrow("THE FATHERS ON")
                    Text("\(bookName) \(chapter ?? 0)")
                        .font(JohnTypography.sans(36, weight: .bold))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Bold", size: 36, targetLineHeight: 44))
                        .foregroundStyle(colors.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(WorksSourceText.plural(entries.count, "reading")) · \(WorksSourceText.plural(groups.count, "author"))")
                        .font(JohnTypography.sans(16)).foregroundStyle(colors.textDim)
                }

                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.collection?.author ?? "")
                            .font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.textDim)
                            .padding(.bottom, 4)
                        ForEach(group.entries, id: \.self) { entry in
                            Button { onOpenWork(entry.workID, entry.sectionIndex) } label: {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.sectionTitle).font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.text)
                                        Text(entry.workTitle).font(JohnTypography.sans(12)).foregroundStyle(colors.textDim)
                                    }
                                    Spacer(minLength: 0)
                                    Text("›").font(JohnTypography.sans(24)).foregroundStyle(colors.tint)
                                }
                                .frame(minHeight: 68)
                                .padding(.vertical, 8)
                                .overlay(alignment: .bottom) { Rectangle().fill(colors.separator).frame(height: 1 / displayScale) }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(WorksPressStyle())
                            .accessibilityLabel("\(entry.sectionTitle), \(entry.workTitle), \(group.collection?.author ?? "")")
                            .accessibilityIdentifier("commentary-\(entry.workID)-\(entry.sectionIndex)")
                        }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
        .task(id: "\(bookCode ?? "")|\(chapter ?? 0)") { await loadCatalog() }
    }

    @ViewBuilder private func missing(_ text: String, canRetry: Bool) -> some View {
        ContentUnavailableView {
            Label(text, systemImage: "text.book.closed")
        } actions: {
            if canRetry { Button("Try again") { Task { await loadCatalog() } } }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    @MainActor private func loadCatalog() async {
        do { catalog = try await runtime.worksCatalog(); failed = catalog == nil }
        catch { failed = true }
    }
}
