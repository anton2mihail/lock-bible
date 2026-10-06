import SwiftUI

struct FeatherIcon: View {
    let name: String
    var size: CGFloat = 20
    var color: Color = .primary

    private static let glyphs: [String: UInt32] = [
        "sun": 61927, "book-open": 61731, "bookmark": 61732, "heart": 61825,
        "settings": 61907, "arrow-up-right": 61719, "chevron-right": 61744,
        "search": 61904, "x": 61768, "arrow-left": 61704, "book": 61730,
        "chevron-down": 61742, "chevron-up": 61745,
        "calendar": 61735, "clock": 61753, "bookmark-plus": 61733,
        "share": 61916, "more-horizontal": 61855, "check": 61739
    ]

    var body: some View {
        let scalar = UnicodeScalar(Self.glyphs[name] ?? 61731)!
        Text(String(scalar))
            .font(.custom("Feather", size: size))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}
