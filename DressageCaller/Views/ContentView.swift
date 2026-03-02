import SwiftUI

/// Main screen composing the arena view and beacon status panel.
struct ContentView: View {
    @State private var beaconService: BeaconRangingService
    @State private var positionEngine: PositionEngine
    @State private var announcementService = AnnouncementService()
    @State private var showDebugPanel = true

    private let configuration: ArenaConfiguration

    init(configuration: ArenaConfiguration = .prototype) {
        self.configuration = configuration
        self._beaconService = State(initialValue: BeaconRangingService(configuration: configuration))
        self._positionEngine = State(initialValue: PositionEngine(configuration: configuration))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Arena diagram
            ArenaView(
                configuration: configuration,
                riderState: positionEngine.riderState,
                detectedBeacons: beaconService.detectedBeacons
            )
            .frame(maxHeight: .infinity)

            Divider()

            // Debug panel (collapsible)
            if showDebugPanel {
                ScrollView {
                    BeaconStatusView(
                        beacons: beaconService.detectedBeacons,
                        expectedCount: configuration.beaconMappings.count
                    )
                }
                .frame(maxHeight: 200)
                .transition(.move(edge: .bottom))
            }

            // Controls
            controlBar
                .padding()
        }
        .onChange(of: beaconService.detectedBeacons) { _, newBeacons in
            positionEngine.update(from: newBeacons)
            announcementService.checkAndAnnounce(state: positionEngine.riderState)
        }
        .onAppear {
            beaconService.requestAuthorization()
        }
    }

    private var statusBar: some View {
        HStack {
            if beaconService.isRanging {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.green)
                Text("Ranging... \(beaconService.beaconsDetectedCount)/\(configuration.beaconMappings.count) beacons")
                    .font(.subheadline)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(.secondary)
                Text("Not ranging")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if positionEngine.riderState.confidence != .none {
                Text("Near \(positionEngine.riderState.nearestLetter.rawValue)")
                    .font(.subheadline.bold())
            }
        }
    }

    private var controlBar: some View {
        HStack {
            Button {
                if beaconService.isRanging {
                    beaconService.stopRanging()
                } else {
                    beaconService.startRanging()
                }
            } label: {
                Label(
                    beaconService.isRanging ? "Stop" : "Start",
                    systemImage: beaconService.isRanging ? "stop.circle.fill" : "play.circle.fill"
                )
                .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .tint(beaconService.isRanging ? .red : .green)

            Spacer()

            Button {
                withAnimation {
                    showDebugPanel.toggle()
                }
            } label: {
                Label(
                    showDebugPanel ? "Hide Debug" : "Show Debug",
                    systemImage: showDebugPanel ? "eye.slash" : "eye"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
        }
    }
}
