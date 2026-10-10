import Foundation
import UIKit
import JohnCore

/// One reversible change. UndoManager holds it for undo and for redo.
@MainActor final class SavedUndoStep {
    let name: String
    let undo: @MainActor () async -> Void
    let redo: @MainActor () async -> Void
    init(name: String, undo: @escaping @MainActor () async -> Void, redo: @escaping @MainActor () async -> Void) {
        self.name = name; self.undo = undo; self.redo = redo
    }
    var inverse: SavedUndoStep { SavedUndoStep(name: name, undo: redo, redo: undo) }
}

@MainActor extension JohnRuntime {
    /// Registers `step` with the manager. The inverse is registered at once, so UndoManager treats it as redo.
    /// The environment undo manager, or the key window one. The window one also receives shake to undo.
    func resolveUndoManager(_ manager: UndoManager?) -> UndoManager? {
        if let manager { return manager }
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.undoManager
    }

    func register(_ step: SavedUndoStep, in manager: UndoManager?) {
        guard let manager = resolveUndoManager(manager) else { return }
        nonisolated(unsafe) let box = manager
        // UndoManager keeps its target weakly, so the runtime is the target and the closure holds the step.
        manager.registerUndo(withTarget: self) { runtime in
            MainActor.assumeIsolated {
                runtime.register(step.inverse, in: box)
                Task { @MainActor in
                    await step.undo()
                    runtime.savedRevision += 1
                }
            }
        }
        manager.setActionName(step.name)
    }

    /// Runs `change`, compares the saved items of `kinds` before and after, and registers an undo step for the difference.
    func undoable<T>(_ name: String, kinds: Set<SavedItemKind>, undoManager: UndoManager?,
                     _ change: () async throws -> T) async throws -> T {
        let before = try await savedItems().filter { kinds.contains($0.kind) }
        let result = try await change()
        let after = try await savedItems().filter { kinds.contains($0.kind) }
        let beforeByID = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let afterByID = Dictionary(after.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let added = after.filter { beforeByID[$0.id] == nil }
        let removed = before.filter { afterByID[$0.id] == nil }
        let changed = before.filter { afterByID[$0.id] != nil && afterByID[$0.id] != $0 }
        guard !(added.isEmpty && removed.isEmpty && changed.isEmpty) else { return result }
        let changedAfter = changed.compactMap { afterByID[$0.id] }
        register(SavedUndoStep(name: name, undo: { [weak self] in
            guard let self else { return }
            for item in added { try? await self.deleteSavedItem(item) }
            for item in removed + changed { try? await self.restoreSavedItem(item) }
        }, redo: { [weak self] in
            guard let self else { return }
            for item in removed { try? await self.deleteSavedItem(item) }
            for item in added + changedAfter { try? await self.restoreSavedItem(item) }
        }), in: undoManager)
        return result
    }

    func toggleBookmarkUndoable(_ passage: PassageSelection, undoManager: UndoManager?) async throws -> Bool {
        try await undoable("Bookmark", kinds: [.bookmark], undoManager: undoManager) { try await toggleBookmark(passage) }
    }

    func applyHighlightUndoable(_ passage: PassageSelection, color: HighlightColor, undoManager: UndoManager?) async throws {
        try await undoable("Highlight", kinds: [.highlight], undoManager: undoManager) { try await applyHighlight(passage, color: color) }
    }

    func clearHighlightUndoable(_ passage: PassageSelection, undoManager: UndoManager?) async throws {
        try await undoable("Remove Highlight", kinds: [.highlight], undoManager: undoManager) { try await clearHighlight(passage) }
    }

    func saveNoteUndoable(_ passage: PassageSelection, text: String, undoManager: UndoManager?) async throws {
        try await undoable("Note", kinds: [.note], undoManager: undoManager) { try await saveNote(passage, text: text) }
    }

    func deleteNoteUndoable(for passage: PassageSelection, undoManager: UndoManager?) async throws {
        try await undoable("Delete Note", kinds: [.note], undoManager: undoManager) { try await deleteNote(for: passage) }
    }

    func deleteSavedItemUndoable(_ item: SavedItem, undoManager: UndoManager?) async throws {
        try await deleteSavedItem(item)
        register(SavedUndoStep(name: "Delete", undo: { [weak self] in try? await self?.restoreSavedItem(item) },
                               redo: { [weak self] in try? await self?.deleteSavedItem(item) }), in: undoManager)
    }

    // MARK: Tags

    func savedTags() async -> [String: [String]] { await tagStore?.all() ?? [:] }

    func setTags(_ tags: [String], for id: String) async throws {
        try await tagStore?.set(tags, for: id)
        savedRevision += 1
    }

    // MARK: Export and import

    /// Writes the three export files to a temporary folder. The names are stable so tests can find them.
    func exportDocuments() async throws -> SavedExportBundle {
        let items = try await savedItems()
        let tags = await savedTags()
        let backup = SavedBackup(items: items, tags: tags, exportedAt: Int64(featureNow().timeIntervalSince1970 * 1000))
        return SavedExportBundle(markdown: SavedMarkdown.render(items: items, tags: tags),
                                 backup: try backup.encoded(), items: items, tags: tags)
    }

    /// Adds backup items that are not yet saved. Returns the number of added items.
    func importBackup(_ data: Data) async throws -> Int {
        let backup = try SavedBackup.decode(data)
        let existing = Set(try await savedItems().map(\.id))
        let fresh = backup.newItems(existingIDs: existing)
        for item in fresh { try await restoreSavedItem(item) }
        try await tagStore?.merge(backup.tags)
        savedRevision += 1
        return fresh.count
    }
}

struct SavedExportBundle: Sendable {
    let markdown: String
    let backup: Data
    let items: [SavedItem]
    let tags: [String: [String]]
}
