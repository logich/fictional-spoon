import CoreLocation
import Foundation
import OSLog
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
    private let logger = Logger(subsystem: "com.dressagecaller.app", category: "BeaconRanging")

#if !targetEnvironment(simulator)
    // MARK: - Real device implementation

    private let locationManager = CLLocationManager()
    private var beaconConstraint: CLBeaconIdentityConstraint?
    private var beaconRegion: CLBeaconRegion?
    private var evictionTimer: Timer?
    private var smoothedRSSI: [ArenaLetter: Double] = [:]
    /// Set when startRanging() is called before authorization is granted.
    private var pendingStart = false

    /// Beacons not seen within this window are removed from detectedBeacons.
    private let staleThreshold: TimeInterval = 3.0

    init(configuration: ArenaConfiguration = .prototype) {
        self.configuration = configuration
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func requestAuthorization() {
        logger.info("Requesting authorization, current status: \(self.locationManager.authorizationStatus.rawValue, privacy: .public)")
        locationManager.requestWhenInUseAuthorization()
    }

    func startRanging() {
        guard !isRanging else { return }

        let status = locationManager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            pendingStart = true
            logger.info("startRanging deferred — not yet authorized")
            return
        }
        pendingStart = false

        logger.info("startRanging called, auth status: \(self.locationManager.authorizationStatus.rawValue, privacy: .public)")

        let constraint = CLBeaconIdentityConstraint(uuid: configuration.beaconUUID)
        let region = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: "dressage-arena")
        region.notifyOnEntry = true
        region.notifyOnExit = true

        self.beaconConstraint = constraint
        self.beaconRegion = region

        locationManager.startMonitoring(for: region)
        locationManager.startRangingBeacons(satisfying: constraint)
        isRanging = true
        logger.info("Ranging started")

        evictionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.evictStaleBeacons() }
        }
    }

    func stopRanging() {
        pendingStart = false
        guard isRanging else { return }
        if let constraint = beaconConstraint {
            locationManager.stopRangingBeacons(satisfying: constraint)
        }
        if let region = beaconRegion {
            locationManager.stopMonitoring(for: region)
        }
        evictionTimer?.invalidate()
        evictionTimer = nil
        isRanging = false
        detectedBeacons = []
        smoothedRSSI.removeAll()
    }

    private func evictStaleBeacons() {
        let cutoff = Date().addingTimeInterval(-staleThreshold)
        detectedBeacons = detectedBeacons.filter { $0.lastSeen >= cutoff }
    }

#else
    // MARK: - Simulator mock implementation

    /// Beacon letters the simulated rider loops through (matches the 8 deployed beacons).
    private static let route: [ArenaLetter] = [.A, .K, .E, .H, .C, .M, .B, .F]

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
        logger.info("Auth changed: \(manager.authorizationStatus.rawValue, privacy: .public)")
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            // Upgrade to always for background ranging
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            if pendingStart { startRanging() }
        case .denied, .restricted:
            logger.info("Authorization denied/restricted — stopping")
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
        logger.debug("didRange called — \(beacons.count) raw beacons")
        for b in beacons {
            logger.debug("  major=\(b.major, privacy: .public) minor=\(b.minor, privacy: .public) rssi=\(b.rssi) accuracy=\(b.accuracy) proximity=\(b.proximity.rawValue, privacy: .public)")
        }

        detectedBeacons = beacons.compactMap { beacon in
            guard let letter = configuration.letter(
                forMajor: beacon.major.uint16Value,
                minor: beacon.minor.uint16Value
            ) else {
                logger.error("No letter mapping for major=\(beacon.major, privacy: .public) minor=\(beacon.minor, privacy: .public)")
                return nil
            }

            let raw = Double(beacon.rssi)
            let prev = smoothedRSSI[letter] ?? raw
            let smoothed = 0.3 * raw + 0.7 * prev
            smoothedRSSI[letter] = smoothed

            return DetectedBeacon(
                letter: letter,
                rssi: Int(smoothed.rounded()),
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
        logger.error("Ranging error: \(error.localizedDescription, privacy: .public)")
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        logger.error("Monitoring failed: \(error.localizedDescription, privacy: .public)")
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        logger.info("Started monitoring region: \(region.identifier, privacy: .public)")
    }
}
#endif
