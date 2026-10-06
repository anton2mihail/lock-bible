import AVFoundation
import Foundation
import Observation

enum RosaryMediaMode: String, CaseIterable, Identifiable {
    case video, audio
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum RosaryMediaPlaybackState: Equatable {
    case pending
    case loading
    case ready
    case failed
}

@MainActor @Observable final class RosaryMediaModel {
    private(set) var episode: RosaryMediaEpisode
    private(set) var mode: RosaryMediaMode = .video
    private(set) var state: RosaryMediaPlaybackState = .pending
    private(set) var player: AVPlayer?
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var isTestSource = false

    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var playbackObservation: NSKeyValueObservation?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var isActive = false

    #if DEBUG
    private static let testVideoURI = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    private static let testAudioURI = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"
    #endif

    init(episode: RosaryMediaEpisode) {
        self.episode = episode
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.player?.pause() }
        }
        configurePlayer()
    }

    var playerAvailable: Bool {
        #if DEBUG
        true
        #else
        [episode.videoUri, episode.audioUri].contains { !($0 ?? "").isEmpty }
        #endif
    }

    var progress: Double {
        guard duration.isFinite, duration > 0, currentTime.isFinite else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    func selectMode(_ next: RosaryMediaMode) {
        guard mode != next else { return }
        player?.pause()
        releasePlayer()
        mode = next
        configurePlayer()
    }

    func selectEpisode(_ next: RosaryMediaEpisode) {
        guard episode.id != next.id else { return }
        player?.pause()
        releasePlayer()
        episode = next
        mode = .video
        currentTime = 0
        duration = 0
        isPlaying = false
        configurePlayer()
    }

    func togglePlayback() {
        guard state == .ready, let player else { return }
        if player.timeControlStatus == .playing { player.pause() }
        else { player.play() }
    }

    func seek(to progress: Double) {
        guard let player, duration.isFinite, duration > 0 else { return }
        let bounded = min(1, max(0, progress.isFinite ? progress : 0))
        player.seek(to: CMTime(seconds: duration * bounded, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func pause() { player?.pause() }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        player?.pause()
        releasePlayer()
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        interruptionObserver = nil
        state = .pending
    }

    func stopAndRelease() { deactivate() }

    private func configurePlayer() {
        guard playerAvailable else { state = .pending; return }
        let directURI = mode == .video ? episode.videoUri : episode.audioUri
        #if DEBUG
        let uri: String? = directURI ?? (mode == .video ? Self.testVideoURI : Self.testAudioURI)
        isTestSource = directURI == nil
        #else
        let uri = directURI
        isTestSource = false
        #endif
        guard let uri, !uri.isEmpty, let url = URL(string: uri) else {
            state = .pending
            return
        }
        state = .loading
        let item = AVPlayerItem(url: url)
        let activePlayer = AVPlayer(playerItem: item)
        player = activePlayer
        playbackObservation = activePlayer.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self, weak activePlayer] _, _ in
            Task { @MainActor in
                guard let self, let activePlayer, self.isActive, self.player === activePlayer else { return }
                self.isPlaying = activePlayer.timeControlStatus == .playing
            }
        }
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, self.player?.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    self.state = .ready
                    let seconds = item.duration.seconds
                    self.duration = seconds.isFinite ? max(0, seconds) : 0
                case .failed:
                    self.state = .failed
                case .unknown:
                    self.state = .loading
                @unknown default:
                    self.state = .failed
                }
            }
        }
        timeObserver = activePlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self, self.isActive, self.player === activePlayer else { return }
                let seconds = time.seconds
                self.currentTime = seconds.isFinite ? max(0, seconds) : 0
                self.isPlaying = activePlayer.timeControlStatus == .playing
                let itemDuration = activePlayer.currentItem?.duration.seconds ?? 0
                self.duration = itemDuration.isFinite ? max(0, itemDuration) : 0
            }
        }
    }

    private func releasePlayer() {
        statusObservation?.invalidate()
        statusObservation = nil
        playbackObservation?.invalidate()
        playbackObservation = nil
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        player?.replaceCurrentItem(with: nil)
        player = nil
        currentTime = 0
        duration = 0
        isPlaying = false
    }
}

func rosaryMediaTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let whole = Int(seconds)
    return "\(whole / 60):\(String(format: "%02d", whole % 60))"
}
