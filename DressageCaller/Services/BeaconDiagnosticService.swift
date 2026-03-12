import CoreBluetooth
import CoreLocation
import Foundation
import Observation

/// A single iBeacon detected during diagnostic ranging, with raw major/minor (not yet mapped to a letter).
struct RawBeaconResult: Identifiable, Sendable {
    let uuid: UUID
    let major: UInt16
    let minor: UInt16
    let proximity: CLProximity
    let accuracy: Double
    let rssi: Int
    let lastSeen: Date

    var id: String { "\(uuid)-\(major)-\(minor)" }

    var proximityLabel: String {
        switch proximity {
        case .immediate: "Immediate"
        case .near: "Near"
        case .far: "Far"
        default: "Unknown"
        }
    }
}

/// A Kontakt BLE peripheral seen via CoreBluetooth raw scan on the FE6A service UUID.
struct NearbyBLEDevice: Identifiable, Sendable {
    let identifier: UUID
    let name: String?
    let rssi: Int
    /// Human-readable device ID extracted from Kontakt service data (e.g. "C01U").
    let kontaktDeviceID: String?
    let lastSeen: Date

    var id: UUID { identifier }
    var displayName: String { name ?? kontaktDeviceID ?? "Unnamed device" }
}

/// Verifies Kontakt iBeacons by combining CoreLocation ranging (iBeacon-specific)
/// and CoreBluetooth scanning on the Kontakt FE6A service UUID (confirms hardware is live).
///
/// Use this before the first ride to confirm all 4 beacons are reachable and to
/// discover their major/minor values so arena letter mappings can be configured.
@MainActor
@Observable
final class BeaconDiagnosticService: NSObject {

    /// Kontakt.io factory-default iBeacon proximity UUID.
    static let kontaktDefaultUUID = UUID(uuidString: "F7826DA6-4FA2-4E98-8024-BC5B71E0893E")!

    /// Kontakt.io GATT service UUID, present in all Kontakt beacon advertisements.
    /// Used by CoreBluetooth to filter specifically for Kontakt hardware.
    static let kontaktServiceUUID = CBUUID(string: "FE6A")

    var iBeaconResults: [RawBeaconResult] = []
    var bleDevices: [NearbyBLEDevice] = []
    var isScanning = false
    var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    var bluetoothState: CBManagerState = .unknown

#if !targetEnvironment(simulator)

    private let locationManager = CLLocationManager()
    private var centralManager: CBCentralManager?
    private var evictionTimer: Timer?
    private let staleThreshold: TimeInterval = 5.0

    override init() {
        super.init()
        locationManager.delegate = self
        locationAuthStatus = locationManager.authorizationStatus
    }

    func startDiagnostic() {
        guard !isScanning else { return }
        isScanning = true

        // iBeacon ranging — no major/minor filter so we see all 4 beacons.
        locationManager.requestWhenInUseAuthorization()
        let constraint = CLBeaconIdentityConstraint(uuid: Self.kontaktDefaultUUID)
        let region = CLBeaconRegion(
            beaconIdentityConstraint: constraint,
            identifier: "beacon-diagnostic"
        )
        locationManager.startMonitoring(for: region)
        locationManager.startRangingBeacons(satisfying: constraint)

        // CoreBluetooth — filter on the Kontakt FE6A service UUID so only Kontakt
        // devices appear, regardless of iBeacon UUID configuration.
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        } else {
            startBLEScanIfReady()
        }

        evictionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.evictStale() }
        }
    }

    func stopDiagnostic() {
        guard isScanning else { return }
        let constraint = CLBeaconIdentityConstraint(uuid: Self.kontaktDefaultUUID)
        let region = CLBeaconRegion(
            beaconIdentityConstraint: constraint,
            identifier: "beacon-diagnostic"
        )
        locationManager.stopRangingBeacons(satisfying: constraint)
        locationManager.stopMonitoring(for: region)
        centralManager?.stopScan()
        evictionTimer?.invalidate()
        evictionTimer = nil
        isScanning = false
        iBeaconResults = []
        bleDevices = []
    }

    private func startBLEScanIfReady() {
        guard centralManager?.state == .poweredOn else { return }
        // Scan specifically for FE6A — works in background and only returns Kontakt devices.
        centralManager?.scanForPeripherals(
            withServices: [Self.kontaktServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func evictStale() {
        let cutoff = Date().addingTimeInterval(-staleThreshold)
        iBeaconResults = iBeaconResults.filter { $0.lastSeen >= cutoff }
        bleDevices = bleDevices.filter { $0.lastSeen >= cutoff }
    }

    /// Attempts to extract a human-readable Kontakt device ID from FE6A service data.
    ///
    /// Kontakt service data layout (observed from Anchor Beacon 2):
    ///   [0-1]   FE6A  — service UUID (already stripped by CoreBluetooth)
    ///   [0-5]   07 64 F4 26 22 00 — Kontakt frame header
    ///   [6-9]   device-specific bytes (address fragment)
    ///   [10-11] calibration / status bytes
    ///   [12]    0xFF separator
    ///   [13+]   ASCII device identifier string (e.g. "15mC01Ur")
    ///
    /// The last 4 alphanumeric characters of the ASCII portion are the unique device ID.
    private func kontaktDeviceID(from serviceData: [CBUUID: Data]) -> String? {
        guard let data = serviceData[Self.kontaktServiceUUID],
              data.count >= 14 else { return nil }
        // Find the ASCII printable region after offset 12.
        let asciiSlice = data.dropFirst(12)
        let asciiString = String(bytes: asciiSlice.filter { $0 >= 0x20 && $0 < 0x7F }, encoding: .ascii)
        // The unique ID is the trailing portion (after any firmware-version prefix like "15m").
        return asciiString.flatMap { str in
            let trimmed = str.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

#else
    // MARK: - Simulator mock

    override init() {
        super.init()
        locationAuthStatus = .authorizedWhenInUse
        bluetoothState = .poweredOn
    }

    func startDiagnostic() {
        guard !isScanning else { return }
        isScanning = true
        iBeaconResults = [
            RawBeaconResult(uuid: Self.kontaktDefaultUUID, major: 1, minor: 1,
                            proximity: .near, accuracy: 3.2, rssi: -72, lastSeen: .now),
            RawBeaconResult(uuid: Self.kontaktDefaultUUID, major: 1, minor: 2,
                            proximity: .immediate, accuracy: 0.9, rssi: -55, lastSeen: .now),
            RawBeaconResult(uuid: Self.kontaktDefaultUUID, major: 1, minor: 3,
                            proximity: .far, accuracy: 9.4, rssi: -88, lastSeen: .now),
        ]
        bleDevices = [
            NearbyBLEDevice(identifier: UUID(), name: nil,
                            rssi: -66, kontaktDeviceID: "C01U", lastSeen: .now),
            NearbyBLEDevice(identifier: UUID(), name: nil,
                            rssi: -71, kontaktDeviceID: "U01V", lastSeen: .now),
            NearbyBLEDevice(identifier: UUID(), name: nil,
                            rssi: -84, kontaktDeviceID: "P01V", lastSeen: .now),
        ]
    }

    func stopDiagnostic() {
        guard isScanning else { return }
        isScanning = false
        iBeaconResults = []
        bleDevices = []
    }
#endif
}

// MARK: - CLLocationManagerDelegate

#if !targetEnvironment(simulator)
extension BeaconDiagnosticService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthStatus = manager.authorizationStatus
    }

    func locationManager(
        _ manager: CLLocationManager,
        didRange beacons: [CLBeacon],
        satisfying constraint: CLBeaconIdentityConstraint
    ) {
        let now = Date()
        let incoming = beacons.map {
            RawBeaconResult(
                uuid: $0.uuid,
                major: $0.major.uint16Value,
                minor: $0.minor.uint16Value,
                proximity: $0.proximity,
                accuracy: $0.accuracy,
                rssi: $0.rssi,
                lastSeen: now
            )
        }
        var updated = iBeaconResults
        for result in incoming {
            if let idx = updated.firstIndex(where: { $0.id == result.id }) {
                updated[idx] = result
            } else {
                updated.append(result)
            }
        }
        iBeaconResults = updated.sorted { $0.minor < $1.minor }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailRangingFor constraint: CLBeaconIdentityConstraint,
        error: Error
    ) {
        print("[BeaconDiagnostic] Ranging error: \(error.localizedDescription)")
    }
}

// MARK: - CBCentralManagerDelegate

extension BeaconDiagnosticService: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn && isScanning {
            startBLEScanIfReady()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let now = Date()
        let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
        let deviceID = serviceData.flatMap { kontaktDeviceID(from: $0) }
        let device = NearbyBLEDevice(
            identifier: peripheral.identifier,
            name: peripheral.name
                ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String,
            rssi: RSSI.intValue,
            kontaktDeviceID: deviceID,
            lastSeen: now
        )
        if let idx = bleDevices.firstIndex(where: { $0.identifier == peripheral.identifier }) {
            bleDevices[idx] = device
        } else {
            bleDevices.append(device)
        }
    }
}
#endif
