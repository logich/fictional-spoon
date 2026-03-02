import AVFoundation
import Foundation

/// Text-to-speech service for announcing arena letters.
@MainActor
@Observable
final class AnnouncementService: NSObject {
    /// Distance threshold in meters to trigger an announcement.
    var triggerThreshold: Double = 5.0

    /// Cooldown in seconds before re-announcing the same letter.
    var cooldownInterval: TimeInterval = 10.0

    private let synthesizer = AVSpeechSynthesizer()
    private var lastAnnouncedLetter: ArenaLetter?
    private var lastAnnouncementTime: Date = .distantPast

    override init() {
        super.init()
        configureAudioSession()
    }

    /// Check rider state and announce if approaching a letter.
    func checkAndAnnounce(state: RiderState) {
        guard state.confidence != .none else { return }
        guard state.distanceToNearest < triggerThreshold else {
            return
        }

        let now = Date()
        let sameLetterCooldownExpired =
            state.nearestLetter != lastAnnouncedLetter
            || now.timeIntervalSince(lastAnnouncementTime) >= cooldownInterval

        guard sameLetterCooldownExpired else { return }

        announce("Approaching \(state.nearestLetter.rawValue)")
        lastAnnouncedLetter = state.nearestLetter
        lastAnnouncementTime = now
    }

    /// Speak the given text.
    func announce(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error.localizedDescription)")
        }
    }
}
