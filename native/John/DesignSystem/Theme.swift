import SwiftUI

struct JohnColors {
    let background: Color
    let card: Color
    let border: Color
    let separator: Color
    let text: Color
    let textDim: Color
    let tint: Color

    static let light = JohnColors(
        background: Color(hex: 0xF6F2EA), card: Color(hex: 0xFFFCF6),
        border: Color(hex: 0xC6BAA9), separator: Color(hex: 0xE1D9CC),
        text: Color(hex: 0x191015), textDim: Color(hex: 0x564E4A),
        tint: Color(hex: 0x745439)
    )

    static let dark = JohnColors(
        background: Color(hex: 0x191419), card: Color(hex: 0x251D23),
        border: Color(hex: 0x564E4A), separator: Color(hex: 0x3C3836),
        text: Color(hex: 0xF4F2F1), textDim: Color(hex: 0xB6ACA6),
        tint: Color(hex: 0xD9BE8D)
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct JohnTypography {
    static func title(_ size: CGFloat) -> Font { .custom("Lora-Regular", size: size) }
    static func serif(_ size: CGFloat) -> Font { .custom("Lora-Regular", size: size) }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .light: name = "SpaceGrotesk-Light"
        case .medium: name = "SpaceGrotesk-Medium"
        case .semibold: name = "SpaceGrotesk-SemiBold"
        case .bold: name = "SpaceGrotesk-Bold"
        default: name = "SpaceGrotesk-Regular"
        }
        return .custom(name, size: size)
    }
}
