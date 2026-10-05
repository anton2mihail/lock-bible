import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case today = "Today"
    case read = "Read"
    case saved = "Saved"
    case pray = "Pray"
    case settings = "Settings"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today: "sun"
        case .read: "book-open"
        case .saved: "bookmark"
        case .pray: "heart"
        case .settings: "settings"
        }
    }
    var identifier: String { "tab-\(rawValue.lowercased())" }
}

struct FlatTabBar: View {
    @Binding var selection: AppTab
    let colors: JohnColors

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 0) {
                        FeatherIcon(name: tab.icon, size: 25, color: selection == tab ? colors.tint : colors.tintInactive)
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(selection == tab ? colors.tint : colors.tintInactive)
                    }
                    .frame(maxWidth: .infinity, minHeight: 49)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(tab.identifier)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .background(colors.background.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(colors.border).frame(height: 0.5) }
    }
}
