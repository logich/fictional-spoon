import AudioToolbox
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

    /// Seconds of estimated travel time to the trigger location at which to announce.
    /// 4 seconds ≈ 2–3 strides at trot. Tune in the field.
    var lookAheadSeconds: Double = 4.0

    /// Fallback distance (meters) used when the rider is nearly stationary.
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
    /// the rider is within look-ahead time (or fallback distance) of the trigger
    /// location, then advances to the next movement.
    func checkAndAnnounce(riderState: RiderState, velocity: CGVector) {
        guard !isFinished else { return }
        guard riderState.confidence != .none else { return }
        guard currentMovementIndex < test.movements.count else {
            finishTest()
            return
        }

        let movement = test.movements[currentMovementIndex]
        let target = movement.location.position(for: configuration.arenaSize)
        let pos = riderState.position

        let dx = target.x - pos.x
        let dy = target.y - pos.y
        let distance = (dx * dx + dy * dy).squareRoot()

        let shouldTrigger = isWithinTriggerZone(
            distance: distance, toTarget: CGPoint(x: dx, y: dy), velocity: velocity
        )

        guard shouldTrigger else { return }
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

    /// Returns true when the rider should receive the announcement for the current movement.
    /// Uses velocity-based ETA when moving; falls back to distance threshold when slow/stationary.
    private func isWithinTriggerZone(distance: Double, toTarget: CGPoint, velocity: CGVector) -> Bool {
        let speed = (velocity.dx * velocity.dx + velocity.dy * velocity.dy).squareRoot()

        // Use ETA-based look-ahead when moving at a meaningful speed.
        if speed > 0.5 {
            // Project velocity onto the direction toward the target.
            let unitDx = toTarget.x / max(distance, 0.001)
            let unitDy = toTarget.y / max(distance, 0.001)
            let approachSpeed = velocity.dx * unitDx + velocity.dy * unitDy

            if approachSpeed > 0.1 {
                let eta = distance / approachSpeed
                return eta < lookAheadSeconds
            }
        }

        // Stationary or moving away — use simple distance threshold.
        return distance < triggerDistance
    }

    private func advanceMovement() {
        let nextIndex = currentMovementIndex + 1
        if nextIndex < test.movements.count {
            currentMovementIndex = nextIndex
        } else {
            finishTest()
        }
    }

    private func finishTest() {
        isFinished = true
        playCompletionChime()
        // Brief delay so the chime plays before speech begins.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.speak("Test complete.")
        }
    }

    private func playCompletionChime() {
        // System sound 1322 — a pleasant completion tone available on iOS 16+.
        // Falls back gracefully on older OS versions.
        AudioServicesPlaySystemSound(SystemSoundID(1322))
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
