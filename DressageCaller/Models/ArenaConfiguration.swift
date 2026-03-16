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

    /// Default prototype configuration: 4 beacons at A, E, C, B in a 20×60m arena.
    // Placeholder major/minor values — update after running Beacon Diagnostic
    static let prototype = ArenaConfiguration(
        beaconUUID: UUID(uuidString: "F7826DA6-4FA2-4E98-8024-BC5B71E0893E")!, // Kontakt factory default
        arenaSize: .standard,
        beaconMappings: [
            // Kontakt hardware
            BeaconMapping(letter: .H, major: 1, minor: 0),
            BeaconMapping(letter: .M, major: 1, minor: 1),
            BeaconMapping(letter: .K, major: 1, minor: 2),
            BeaconMapping(letter: .F, major: 1, minor: 3),
            // ESP32 devices
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
