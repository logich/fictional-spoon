import AudioToolbox
import AVFoundation
import Foundation
import UIKit

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

    /// When true, the start bell and countdown are skipped, and the calling
    /// sequence pauses automatically when the rider halts for > 5 seconds.
    let practiceMode: Bool

    /// Seconds added/subtracted from the look-ahead window.
    /// Negative = announce earlier; positive = announce later.
    let timingOffset: Double

    /// Index into `test.movements` of the movement currently being watched for.
    private(set) var currentMovementIndex: Int = 0

    /// Whether the test has been completed (all movements announced).
    private(set) var isFinished: Bool = false

    /// Phase of the pre-ride bell/countdown sequence.
    private(set) var countdownPhase: CountdownPhase = .idle

    enum CountdownPhase: Sendable {
        case idle      // not started
        case counting  // bell rang, 45-second timer running
        case active    // ready for movement announcements
    }

    /// Seconds of estimated travel time to the trigger location at which to announce.
    /// 4 seconds ≈ 2–3 strides at trot. Tune in the field.
    var lookAheadSeconds: Double = 4.0

    /// Fallback distance (meters) used when the rider is nearly stationary.
    var triggerDistance: Double = 5.0

    private let synthesizer = AVSpeechSynthesizer()
    private(set) var lastAnnouncedIndex: Int = -1

    private var countdownTimer: Timer?
    private var countdownStartTime: Date?

    private var stationaryStartTime: Date?
    private let practiceHaltThreshold: TimeInterval = 5.0

    init(
        test: DressageTest,
        configuration: ArenaConfiguration,
        practiceMode: Bool = false,
        timingOffset: Double = 0.0
    ) {
        self.test = test
        self.configuration = configuration
        self.practiceMode = practiceMode
        self.timingOffset = timingOffset
        configureAudioSession()
    }

    // MARK: - Public interface

    /// Rings the bell and starts the 45-second countdown (competition mode),
    /// or immediately activates movement announcements (practice mode).
    func startCountdown() {
        guard countdownPhase == .idle else { return }
        if practiceMode {
            countdownPhase = .active
            return
        }
        // Bell placeholder — replace with AVAudioPlayer loading "bell.caf" once a real asset is available.
        AudioServicesPlaySystemSound(1057)
        countdownPhase = .counting
        countdownStartTime = Date()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tickCountdown() }
        }
    }

    /// Called on every position update. Announces the current movement when
    /// the rider is within look-ahead time (or fallback distance) of the trigger
    /// location, then advances to the next movement.
    func checkAndAnnounce(riderState: RiderState, velocity: CGVector, motionState: MotionState) {
        guard !isFinished else { return }
        guard countdownPhase == .active else { return }
        guard riderState.confidence != .none else { return }
        guard currentMovementIndex < test.movements.count else {
            finishTest()
            return
        }

        // Practice mode: pause sequence when rider is halted for > threshold seconds.
        if practiceMode {
            if motionState == .stationary {
                if stationaryStartTime == nil { stationaryStartTime = Date() }
                if let start = stationaryStartTime,
                   Date().timeIntervalSince(start) > practiceHaltThreshold {
                    return
                }
            } else {
                stationaryStartTime = nil
            }
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
        countdownTimer?.invalidate()
        countdownTimer = nil
        currentMovementIndex = 0
        lastAnnouncedIndex = -1
        isFinished = false
        countdownPhase = .idle
        stationaryStartTime = nil
    }

    // MARK: - Countdown

    private func tickCountdown() {
        guard let start = countdownStartTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        let remaining = 45.0 - elapsed
        if remaining <= 30.5 && remaining > 29.5 { speak("30 seconds") }
        if remaining <= 15.5 && remaining > 14.5 { speak("15 seconds") }
        if remaining <= 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
            countdownPhase = .active
        }
    }

    // MARK: - Private

    /// Returns true when the rider should receive the announcement for the current movement.
    /// Uses velocity-based ETA when moving; falls back to distance threshold when slow/stationary.
    /// `timingOffset` shifts the trigger window: negative = earlier, positive = later.
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
                // Negative offset makes the window larger (earlier trigger);
                // positive offset makes it smaller (later trigger).
                let effectiveLookAhead = max(lookAheadSeconds - timingOffset, 1.0)
                return eta < effectiveLookAhead
            }
        }

        // Stationary or moving away — use distance threshold adjusted by timing offset.
        let effectiveTriggerDistance = triggerDistance + (timingOffset * motionState(for: speed) * -1)
        return distance < max(effectiveTriggerDistance, 1.0)
    }

    /// Rough speed-based motion state for distance fallback calculation.
    private func motionState(for speed: Double) -> Double {
        switch speed {
        case ..<0.5: return 0.3
        case ..<2.0: return 1.5
        case ..<5.0: return 3.5
        default:     return 6.0
        }
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
