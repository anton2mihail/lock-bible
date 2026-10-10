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
    var message: Text? { Text("Touch and hold a saved item to share it.") }
    var image: Image? { Image(systemName: "hand.tap") }
    var rules: [Rule] { [#Rule(JohnTips.used) { $0.donations.count >= 3 }] }
}

/// A static tip view. It reads the Tip status and shows the tip at once, with no transition.
struct StaticTipView<T: Tip>: View {
    let tip: T
    let identifier: String
    @State private var visible: Bool

    init(tip: T, identifier: String) {
        self.tip = tip
        self.identifier = identifier
        _visible = State(initialValue: tip.shouldDisplay)
    }

    var body: some View {
        VStack(spacing: 0) {
            // A zero-size anchor keeps the status task alive while the tip is hidden.
            Color.clear.frame(height: 0).accessibilityHidden(true)
            content
        }
            .animation(nil, value: visible)
            .transaction { $0.animation = nil; $0.disablesAnimations = true }
            .task {
                for await status in tip.statusUpdates {
                    var show = false
                    if case .available = status { show = true }
                    var t = Transaction(animation: nil)
                    t.disablesAnimations = true
                    withTransaction(t) { visible = show }
                }
            }
    }

    @ViewBuilder private var content: some View {
        if visible {
            HStack(alignment: .top, spacing: 12) {
                if let image = tip.image { image.font(.title3).foregroundStyle(.tint) }
                VStack(alignment: .leading, spacing: 4) {
                    tip.title.font(.headline)
                    if let message = tip.message { message.font(.subheadline).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                Image(systemName: "xmark").font(.footnote.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .onTapGesture { tip.invalidate(reason: .tipClosed) }
                    .accessibilityHidden(true)
            }
            .padding(.leading, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
            .accessibilityAction(named: "Close tip") { tip.invalidate(reason: .tipClosed) }
        }
    }
}
