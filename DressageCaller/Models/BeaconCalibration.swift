import Foundation

/// RSSI fingerprint captured at a specific arena letter position.
/// Records the average RSSI from each visible beacon while the rider stands at that position.
struct FingerprintVector: Sendable, Codable {
    let letter: ArenaLetter
    /// Average RSSI (dBm) per beacon letter observed during the fingerprint walk.
    var rssiByBeacon: [ArenaLetter: Double]

    /// Root-mean-squared RSSI error vs. a set of live readings.
    /// Beacons present in the fingerprint but absent from live readings use −100 dBm.
    func distance(to readings: [ArenaLetter: Double]) -> Double {
        guard !rssiByBeacon.isEmpty else { return .infinity }
        var sumSquares = 0.0
        for (beacon, known) in rssiByBeacon {
            let live = readings[beacon] ?? -100.0
            let diff = known - live
            sumSquares += diff * diff
        }
        return (sumSquares / Double(rssiByBeacon.count)).squareRoot()
    }
}

/// Stores the measured RSSI at 1 meter for each beacon, plus optional arena fingerprints.
struct BeaconCalibration: Sendable, Codable {
    /// Per-letter measured RSSI at 1 meter.
    var readings: [ArenaLetter: Double]

    /// Fingerprint vectors keyed by arena letter. Empty if fingerprinting has not been performed.
    var fingerprints: [ArenaLetter: FingerprintVector] = [:]

    /// The default Apple iBeacon TX power assumption.
    static let defaultRSSIAt1m: Double = -59.0

    /// Number of raw samples averaged to produce each reading.
    static let samplesPerReading = 10

    /// Empty calibration — falls back to defaults for all beacons.
    static let uncalibrated = BeaconCalibration(readings: [:])

    /// UserDefaults key for persisted calibration.
    private static let persistenceKey = "beaconCalibration"

    // Custom Codable so that old persisted data without `fingerprints` still loads.
    private enum CodingKeys: String, CodingKey {
        case readings, fingerprints
    }

    init(readings: [ArenaLetter: Double], fingerprints: [ArenaLetter: FingerprintVector] = [:]) {
        self.readings = readings
        self.fingerprints = fingerprints
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        readings = try container.decode([ArenaLetter: Double].self, forKey: .readings)
        fingerprints = (try? container.decodeIfPresent([ArenaLetter: FingerprintVector].self, forKey: .fingerprints)) ?? [:]
    }

    // MARK: - TX Power

    /// Get the calibrated RSSI at 1m for a given letter, or the default.
    func rssiAt1m(for letter: ArenaLetter) -> Double {
        readings[letter] ?? Self.defaultRSSIAt1m
    }

    /// Estimate distance from RSSI using the log-distance path loss model:
    ///   distance = 10 ^ ((txPower - rssi) / (10 * n))
    /// where n is the path-loss exponent (2.0 for free space, ~2.5–3.0 indoors).
    func estimatedDistance(rssi: Int, for letter: ArenaLetter, pathLossExponent: Double = 2.5) -> Double {
        let txPower = rssiAt1m(for: letter)
        return pow(10.0, (txPower - Double(rssi)) / (10.0 * pathLossExponent))
    }

    // MARK: - Fingerprinting

    /// Find the arena letter whose fingerprint best matches the given live RSSI readings.
    /// Returns nil if fewer than 2 fingerprints are stored.
    func nearestFingerprint(to readings: [ArenaLetter: Double]) -> ArenaLetter? {
        guard fingerprints.count >= 2 else { return nil }
        return fingerprints.values
            .min(by: { $0.distance(to: readings) < $1.distance(to: readings) })
            .map(\.letter)
    }

    // MARK: - Export

    /// Produce a two-section CSV string suitable for Python/Excel analysis.
    /// Pure function — no file I/O. Caller is responsible for writing to disk.
    ///
    /// Section 1: TX calibration readings (RSSI at 1m per beacon).
    /// Section 2: Arena fingerprint vectors (per-position, per-beacon average RSSI).
    func exportCSV() -> String {
        var lines: [String] = []

        lines.append("# TX Calibration (RSSI at 1m)")
        lines.append("beacon,rssi_at_1m")
        for letter in ArenaLetter.allCases {
            if let rssi = readings[letter] {
                lines.append("\(letter.rawValue),\(String(format: "%.1f", rssi))")
            }
        }

        lines.append("")

        lines.append("# Arena Fingerprints")
        lines.append("position,beacon,avg_rssi")
        for positionLetter in ArenaLetter.allCases {
            guard let fp = fingerprints[positionLetter] else { continue }
            for beaconLetter in ArenaLetter.allCases {
                if let rssi = fp.rssiByBeacon[beaconLetter] {
                    lines.append("\(positionLetter.rawValue),\(beaconLetter.rawValue),\(String(format: "%.1f", rssi))")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Persistence

    /// Save this calibration to UserDefaults.
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.persistenceKey)
    }

    /// Load the most recently saved calibration, or return `.uncalibrated` if none exists.
    static func load() -> BeaconCalibration {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let calibration = try? JSONDecoder().decode(BeaconCalibration.self, from: data)
        else { return .uncalibrated }
        return calibration
    }

    /// Remove any saved calibration from UserDefaults.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
    }
}
