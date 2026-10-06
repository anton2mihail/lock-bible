import SwiftUI
import JohnCore

struct WorksCollectionView: View {
    let collectionID: String?
    let onClose: () -> Void
    let onOpenWork: (String, Int?) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var catalog: WorkCatalog?
    @State private var loadingFailed = false

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var collection: WorkCollection? { catalog?.collections.first { $0.id == collectionID } }
    private var works: [WorkMetadata] {
        guard let collectionID else { return [] }
        return (catalog?.works ?? []).filter { $0.collectionID == collectionID }.sorted { $0.order < $1.order }
    }
    private var groups: [(kind: String, works: [WorkMetadata])] {
        WorksSourceText.kindOrder.compactMap { kind in
            let bucket = works.filter { $0.kind == kind }
            return bucket.isEmpty ? nil : (kind, bucket)
        }
    }

    var body: some View {
        WorksPage(onClose: onClose) {
            if loadingFailed {
                missing("That author isn’t available")
            } else if catalog != nil, let collection {
                Button(action: onClose) {
                    HStack(spacing: 6) { Text("‹"); Text("Library") }
                        .font(JohnTypography.sans(16, weight: .semibold)).foregroundStyle(colors.tint)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to the library")
                VStack(alignment: .leading, spacing: 8) {
                    if let era = collection.era { WorksEyebrow(era.uppercased()) }
                    Text(collection.author)
                        .font(JohnTypography.sans(36, weight: .bold))
                        .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Bold", size: 36, targetLineHeight: 44))
                        .foregroundStyle(colors.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(WorksSourceText.plural(collection.workCount, "work")) · \(WorksSourceText.plural(collection.sectionCount, "section")) · reads offline")
                        .font(JohnTypography.sans(16)).foregroundStyle(colors.textDim)
                }
                ForEach(groups, id: \.kind) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WorksSourceText.kindLabel(group.kind))
                            .font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.textDim)
                            .padding(.bottom, 4)
                        ForEach(group.works, id: \.id) { work in
                            Button { onOpenWork(work.id, nil) } label: {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(work.title).font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.text)
                                        Text(work.sectionCount > 1
                                             ? "\(WorksSourceText.plural(work.sectionCount, "section")) · \(WorksSourceText.readingLength(work.words))"
                                             : WorksSourceText.readingLength(work.words))
                                            .font(JohnTypography.sans(12)).foregroundStyle(colors.textDim)
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
                            .accessibilityLabel("\(work.title). \(WorksSourceText.plural(work.sectionCount, "section")). \(WorksSourceText.readingLength(work.words)).")
                            .accessibilityIdentifier("work-\(work.id)")
                        }
                    }
                }
                Text(collection.attribution).font(JohnTypography.sans(12)).foregroundStyle(colors.textDim)
            } else if catalog != nil {
                missing("That author isn’t available")
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
        .task(id: collectionID) { await loadCatalog() }
    }

    @ViewBuilder private func missing(_ text: String) -> some View {
        VStack(spacing: 16) {
            Text(text).font(JohnTypography.sans(20, weight: .medium)).foregroundStyle(colors.text)
            Button(action: onClose) { Text("Go back").font(JohnTypography.sans(14)).foregroundStyle(colors.tint) }
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    @MainActor private func loadCatalog() async {
        do { catalog = try await runtime.worksCatalog(); loadingFailed = catalog == nil }
        catch { loadingFailed = true }
    }
}
