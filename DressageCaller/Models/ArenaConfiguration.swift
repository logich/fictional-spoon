import Foundation

/// Arena size variants.
enum ArenaSize: String, Sendable, Codable, CaseIterable {
    case small    // 20×40m
    case standard // 20×60m

    var width: Double { 20 }

    var length: Double {
        switch self {
        case .small: 40
        case .standard: 60
        }
    }
}

/// Maps a BLE beacon identity to an arena letter.
struct BeaconMapping: Sendable {
    let letter: ArenaLetter
    let major: UInt16
    let minor: UInt16
}

/// Configuration for a single arena's beacons and dimensions.
struct ArenaConfiguration: Sendable {
    /// Shared iBeacon proximity UUID for all beacons in this app.
    let beaconUUID: UUID

    /// Arena dimensions.
    let arenaSize: ArenaSize

    /// Which letters have beacons and their major/minor values.
    let beaconMappings: [BeaconMapping]

    /// Look up the arena letter for a given major/minor pair.
    func letter(forMajor major: UInt16, minor: UInt16) -> ArenaLetter? {
        beaconMappings.first { $0.major == major && $0.minor == minor }?.letter
    }

    // MARK: - App UUID

    /// Fixed iBeacon proximity UUID pre-programmed into all Dressage Caller hardware.
    /// Every beacon sold with the app uses this UUID — users never need to configure it.
    static let beaconProximityUUID = UUID(uuidString: "74648DDD-D39B-4263-9DE5-4D18C8CF4D83")!

    /// Default configuration: 8 beacons at A, K, E, H, C, M, B, F in a 20×60m arena.
    static let prototype = ArenaConfiguration(
        beaconUUID: beaconProximityUUID,
        arenaSize: .standard,
        beaconMappings: [
            BeaconMapping(letter: .H, major: 1, minor: 0),
            BeaconMapping(letter: .M, major: 1, minor: 1),
            BeaconMapping(letter: .K, major: 1, minor: 2),
            BeaconMapping(letter: .F, major: 1, minor: 3),
            BeaconMapping(letter: .A, major: 1, minor: 4),
            BeaconMapping(letter: .E, major: 1, minor: 5),
            BeaconMapping(letter: .C, major: 1, minor: 6),
            BeaconMapping(letter: .B, major: 1, minor: 7),
        ]
    )

    /// The set of letters that have beacons attached.
    var beaconLetters: Set<ArenaLetter> {
        Set(beaconMappings.map(\.letter))
    }
}
