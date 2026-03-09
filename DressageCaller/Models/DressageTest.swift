import Foundation

// MARK: - Supporting types

/// Recognized dressage organizations.
enum DressageOrganization: String, Sendable, Codable {
    case usdf            // USDF Traditional Dressage
    case usef            // USEF
    case fei             // FEI International
    case westernDressage // Western Dressage
}

/// Gaits a rider may be performing.
enum Gait: String, Sendable, Codable, CaseIterable {
    case halt
    case walk
    case trot
    case canter
}

/// Where a movement is triggered — either at a specific letter or between two letters.
enum MovementLocation: Sendable, Equatable {
    case letter(ArenaLetter)
    case between(ArenaLetter, ArenaLetter)

    /// The arena position (in meters) where this movement should trigger.
    func position(for size: ArenaSize) -> CGPoint {
        switch self {
        case .letter(let l):
            return l.position(for: size)
        case .between(let a, let b):
            let pa = a.position(for: size)
            let pb = b.position(for: size)
            return CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
        }
    }

    /// Human-readable label (e.g. "A" or "Between B & M").
    var label: String {
        switch self {
        case .letter(let l):
            return l.rawValue
        case .between(let a, let b):
            return "Between \(a.rawValue) & \(b.rawValue)"
        }
    }
}

// MARK: - Movement

/// A single step in a dressage test sequence.
struct Movement: Identifiable, Sendable {
    let id: UUID
    /// 1-based position in the test.
    let sequence: Int
    /// Where this movement is announced.
    let location: MovementLocation
    /// What the caller says aloud (e.g. "A — Enter working trot").
    let spokenText: String
    /// Full official directive text for display.
    let directiveText: String
    /// The gait the rider should be in after completing this movement.
    let expectedGait: Gait?

    init(
        id: UUID = UUID(),
        sequence: Int,
        location: MovementLocation,
        spokenText: String,
        directiveText: String,
        expectedGait: Gait? = nil
    ) {
        self.id = id
        self.sequence = sequence
        self.location = location
        self.spokenText = spokenText
        self.directiveText = directiveText
        self.expectedGait = expectedGait
    }
}

// MARK: - DressageTest

/// A dressage test definition — an ordered sequence of movements.
struct DressageTest: Identifiable, Sendable {
    let id: UUID
    let name: String
    let organization: DressageOrganization
    let level: String
    let arenaSize: ArenaSize
    /// Version year of this test (e.g. 2023).
    let year: Int
    let movements: [Movement]

    init(
        id: UUID = UUID(),
        name: String,
        organization: DressageOrganization,
        level: String,
        arenaSize: ArenaSize,
        year: Int,
        movements: [Movement]
    ) {
        self.id = id
        self.name = name
        self.organization = organization
        self.level = level
        self.arenaSize = arenaSize
        self.year = year
        self.movements = movements
    }

    /// The next movement after the given sequence number, or nil if the test is complete.
    func movement(after sequence: Int) -> Movement? {
        movements.first { $0.sequence == sequence + 1 }
    }
}
