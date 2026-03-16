import CoreBluetooth
import CoreLocation
import Foundation
import Observation

struct RawBeaconResult: Identifiable {
    let id: UUID // CLBeacon.uuid
    let major: UInt16
    let minor: UInt16
    let proximity: CLProximity
    let accuracy: Double
    let rssi: Int

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

struct NearbyBLEDevice: Identifiable {
    let id: String // device ID e.g. "C01U"
    let rssi: Int
}

/// Dual-channel beacon diagnostic: CoreLocation iBeacon ranging + CoreBluetooth BLE scan.
/// Used to discover real major/minor values from Kontakt Anchor Beacons before a ride.
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
    private let kontaktUUID = UUID(uuidString: "F7826DA6-4FA2-4E98-8024-BC5B71E0893E")!
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
        let constraint = CLBeaconIdentityConstraint(uuid: kontaktUUID)
        beaconConstraint = constraint
        locationManager.startRangingBeacons(satisfying: constraint)
        print("[Diagnostic] iBeacon ranging started, UUID: \(kontaktUUID)")
    }

    private func startBLEScan() {
        let serviceUUID = CBUUID(string: "FE6A") // Kontakt-specific service
        centralManager?.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        print("[Diagnostic] BLE scan started for FE6A service")
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
                id: beacon.uuid,
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
        // Parse device ID from Kontakt service data (bytes 6–9, ASCII)
        guard
            let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
            let data = serviceData[CBUUID(string: "FE6A")],
            data.count >= 10
        else { return }

        let idBytes = data[6..<10]
        guard let deviceID = String(bytes: idBytes, encoding: .ascii),
              deviceID.unicodeScalars.allSatisfy({ $0.isASCII && $0.value >= 32 }) else { return }

        let rssi = RSSI.intValue
        if let idx = bleDevices.firstIndex(where: { $0.id == deviceID }) {
            bleDevices[idx] = NearbyBLEDevice(id: deviceID, rssi: rssi)
        } else {
            bleDevices.append(NearbyBLEDevice(id: deviceID, rssi: rssi))
            bleDevices.sort { $0.id < $1.id }
        }
    }
}
#endif
