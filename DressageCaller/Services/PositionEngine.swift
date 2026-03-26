import Foundation

/// Estimates rider position from beacon RSSI using proximity-weighted centroid,
/// constrained by accelerometer-derived motion state.
@MainActor
@Observable
final class PositionEngine {
    var riderState: RiderState = .unknown

    private let configuration: ArenaConfiguration
    private let calibration: BeaconCalibration

    /// Last accepted position (after motion filtering).
    private var lastPosition: CGPoint?
    /// Timestamp of last accepted position.
    private var lastUpdateTime: Date?
    /// Smoothed velocity vector (meters/sec) for direction continuity and look-ahead.
    private(set) var velocity: CGVector = .zero

    // MARK: - Letter-change hysteresis
    private var pendingLetter: ArenaLetter? = nil
    private var pendingLetterStart: Date? = nil
    #if targetEnvironment(simulator)
    private let letterHysteresisInterval: TimeInterval = 0.5
    #else
    private let letterHysteresisInterval: TimeInterval = 2.0
    #endif

    init(configuration: ArenaConfiguration = .prototype, calibration: BeaconCalibration = .uncalibrated) {
        self.configuration = configuration
        self.calibration = calibration
    }

    /// Update the position estimate from the latest beacon readings,
    /// constrained by the current motion state from the accelerometer.
    func update(from beacons: [DetectedBeacon], motionState: MotionState) {
        // Prefer beacons above the noise floor; fall back to all negatives if nothing qualifies.
        let strong = beacons.filter { $0.rssi < 0 && $0.rssi > -90 }
        let valid = strong.isEmpty ? beacons.filter { $0.rssi < 0 } : strong

        guard !valid.isEmpty else {
            riderState = .unknown
            return
        }

        // Proximity-weighted centroid — no distance conversion needed
        let raw = weightedCentroid(beacons: valid)

        // Clamp to arena bounds
        let clamped = CGPoint(
            x: min(max(raw.x, 0), configuration.arenaSize.width),
            y: min(max(raw.y, 0), configuration.arenaSize.length)
        )

        // Motion-aware filtering
        let filtered = applyMotionFilter(
            newPosition: clamped,
            motionState: motionState
        )

        lastPosition = filtered
        lastUpdateTime = Date()

        // Find nearest letter
        let (nearest, distance) = findNearestLetter(to: filtered)

        // Use fingerprint match if available (more accurate in RF-challenging environments)
        let rssiMap = Dictionary(uniqueKeysWithValues: valid.map { ($0.letter, Double($0.rssi)) })
        let candidate = calibration.nearestFingerprint(to: rssiMap) ?? nearest

        // Letter-change hysteresis — require stable reading for hysteresisInterval before committing
        let now = Date()
        if candidate != pendingLetter {
            pendingLetter = candidate
            pendingLetterStart = now
        }
        let elapsed = pendingLetterStart.map { now.timeIntervalSince($0) } ?? 0
        let committedLetter = elapsed >= letterHysteresisInterval
            ? candidate
            : riderState.nearestLetter

        // Count clearly audible beacons rather than requiring all to be strong
        // (impossible with 8 beacons spread across a metal barn).
        let strongCount = valid.filter { $0.rssi > -75 }.count
        let confidence: RiderState.Confidence
        if strongCount >= 3 {
            confidence = .strong
        } else if valid.count >= 1 {
            confidence = .weak
        } else {
            confidence = .none
        }

        riderState = RiderState(
            position: filtered,
            nearestLetter: committedLetter,
            distanceToNearest: distance,
            confidence: confidence
        )
    }

    // MARK: - Motion-aware filter

