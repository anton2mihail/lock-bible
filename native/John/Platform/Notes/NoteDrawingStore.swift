import Foundation
import PencilKit
import JohnCore

/// Stores a handwritten drawing for a note. Each drawing is a separate file.
/// The note text and the saved-state file do not change, so old data stays valid.
enum NoteDrawingStore {
    static func key(for passage: PassageSelection) -> String {
        let id = passage.id
        return "\(id.translationID.rawValue)-\(id.bookCode.rawValue)-\(id.chapter)-\(id.startVerse.rawValue)-\(id.endVerse.rawValue)"
    }

    static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("NoteDrawings", isDirectory: true)
    }

    static func fileURL(key: String) -> URL {
        let safe = key.map { $0.isLetter || $0.isNumber || $0 == "-" ? String($0) : "_" }.joined()
        return directory().appendingPathComponent(safe).appendingPathExtension("drawing")
    }

    /// Returns nil when no file exists or the file cannot be read.
    static func load(key: String) -> PKDrawing? {
        guard let data = try? Data(contentsOf: fileURL(key: key)) else { return nil }
        return try? PKDrawing(data: data)
    }

    /// An empty drawing removes the file.
    static func save(_ drawing: PKDrawing, key: String) throws {
        let url = fileURL(key: key)
        if drawing.strokes.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try FileManager.default.createDirectory(at: directory(), withIntermediateDirectories: true)
        try drawing.dataRepresentation().write(to: url, options: .atomic)
    }

    static func delete(key: String) { try? FileManager.default.removeItem(at: fileURL(key: key)) }
}
