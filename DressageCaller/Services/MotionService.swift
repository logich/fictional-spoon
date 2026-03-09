import CoreMotion
import Foundation
import Observation

/// Detected motion intensity, used to constrain position updates.
enum MotionState: String, Sendable {
    case stationary  // Standing still — no meaningful acceleration
    case walking     // Slow movement (~1.5 m/s)
    case trotting    // Moderate rhythmic movement (~3.5 m/s)
    case cantering   // Fast rhythmic movement (~6 m/s)

    /// Maximum plausible speed in meters per second for this state.
    var maxSpeed: Double {
        switch self {
        case .stationary: return 0.3   // small drift allowance
        case .walking:    return 2.0
        case .trotting:   return 5.0
        case .cantering:  return 8.0
        }
    }
}

/// Reads the device accelerometer to classify motion intensity.
/// Used by PositionEngine to reject implausible position jumps.
@MainActor
@Observable
final class MotionService {
    private(set) var motionState: MotionState = .stationary
    private(set) var accelerationMagnitude: Double = 0

    private let motionManager = CMMotionManager()
    private var isRunning = false

    /// Rolling buffer of recent acceleration magnitudes for variance calculation.
    private var magnitudeBuffer: [Double] = []
    private let bufferSize = 20  // ~2 seconds at 10 Hz

    // MARK: - Thresholds

    /// Acceleration variance thresholds (empirically tuned).
    /// These classify the "bumpiness" of recent motion.
    private let stationaryThreshold = 0.005  // very still
    private let walkingThreshold    = 0.03   // gentle sway
    private let trottingThreshold   = 0.15   // rhythmic bounce

    func start() {
        guard !isRunning, motionManager.isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = 0.1  // 10 Hz
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            // Already delivered on .main — no Task hop needed.
            MainActor.assumeIsolated {
                self.processAcceleration(data.acceleration)
            }
        }
        isRunning = true
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
        isRunning = false
        motionState = .stationary
        magnitudeBuffer.removeAll()
    }

    private func processAcceleration(_ accel: CMAcceleration) {
        // Magnitude minus gravity (~1.0g when at rest)
        let mag = (accel.x * accel.x + accel.y * accel.y + accel.z * accel.z).squareRoot()
        let deviation = abs(mag - 1.0)  // deviation from resting gravity

        accelerationMagnitude = deviation

        magnitudeBuffer.append(deviation)
        if magnitudeBuffer.count > bufferSize {
            magnitudeBuffer.removeFirst()
        }

        guard magnitudeBuffer.count >= bufferSize / 2 else { return }

        let variance = self.variance(of: magnitudeBuffer)

        if variance < stationaryThreshold {
            motionState = .stationary
        } else if variance < walkingThreshold {
            motionState = .walking
        } else if variance < trottingThreshold {
            motionState = .trotting
        } else {
            motionState = .cantering
        }
    }

    private func variance(of values: [Double]) -> Double {
        let n = Double(values.count)
        let mean = values.reduce(0, +) / n
        let sumSqDiff = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sumSqDiff / n
    }
}
