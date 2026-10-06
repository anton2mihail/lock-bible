import SwiftUI
import JohnCore

/// Go to. The Reader shows it as a sheet with medium and large detents (audit B6), so the chapter stays in context and
/// a swipe down closes it. The title row with Cancel stays fixed above the book list, so Cancel is always visible.
/// Cancel and a chapter choice close it with `dismiss`, which also works for the older pushed route (`AppRoute.goTo`).
struct GoToView: View {
    let initialBookCode: String?
    let initialChapter: Int?
    /// True in the Reader sheet: no opaque page fill, so the sheet keeps its system (Liquid Glass) background.
    var presentedAsSheet = false
    @Environment(\.dismiss) private var dismiss
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var books: [BibleBookDescriptor] = []
    @State private var openBookCode: String?
    @ScaledMetric(relativeTo: .body) private var chapterCellSize: CGFloat = 52

    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Go to")
                    .font(JohnTypography.sans(36, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(colors.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(JohnTypography.sans(15, weight: .medium))
                    .foregroundStyle(colors.tint)
                    .accessibilityIdentifier("go-to-cancel")
            }
            .frame(maxWidth: 740, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(BookGroupOrder.allCases, id: \.self) { group in
                        let groupBooks = books.filter { $0.group == group.rawValue }
                        if !groupBooks.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(group.title)
                                    .font(JohnTypography.sans(13, weight: .medium))
                                    .foregroundStyle(colors.textDim)
                                    .padding(.bottom, 5)
                                ForEach(groupBooks, id: \.code) { book in
                                    VStack(alignment: .leading, spacing: 0) {
                                        Button { selectBook(book) } label: {
                                            HStack {
                                                Text(book.name)
                                                    .font(JohnTypography.sans(16, weight: book.code == initialBookCode ? .semibold : .regular))
                                                    .foregroundStyle(book.code == initialBookCode ? colors.tint : colors.text)
                                                Spacer()
                                            if book.chapterCount > 1 {
                                                    FeatherIcon(name: openBookCode == book.code ? "chevron-up" : "chevron-down", color: colors.textDim)
                                                }
                                            }
                                            .frame(minHeight: 52)
                                            .overlay(alignment: .bottom) { Rectangle().fill(colors.separator).frame(height: 1) }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("\(book.name), \(book.chapterCount) chapters")
                                        .accessibilityValue(openBookCode == book.code ? "Expanded" : "Collapsed")
                                        .accessibilityIdentifier("go-to-book-\(book.code)")
                                        .id(book.code)

                                        if openBookCode == book.code {
                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: chapterCellSize, maximum: chapterCellSize), spacing: 10)], spacing: 10) {
                                                ForEach(1...book.chapterCount, id: \.self) { number in
                                                    Button {
                                                        router.openReader(bookCode: book.code, chapter: number, translation: preferences.translation)
                                                        if presentedAsSheet { dismiss() }
                                                    } label: {
                                                        Text(String(number))
                                                            .font(JohnTypography.sans(15, weight: number == initialChapter && book.code == initialBookCode ? .semibold : .regular))
                                                            .foregroundStyle(number == initialChapter && book.code == initialBookCode ? colors.card : colors.text)
                                                            .frame(width: chapterCellSize, height: chapterCellSize)
                                                            .background(number == initialChapter && book.code == initialBookCode ? colors.tint : colors.card,
                                                                        in: RoundedRectangle(cornerRadius: 11))
                                                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(colors.border, lineWidth: 1))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .accessibilityLabel("\(book.name) chapter \(number)")
                                                    .accessibilityIdentifier("go-to-chapter-\(book.code)-\(number)")
                                                    .id("go-to-chapter-\(book.code)-\(number)")
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            .id("chapters-\(book.code)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 740, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity)
            }
            .task(id: preferences.translation) {
                books = await runtime.books(translation: preferences.translation)
                if let initialBookCode, books.contains(where: { $0.code == initialBookCode && $0.chapterCount > 1 }) {
                    openBookCode = initialBookCode
                    await Task.yield()
                    let selected = initialChapter ?? 1
                    withAnimation(.none) { proxy.scrollTo("go-to-chapter-\(initialBookCode)-\(selected)", anchor: .center) }
                }
            }
        }
        }
        .background(presentedAsSheet ? Color.clear : colors.background)
    }

    private func selectBook(_ book: BibleBookDescriptor) {
        guard book.chapterCount > 1 else {
            router.openReader(bookCode: book.code, chapter: 1, translation: preferences.translation)
            if presentedAsSheet { dismiss() }
            return
        }
        openBookCode = openBookCode == book.code ? nil : book.code
    }
}
