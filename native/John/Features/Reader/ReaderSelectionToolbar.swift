import SwiftUI
import JohnCore

/// A presentation-only toolbar for one immutable passage selection.
/// The caller owns every read and write operation.
struct ReaderSelectionToolbar: View {
    let passage: PassageSelection
    let displayReference: String
    let bookmarkStateKnown: Bool
    let isBookmarked: Bool
    let highlightColor: HighlightColor?
    let hasAnyHighlight: Bool
    let feedback: String?
    let isBusy: Bool
    let onClose: () -> Void
    let onBookmark: () -> Void
    let onHighlight: (HighlightColor) -> Void
    let onClearHighlight: () -> Void
    let onNote: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    let onPray: () -> Void
    let onCard: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var swatchTapCount = 0
    @ScaledMetric(relativeTo: .caption) private var scaledLabelSize: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var scaledReferenceSize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption) private var scaledFeedbackSize: CGFloat = 12

    private var colors: JohnColors { colorScheme == .dark ? .dark : .light }
    private let colorsInOrder: [HighlightColor] = [.gold, .sage, .rose, .blue]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Text(displayReference)
                    .font(.custom("SpaceGrotesk-SemiBold", fixedSize: min(max(scaledReferenceSize, 14), 21)))
                    .foregroundStyle(colors.text)
                    .lineLimit(2)
                    .padding(.leading, 8)
                    .accessibilityIdentifier("reader-selection-reference")
                Spacer(minLength: 8)
                Button(action: onClose) {
                    FeatherIcon(name: "x", size: 20, color: colors.text)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear passage selection")
                .accessibilityIdentifier("reader-selection-close")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    swatchesRow
                    clearHighlightButton
                }
                VStack(alignment: .leading, spacing: 4) {
                    swatchesRow
                    clearHighlightButton
                }
            }

            FlowActionLayout(spacing: 0, baseWidth: min(max(scaledLabelSize / 12, 1), 1.5) * 56) {
                action("bookmark", title: bookmarkTitle,
                       label: "Bookmark \(displayReference)", id: "reader-selection-bookmark",
                       selected: bookmarkStateKnown && isBookmarked,
                       disabled: isBusy || !bookmarkStateKnown, action: onBookmark)
                action("note", title: "Note", label: "Note \(displayReference)",
                       id: "reader-selection-note", disabled: isBusy, action: onNote)
                action("copy", title: "Copy", label: "Copy \(displayReference)",
                       id: "reader-selection-copy", action: onCopy)
                action("share", title: "Share", label: "Share \(displayReference)",
                       id: "reader-selection-share", action: onShare)
                action("pray", title: "Pray", label: "Pray \(displayReference)",
                       id: "reader-selection-pray", action: onPray)
                action("card", title: "Card", label: "Create card \(displayReference)",
                       id: "reader-selection-card", action: onCard)
            }

            if let feedback {
                Text(feedback)
                    .font(.custom("SpaceGrotesk-Regular", fixedSize: min(max(scaledFeedbackSize, 12), 18)))
                    .foregroundStyle(colors.tint)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("reader-selection-feedback")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .modifier(SelectionPanelSurface(shape: panelShape, colors: colors,
                                        hairline: 1 / displayScale, solid: reduceTransparency))
        // The whole panel takes touches, also between its controls, so a tap on the panel never reaches the
        // Scripture text that scrolls under it. Taps outside the panel still go to the owned-glyph hit test.
        .contentShape(panelShape)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-selection-panel")
        .sensoryFeedback(.selection, trigger: swatchTapCount)
    }

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var panelShape: RoundedRectangle { RoundedRectangle(cornerRadius: 24, style: .continuous) }

    private var bookmarkTitle: String {
        guard bookmarkStateKnown else { return "Unavailable" }
        return isBookmarked ? "Saved" : "Bookmark"
    }

    @ViewBuilder
    private var swatchesRow: some View {
        HStack(spacing: 0) {
            ForEach(colorsInOrder, id: \.rawValue) { color in swatch(color) }
        }
    }

    @ViewBuilder
    private var clearHighlightButton: some View {
        if hasAnyHighlight && highlightColor == nil {
            Button(action: onClearHighlight) {
                ZStack {
                    Circle().fill(colors.background)
                        .overlay(Circle().strokeBorder(colors.border, lineWidth: 1))
                        .frame(width: 30, height: 30)
                    FeatherIcon(name: "slash", size: 16, color: colors.textDim)
                }
                .frame(width: 48, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(colors.textDim)
            .accessibilityLabel("Remove highlight")
            .accessibilityIdentifier("reader-highlight-clear")
            .disabled(isBusy)
        }
    }

    private func swatch(_ color: HighlightColor) -> some View {
        let selected = highlightColor == color
        return Button {
            swatchTapCount += 1
            if selected { onClearHighlight() } else { onHighlight(color) }
        } label: {
            Circle()
                .fill(swatches[color] ?? colors.tint)
                .frame(width: 30, height: 30)
                .overlay {
                    Circle().strokeBorder(selected ? colors.tint : colors.border, lineWidth: selected ? 2 : 1)
                }
                .overlay {
                    if selected { FeatherIcon(name: "check", size: 16, color: Color(hex: 0x191015)) }
                }
                .frame(width: 48, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(selected ? "Remove" : "Apply") \(color.rawValue) highlight")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("reader-highlight-\(color.rawValue)")
        .disabled(isBusy)
    }

    private var swatches: [HighlightColor: Color] {
        return [
            .gold: Color(hex: 0xF4D89A),
            .sage: Color(hex: 0xC8D6C0),
            .rose: Color(hex: 0xE6C5C8),
            .blue: Color(hex: 0xC6D5E6)
        ]
    }

    @ViewBuilder
    private func action(_ name: String, title: String, label: String, id: String,
                        selected: Bool = false, disabled: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon(name, color: selected ? colors.card : colors.text)
                    .frame(width: 36, height: 36)
                    .background(selected ? colors.tint : .clear, in: Circle())
                Text(title)
                    .font(.custom("SpaceGrotesk-Medium", fixedSize: min(max(scaledLabelSize, 12), 18)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(selected ? colors.tint : colors.text)
            .frame(minWidth: 56, maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
        .disabled(disabled)
    }

    @ViewBuilder
    private func icon(_ name: String, color: Color) -> some View {
        switch name {
        case "bookmark": FeatherIcon(name: "bookmark", size: 20, color: color)
        case "share": FeatherIcon(name: "share", size: 20, color: color)
        case "pray": FeatherIcon(name: "heart", size: 20, color: color)
        case "note": FeatherIcon(name: "edit-3", size: 20, color: color)
        case "copy": FeatherIcon(name: "copy", size: 20, color: color)
        default: FeatherIcon(name: "image", size: 20, color: color)
        }
    }
}

/// The floating selection panel surface (audit B3): one Liquid Glass shape inside a `GlassEffectContainer`, so the
/// swatches and actions share one glass surface. With Reduce Transparency on, a solid card fill with a hairline
/// border replaces the glass, as the flat panel had.
private struct SelectionPanelSurface: ViewModifier {
    let shape: RoundedRectangle
    let colors: JohnColors
    let hairline: CGFloat
    let solid: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if solid {
            content
                .background(colors.card, in: shape)
                .overlay(shape.strokeBorder(colors.border, lineWidth: hairline))
        } else {
            GlassEffectContainer {
                content.glassEffect(.regular, in: shape)
            }
        }
    }
}

private struct FlowActionLayout: Layout {
    var spacing: CGFloat
    var baseWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }
        return arrange(subviews, width: width).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews, width: bounds.width)
        for (index, point) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                                  proposal: ProposedViewSize(width: result.widths[index], height: nil))
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, origins: [CGPoint], widths: [CGFloat]) {
        guard !subviews.isEmpty else { return (.zero, [], []) }
        let basis = min(width, baseWidth)
        var rows: [[Int]] = [[]]
        for index in subviews.indices {
            let row = rows.count - 1
            let proposedRowWidth = CGFloat(rows[row].count + 1) * basis
                + CGFloat(rows[row].count) * spacing
            if !rows[row].isEmpty && proposedRowWidth > width {
                rows.append([index])
            } else {
                rows[row].append(index)
            }
        }
        var origins: [CGPoint] = []
        var widths = Array(repeating: basis, count: subviews.count)
        var y: CGFloat = 0
        for row in rows {
            let cellWidth = (width - spacing * CGFloat(max(0, row.count - 1))) / CGFloat(row.count)
            var rowHeight: CGFloat = 56
            for index in row {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: min(basis, cellWidth), height: nil))
                rowHeight = max(rowHeight, size.height)
            }
            for (column, index) in row.enumerated() {
                origins.append(CGPoint(x: CGFloat(column) * (cellWidth + spacing), y: y))
                widths[index] = cellWidth
            }
            y += rowHeight + spacing
        }
        return (CGSize(width: width, height: max(0, y - spacing)), origins, widths)
    }
}
