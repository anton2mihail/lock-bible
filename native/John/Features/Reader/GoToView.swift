import SwiftUI
import JohnCore

struct GoToView: View {
    let initialBookCode: String?
    let initialChapter: Int?
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var books: [BibleBookDescriptor] = []
    @State private var openBookCode: String?

    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Go to")
                            .font(JohnTypography.title(36))
                            .tracking(-0.8)
                            .foregroundStyle(colors.text)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button("Cancel") { router.pop() }
                            .font(JohnTypography.sans(15, weight: .medium))
                            .foregroundStyle(colors.tint)
                            .accessibilityLabel("Close")
                            .accessibilityIdentifier("go-to-cancel")
                    }

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
                                                Text(book.chapterCount == 1 ? "1 chapter" : "\(book.chapterCount) chapters")
                                                    .font(JohnTypography.sans(12))
                                                    .foregroundStyle(colors.textDim)
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
                                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(50), spacing: 10), count: 5), spacing: 10) {
                                                ForEach(1...book.chapterCount, id: \.self) { number in
                                                    Button {
                                                        router.openReader(bookCode: book.code, chapter: number, translation: preferences.translation)
                                                    } label: {
                                                        Text(String(number))
                                                            .font(JohnTypography.sans(15, weight: number == initialChapter && book.code == initialBookCode ? .semibold : .regular))
                                                            .foregroundStyle(number == initialChapter && book.code == initialBookCode ? colors.card : colors.text)
                                                            .frame(width: 50, height: 50)
                                                            .background(number == initialChapter && book.code == initialBookCode ? colors.tint : colors.card,
                                                                        in: RoundedRectangle(cornerRadius: 11))
                                                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(colors.border, lineWidth: 1))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .accessibilityLabel("\(book.name) chapter \(number)")
                                                    .accessibilityIdentifier("go-to-chapter-\(book.code)-\(number)")
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
                .padding(.top, 24)
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity)
            }
            .task(id: preferences.translation) {
                books = await runtime.books(translation: preferences.translation)
                if let initialBookCode, books.contains(where: { $0.code == initialBookCode && $0.chapterCount > 1 }) {
                    openBookCode = initialBookCode
                    await Task.yield()
                    withAnimation(.none) { proxy.scrollTo("chapters-\(initialBookCode)", anchor: .center) }
                }
            }
        }
        .background(colors.background)
    }

    private func selectBook(_ book: BibleBookDescriptor) {
        guard book.chapterCount > 1 else {
            router.openReader(bookCode: book.code, chapter: 1, translation: preferences.translation)
            return
        }
        openBookCode = openBookCode == book.code ? nil : book.code
    }
}
