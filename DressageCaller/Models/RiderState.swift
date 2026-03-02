import Foundation

/// Represents the rider's current estimated state in the arena.
struct RiderState: Sendable {
    /// Estimated position in meters (arena coordinates).
    var position: CGPoint

    /// The nearest arena letter to the current position.
    var nearestLetter: ArenaLetter

    /// Distance in meters to the nearest letter.
    var distanceToNearest: Double

    /// Confidence level based on signal quality.
    var confidence: Confidence

    enum Confidence: Sendable {
        case strong  // Multiple beacons with good signal
        case weak    // Few beacons or poor signal
        case none    // No beacon data
    }

    static let unknown = RiderState(
        position: .zero,
        nearestLetter: .X,
        distanceToNearest: .infinity,
        confidence: .none
    )
}
