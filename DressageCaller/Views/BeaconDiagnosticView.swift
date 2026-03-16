import CoreBluetooth
import CoreLocation
import SwiftUI

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
                Button(service.isRunning ? "Stop" : "Start") {
                    if service.isRunning { service.stop() } else { service.start() }
                }
            }
        }
        .onAppear { service.start() }
        .onDisappear { service.stop() }
    }

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Text("iBeacons")
                Spacer()
                Label(
                    "\(service.rawBeacons.count)/8 detected",
                    systemImage: service.rawBeacons.count > 0 ? "circle.fill" : "circle"
                )
                .foregroundStyle(service.rawBeacons.count == 8 ? .green : service.rawBeacons.count > 0 ? .orange : .red)
                .font(.subheadline)
            }
            HStack {
                Text("Location")
                Spacer()
                Text(authLabel)
                    .foregroundStyle(authOK ? .green : .secondary)
                    .font(.subheadline)
            }
            HStack {
                Text("Bluetooth")
                Spacer()
                Text(bluetoothLabel)
                    .foregroundStyle(service.bluetoothState == .poweredOn ? .green : .secondary)
                    .font(.subheadline)
            }
        }
    }

    private var iBeaconSection: some View {
        Section("iBeacon Ranging") {
            if service.rawBeacons.isEmpty {
                Text(service.isRunning ? "Scanning…" : "Not started")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(service.rawBeacons) { beacon in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Major \(beacon.major)  Minor \(beacon.minor)")
                                .font(.headline)
                            Spacer()
                            Text(beacon.proximityLabel)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                        HStack(spacing: 16) {
                            Label(String(format: "%.1fm", beacon.accuracy), systemImage: "ruler")
                            Label("\(beacon.rssi) dBm", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var bleSection: some View {
        Section("BLE Devices (FE6A)") {
            if service.bleDevices.isEmpty {
                Text(service.isRunning ? "Scanning…" : "Not started")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(service.bleDevices) { device in
                    HStack {
                        Text(device.id)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Label("\(device.rssi) dBm", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var authOK: Bool {
        service.authorizationStatus == .authorizedAlways || service.authorizationStatus == .authorizedWhenInUse
    }

    private var authLabel: String {
        switch service.authorizationStatus {
        case .authorizedAlways: "Always"
        case .authorizedWhenInUse: "When In Use"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not Determined"
        @unknown default: "Unknown"
        }
    }

    private var bluetoothLabel: String {
        switch service.bluetoothState {
        case .poweredOn: "On"
        case .poweredOff: "Off"
        case .unauthorized: "Unauthorized"
        case .unsupported: "Unsupported"
        case .resetting: "Resetting"
        case .unknown: "Unknown"
        @unknown default: "Unknown"
        }
    }
}
