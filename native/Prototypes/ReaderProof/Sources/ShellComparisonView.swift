import SwiftUI

private enum ProofTab: String, CaseIterable, Identifiable {
  case today = "Today"
  case reader = "Read"
  case saved = "Saved"
  case pray = "Pray"
  case settings = "Settings"

  var id: String { rawValue }

  var feather: String {
    switch self {
    case .today: "\u{f1e7}" // sun
    case .reader: "\u{f123}" // book-open
    case .saved: "\u{f124}" // bookmark
    case .pray: "\u{f181}" // heart
    case .settings: "\u{f1d3}" // settings
    }
  }
}

struct ShellComparisonView: View {
  @State private var selected: ProofTab = .today

  var body: some View {
    VStack(spacing: 12) {
      Text("Standard iOS 26 tab bar")
        .font(.system(size: 14, weight: .semibold))
      TabView {
        ForEach(ProofTab.allCases) { tab in
          shellPage(tab)
            .tabItem { Label(tab.rawValue, systemImage: systemIcon(tab)) }
            .tag(tab)
        }
      }
      .frame(height: 310)
      .accessibilityIdentifier("standard-tab-view")

      Text("Custom flat comparison")
        .font(.system(size: 14, weight: .semibold))
      shellPage(selected)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      customBar
        .accessibilityIdentifier("custom-tab-bar")
    }
    .padding(.horizontal, 14)
    .padding(.top, 12)
  }

  private var customBar: some View {
    HStack(spacing: 0) {
      ForEach(ProofTab.allCases) { tab in
        Button { selected = tab } label: {
          VStack(spacing: 3) {
            Text(tab.feather)
              .font(.custom("Feather", size: 20))
            Text(tab.rawValue)
              .font(.system(size: 10, weight: selected == tab ? .semibold : .regular))
              .lineLimit(1)
          }
          .foregroundStyle(selected == tab ? ReaderProofTheme.tint : Color(hex: 0x564E4A))
          .frame(maxWidth: .infinity)
          .frame(height: 49)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("custom-tab-\(tab.rawValue.lowercased())")
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(selected == tab ? .isSelected : [])
      }
    }
    .padding(.horizontal, 4)
    .background(ReaderProofTheme.background)
    .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xC6BAA9)).frame(height: 0.5) }
  }

  private func shellPage(_ tab: ProofTab) -> some View {
    VStack(spacing: 8) {
      Text(tab.rawValue)
        .font(.system(size: 20, weight: .semibold))
      Text("Matched label and icon metrics use the source Feather forms.")
        .font(.system(size: 12))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 18)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ReaderProofTheme.background)
  }

  private func systemIcon(_ tab: ProofTab) -> String {
    switch tab {
    case .today: "sun.max"
    case .reader: "book"
    case .saved: "bookmark"
    case .pray: "heart"
    case .settings: "gearshape"
    }
  }
}

private extension Color {
  init(hex: UInt32) {
    self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: 1)
  }
}
