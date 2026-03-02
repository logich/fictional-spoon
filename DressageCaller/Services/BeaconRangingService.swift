import CoreLocation
import Foundation
import Observation

/// Beacon data for a single detected beacon mapped to an arena letter.
struct DetectedBeacon: Identifiable, Sendable, Equatable {
    let letter: ArenaLetter
    let rssi: Int
    let accuracy: Double // estimated distance in meters; -1 if unknown
    let proximity: CLProximity
    let lastSeen: Date

    var id: String { letter.rawValue }

    var proximityLabel: String {
        switch proximity {
        case .immediate: "Immediate"
        case .near: "Near"
        case .far: "Far"
        case .unknown: "Unknown"
        @unknown default: "Unknown"
        }
    }
}

/// Wraps CLLocationManager for iBeacon ranging.
@MainActor
@Observable
final class BeaconRangingService: NSObject {
    var detectedBeacons: [DetectedBeacon] = []
    var isRanging = false
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var beaconsDetectedCount: Int { detectedBeacons.count }

    private let configuration: ArenaConfiguration

#if !targetEnvironment(simulator)
    // MARK: - Real device implementation

    private let locationManager = CLLocationManager()
    private var beaconConstraint: CLBeaconIdentityConstraint?
    private var beaconRegion: CLBeaconRegion?

    init(configuration: ArenaConfiguration = .prototype) {
        self.configuration = configuration
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startRanging() {
        guard !isRanging else { return }

        let constraint = CLBeaconIdentityConstraint(uuid: configuration.beaconUUID)
        let region = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: "dressage-arena")
        region.notifyOnEntry = true
        region.notifyOnExit = true

        self.beaconConstraint = constraint
        self.beaconRegion = region

        locationManager.startMonitoring(for: region)
        locationManager.startRangingBeacons(satisfying: constraint)
        isRanging = true
    }

    func stopRanging() {
        guard isRanging else { return }
        if let constraint = beaconConstraint {
            locationManager.stopRangingBeacons(satisfying: constraint)
        }
        if let region = beaconRegion {
            locationManager.stopMonitoring(for: region)
        }
        isRanging = false
        detectedBeacons = []
    }

#else
    // MARK: - Simulator mock implementation

    /// Perimeter letters the simulated rider loops through.
    private static let route: [ArenaLetter] = [.A, .K, .V, .E, .S, .H, .C, .M, .R, .B, .P, .F]

    /// Current index into `route`.
    private var routeIndex = 0

    /// Timer driving the simulated beacon updates.
    private var simulationTimer: Timer?

    init(configuration: ArenaConfiguration = .prototype) {
        self.configuration = configuration
        super.init()
    }

    func requestAuthorization() {
        // Always authorized on simulator.
        authorizationStatus = .authorizedAlways
    }

    func startRanging() {
        guard !isRanging else { return }
        isRanging = true
        routeIndex = 0
        generateSimulatedBeacons()

        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceSimulation()
            }
        }
    }

    func stopRanging() {
        guard isRanging else { return }
        simulationTimer?.invalidate()
        simulationTimer = nil
        isRanging = false
        detectedBeacons = []
    }

    /// Advance to the next waypoint and regenerate beacons.
    private func advanceSimulation() {
        routeIndex = (routeIndex + 1) % Self.route.count
        generateSimulatedBeacons()
    }

    /// Generate fake beacon readings based on the rider's current simulated position.
    private func generateSimulatedBeacons() {
        let currentLetter = Self.route[routeIndex]
        let riderPos = currentLetter.position(for: configuration.arenaSize)
        let now = Date()
        let beaconLetters = configuration.beaconLetters

        detectedBeacons = beaconLetters.compactMap { letter -> DetectedBeacon? in
            let beaconPos = letter.position(for: configuration.arenaSize)
            let dx = riderPos.x - beaconPos.x
            let dy = riderPos.y - beaconPos.y
            let distance = sqrt(dx * dx + dy * dy)

            // Simulate RSSI: closer → stronger (less negative).
            let rssi = max(-100, Int(-40 - distance * 1.5))

            let proximity: CLProximity
            switch distance {
            case 0..<2: proximity = .immediate
            case 2..<8: proximity = .near
            default: proximity = .far
            }

            return DetectedBeacon(
                letter: letter,
                rssi: rssi,
                accuracy: distance,
                proximity: proximity,
                lastSeen: now
            )
        }
        .sorted { $0.letter.rawValue < $1.letter.rawValue }
    }
#endif
}

#if !targetEnvironment(simulator)
extension BeaconRangingService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            // Upgrade to always for background ranging
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        case .denied, .restricted:
            stopRanging()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didRange beacons: [CLBeacon],
        satisfying constraint: CLBeaconIdentityConstraint
    ) {
        let now = Date()
        detectedBeacons = beacons.compactMap { beacon in
            guard let letter = configuration.letter(
                forMajor: beacon.major.uint16Value,
                minor: beacon.minor.uint16Value
            ) else { return nil }

            return DetectedBeacon(
                letter: letter,
                rssi: beacon.rssi,
                accuracy: beacon.accuracy,
                proximity: beacon.proximity,
                lastSeen: now
            )
        }
        .sorted { $0.letter.rawValue < $1.letter.rawValue }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailRangingFor constraint: CLBeaconIdentityConstraint,
        error: Error
    ) {
        print("Beacon ranging error: \(error.localizedDescription)")
    }
}
#endif
