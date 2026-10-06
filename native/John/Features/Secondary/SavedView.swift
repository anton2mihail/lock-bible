import SwiftUI
import JohnCore

struct SavedView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var filter: SavedFilter = .all
    @State private var items: [SavedItem] = []
    @State private var loading = false
    @State private var message: String?
    @State private var undoItem: SavedItem?
    @State private var noteItem: SavedItem?
    @State private var generation = 0
    @State private var undoToken = UUID()

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    var body: some View {
        VStack(spacing: 0) {
            Text("Saved")
                .font(JohnTypography.sans(36, weight: .bold))
                .foregroundStyle(colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
            filterBar
            if let message, !items.isEmpty {
                Text(message)
                    .font(JohnTypography.sans(13))
                    .foregroundStyle(colors.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("saved-status")
                    .contentAnnouncement(message)
            }
            if loading {
                ProgressView("Loading saved items…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                emptyOrErrorState
            } else {
                savedList
            }
            if let undoItem {
                HStack(spacing: 12) {
                    Text("\(undoItem.reference) deleted")
                        .font(JohnTypography.sans(14))
                        .accessibilityIdentifier("saved-undo-status")
                    Spacer()
                    Button {
                        Task { await undo(undoItem) }
                    } label: {
                        Text("Undo")
                            .font(JohnTypography.sans(14, weight: .semibold))
                            .foregroundStyle(colors.tint)
                            .frame(minWidth: 56, minHeight: 44)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("saved-undo-button")
                }
                .foregroundStyle(colors.text)
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(colors.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .background(colors.background.ignoresSafeArea())
        .task(id: filter.rawValue) { await reload() }
        .onChange(of: router.selectedTab) { _, tab in
            if tab == .saved { Task { await reload() } }
        }
        .sheet(isPresented: Binding(get: { noteItem != nil }, set: { if !$0 { noteItem = nil } })) {
            if let item = noteItem {
                NavigationStack {
                    SavedNoteEditor(item: item, onSaved: { await reload() })
                }
                .environment(runtime)
                .environment(preferences)
            }
        }
        .task(id: undoToken) {
            let token = undoToken
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled, token == undoToken { undoItem = nil }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(SavedFilterChoice.allCases) { choice in
                Button {
                    filter = choice.filter
                } label: {
                    Text(choice.title)
                        .font(JohnTypography.sans(14, weight: .medium))
                        .foregroundStyle(filter == choice.filter ? colors.card : colors.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(filter == choice.filter ? colors.tint : colors.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(filter == choice.filter ? colors.tint : colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("saved-filter-\(choice.filter.rawValue)")
                .accessibilityAddTraits(filter == choice.filter ? .isSelected : [])
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var savedList: some View {
        List {
            ForEach(items, id: \.id) { item in
                SavedRow(item: item, colors: colors,
                         open: { open(item) }, editNote: { open(item) }, delete: { Task { await delete(item) } })
                    .listRowBackground(colors.background)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// The empty list and the load failure. The description keeps the message text and the `saved-empty-state` identifier.
    private var emptyOrErrorState: some View {
        ContentUnavailableView {
            if message == nil {
                Label("Nothing saved", systemImage: emptyIcon)
            } else {
                Label("Could not load Saved", systemImage: "exclamationmark.triangle")
            }
        } description: {
            Text(message ?? emptyText)
                .accessibilityIdentifier("saved-empty-state")
        } actions: {
            if message != nil {
                Button("Try again") { Task { await reload() } }
            }
        }
    }

    private var emptyIcon: String {
        switch filter {
        case .all, .bookmark: "bookmark"
        case .highlight: "highlighter"
        case .note: "note.text"
        }
    }

    private var emptyText: String {
        switch filter {
        case .all: "Nothing saved yet. Select a verse while reading to bookmark, highlight, or add a note."
        case .bookmark: "No bookmarks yet."
        case .highlight: "No highlights yet."
        case .note: "No notes yet."
        }
    }

    @MainActor private func reload() async {
        generation += 1
        let current = generation
        loading = true
        defer { if current == generation { loading = false } }
        do {
            let result = try await runtime.savedItems(filter: filter)
            guard current == generation else { return }
            items = result
            message = nil
        } catch {
            guard current == generation else { return }
            items = []
            message = "Saved passages could not be loaded. Close and reopen this tab."
        }
    }

    @MainActor private func delete(_ item: SavedItem) async {
        generation += 1
        do {
            try await runtime.deleteSavedItem(item)
            generation += 1
            undoItem = item
            items.removeAll { $0.id == item.id }
            loading = false
            message = nil
            undoToken = UUID()
        } catch {
            loading = false
            message = "That saved item could not be deleted. Try again."
        }
    }

    @MainActor private func undo(_ item: SavedItem) async {
        let token = undoToken
        generation += 1
        do {
            try await runtime.restoreSavedItem(item)
            generation += 1
            if token == undoToken { undoItem = nil; undoToken = UUID() }
            await reload()
            message = nil
        } catch {
            message = "That saved item could not be restored."
        }
    }

    /// A saved item that cannot load keeps the user here and shows one line in `saved-status`.
    /// Like the other status lines on this screen, it stays until the next open, delete, undo, or reload.
    private func open(_ item: SavedItem) {
        Task {
            message = nil
            let opened: Bool
            if item.kind == .note {
                opened = await router.savedItemPassage(item, using: runtime) != nil
                if opened { noteItem = item }
            } else {
                opened = await router.openSavedItem(item, using: runtime)
            }
            if !opened { message = "This passage could not be opened." }
        }
    }
}

private struct SavedRow: View {
    let item: SavedItem
    let colors: JohnColors
    let open: () -> Void
    let editNote: () -> Void
    let delete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(markerColor)
                .frame(width: 4)
                .padding(.vertical, 16)
                .accessibilityHidden(true)
            Button(action: item.kind == .note ? editNote : open) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.reference)
                        .font(JohnTypography.sans(16, weight: .semibold))
                        .foregroundStyle(colors.text)
                    Text(item.scriptureText)
                        .font(.custom("Georgia", size: 16))
                        .lineSpacing(4)
                        .foregroundStyle(colors.text)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    if let noteText = item.noteText, !noteText.isEmpty {
                        Text(noteText)
                            .font(JohnTypography.sans(13))
                            .foregroundStyle(colors.textDim)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Text(kindName)
                        .font(JohnTypography.sans(12))
                        .foregroundStyle(colors.textDim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saved-row-\(item.id)")
            .accessibilityLabel("\(item.reference), \(kindName). \(item.scriptureText)")
            .accessibilityHint(item.kind == .note ? "Edit note" : "Open passage")
            Button("Delete", action: delete)
            .font(JohnTypography.sans(12))
            .foregroundStyle(colorScheme == .dark ? Color(hex: 0xF4876B) : Color(hex: 0xC03403))
            .frame(minWidth: 52, minHeight: 44)
            .accessibilityIdentifier("saved-delete-\(item.id)")
        }
        .frame(minHeight: 128)
    }

    private var kindName: String {
        switch item.kind {
        case .bookmark: "Bookmark"
        case .highlight: "\(item.color?.rawValue.capitalized ?? "Gold") highlight"
        case .note: "Note"
        }
    }

    private var markerColor: Color {
        switch item.color {
        case .gold: Color(hex: 0xF4D89A)
        case .sage: Color(hex: 0xC8D6C0)
        case .rose: Color(hex: 0xE6C5C8)
        case .blue: Color(hex: 0xC6D5E6)
        case nil: colors.tint
        }
    }
}

private enum SavedFilterChoice: String, CaseIterable, Identifiable {
    case all, bookmark, highlight, note
    var id: String { rawValue }
    var filter: SavedFilter { SavedFilter(rawValue: rawValue)! }
    var title: String {
        switch self { case .all: "All"; case .bookmark: "Bookmarks"; case .highlight: "Highlights"; case .note: "Notes" }
    }
}

struct SavedNoteEditor: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let item: SavedItem?
    let initialPassage: PassageSelection?
    let onSaved: () async -> Void
    let onClose: (() -> Void)?
    @State private var draft: String
    @State private var passage: PassageSelection?
    @State private var hasPersistedNote = false
    @State private var isLoading = true
    @State private var isLoadReady = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(item: SavedItem, onSaved: @escaping () async -> Void, onClose: (() -> Void)? = nil) {
        self.item = item
        initialPassage = nil
        self.onSaved = onSaved
        self.onClose = onClose
        _draft = State(initialValue: item.noteText ?? "")
        _passage = State(initialValue: nil)
        _hasPersistedNote = State(initialValue: item.kind == .note)
    }

    init(passage: PassageSelection, onSaved: @escaping () async -> Void,
         onClose: (() -> Void)? = nil) {
        item = nil
        initialPassage = passage
        self.onSaved = onSaved
        self.onClose = onClose
        _draft = State(initialValue: "")
        _passage = State(initialValue: passage)
        _hasPersistedNote = State(initialValue: false)
    }

    private var reference: String {
        item?.reference ?? initialPassage.map(Self.reference(for:)) ?? ""
    }
    private var scriptureText: String { item?.scriptureText ?? initialPassage?.scriptureText ?? "" }

    private static func reference(for passage: PassageSelection) -> String {
        let verses = passage.startVerse == passage.endVerse
            ? passage.startVerse.rawValue
            : "\(passage.startVerse.rawValue)–\(passage.endVerse.rawValue)"
        return "\(passage.bookName) \(passage.chapter):\(verses)"
    }

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var draftHasContent: Bool {
        func isTrimScalar(_ value: UInt32) -> Bool {
            (0x0009...0x000D).contains(value) || [0x0020, 0x00A0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF].contains(value) || (0x2000...0x200A).contains(value)
        }
        let scalars = Array(draft.unicodeScalars)
        var start = 0
        var end = scalars.count
        while start < end, isTrimScalar(scalars[start].value) { start += 1 }
        while end > start, isTrimScalar(scalars[end - 1].value) { end -= 1 }
        return start < end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
                Text(scriptureText)
                    .font(.custom("Georgia", size: 17))
                    .lineSpacing(10)
                    .foregroundStyle(colors.text)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
                TextEditor(text: $draft)
                    .font(.custom("SpaceGrotesk-Regular", size: 18))
                    .lineSpacing(10)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(colors.card, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topLeading) {
                        if draft.isEmpty {
                            Text("Write a private note…")
                                .font(.custom("SpaceGrotesk-Regular", size: 18))
                                .foregroundStyle(colors.textDim.opacity(0.7))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityIdentifier("saved-note-editor")
                    .disabled(isLoading || !isLoadReady)
                if hasPersistedNote {
                    Button("Delete note", role: .destructive) { Task { await deleteNote() } }
                        .disabled(isLoading || isSaving || !isLoadReady)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("saved-note-delete")
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(JohnTypography.sans(13))
                        .foregroundStyle(colors.textDim)
                        .accessibilityIdentifier("saved-note-error")
                }
                Spacer(minLength: 0)
        }
        .padding(20)
        .background(colors.background.ignoresSafeArea())
        // An editor needs Cancel and Save, so it keeps its own bar. It is a sheet from Saved and a push from the Reader.
        // The pushed editor hides the system back button: Cancel is its only exit, and the edge swipe cannot drop a draft.
        .navigationTitle(reference)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: close)
                    .accessibilityIdentifier("saved-note-cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(isLoading || isSaving || !isLoadReady)
                    .accessibilityIdentifier("saved-note-save")
            }
        }
        .overlay {
            if isLoading { ProgressView("Loading note…") }
        }
        .task { await loadPassage() }
    }

    @MainActor private func loadPassage() async {
        if let initialPassage {
            passage = initialPassage
            do {
                draft = try await runtime.note(for: initialPassage.id)
                hasPersistedNote = draftHasContent
                isLoadReady = true
            } catch {
                errorMessage = "Your note could not be loaded. Return to the reader and try again."
            }
            isLoading = false
            return
        }
        guard let item, let translation = TranslationID(rawValue: item.translationID) else {
            errorMessage = "This note could not be opened. Return to the reader and try again."
            isLoading = false
            return
        }
        passage = await runtime.passage(translation: translation, bookCode: item.bookCode,
                                        chapter: item.chapter, startVerse: item.startVerse,
                                        endVerse: item.endVerse)
        hasPersistedNote = item.kind == .note
        if passage == nil {
            errorMessage = "This note could not be opened. Return to the reader and try again."
        } else {
            isLoadReady = true
        }
        isLoading = false
    }

    @MainActor private func save() async {
        guard isLoadReady, !isSaving, let passage else {
            errorMessage = "This note cannot be saved now. Try again."
            return
        }
        isSaving = true
        do {
            try await runtime.saveNote(passage, text: draft)
            await onSaved()
            close()
        } catch {
            errorMessage = "Your note could not be saved. It is still visible here so you can try again."
            isSaving = false
        }
    }

    @MainActor private func deleteNote() async {
        guard isLoadReady, !isSaving, hasPersistedNote, let passage else {
            errorMessage = "Your note could not be deleted. Try again."
            return
        }
        isSaving = true
        do {
            try await runtime.deleteNote(for: passage)
            await onSaved()
            close()
        } catch {
            errorMessage = "Your note could not be deleted. Try again."
            isSaving = false
        }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}
