import SwiftUI

/// Debug panel showing raw beacon data for each detected beacon.
struct BeaconStatusView: View {
    let beacons: [DetectedBeacon]
    let expectedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Beacon Status")
                .font(.headline)

            if beacons.isEmpty {
                Text("No beacons detected")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(beacons) { beacon in
                    BeaconRow(beacon: beacon)
                }
            }
        }
        .padding()
    }
}

private struct BeaconRow: View {
    let beacon: DetectedBeacon

    var body: some View {
        HStack {
            Text(beacon.letter.rawValue)
                .font(.title3.bold().monospaced())
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 12) {
                    Label(
                        "\(beacon.rssi) dBm",
                        systemImage: signalIcon
                    )
                    .foregroundStyle(signalColor)

                    if beacon.accuracy > 0 {
                        Text(String(format: "%.1fm", beacon.accuracy))
                            .foregroundStyle(.primary)
                    } else {
                        Text("--m")
                            .foregroundStyle(.secondary)
                    }

                    Text(beacon.proximityLabel)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                Text("Last seen: \(beacon.lastSeen.formatted(.dateTime.hour().minute().second()))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var signalIcon: String {
        switch beacon.proximity {
        case .immediate: "wifi"
        case .near: "wifi"
        case .far: "wifi.exclamationmark"
        default: "wifi.slash"
        }
    }

    private var signalColor: Color {
        switch beacon.proximity {
        case .immediate: .green
        case .near: .blue
        case .far: .orange
        default: .red
        }
    }
}
