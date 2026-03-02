import Foundation

/// All standard dressage arena letters with their positions in meters.
/// Origin (0,0) is the bottom-left corner of the arena (A end, left side when facing C).
enum ArenaLetter: String, CaseIterable, Identifiable, Sendable {
    // Perimeter letters (clockwise from A)
    case A, K, V, E, S, H, C, M, R, B, P, F
    // Centerline letters
    case D, L, X, I, G

    var id: String { rawValue }

    /// Position in a 20×60m arena. Origin at bottom-left, A at bottom center.
    var position60: CGPoint {
        switch self {
        // Bottom (A end)
        case .A: CGPoint(x: 10, y: 0)
        // Left wall going up (viewer's left facing C)
        case .K: CGPoint(x: 0, y: 6)
        case .V: CGPoint(x: 0, y: 18)
        case .E: CGPoint(x: 0, y: 30)
        case .S: CGPoint(x: 0, y: 42)
        case .H: CGPoint(x: 0, y: 54)
        // Top (C end)
        case .C: CGPoint(x: 10, y: 60)
        // Right wall going down
        case .M: CGPoint(x: 20, y: 54)
        case .R: CGPoint(x: 20, y: 42)
        case .B: CGPoint(x: 20, y: 30)
        case .P: CGPoint(x: 20, y: 18)
        case .F: CGPoint(x: 20, y: 6)
        // Centerline (bottom to top)
        case .D: CGPoint(x: 10, y: 6)
        case .L: CGPoint(x: 10, y: 18)
        case .X: CGPoint(x: 10, y: 30)
        case .I: CGPoint(x: 10, y: 42)
        case .G: CGPoint(x: 10, y: 54)
        }
    }

    /// Position in a 20×40m arena. Origin at bottom-left, A at bottom center.
    var position40: CGPoint {
        switch self {
        // Bottom (A end)
        case .A: CGPoint(x: 10, y: 0)
        // Left wall
        case .K: CGPoint(x: 0, y: 6)
        case .V: CGPoint(x: 0, y: 14)
        case .E: CGPoint(x: 0, y: 20)
        case .S: CGPoint(x: 0, y: 26)
        case .H: CGPoint(x: 0, y: 34)
        // Top (C end)
        case .C: CGPoint(x: 10, y: 40)
        // Right wall
        case .M: CGPoint(x: 20, y: 34)
        case .R: CGPoint(x: 20, y: 26)
        case .B: CGPoint(x: 20, y: 20)
        case .P: CGPoint(x: 20, y: 14)
        case .F: CGPoint(x: 20, y: 6)
        // Centerline
        case .D: CGPoint(x: 10, y: 6)
        case .L: CGPoint(x: 10, y: 14)
        case .X: CGPoint(x: 10, y: 20)
        case .I: CGPoint(x: 10, y: 26)
        case .G: CGPoint(x: 10, y: 34)
        }
    }

    /// Position for a given arena size.
    func position(for size: ArenaSize) -> CGPoint {
        switch size {
        case .small: position40
        case .standard: position60
        }
    }

    /// Whether this letter is on the perimeter (not centerline).
    var isPerimeter: Bool {
        switch self {
        case .D, .L, .X, .I, .G: false
        default: true
        }
    }
}
