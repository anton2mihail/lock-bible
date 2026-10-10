import AVKit
import SwiftUI

struct RosaryMediaView: View {
    let episodeID: String?
    let catalog: RosaryHomeCatalog
    let onOpenURL: (URL) -> Void

    @Environment(JohnRuntime.self) private var runtime
    @Environment(SharedPreferencesModel.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: RosaryMediaModel

    private var colors: JohnColors { preferences.colors(for: colorScheme) }
    private var currentEpisode: RosaryMediaEpisode { model.episode }

    init(episodeID: String?, catalog: RosaryHomeCatalog,
         onOpenURL: @escaping (URL) -> Void) {
        self.episodeID = episodeID
        self.catalog = catalog
        self.onOpenURL = onOpenURL
        let chosen = catalog.mediaEpisodes.first { $0.id == episodeID } ?? catalog.mediaEpisodes.first ?? .unavailable
        _model = State(initialValue: RosaryMediaModel(episode: chosen))
    }

    var body: some View {
        Group {
            if !catalog.isValid {
                ContentUnavailableView {
                    Label("Media is not available", systemImage: "play.slash")
                } description: {
                    Text("The Rosary media list could not be opened.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(colors.background)
            } else {
                mediaPage
            }
        }
        .onAppear {
            guard catalog.isValid else { return }
            if let existing = runtime.mediaAudio, existing !== model {
                // Audio from an earlier visit keeps playing. Reuse it for the same episode.
                if existing.episode.id == model.episode.id, existing.mode == .audio { model = existing }
                else { existing.stopAndRelease() }
            }
            runtime.mediaAudio = model
            model.activate()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, catalog.isValid { model.activate() }
            else if model.mode == .video { model.pause() }
        }
        .onChange(of: episodeID) { _, nextID in
            if let next = catalog.mediaEpisodes.first(where: { $0.id == nextID }) ?? catalog.mediaEpisodes.first {
                model.selectEpisode(next)
            }
        }
        .onDisappear {
            // Playing audio stays alive for the mini-player. Video and paused audio stop.
            if model.mode == .audio, model.isPlaying { return }
            model.deactivate()
            if runtime.mediaAudio === model { runtime.mediaAudio = nil }
        }
    }

    private var mediaPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WORD ON FIRE SERIES").font(JohnTypography.sans(12, weight: .semibold))
                        .tracking(1.5).foregroundStyle(colors.tint)
                    Text(currentEpisode.title).font(JohnTypography.sans(36, weight: .bold))
                        .foregroundStyle(colors.text).accessibilityAddTraits(.isHeader)
                    Text(currentEpisode.subtitle).font(JohnTypography.sans(16))
                        .foregroundStyle(colors.textDim).textSelection(.enabled)
                }

                if model.playerAvailable {
                    modePicker
                    playerContent
                }

                #if DEBUG
                rightsCard
                #endif

                VStack(alignment: .leading, spacing: 12) {
                    Text("All episodes").font(JohnTypography.sans(20, weight: .medium)).foregroundStyle(colors.text)
                    VStack(spacing: 8) {
                        ForEach(Array(catalog.mediaEpisodes.enumerated()), id: \.element.id) { index, episode in
                            episodeRow(episode, number: index + 1)
                        }
                    }
                }

                Button {
                    open(currentEpisode.officialUrl)
                } label: {
                    Text("Watch on the official site")
                        .font(JohnTypography.sans(16, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(colors.background, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(colors.border, lineWidth: 1))
                        .foregroundStyle(colors.text)
                }
                .buttonStyle(.plain)

            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(colors.background)
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(RosaryMediaMode.allCases) { mode in
                let selected = model.mode == mode
                Button { model.selectMode(mode) } label: {
                    Text(mode.title).font(JohnTypography.sans(14, weight: .semibold))
                        .foregroundStyle(selected ? colors.card : colors.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selected ? colors.tint : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.title)
                .accessibilityValue(selected ? "Selected" : "Not selected")
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("rosary-media-mode-\(mode.id)")
            }
        }
        .padding(4)
        .background(colors.card, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private var playerContent: some View {
        if model.mode == .video {
            if let player = model.player {
                VStack(spacing: 12) {
                    RosaryVideoController(player: player)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    if model.isTestSource { Text("Development test clip · This is open sample footage, not Bishop Barron’s video.")
                        .font(JohnTypography.sans(12)).foregroundStyle(colors.textDim) }
                }
                .padding(16)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 20))
            } else {
                pendingCard(kind: "video")
            }
        } else if let _ = model.player {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 18).fill(colors.background)
                    .frame(maxWidth: .infinity).aspectRatio(1.8, contentMode: .fit)
                    .overlay(Text("✢").font(JohnTypography.sans(48)).foregroundStyle(colors.tint))
                    .accessibilityHidden(true)
                Text(currentEpisode.title).font(JohnTypography.sans(20, weight: .medium)).foregroundStyle(colors.text)
                Text(model.isTestSource ? "Development test audio · not Rosary content" : "Bishop Robert Barron")
                    .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim)
                Slider(value: Binding(get: { model.progress }, set: { model.seek(to: $0) }), in: 0...1)
                    .tint(colors.tint)
                HStack {
                    Text(rosaryMediaTime(model.currentTime))
                    Spacer()
                    Text(rosaryMediaTime(model.duration))
                }.font(JohnTypography.sans(12).monospacedDigit()).foregroundStyle(colors.textDim)
                Button { model.togglePlayback() } label: {
                    Text(model.state == .failed ? "Audio unavailable" : "\(model.isPlaying ? "Pause" : "Play") audio")
                        .font(JohnTypography.sans(16, weight: .medium)).frame(maxWidth: .infinity, minHeight: 56)
                        .background(colors.tint, in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(colors.background)
                }
                .disabled(model.state != .ready)
            }
            .padding(24).background(colors.card, in: RoundedRectangle(cornerRadius: 24))
        } else {
            pendingCard(kind: "audio")
        }
    }

    private var rightsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PERMISSION PENDING").font(JohnTypography.sans(11, weight: .semibold)).tracking(1.5).foregroundStyle(colors.tint)
            Text("The player is prepared for approved direct media URLs. Word on Fire’s standard permission page says archived on-demand audio and video require permission, so its files are not bundled here yet.")
                .font(JohnTypography.sans(14)).foregroundStyle(colors.textDim).textSelection(.enabled)
            HStack(spacing: 16) {
                link("Official Rosary page", "https://www.wordonfire.org/rosary/")
                link("Content permission form", "https://www.wordonfire.org/contact/content-request/")
            }
        }
        .padding(.leading, 16)
        .overlay(alignment: .leading) { Rectangle().fill(colors.tint).frame(width: 3) }
    }

    private func episodeRow(_ episode: RosaryMediaEpisode, number: Int) -> some View {
        let selected = episode.id == currentEpisode.id
        return Button { model.selectEpisode(episode) } label: {
            HStack(spacing: 12) {
                Text(String(format: "%02d", number)).font(JohnTypography.sans(12, weight: .semibold))
                    .foregroundStyle(selected ? colors.card : colors.text)
                    .frame(width: 38, height: 38).background(selected ? colors.tint : colors.background, in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(episode.title).font(JohnTypography.sans(14, weight: .semibold)).foregroundStyle(colors.text)
                    Text(episode.subtitle).font(JohnTypography.sans(12)).foregroundStyle(colors.textDim).lineLimit(2)
                }
                Spacer(minLength: 0)
                Text("›").font(JohnTypography.sans(20)).foregroundStyle(colors.tint)
            }
            .padding(12).frame(minHeight: 76).background(colors.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? colors.tint : .clear, lineWidth: 1))
        }
        .buttonStyle(RosaryMediaPressStyle())
        .accessibilityLabel("Episode \(number), \(episode.title). \(episode.subtitle)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("rosary-media-episode-\(episode.id)")
    }

    private func pendingCard(kind: String) -> some View {
        VStack(spacing: 8) {
            Text("Pray with the official recording").font(JohnTypography.sans(20, weight: .medium)).foregroundStyle(colors.text)
            Text("This \(kind) recording is available on the publisher’s website. Open the official site below to pray along.")
                .font(JohnTypography.sans(16)).foregroundStyle(colors.textDim).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220).padding(24)
        .background(colors.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private func link(_ title: String, _ address: String) -> some View {
        Button(title) { open(address) }
            .font(JohnTypography.sans(14, weight: .semibold)).foregroundStyle(colors.tint).underline()
            .buttonStyle(.plain)
    }

    private func open(_ value: String) {
        guard let url = URL(string: value) else { return }
        onOpenURL(url)
    }
}

private struct RosaryVideoController: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = false
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) { controller.player = player }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) { controller.player = nil }
}

private struct RosaryMediaPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.72 : 1)
    }
}
