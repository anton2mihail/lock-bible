import PencilKit
import SwiftUI
import JohnCore

struct SavedView: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter: SavedFilter = .all
    @State private var items: [SavedItem] = []
    @State private var loading = false
    @State private var message: String?
    @State private var undoItem: SavedItem?
    @State private var noteItem: SavedItem?
    @State private var generation = 0
    @State private var loadedFilter: SavedFilter?
    @State private var undoToken = UUID()
    @State private var undoCount = 0
    @Environment(\.undoManager) private var undoManager
    @State private var tags: [String: [String]] = [:]
    @State private var tagFilter: String?
    @State private var smartFolder: SavedSmartFolder?
    @State private var showExport = false
    @State private var tagTarget: SavedItem?
    @State private var tagDraft = ""

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    var body: some View {
        content.handoff(type: JohnActivity.saved, title: "Saved passages", url: JohnActivity.savedURL)
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Saved")
                    .font(JohnTypography.sans(36, weight: .bold))
                    .foregroundStyle(colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("page-title-saved")
                Button { showExport = true } label: {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 20))
                        .foregroundStyle(colors.tint)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Export and import")
                .accessibilityIdentifier("saved-export-menu")
                // Hidden shortcut for Cmd-Z and Cmd-Shift-Z on a hardware keyboard. Shake to undo uses the window undo manager.
                Button("Undo") { runtime.resolveUndoManager(undoManager)?.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .frame(width: 1, height: 1).opacity(0.01).accessibilityHidden(true)
                Button("Redo") { runtime.resolveUndoManager(undoManager)?.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .frame(width: 1, height: 1).opacity(0.01).accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            filterBar
            organizerBar
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
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement()
                    .accessibilityLabel("Loading saved items")
            } else if items.isEmpty {
                emptyOrErrorState
            } else {
                savedList
            }
            if !items.isEmpty && undoItem == nil {
                StaticTipView(tip: SwipeSavedShareTip(), identifier: "tip-swipe-saved")
                    .padding(.horizontal, 16)
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
                .johnGlassSurface(cornerRadius: 12, colors: colors)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("saved-undo-bar")
            }
        }
        .transaction(value: undoItem?.id) { $0.animation = nil }
        .onAppear { JohnTips.noteUse() }
        .sensoryFeedback(.impact(weight: .medium), trigger: undoCount)
        .transaction(value: loading) { $0.animation = nil }
        .transaction(value: items.count) { if undoItem == nil { $0.animation = nil } }
        .background(colors.background.ignoresSafeArea())
        .task(id: filter.rawValue) { await reload() }
        .onChange(of: runtime.savedRevision) { _, _ in Task { await reload() } }
        .sheet(isPresented: $showExport) {
            SavedExportSheet(colors: colors, onImported: { _ in })
                .environment(runtime)
        }
        .alert("Add tag", isPresented: Binding(get: { tagTarget != nil }, set: { if !$0 { tagTarget = nil } })) {
            TextField("Tag", text: $tagDraft)
            Button("Add") {
                if let target = tagTarget, let tag = SavedTags.normalize(tagDraft) {
                    Task { try? await runtime.setTagsUndoable((tags[target.id] ?? []) + [tag], for: target.id, undoManager: undoManager) }
                }
                tagDraft = ""; tagTarget = nil
            }
            Button("Cancel", role: .cancel) { tagDraft = ""; tagTarget = nil }
        }
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
        AdaptiveChipStack {
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
        .sensoryFeedback(.selection, trigger: filter)
    }

    private var visibleItems: [SavedItem] {
        let now = Int64(runtime.featureNow().timeIntervalSince1970 * 1000)
        return items.filter { item in
            let itemTags = tags[item.id] ?? []
            if let smartFolder, !smartFolder.matches(item, tags: itemTags, nowMilliseconds: now) { return false }
            if let tagFilter, !itemTags.contains(tagFilter) { return false }
            return true
        }
    }

    private var organizerBar: some View {
        let allTags = Array(Set(tags.values.flatMap { $0 })).sorted()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SavedSmartFolder.allCases, id: \.rawValue) { folder in
                    chip(folder.title, selected: smartFolder == folder, id: "saved-folder-\(folder.rawValue)") {
                        smartFolder = smartFolder == folder ? nil : folder
                    }
                }
                ForEach(allTags, id: \.self) { tag in
                    chip("#\(tag)", selected: tagFilter == tag, id: "saved-tag-\(tag)") {
                        tagFilter = tagFilter == tag ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 8)
    }

    private func chip(_ title: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(JohnTypography.sans(13, weight: .medium))
                .foregroundStyle(selected ? colors.card : colors.text)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(selected ? colors.tint : colors.card, in: Capsule())
                .overlay(Capsule().stroke(selected ? colors.tint : colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var savedList: some View {
        List {
            ForEach(visibleItems, id: \.id) { item in
                SavedRow(item: item, tags: tags[item.id] ?? [], colors: colors,
                         open: { open(item) }, editNote: { open(item) }, delete: { Task { await delete(item) } })
                    .readerZoomSource(id: "saved-\(item.id)")
                    .listRowBackground(colors.background)
                    .draggable(item.scriptureText)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button { tagTarget = item } label: { Label("Tag", systemImage: "tag") }
                            .tint(colors.tint)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await delete(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button { open(item) } label: { Label("Open", systemImage: "book") }
                        ScriptureShareLink(text: item.scriptureText, reference: item.reference,
                                           translationLabel: TranslationID(rawValue: item.translationID)?.shareLabel
                                               ?? item.translationID.uppercased()) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button { tagTarget = item } label: { Label("Add tag", systemImage: "tag") }
                        ForEach(tags[item.id] ?? [], id: \.self) { tag in
                            Button {
                                Task { try? await runtime.setTagsUndoable((tags[item.id] ?? []).filter { $0 != tag }, for: item.id, undoManager: undoManager) }
                            } label: { Label("Remove #\(tag)", systemImage: "tag.slash") }
                        }
                        Button(role: .destructive) {
                            Task { await delete(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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
        let requestedFilter = filter
        // Rows from another filter would be wrong, so drop them. Rows of the same filter stay
        // visible during a refresh, so the list does not flash a spinner on each visit.
        if loadedFilter != requestedFilter { items = [] }
        loading = items.isEmpty
        defer { if current == generation { loading = false } }
        do {
            let result = try await runtime.savedItems(filter: requestedFilter)
            guard current == generation else { return }
            items = result
            tags = await runtime.savedTags()
            loadedFilter = requestedFilter
            message = nil
        } catch {
            guard current == generation else { return }
            items = []
            loadedFilter = requestedFilter
            message = "Saved passages could not be loaded. Close and reopen this tab."
        }
    }

    @MainActor private func delete(_ item: SavedItem) async {
        generation += 1
        do {
            try await runtime.deleteSavedItemUndoable(item, undoManager: undoManager)
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
            // The undo bar and UndoManager share one step. Use the step when it exists, so redo stays valid.
            if let manager = runtime.resolveUndoManager(undoManager), manager.canUndo {
                manager.undo()
                // The step runs on the queue. Wait for it, so reload reads the restored data.
                await SavedUndoQueue.shared.flush()
            } else {
                try await runtime.restoreSavedItem(item)
            }
            generation += 1
            if token == undoToken { undoItem = nil; undoToken = UUID() }
            undoCount += 1
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
    let tags: [String]
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
                    Text(kindName + (tags.isEmpty ? "" : " · " + tags.map { "#\($0)" }.joined(separator: " ")))
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
    @Environment(\.undoManager) private var undoManager
    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var editorFocused: Bool
    let item: SavedItem?
    let initialPassage: PassageSelection?
    let onSaved: () async -> Void
    let onClose: (() -> Void)?
    @State private var draft: String
    @State private var originalText: String
    @State private var passage: PassageSelection?
    @State private var hasPersistedNote = false
    @State private var isLoading = true
    @State private var isLoadReady = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var dictation = NoteDictation()
    @State private var dictationBase = ""
    @State private var drawing = PKDrawing()
    @State private var originalDrawingData = Data()
    @State private var showCanvas = false

    init(item: SavedItem, onSaved: @escaping () async -> Void, onClose: (() -> Void)? = nil) {
        self.item = item
        initialPassage = nil
        self.onSaved = onSaved
        self.onClose = onClose
        _draft = State(initialValue: item.noteText ?? "")
        _originalText = State(initialValue: item.noteText ?? "")
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
        _originalText = State(initialValue: "")
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
        ScrollViewReader { scrollProxy in
          ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(scriptureText)
                    .font(.custom("Georgia", size: 17, relativeTo: .body))
                    .lineSpacing(10)
                    .foregroundStyle(colors.text)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("saved-note-scripture")
                TextEditor(text: $draft)
                    .font(.custom("SpaceGrotesk-Regular", size: 18, relativeTo: .body))
                    .lineSpacing(10)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 180, maxHeight: 280, alignment: .topLeading)
                    .background(colors.card, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topLeading) {
                        if draft.isEmpty {
                            Text("Write a private note…")
                                .font(.custom("SpaceGrotesk-Regular", size: 18, relativeTo: .body))
                                .foregroundStyle(colors.textDim.opacity(0.7))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .focused($editorFocused)
                    .writingToolsBehavior(.complete)
                    .dropDestination(for: String.self) { texts, _ in
                        guard isLoadReady, !texts.isEmpty else { return false }
                        let dropped = texts.joined(separator: "\n")
                        draft += (draft.isEmpty || draft.hasSuffix("\n") ? "" : "\n") + dropped
                        return true
                    }
                    .accessibilityLabel("Private note")
                    .accessibilityHint("Write a private note for this passage.")
                    .accessibilityIdentifier("saved-note-editor")
                    .id("saved-note-editor")
                    .disabled(isLoading || !isLoadReady)
                HStack(spacing: 12) {
                    Button { Task { await toggleDictation() } } label: {
                        Label(dictation.isListening ? "Stop dictation" : "Dictate",
                              systemImage: dictation.isListening ? "mic.fill" : "mic")
                    }
                    .frame(minHeight: 44)
                    .disabled(isLoading || !isLoadReady)
                    .accessibilityIdentifier("saved-note-dictate")
                    Button { showCanvas = true } label: {
                        Label("Handwrite", systemImage: "pencil.tip")
                    }
                    .frame(minHeight: 44)
                    .disabled(isLoading || !isLoadReady)
                    .accessibilityIdentifier("saved-note-handwrite")
                }
                if dictation.state == .denied {
                    Text("Dictation needs microphone and speech access. Allow it in Settings, or use the keyboard microphone.")
                        .font(JohnTypography.sans(13)).foregroundStyle(colors.textDim)
                        .accessibilityIdentifier("saved-note-dictation-denied")
                } else if dictation.state == .unavailable {
                    Text("Dictation on this device is not available now. Use the keyboard microphone.")
                        .font(JohnTypography.sans(13)).foregroundStyle(colors.textDim)
                        .accessibilityIdentifier("saved-note-dictation-unavailable")
                }
                if !drawing.strokes.isEmpty {
                    NoteDrawingPreview(drawing: drawing)
                        .accessibilityIdentifier("saved-note-drawing")
                }
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
            }
            .padding(20)
          }
          .scrollDismissesKeyboard(.interactively)
          .onChange(of: editorFocused) { _, focused in
              guard focused else { return }
              withAnimation(.easeOut(duration: 0.2)) {
                  scrollProxy.scrollTo("saved-note-editor", anchor: .bottom)
              }
          }
        }
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
        .interactiveDismissDisabled(draft != originalText || drawing.dataRepresentation() != originalDrawingData)
        .sheet(isPresented: $showCanvas) { NoteDrawingSheet(drawing: $drawing) }
        .onChange(of: dictation.transcript) { _, text in
            guard dictation.isListening || !text.isEmpty else { return }
            draft = dictationBase.isEmpty ? text : dictationBase + " " + text
        }
        .onDisappear { dictation.stop() }
        .overlay {
            if isLoading { ProgressView("Loading note…") }
        }
        .task { await loadPassage() }
    }

    @MainActor private func toggleDictation() async {
        if !dictation.isListening { dictationBase = draft.trimmingCharacters(in: .whitespacesAndNewlines) }
        await dictation.toggle()
    }

    @MainActor private func loadDrawing(for passage: PassageSelection?) {
        guard let passage, let stored = NoteDrawingStore.load(key: NoteDrawingStore.key(for: passage)) else { return }
        drawing = stored
        originalDrawingData = stored.dataRepresentation()
    }

    @MainActor private func loadPassage() async {
        if let initialPassage {
            passage = initialPassage
            do {
                draft = try await runtime.note(for: initialPassage.id)
                originalText = draft
                hasPersistedNote = draftHasContent
                loadDrawing(for: initialPassage)
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
            loadDrawing(for: passage)
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
            try await runtime.saveNoteUndoable(passage, text: draft, undoManager: undoManager)
            try? NoteDrawingStore.save(drawing, key: NoteDrawingStore.key(for: passage))
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
            try await runtime.deleteNoteUndoable(for: passage, undoManager: undoManager)
            NoteDrawingStore.delete(key: NoteDrawingStore.key(for: passage))
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
