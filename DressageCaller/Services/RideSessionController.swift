import AVFoundation
import Foundation

/// Controls progression through a dressage test during a ride.
///
/// Tracks the current movement index, monitors the rider's proximity to each
/// movement's trigger location, and speaks the movement text via TTS at the
/// right moment.
@MainActor
@Observable
final class RideSessionController {

    let test: DressageTest
    private let configuration: ArenaConfiguration

    /// Index into `test.movements` of the movement currently being watched for.
    private(set) var currentMovementIndex: Int = 0

    /// Whether the test has been completed (all movements announced).
    private(set) var isFinished: Bool = false

    /// Distance in meters from the rider to the current movement trigger location
    /// that causes an announcement. Tune in the field.
    var triggerDistance: Double = 5.0

    private let synthesizer = AVSpeechSynthesizer()
    private var lastAnnouncedIndex: Int = -1

    init(test: DressageTest, configuration: ArenaConfiguration) {
        self.test = test
        self.configuration = configuration
        configureAudioSession()
    }

    // MARK: - Public interface

    /// Called on every position update. Announces the current movement when
    /// the rider enters the trigger zone, then advances to the next movement.
    func checkAndAnnounce(riderState: RiderState) {
        guard !isFinished else { return }
        guard riderState.confidence != .none else { return }
        guard currentMovementIndex < test.movements.count else {
            isFinished = true
            return
        }

        let movement = test.movements[currentMovementIndex]
        let target = movement.location.position(for: configuration.arenaSize)
        let pos = riderState.position

        let dx = pos.x - target.x
        let dy = pos.y - target.y
        let distance = (dx * dx + dy * dy).squareRoot()

        guard distance < triggerDistance else { return }
        guard lastAnnouncedIndex != currentMovementIndex else { return }

        lastAnnouncedIndex = currentMovementIndex
        speak(movement.spokenText)
        advanceMovement()
    }

    /// Manually skip forward to the next movement (e.g. rider tapped "next").
    func skipMovement() {
        advanceMovement()
    }

    /// Resets the test back to the first movement.
    func reset() {
        synthesizer.stopSpeaking(at: .immediate)
        currentMovementIndex = 0
        lastAnnouncedIndex = -1
        isFinished = false
    }

    // MARK: - Private

    private func advanceMovement() {
        let nextIndex = currentMovementIndex + 1
        if nextIndex < test.movements.count {
            currentMovementIndex = nextIndex
        } else {
            isFinished = true
        }
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = VoicePreference.resolvedVoice()
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("RideSessionController: audio session error: \(error.localizedDescription)")
        }
    }
}
