import AVFoundation
import MediaPlayer
import Observation
import JohnCore

/// One chapter that the synthesizer reads. Verse numbers are not part of `texts`.
struct ReadAloudChapter: Equatable, Sendable {
    let bookCode: String
    let bookName: String
    let chapter: Int
    let translation: TranslationID
    let labels: [String]
    let texts: [String]
    var title: String { "\(bookName) \(chapter)" }
}

/// Reads a chapter verse by verse with AVSpeechSynthesizer.
/// It owns the audio session, the lock screen controls, and the interruption handling.
@MainActor @Observable final class ReadAloudController: NSObject {
    static let rateKey = "readAloudRate"
    static let voiceKey = "readAloudVoiceID"

    private(set) var chapter: ReadAloudChapter?
    private(set) var currentIndex = 0
    private(set) var isPlaying = false

    /// Speech rate from `AVSpeechUtteranceMinimumSpeechRate` to `AVSpeechUtteranceMaximumSpeechRate`.
    var rate: Float {
        didSet {
            UserDefaults.standard.set(rate, forKey: Self.rateKey)
            restartVerseIfPlaying()
        }
    }
    /// Identifier of a system voice. Nil means the default voice for English.
    var voiceID: String? {
        didSet {
            UserDefaults.standard.set(voiceID, forKey: Self.voiceKey)
            restartVerseIfPlaying()
        }
    }

    var isActive: Bool { chapter != nil }
    var currentLabel: String? {
        guard let chapter, chapter.labels.indices.contains(currentIndex) else { return nil }
        return chapter.labels[currentIndex]
    }
    var canGoNext: Bool { chapter.map { currentIndex + 1 < $0.texts.count } ?? false }
    var canGoPrevious: Bool { currentIndex > 0 }

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var currentUtterance: AVSpeechUtterance?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var commandsRegistered = false

    override init() {
        let stored = UserDefaults.standard.object(forKey: Self.rateKey) as? Float
        rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate,
                                                           stored ?? AVSpeechUtteranceDefaultSpeechRate))
        voiceID = UserDefaults.standard.string(forKey: Self.voiceKey)
        super.init()
        synthesizer.delegate = self
    }

    /// System voices for English, sorted by name.
    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name == $1.name ? $0.identifier < $1.identifier : $0.name < $1.name }
    }

    func isReading(bookCode: String, chapter number: Int, translation: TranslationID) -> Bool {
        guard let chapter else { return false }
        return chapter.bookCode == bookCode && chapter.chapter == number && chapter.translation == translation
    }

    /// The verse index in this chapter that is spoken now, or nil when another chapter is read or nothing is read.
    func spokenIndex(bookCode: String, chapter number: Int, translation: TranslationID) -> Int? {
        isReading(bookCode: bookCode, chapter: number, translation: translation) ? currentIndex : nil
    }

    // MARK: Commands

    func start(_ chapter: ReadAloudChapter, from index: Int = 0) {
        guard !chapter.texts.isEmpty else { return }
        configureSession()
        registerRemoteCommands()
        stopSpeaking()
        self.chapter = chapter
        currentIndex = min(max(0, index), chapter.texts.count - 1)
        speakCurrent()
    }

    func play() {
        guard chapter != nil, !isPlaying else { return }
        configureSession()
        if synthesizer.isPaused, synthesizer.continueSpeaking() {
            isPlaying = true
            updateNowPlaying()
        } else {
            speakCurrent()
        }
    }

    func pause() {
        guard chapter != nil, isPlaying else { return }
        if !synthesizer.pauseSpeaking(at: .immediate) { stopSpeaking() }
        isPlaying = false
        updateNowPlaying()
    }

    func togglePlayback() { isPlaying ? pause() : play() }

    func next() {
        guard canGoNext else { return }
        currentIndex += 1
        speakCurrent()
    }

    func previous() {
        guard chapter != nil, currentIndex > 0 else { return }
        currentIndex -= 1
        speakCurrent()
    }

    func stop() {
        stopSpeaking()
        chapter = nil
        currentIndex = 0
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        removeInterruptionObserver()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Speech

    private func stopSpeaking() {
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func speakCurrent() {
        guard let chapter, chapter.texts.indices.contains(currentIndex) else { return }
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: chapter.texts[currentIndex])
        utterance.rate = rate
        utterance.voice = voiceID.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
            ?? AVSpeechSynthesisVoice(language: "en-US")
        currentUtterance = utterance
        isPlaying = true
        synthesizer.speak(utterance)
        updateNowPlaying()
    }

    private func restartVerseIfPlaying() {
        if chapter != nil, isPlaying { speakCurrent() }
    }

    fileprivate func utteranceFinished(_ id: ObjectIdentifier) {
        guard let currentUtterance, ObjectIdentifier(currentUtterance) == id else { return }
        if canGoNext {
            currentIndex += 1
            speakCurrent()
        } else {
            stop()
        }
    }

    // MARK: Audio session, interruptions, lock screen

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:))
            Task { @MainActor in self?.handleInterruption(type: type, options: options) }
        }
    }

    private func removeInterruptionObserver() {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        interruptionObserver = nil
    }

    private func handleInterruption(type: AVAudioSession.InterruptionType?, options: AVAudioSession.InterruptionOptions?) {
        guard chapter != nil else { return }
        switch type {
        case .began:
            if isPlaying { pause() }
        case .ended:
            if options?.contains(.shouldResume) == true { play() }
        default:
            break
        }
    }

    private func registerRemoteCommands() {
        guard !commandsRegistered else { return }
        commandsRegistered = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let chapter else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: chapter.title,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let label = currentLabel { info[MPMediaItemPropertyArtist] = "Verse \(label)" }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

extension ReadAloudController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceFinished(id) }
    }
}
