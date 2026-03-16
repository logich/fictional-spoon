import SwiftUI

/// Debug panel showing raw beacon data for all expected beacons in a 2-column grid.
/// Missing beacons are shown as greyed-out tiles so gaps are immediately visible.
struct BeaconStatusView: View {
    let beacons: [DetectedBeacon]
    let expectedLetters: [ArenaLetter]

    private func detected(_ letter: ArenaLetter) -> DetectedBeacon? {
        beacons.first { $0.letter == letter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Beacon Status")
                    .font(.headline)
                Spacer()
                Text("\(beacons.count)/\(expectedLetters.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(beacons.count == expectedLetters.count ? .green : .orange)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(expectedLetters, id: \.self) { letter in
                    BeaconTile(letter: letter, beacon: detected(letter))
                }
            }
        }
        .padding()
    }
}

private struct BeaconTile: View {
    let letter: ArenaLetter
    let beacon: DetectedBeacon?

    var body: some View {
        HStack(spacing: 6) {
            Text(letter.rawValue)
                .font(.system(.body, design: .monospaced).bold())
                .frame(width: 22)
                .foregroundStyle(beacon == nil ? .tertiary : .primary)

            if let beacon {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(beacon.rssi) dBm")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(signalColor(beacon))
                    Text(beacon.accuracy > 0 ? String(format: "%.1fm", beacon.accuracy) : "--m")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            Circle()
                .fill(beacon == nil ? Color.secondary.opacity(0.3) : signalColor(beacon!))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }

    private func signalColor(_ beacon: DetectedBeacon) -> Color {
        switch beacon.proximity {
        case .immediate: .green
        case .near: .blue
        case .far: .orange
        default: .red
        }
    }
}
