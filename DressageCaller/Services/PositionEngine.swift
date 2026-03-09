import Foundation

/// Estimates rider position from beacon distances using least-squares trilateration,
/// constrained by accelerometer-derived motion state.
@MainActor
@Observable
final class PositionEngine {
    var riderState: RiderState = .unknown

    private let configuration: ArenaConfiguration
    private let calibration: BeaconCalibration

    /// Number of iterations for the non-linear least-squares solver.
    private let solverIterations = 10

    /// Last accepted position (after motion filtering).
    private var lastPosition: CGPoint?
    /// Timestamp of last accepted position.
    private var lastUpdateTime: Date?
    /// Smoothed velocity vector (meters/sec) for direction continuity and look-ahead.
    private(set) var velocity: CGVector = .zero

    init(configuration: ArenaConfiguration = .prototype, calibration: BeaconCalibration = .uncalibrated) {
        self.configuration = configuration
        self.calibration = calibration
    }

    /// Update the position estimate from the latest beacon readings,
    /// constrained by the current motion state from the accelerometer.
    func update(from beacons: [DetectedBeacon], motionState: MotionState) {
        // When calibrated, compute distance from RSSI using the measured TX power.
        // Otherwise fall back to CoreLocation's accuracy (distance estimate).
        let valid: [DetectedBeacon]
        if calibration.readings.isEmpty {
            valid = beacons.filter { $0.accuracy > 0 }
        } else {
            valid = beacons.filter { $0.rssi != 0 }.map { beacon in
                let dist = calibration.estimatedDistance(rssi: beacon.rssi, for: beacon.letter)
                return DetectedBeacon(
                    letter: beacon.letter,
                    rssi: beacon.rssi,
                    accuracy: dist,
                    proximity: beacon.proximity,
                    lastSeen: beacon.lastSeen
                )
            }
        }

        guard !valid.isEmpty else {
            riderState = .unknown
            return
        }

        // Raw trilateration estimate
        let raw: CGPoint
        if valid.count >= 3 {
            raw = trilaterate(beacons: valid)
        } else if valid.count == 2 {
            raw = bilateralEstimate(beacons: valid)
        } else {
            raw = singleBeaconEstimate(beacon: valid[0])
        }

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

        // Determine confidence
        let confidence: RiderState.Confidence
        if valid.count >= 3 && valid.allSatisfy({ $0.accuracy < 10 }) {
            confidence = .strong
        } else if valid.count >= 1 {
            confidence = .weak
        } else {
            confidence = .none
        }

        riderState = RiderState(
            position: filtered,
            nearestLetter: nearest,
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

    // MARK: - Trilateration (3+ beacons)

    /// Least-squares trilateration via iterative Gauss-Newton.
    private func trilaterate(beacons: [DetectedBeacon]) -> CGPoint {
        let points = beacons.map { $0.letter.position(for: configuration.arenaSize) }
        let distances = beacons.map(\.accuracy)
        let weights = distances.map { 1.0 / max($0 * $0, 0.25) }

        // Seed: weighted centroid
        var x = 0.0, y = 0.0, tw = 0.0
        for (i, p) in points.enumerated() {
            let w = weights[i]
            x += w * p.x
            y += w * p.y
            tw += w
        }
        x /= tw
        y /= tw

        // Gauss-Newton iterations
        for _ in 0..<solverIterations {
            var jtWj00 = 0.0, jtWj01 = 0.0, jtWj11 = 0.0
            var jtWr0 = 0.0, jtWr1 = 0.0

            for (i, p) in points.enumerated() {
                let ddx = x - p.x
                let ddy = y - p.y
                let dist = max((ddx * ddx + ddy * ddy).squareRoot(), 0.001)
                let residual = distances[i] - dist

                let jx = ddx / dist
                let jy = ddy / dist
                let w = weights[i]

                jtWj00 += w * jx * jx
                jtWj01 += w * jx * jy
                jtWj11 += w * jy * jy
                jtWr0 += w * jx * residual
                jtWr1 += w * jy * residual
            }

            let det = jtWj00 * jtWj11 - jtWj01 * jtWj01
            guard abs(det) > 1e-12 else { break }

            let deltaX = (jtWj11 * jtWr0 - jtWj01 * jtWr1) / det
            let deltaY = (jtWj00 * jtWr1 - jtWj01 * jtWr0) / det

            x -= deltaX
            y -= deltaY

            if deltaX * deltaX + deltaY * deltaY < 0.001 { break }
        }

        return CGPoint(x: x, y: y)
    }

    // MARK: - Two-beacon estimate

    private func bilateralEstimate(beacons: [DetectedBeacon]) -> CGPoint {
        let p1 = beacons[0].letter.position(for: configuration.arenaSize)
        let p2 = beacons[1].letter.position(for: configuration.arenaSize)
        let d1 = beacons[0].accuracy
        let d2 = beacons[1].accuracy

        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let dist12 = max((dx * dx + dy * dy).squareRoot(), 0.001)

        let a = (d1 * d1 - d2 * d2 + dist12 * dist12) / (2 * dist12)
        let hSq = d1 * d1 - a * a

        let mx = p1.x + a * dx / dist12
        let my = p1.y + a * dy / dist12

        if hSq <= 0 {
            return CGPoint(x: mx, y: my)
        }

        let h = hSq.squareRoot()
        let nx = -dy / dist12
        let ny = dx / dist12

        let c1 = CGPoint(x: mx + h * nx, y: my + h * ny)
        let c2 = CGPoint(x: mx - h * nx, y: my - h * ny)

        let center = CGPoint(x: configuration.arenaSize.width / 2,
                             y: configuration.arenaSize.length / 2)

        func distToCenter(_ p: CGPoint) -> Double {
            let ddx = p.x - center.x
            let ddy = p.y - center.y
            return ddx * ddx + ddy * ddy
        }

        func isInBounds(_ p: CGPoint) -> Bool {
            p.x >= 0 && p.x <= configuration.arenaSize.width &&
            p.y >= 0 && p.y <= configuration.arenaSize.length
        }

        let c1In = isInBounds(c1)
        let c2In = isInBounds(c2)

        if c1In && !c2In { return c1 }
        if c2In && !c1In { return c2 }

        return distToCenter(c1) < distToCenter(c2) ? c1 : c2
    }

    // MARK: - Single-beacon estimate

    private func singleBeaconEstimate(beacon: DetectedBeacon) -> CGPoint {
        let beaconPos = beacon.letter.position(for: configuration.arenaSize)
        let center = CGPoint(x: configuration.arenaSize.width / 2,
                             y: configuration.arenaSize.length / 2)

        let dx = center.x - beaconPos.x
        let dy = center.y - beaconPos.y
        let dist = max((dx * dx + dy * dy).squareRoot(), 0.001)

        let ratio = min(beacon.accuracy / dist, 1.0)
        return CGPoint(x: beaconPos.x + dx * ratio,
                       y: beaconPos.y + dy * ratio)
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
