import SwiftUI
import JohnCore

struct WorksLibraryView: View {
    let onOpenCollection: (String) -> Void
    let onOpenWork: (String, Int?) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var catalog: WorkCatalog?
    @State private var loadingFailed = false

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var totalWords: Int { catalog?.collections.reduce(0) { $0 + $1.words } ?? 0 }
    private var lastRead: (work: WorkMetadata, position: WorkReadingPosition)? {
        guard let catalog else { return nil }
        let positions = runtime.committedNativeState?.worksPositions ?? [:]
        let latest = catalog.works.compactMap { work in positions[work.id].map { (work, $0) } }
            .reduce(nil as (WorkMetadata, WorkReadingPosition)?) { current, candidate in
                guard let current else { return candidate }
                let currentTime = positionTime(current.1)
                let candidateTime = positionTime(candidate.1)
                return currentTime > candidateTime ? current : candidate
            }
        return latest
    }

    var body: some View {
        WorksPage {
            VStack(alignment: .leading, spacing: 8) {
                WorksEyebrow("THE LIBRARY")
                Text("The Fathers & Doctors")
                    .font(JohnTypography.sans(36, weight: .bold))
                    .lineSpacing(ContentTypography.additionalSpacing(fontName: "SpaceGrotesk-Bold", size: 36, targetLineHeight: 44))
                    .foregroundStyle(colors.text)
                    .accessibilityAddTraits(.isHeader)
                Text("\(WorksSourceText.plural(catalog?.collections.count ?? 0, "author")) · \(WorksSourceText.plural(catalog?.works.count ?? 0, "work")) · \(WorksSourceText.corpusSize(totalWords)) · reads offline")
                    .font(JohnTypography.sans(16))
                    .foregroundStyle(colors.textDim)
            }

            if let lastRead {
                Button {
                    onOpenWork(lastRead.work.id, nil)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        WorksEyebrow("CONTINUE READING")
                        Text(lastRead.work.title).font(JohnTypography.sans(20, weight: .medium)).foregroundStyle(colors.text)
                        Text("Section \(WorksSourceText.positionIndex(lastRead.position, key: "sectionIndex") + 1) of \(lastRead.work.sectionCount)")
                            .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(colors.card, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(WorksPressStyle())
                .accessibilityLabel("Continue \(lastRead.work.title), section \(WorksSourceText.positionIndex(lastRead.position, key: "sectionIndex") + 1)")
                .accessibilityIdentifier("works-continue")
            }

            if loadingFailed {
                ContentMutedText(text: "The library could not be opened on this device.")
            } else if let catalog {
                LazyVStack(spacing: 0) {
                    ForEach(catalog.collections.sorted(by: { $0.order < $1.order }), id: \.id) { collection in
                        Button { onOpenCollection(collection.id) } label: {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(collection.author).font(JohnTypography.sans(16, weight: .medium)).foregroundStyle(colors.text)
                                    Text(collection.era.map { "\($0) · " }.orEmpty + "\(WorksSourceText.plural(collection.workCount, "work")) · \(WorksSourceText.corpusSize(collection.words))")
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
                        .accessibilityLabel("\(collection.author). \(WorksSourceText.plural(collection.workCount, "work")). \(WorksSourceText.readingLength(collection.words)).")
                        .accessibilityIdentifier("collection-\(collection.id)")
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
        .task { await loadCatalog() }
    }

    @Environment(\.displayScale) private var displayScale

    @MainActor private func loadCatalog() async {
        do { catalog = try await runtime.worksCatalog(); loadingFailed = catalog == nil }
        catch { loadingFailed = true }
    }

    private func positionTime(_ position: WorkReadingPosition) -> Double {
        guard case let .number(value)? = position.fields["updatedAt"], value.isFinite else { return 0 }
        return value
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}
