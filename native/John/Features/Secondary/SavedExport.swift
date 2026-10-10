import SwiftUI
import UniformTypeIdentifiers
import JohnCore

enum SavedFileType {
    static let markdown = UTType("net.daringfireball.markdown") ?? .plainText
}

struct SavedFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    static let writableContentTypes: [UTType] = [.json, .pdf, SavedFileType.markdown, .plainText]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// Renders the saved items as PDF pages with ImageRenderer. No view animates, so the pages are final at once.
@MainActor enum SavedPDFRenderer {
    private static let pageSize = CGSize(width: 612, height: 792)

    static func render(items: [SavedItem], tags: [String: [String]]) -> Data {
        let pages = paginate(items)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var box = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        for (index, page) in pages.enumerated() {
            let renderer = ImageRenderer(content: PDFPage(items: page, tags: tags, number: index + 1, count: pages.count)
                .frame(width: pageSize.width, height: pageSize.height))
            renderer.proposedSize = ProposedViewSize(pageSize)
            renderer.render { _, draw in
                context.beginPDFPage(nil)
                draw(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        return data as Data
    }

    private static func paginate(_ items: [SavedItem]) -> [[SavedItem]] {
        var pages: [[SavedItem]] = [[]]
        var used = 0
        for item in items {
            let cost = 3 + min(8, (item.scriptureText.count + 79) / 80) + min(6, ((item.noteText ?? "").count + 79) / 80)
            if used + cost > 38, !pages[pages.count - 1].isEmpty { pages.append([]); used = 0 }
            pages[pages.count - 1].append(item); used += cost
        }
        return pages
    }

    private struct PDFPage: View {
        let items: [SavedItem]; let tags: [String: [String]]; let number: Int; let count: Int
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if number == 1 { Text("Saved passages").font(.system(size: 20, weight: .bold)) }
                ForEach(items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.reference) · \(item.kind.rawValue.capitalized)").font(.system(size: 11, weight: .semibold))
                        Text(item.scriptureText).font(.system(size: 10, design: .serif)).lineLimit(8)
                        if let note = item.noteText, !note.isEmpty { Text(note).font(.system(size: 10)).lineLimit(6) }
                        if let list = tags[item.id], !list.isEmpty {
                            Text(list.map { "#\($0)" }.joined(separator: " ")).font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
                Text("Page \(number) of \(count)").font(.system(size: 8)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(40)
            .foregroundStyle(.black)
            .background(.white)
        }
    }
}

/// Export and import sheet. Each export has a file exporter and a ShareLink for the same temporary file.
struct SavedExportSheet: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    let colors: JohnColors
    let onImported: (Int) -> Void
    @State private var bundle: SavedExportBundle?
    @State private var pdf = Data()
    @State private var urls: [String: URL] = [:]
    @State private var exporting: ExportKind?
    @State private var importing = false
    @State private var status: String?

    enum ExportKind: String, Identifiable {
        case markdown, pdf, backup
        var id: String { rawValue }
        var type: UTType { switch self { case .markdown: SavedFileType.markdown; case .pdf: .pdf; case .backup: .json } }
        var fileName: String { switch self { case .markdown: "Saved.md"; case .pdf: "Saved.pdf"; case .backup: "Saved-backup.json" } }
        var title: String { switch self { case .markdown: "Export Markdown"; case .pdf: "Export PDF"; case .backup: "Export backup (JSON)" } }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach([ExportKind.markdown, .pdf, .backup]) { kind in
                    HStack {
                        Button(kind.title) { exporting = kind }
                            .disabled(bundle == nil)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("saved-export-\(kind.rawValue)")
                        Spacer()
                        if let url = urls[kind.rawValue] {
                            ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel("Share \(kind.title)")
                                .accessibilityIdentifier("saved-export-share-\(kind.rawValue)")
                        }
                    }
                }
                Button("Import backup (JSON)") { importing = true }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("saved-import-button")
                if let status {
                    Text(status).font(JohnTypography.sans(13)).foregroundStyle(colors.textDim)
                        .accessibilityIdentifier("saved-export-status")
                }
            }
            .navigationTitle("Export and import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("saved-export-done") } }
        }
        .task { await prepare() }
        .fileExporter(isPresented: Binding(get: { exporting != nil }, set: { if !$0 { exporting = nil } }),
                      document: SavedFileDocument(data: data(for: exporting)),
                      contentType: exporting?.type ?? .json, defaultFilename: exporting?.fileName ?? "Saved") { result in
            if case .success = result { status = "Export saved." } else { status = "The export could not be saved." }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            Task { await importFile(result) }
        }
    }

    private func data(for kind: ExportKind?) -> Data {
        switch kind {
        case .markdown: Data((bundle?.markdown ?? "").utf8)
        case .pdf: pdf
        case .backup, nil: bundle?.backup ?? Data()
        }
    }

    @MainActor private func prepare() async {
        do {
            let made = try await runtime.exportDocuments()
            bundle = made
            pdf = SavedPDFRenderer.render(items: made.items, tags: made.tags)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("saved-export", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for kind in [ExportKind.markdown, .pdf, .backup] {
                let url = folder.appendingPathComponent(kind.fileName)
                try data(for: kind).write(to: url, options: .atomic)
                urls[kind.rawValue] = url
            }
        } catch {
            status = "The export could not be prepared."
        }
    }

    @MainActor private func importFile(_ result: Result<URL, any Error>) async {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let added = try await runtime.importBackup(Data(contentsOf: url))
            status = added == 0 ? "Nothing new to import." : "Imported \(added) items."
            onImported(added)
            await prepare()
        } catch {
            status = "The backup file could not be imported."
        }
    }
}
