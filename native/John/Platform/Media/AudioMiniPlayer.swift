import SwiftUI

/// The mini-player content for `tabViewBottomAccessory`. It shows read-aloud first, then Media audio.
/// It has no entrance animation: the accessory shows in its final state.
struct AudioMiniPlayer: View {
    @Environment(JohnRuntime.self) private var runtime
    @Environment(AppRouter.self) private var router
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var colors: JohnColors { preferences.colors(for: colorScheme) }

    static func isActive(in runtime: JohnRuntime) -> Bool {
        runtime.readAloud.isActive || runtime.activeMediaAudio != nil
    }

    var body: some View {
        let readAloud = runtime.readAloud
        let media = runtime.activeMediaAudio
        let showsReadAloud = readAloud.isActive
        let title = showsReadAloud ? (readAloud.chapter?.title ?? "") : (media?.episode.title ?? "")
        let subtitle = showsReadAloud ? readAloud.currentLabel.map { "Verse \($0)" } : "Rosary audio"
        let playing = showsReadAloud ? readAloud.isPlaying : (media?.isPlaying ?? false)

        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 10) {
                    Image(systemName: showsReadAloud ? "text.book.closed" : "headphones")
                        .foregroundStyle(colors.tint)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title).font(JohnTypography.sans(14, weight: .semibold)).lineLimit(1)
                        if placement != .inline, let subtitle {
                            Text(subtitle).font(JohnTypography.sans(12)).foregroundStyle(colors.textDim).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showsReadAloud ? "Open \(title) in the Reader" : "Open \(title)")
            .accessibilityIdentifier("audio-mini-player-open")

            Button {
                if showsReadAloud { readAloud.togglePlayback() } else { media?.togglePlayback() }
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playing ? "Pause" : "Play")
            .accessibilityIdentifier("audio-mini-player-toggle")
        }
        .padding(.horizontal, 16)
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("audio-mini-player")
        .accessibilityValue("\(showsReadAloud ? "read-aloud" : "media"), \(playing ? "playing" : "paused")")
    }

    private func open() {
        let readAloud = runtime.readAloud
        if let chapter = readAloud.chapter {
            router.openReader(bookCode: chapter.bookCode, chapter: chapter.chapter, translation: chapter.translation,
                              verse: readAloud.currentLabel)
        } else if let media = runtime.activeMediaAudio {
            router.select(.pray)
            if case .rosaryMedia? = router.path(for: .pray).last { return }
            router.push(.rosaryMedia(media.episode.id))
        }
    }
}

/// Adds the bottom accessory only while audio is active. `isEnabled:` needs iOS 26.1. On iOS 26.0 the accessory
/// content is added only while audio is active, so no empty accessory shows.
struct AudioMiniPlayerAccessory: ViewModifier {
    let isActive: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isActive) { AudioMiniPlayer() }
        } else if isActive {
            content.tabViewBottomAccessory { AudioMiniPlayer() }
        } else {
            content
        }
    }
}