    /// Filters the raw trilateration result using:
    /// 1. **Speed cap** — displacement limited by gait-based max speed
    /// 2. **Direction continuity** — new heading blended with current velocity direction;
    ///    faster gaits allow less abrupt turns (a cantering horse has a wide turn radius)
    /// 3. **Adaptive blend** — stationary ≈ locks position; faster gaits trust new readings more
    private func applyMotionFilter(newPosition: CGPoint, motionState: MotionState) -> CGPoint {
        guard let prev = lastPosition, let prevTime = lastUpdateTime else {
            return newPosition
        }

        let dt = max(Date().timeIntervalSince(prevTime), 0.1)

        // Proposed displacement vector
        var dx = newPosition.x - prev.x
        var dy = newPosition.y - prev.y
        let jumpDistance = (dx * dx + dy * dy).squareRoot()

        // --- 1. Speed cap ---
        let maxDisplacement = motionState.maxSpeed * dt
        if jumpDistance > maxDisplacement && jumpDistance > 0.001 {
            let scale = maxDisplacement / jumpDistance
            dx *= scale
            dy *= scale
        }

        // --- 2. Direction continuity ---
        let currentSpeed = (velocity.dx * velocity.dx + velocity.dy * velocity.dy).squareRoot()

        if currentSpeed > 0.3 && jumpDistance > 0.001 {
            // Maximum allowed heading change per update, in radians.
            // Slower gaits can turn sharply; faster gaits are constrained.
            let maxTurnRate = maxTurnRadians(for: motionState)
            let maxTurn = maxTurnRate * dt

            let currentHeading = atan2(velocity.dy, velocity.dx)
            let proposedHeading = atan2(dy, dx)
            var headingDiff = proposedHeading - currentHeading

            // Normalise to [-π, π]
            while headingDiff > .pi { headingDiff -= 2 * .pi }
            while headingDiff < -.pi { headingDiff += 2 * .pi }

            // Clamp the turn
            let clampedDiff = min(max(headingDiff, -maxTurn), maxTurn)
            let newHeading = currentHeading + clampedDiff

            let stepDistance = (dx * dx + dy * dy).squareRoot()
            dx = cos(newHeading) * stepDistance
            dy = sin(newHeading) * stepDistance
        }

        // --- 3. Adaptive blend ---
        let alpha: Double
        switch motionState {
        case .stationary: alpha = 0.05
        case .walking:    alpha = 0.3
        case .trotting:   alpha = 0.5
        case .cantering:  alpha = 0.7
        }

        let filteredX = prev.x + alpha * dx
        let filteredY = prev.y + alpha * dy

        // Update smoothed velocity (exponential moving average)
        let velAlpha = 0.3
        velocity = CGVector(
            dx: velocity.dx * (1 - velAlpha) + (dx / dt) * velAlpha,
            dy: velocity.dy * (1 - velAlpha) + (dy / dt) * velAlpha
        )

        return CGPoint(x: filteredX, y: filteredY)
    }

    /// Maximum turn rate in radians per second for each gait.
    /// A horse at canter needs ~10m to do a 180°; at walk it can turn on the spot.
    private func maxTurnRadians(for motionState: MotionState) -> Double {
        switch motionState {
        case .stationary: return .pi * 4   // effectively unconstrained
        case .walking:    return .pi * 2   // full 360°/sec — can turn in place
        case .trotting:   return .pi       // 180°/sec — moderate turn arc
        case .cantering:  return .pi * 0.5 // 90°/sec — wide sweeping turns
        }
    }

    // MARK: - Proximity-weighted centroid

    /// Position estimate as the RSSI-weighted centroid of visible beacons.
    /// weight = 10^((rssi + 50) / 20) — stronger signal → much higher weight.
    /// Works for 1, 2, or 3+ beacons without branching.
    private func weightedCentroid(beacons: [DetectedBeacon]) -> CGPoint {
        var wx = 0.0, wy = 0.0, wSum = 0.0
        for b in beacons {
            // Normalise by calibrated TX power so mounting orientation and local
            // multipath variance don't bias the centroid toward any one beacon.
            let txPower = calibration.rssiAt1m(for: b.letter)
            let w = pow(10.0, (Double(b.rssi) - txPower) / 20.0)
            let pos = b.letter.position(for: configuration.arenaSize)
            wx += w * Double(pos.x)
            wy += w * Double(pos.y)
            wSum += w
        }
        guard wSum > 0 else {
            return CGPoint(x: configuration.arenaSize.width / 2, y: configuration.arenaSize.length / 2)
        }
        return CGPoint(x: wx / wSum, y: wy / wSum)
    }

    // MARK: - Nearest letter

    private func findNearestLetter(to point: CGPoint) -> (ArenaLetter, Double) {
        var best: ArenaLetter = .X
        var bestDistance = Double.infinity

        for letter in ArenaLetter.allCases {
            let pos = letter.position(for: configuration.arenaSize)
            let dx = point.x - pos.x
            let dy = point.y - pos.y
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist < bestDistance {
                bestDistance = dist
                best = letter
            }
        }

        return (best, bestDistance)
    }
}
