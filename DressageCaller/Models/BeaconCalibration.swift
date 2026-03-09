import Foundation

/// Stores the measured RSSI at 1 meter for each beacon.
/// Used to convert raw RSSI to distance more accurately than the default -59 dBm.
struct BeaconCalibration: Sendable, Codable {
    /// Per-letter measured RSSI at 1 meter.
    var readings: [ArenaLetter: Double]

    /// The default Apple iBeacon TX power assumption.
    static let defaultRSSIAt1m: Double = -59.0

    /// Number of raw samples averaged to produce each reading.
    static let samplesPerReading = 10

    /// Empty calibration — falls back to defaults for all beacons.
    static let uncalibrated = BeaconCalibration(readings: [:])

    /// UserDefaults key for persisted calibration.
    private static let persistenceKey = "beaconCalibration"

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
