import SwiftUI
import UIKit
import CoreText
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

/// Renders the saved items as PDF pages with CoreText. Text flows over as many pages as it needs, with no truncation.
/// It throws if no PDF data results, so a blank file is never written.
@MainActor enum SavedPDFRenderer {
    struct RenderError: Error {}
    private static let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 40

    static func attributedText(items: [SavedItem], tags: [String: [String]]) -> NSAttributedString {
        let out = NSMutableAttributedString()
        func add(_ text: String, _ font: UIFont, _ color: UIColor = .black, after: CGFloat = 2) {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = after
            out.append(NSAttributedString(string: text + "\n", attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: style]))
        }
        add("Saved passages", .systemFont(ofSize: 20, weight: .bold), after: 10)
        for item in items {
            add("\(item.reference) · \(item.kind.rawValue.capitalized)", .systemFont(ofSize: 11, weight: .semibold))
            add(item.scriptureText, UIFont(descriptor: UIFont.systemFont(ofSize: 10).fontDescriptor.withDesign(.serif) ?? UIFont.systemFont(ofSize: 10).fontDescriptor, size: 10))
            if let note = item.noteText, !note.isEmpty { add(note, .systemFont(ofSize: 10)) }
            if let list = tags[item.id], !list.isEmpty {
                add(list.map { "#\($0)" }.joined(separator: " "), .systemFont(ofSize: 9), .darkGray)
            }
            add("", .systemFont(ofSize: 6), after: 6)
        }
        return out
    }

    static func render(items: [SavedItem], tags: [String: [String]]) throws -> Data {
        let text = attributedText(items: items, tags: tags)
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let area = pageSize.insetBy(dx: margin, dy: margin)
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize)
        var failed = false
        var pageCount = 0
        let data = renderer.pdfData { context in
            var location = 0
            repeat {
                context.beginPage()
                pageCount += 1
                let cg = context.cgContext
                cg.saveGState()
                cg.translateBy(x: 0, y: pageSize.height)
                cg.scaleBy(x: 1, y: -1)
                let path = CGPath(rect: CGRect(x: area.minX, y: margin, width: area.width, height: area.height), transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
                let visible = CTFrameGetVisibleStringRange(frame)
                CTFrameDraw(frame, cg)
                cg.restoreGState()
                if visible.length == 0 { failed = true; return }
                location += visible.length
            } while location < text.length
        }
        guard !failed, pageCount > 0, data.count > 0 else { throw RenderError() }
        return data
    }
}

/// Export and import sheet. Each export has a file exporter and a ShareLink for the same temporary file.
struct SavedExportSheet: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
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
                            .disabled(bundle == nil || (kind == .pdf && pdf.isEmpty))
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
            pdf = Data()
            urls = [:]
            var pdfFailed = false
            do { pdf = try SavedPDFRenderer.render(items: made.items, tags: made.tags) } catch { pdfFailed = true }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("saved-export", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for kind in [ExportKind.markdown, .pdf, .backup] {
                if kind == .pdf, pdfFailed { continue }
                let url = folder.appendingPathComponent(kind.fileName)
                try data(for: kind).write(to: url, options: .atomic)
                urls[kind.rawValue] = url
            }
            status = pdfFailed ? "The PDF could not be made. Markdown and backup are ready." : nil
        } catch {
            status = "The export could not be prepared."
        }
    }

    @MainActor private func importFile(_ result: Result<URL, any Error>) async {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let added = try await runtime.importBackupUndoable(Data(contentsOf: url), undoManager: undoManager)
            status = added == 0 ? "Nothing new to import." : "Imported \(added) items."
            onImported(added)
            await prepare()
        } catch {
            status = "The backup file could not be imported."
        }
    }
}
