import SwiftUI

struct FeatherIcon: View {
    let name: String
    var size: CGFloat = 20
    var color: Color = .primary

    private static let glyphs: [String: UInt32] = [
        "sun": 61927, "book-open": 61731, "bookmark": 61732, "heart": 61825,
        "settings": 61907, "arrow-up-right": 61719, "chevron-right": 61744,
        "search": 61904, "x": 61974, "arrow-left": 61712, "book": 61730,
        "chevron-down": 61742, "chevron-up": 61745, "chevron-left": 61743,
        "calendar": 61735, "clock": 61753, "edit-3": 61793,
        "copy": 61767, "image": 61829, "slash": 61919,
        "share": 61908, "more-horizontal": 61864, "check": 61739
    ]

    var body: some View {
        let scalar = UnicodeScalar(Self.glyphs[name] ?? 61731)!
        Text(String(scalar))
            .font(.custom("Feather", size: size))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}
