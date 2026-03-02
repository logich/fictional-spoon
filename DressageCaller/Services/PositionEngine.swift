import Foundation

/// Estimates rider position from beacon distances using weighted trilateration.
@MainActor
@Observable
final class PositionEngine {
    var riderState: RiderState = .unknown

    private let configuration: ArenaConfiguration
    private let smoothingWindow: Int
    private var positionHistory: [CGPoint] = []

    init(configuration: ArenaConfiguration = .prototype, smoothingWindow: Int = 5) {
        self.configuration = configuration
        self.smoothingWindow = smoothingWindow
    }

    /// Update the position estimate from the latest beacon readings.
    func update(from beacons: [DetectedBeacon]) {
        // Filter to beacons with valid distance readings
        let valid = beacons.filter { $0.accuracy > 0 }

        guard !valid.isEmpty else {
            riderState = .unknown
            positionHistory.removeAll()
            return
        }

        // Weighted centroid approximation
        var totalWeight: Double = 0
        var weightedX: Double = 0
        var weightedY: Double = 0

        for beacon in valid {
            let pos = beacon.letter.position(for: configuration.arenaSize)
            let weight = 1.0 / max(beacon.accuracy, 0.5)
            weightedX += weight * pos.x
            weightedY += weight * pos.y
            totalWeight += weight
        }

        let raw = CGPoint(x: weightedX / totalWeight, y: weightedY / totalWeight)

        // Clamp to arena bounds
        let clamped = CGPoint(
            x: min(max(raw.x, 0), configuration.arenaSize.width),
            y: min(max(raw.y, 0), configuration.arenaSize.length)
        )

        // Smoothing via rolling average
        positionHistory.append(clamped)
        if positionHistory.count > smoothingWindow {
            positionHistory.removeFirst(positionHistory.count - smoothingWindow)
        }

        let smoothed = CGPoint(
            x: positionHistory.map(\.x).reduce(0, +) / Double(positionHistory.count),
            y: positionHistory.map(\.y).reduce(0, +) / Double(positionHistory.count)
        )

        // Find nearest letter
        let (nearest, distance) = findNearestLetter(to: smoothed)

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
            position: smoothed,
            nearestLetter: nearest,
            distanceToNearest: distance,
            confidence: confidence
        )
    }

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
