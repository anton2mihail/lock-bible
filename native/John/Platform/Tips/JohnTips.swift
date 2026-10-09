import SwiftUI
import TipKit

/// Three small tips. Each tip shows only after the user has used the app a few times.
/// A tip never animates in. The tip view removes the animation from its transaction.
enum JohnTips {
    /// One use event. The Reader and Saved screens donate one event each time the user opens them.
    static let used = Tips.Event(id: "john.used")

    @MainActor static func configure() {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        if arguments.contains("-JohnResetTips") { try? Tips.resetDatastore() }
        if arguments.contains("-JohnTipsShowAll") {
            Tips.showAllTipsForTesting()
        } else if arguments.contains("-JohnResetNativeState"), !arguments.contains("-JohnShowTips") {
            // Existing UI tests must not see a tip.
            Tips.hideAllTipsForTesting()
        }
        #endif
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    static func noteUse() { Task { await used.donate() } }
}

struct PinchTextSizeTip: Tip {
    var title: Text { Text("Resize the text") }
    var message: Text? { Text("Pinch the chapter with two fingers to make the text larger or smaller.") }
    var image: Image? { Image(systemName: "textformat.size") }
    var rules: [Rule] { [#Rule(JohnTips.used) { $0.donations.count >= 3 }] }
}

struct ShareVerseTip: Tip {
    var title: Text { Text("Share a verse") }
    var message: Text? { Text("Press and hold a verse. Then choose Card or Copy to share it.") }
    var image: Image? { Image(systemName: "square.and.arrow.up") }
    var rules: [Rule] { [#Rule(JohnTips.used) { $0.donations.count >= 5 }] }
}

struct SwipeSavedShareTip: Tip {
    var title: Text { Text("Share a saved verse") }
    var message: Text? { Text("Swipe a saved item to the right to share it.") }
    var image: Image? { Image(systemName: "arrow.right.circle") }
    var rules: [Rule] { [#Rule(JohnTips.used) { $0.donations.count >= 3 }] }
}

/// A TipView with no entrance animation.
struct StaticTipView<T: Tip>: View {
    let tip: T
    let identifier: String

    var body: some View {
        TipView(tip)
            .transaction { $0.animation = nil }
            .transition(.identity)
            .accessibilityIdentifier(identifier)
    }
}
