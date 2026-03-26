import CoreBluetooth
import CoreLocation
import Foundation
import Observation

struct RawBeaconResult: Identifiable, Sendable {
    /// Unique per beacon: "\(major)-\(minor)".
    /// Using CLBeacon.uuid here would give every beacon the same id (shared app-level UUID),
    /// causing ForEach to collapse all rows to one.
    let id: String
    let major: UInt16
    let minor: UInt16
    let proximity: CLProximity
    let accuracy: Double
    let rssi: Int

    init(major: UInt16, minor: UInt16, proximity: CLProximity, accuracy: Double, rssi: Int) {
        self.id = "\(major)-\(minor)"
        self.major = major
        self.minor = minor
        self.proximity = proximity
        self.accuracy = accuracy
        self.rssi = rssi
    }

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

struct NearbyBLEDevice: Identifiable, Sendable {
    let id: String          // MAC address e.g. "AA:BB:CC:DD:EE:FF"
    let rssi: Int
    let batteryLevel: Int?  // 0–100, nil if frame could not be parsed
}

/// Dual-channel beacon diagnostic: CoreLocation iBeacon ranging + CoreBluetooth BLE scan.
/// Used to verify beacon major/minor assignments and signal strength before a ride.
@MainActor
@Observable
final class BeaconDiagnosticService: NSObject {
    var rawBeacons: [RawBeaconResult] = []
    var bleDevices: [NearbyBLEDevice] = []
    var isRunning = false
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var bluetoothState: CBManagerState = .unknown

#if !targetEnvironment(simulator)
    private let locationManager = CLLocationManager()
    private var centralManager: CBCentralManager?
    private var beaconConstraint: CLBeaconIdentityConstraint?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Channel 1: iBeacon ranging — no major/minor filter to surface all 8 beacons
        let status = locationManager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            startRanging()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }

        // Channel 2: BLE scan
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let constraint = beaconConstraint {
            locationManager.stopRangingBeacons(satisfying: constraint)
        }
        beaconConstraint = nil
        centralManager?.stopScan()
        centralManager = nil
        rawBeacons = []
        bleDevices = []
    }

    private func startRanging() {
        let constraint = CLBeaconIdentityConstraint(uuid: ArenaConfiguration.beaconProximityUUID)
        beaconConstraint = constraint
        locationManager.startRangingBeacons(satisfying: constraint)
        print("[Diagnostic] iBeacon ranging started, UUID: \(ArenaConfiguration.beaconProximityUUID)")
    }

    private func startBLEScan() {
        let serviceUUID = CBUUID(string: "FFE1") // Minew Device Info frame
        centralManager?.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        print("[Diagnostic] BLE scan started for FFE1 service")
    }

#else
    // MARK: - Simulator stub

    override init() {
        super.init()
        authorizationStatus = .authorizedAlways
        bluetoothState = .poweredOn
    }

    func start() {
        isRunning = true
        rawBeacons = []
        bleDevices = []
    }

    func stop() {
        isRunning = false
        rawBeacons = []
        bleDevices = []
    }
#endif
}

#if !targetEnvironment(simulator)
extension BeaconDiagnosticService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways),
           isRunning, beaconConstraint == nil {
            startRanging()
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didRange beacons: [CLBeacon],
        satisfying constraint: CLBeaconIdentityConstraint
    ) {
        rawBeacons = beacons.map { beacon in
            RawBeaconResult(
                major: beacon.major.uint16Value,
                minor: beacon.minor.uint16Value,
                proximity: beacon.proximity,
                accuracy: beacon.accuracy,
                rssi: beacon.rssi
            )
        }
        .sorted { ($0.major, $0.minor) < ($1.major, $1.minor) }
    }
}

extension BeaconDiagnosticService: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn, isRunning {
            startBLEScan()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // Parse Minew Device Info frame (FFE1 service).
        // CoreBluetooth strips the leading UUID bytes; payload layout:
        //   byte 0: frame type (0xA1)
        //   byte 1: version
        //   byte 2: battery level (0–100)
        //   bytes 3–8: MAC address (6 bytes, little-endian)
        //   bytes 9+: device name (ASCII)
        guard
            let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
            let data = serviceData[CBUUID(string: "FFE1")],
            data.count >= 9,
            data[0] == 0xA1
        else { return }

        let batteryLevel = Int(data[2])
        let macBytes = data[3..<9]
        let macAddress = macBytes.reversed().map { String(format: "%02X", $0) }.joined(separator: ":")

        let rssi = RSSI.intValue
        if let idx = bleDevices.firstIndex(where: { $0.id == macAddress }) {
            bleDevices[idx] = NearbyBLEDevice(id: macAddress, rssi: rssi, batteryLevel: batteryLevel)
        } else {
            bleDevices.append(NearbyBLEDevice(id: macAddress, rssi: rssi, batteryLevel: batteryLevel))
            bleDevices.sort { $0.id < $1.id }
        }
    }
}
#endif
