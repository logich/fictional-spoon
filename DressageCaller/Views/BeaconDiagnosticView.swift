import CoreBluetooth
import SwiftUI

/// Full-screen diagnostic panel for verifying Kontakt Anchor Beacon 2 hardware.
///
/// Shows two parallel checks:
/// 1. CoreLocation iBeacon ranging — confirms the beacons are broadcasting the
///    expected proximity UUID and reveals their major/minor values.
/// 2. CoreBluetooth FE6A scan — confirms the hardware is powered on and advertising
///    even if the iBeacon UUID has been changed from the factory default.
struct BeaconDiagnosticView: View {
    @State private var service = BeaconDiagnosticService()

    var body: some View {
        List {
            statusSection
            iBeaconSection
            bleSection
        }
        .navigationTitle("Beacon Diagnostic")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(service.isScanning ? "Stop" : "Start") {
                    if service.isScanning {
                        service.stopDiagnostic()
                    } else {
                        service.startDiagnostic()
                    }
                }
                .tint(service.isScanning ? .red : .accentColor)
            }
        }
        .onDisappear { service.stopDiagnostic() }
    }

    // MARK: - Status section

    @ViewBuilder
    private var statusSection: some View {
        Section("Status") {
            HStack {
                Image(systemName: passIcon)
                    .foregroundStyle(passColor)
                Text(passLabel)
                Spacer()
                if service.isScanning {
                    ProgressView()
                }
            }

            HStack {
                Image(systemName: locationIcon)
                    .foregroundStyle(locationColor)
                Text(locationLabel)
                    .font(.subheadline)
            }

            HStack {
                Image(systemName: service.bluetoothState == .poweredOn ? "bluetooth" : "bluetooth.slash")
                    .foregroundStyle(service.bluetoothState == .poweredOn ? .blue : .secondary)
                Text(bluetoothLabel)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - iBeacon section

    @ViewBuilder
    private var iBeaconSection: some View {
        Section {
            if service.iBeaconResults.isEmpty {
                Text(service.isScanning
                     ? "Waiting for iBeacon responses…"
                     : "Tap Start to begin ranging")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(service.iBeaconResults) { result in
                    IBeaconRow(result: result)
                }
            }
        } header: {
            Text("iBeacon Ranging")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ranging UUID (Kontakt factory default):")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(BeaconDiagnosticService.kontaktDefaultUUID.uuidString.lowercased())
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
                Text("Note the major/minor values above — you will need them to map each beacon to an arena letter.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - BLE section

    @ViewBuilder
    private var bleSection: some View {
        Section {
            if service.bleDevices.isEmpty {
                Text(service.isScanning
                     ? "Scanning for Kontakt hardware (FE6A)…"
                     : "Tap Start to begin scanning")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(service.bleDevices) { device in
                    BLEDeviceRow(device: device)
                }
            }
        } header: {
            Text("Kontakt Hardware (FE6A)")
        } footer: {
            Text("This scan uses the Kontakt GATT service UUID (FE6A) and works independently of the iBeacon UUID. If beacons appear here but not under iBeacon Ranging, the iBeacon UUID on the beacons differs from the factory default and needs reconfiguring via Kio Cloud.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Computed status helpers

    private var passIcon: String {
        service.iBeaconResults.count >= 4 ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }

    private var passColor: Color {
        switch service.iBeaconResults.count {
        case 4...: .green
        case 1...: .orange
        default: service.isScanning ? .orange : .secondary
        }
    }

    private var passLabel: String {
        "\(service.iBeaconResults.count) of 4 iBeacons detected"
    }

    private var locationIcon: String {
        switch service.locationAuthStatus {
        case .authorizedAlways, .authorizedWhenInUse: "location.fill"
        case .denied, .restricted: "location.slash.fill"
        default: "location"
        }
    }

    private var locationColor: Color {
        switch service.locationAuthStatus {
        case .authorizedAlways, .authorizedWhenInUse: .green
        case .denied, .restricted: .red
        default: .orange
        }
    }

    private var locationLabel: String {
        switch service.locationAuthStatus {
        case .authorizedAlways: "Location: Always"
        case .authorizedWhenInUse: "Location: When In Use"
        case .denied: "Location: Denied — check Settings"
        case .restricted: "Location: Restricted"
        case .notDetermined: "Location: Not yet requested"
        @unknown default: "Location: Unknown"
        }
    }

    private var bluetoothLabel: String {
        switch service.bluetoothState {
        case .poweredOn: "Bluetooth: On"
        case .poweredOff: "Bluetooth: Off — enable in Settings"
        case .unauthorized: "Bluetooth: Unauthorized — check Settings"
        case .unsupported: "Bluetooth: Not supported on this device"
        case .resetting: "Bluetooth: Resetting"
        default: "Bluetooth: Unknown"
        }
    }
}

// MARK: - Row views

private struct IBeaconRow: View {
    let result: RawBeaconResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(result.proximityLabel, systemImage: proximityIcon)
                    .foregroundStyle(proximityColor)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(result.rssi) dBm")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Text("Major: \(result.major)")
                Text("Minor: \(result.minor)")
                if result.accuracy > 0 {
                    Text(String(format: "%.1f m", result.accuracy))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var proximityIcon: String {
        switch result.proximity {
        case .immediate: "wifi"
        case .near: "wifi"
        case .far: "wifi.exclamationmark"
        default: "wifi.slash"
        }
    }

    private var proximityColor: Color {
        switch result.proximity {
        case .immediate: .green
        case .near: .blue
        case .far: .orange
        default: .secondary
        }
    }
}

private struct BLEDeviceRow: View {
    let device: NearbyBLEDevice

    var body: some View {
        HStack {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.subheadline)
                if let id = device.kontaktDeviceID {
                    Text("Device ID: \(id)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(device.rssi) dBm")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
