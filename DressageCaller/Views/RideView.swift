import SwiftUI

/// Active ride screen — arena diagram, beacon status, and ride controls.
struct RideView: View {
    @State private var beaconService: BeaconRangingService
    @State private var positionEngine: PositionEngine
    @State private var motionService = MotionService()
    @State private var announcementService = AnnouncementService()
    @State private var sessionLogger = SessionLogger()
    @State private var showDebugPanel = false
    @State private var showShareSheet = false

    let configuration: ArenaConfiguration
    let calibration: BeaconCalibration
    let test: DressageTest?
    let horseName: String?

    init(configuration: ArenaConfiguration, calibration: BeaconCalibration = .uncalibrated, test: DressageTest? = nil, horseName: String? = nil) {
        self.configuration = configuration
        self.calibration = calibration
        self.test = test
        self.horseName = horseName
        self._beaconService = State(initialValue: BeaconRangingService(configuration: configuration))
        self._positionEngine = State(initialValue: PositionEngine(configuration: configuration, calibration: calibration))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Test info bar
            if let test {
                testInfoBar(test)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                Divider()
            }

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
        .navigationTitle(test?.name ?? "Ride")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: beaconService.detectedBeacons) { _, newBeacons in
            positionEngine.update(from: newBeacons, motionState: motionService.motionState)
            announcementService.checkAndAnnounce(state: positionEngine.riderState)
            if sessionLogger.isLogging {
                sessionLogger.log(
                    beacons: newBeacons,
                    riderState: positionEngine.riderState,
                    motionState: motionService.motionState,
                    accelerationMagnitude: motionService.accelerationMagnitude
                )
            }
        }
        .onAppear {
            beaconService.requestAuthorization()
            motionService.start()
        }
        .onDisappear {
            motionService.stop()
            sessionLogger.stop()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = sessionLogger.logFileURL {
                ShareSheet(items: [url])
            }
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

            Text(motionService.motionState.rawValue.capitalized)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(motionStateColor.opacity(0.2), in: Capsule())
                .foregroundStyle(motionStateColor)

            if positionEngine.riderState.confidence != .none {
                Text("Near \(positionEngine.riderState.nearestLetter.rawValue)")
                    .font(.subheadline.bold())
            }
        }
    }

    private func testInfoBar(_ test: DressageTest) -> some View {
        HStack {
            if let horse = horseName {
                Label(horse, systemImage: "pawprint.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(test.level) \u{00B7} \(test.movements.count) movements")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var motionStateColor: Color {
        switch motionService.motionState {
        case .stationary: .secondary
        case .walking:    .blue
        case .trotting:   .orange
        case .cantering:  .red
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

            // Log controls
            Button {
                if sessionLogger.isLogging {
                    sessionLogger.stop()
                    showShareSheet = true
                } else {
                    sessionLogger.start()
                }
            } label: {
                Label(
                    sessionLogger.isLogging ? "\(sessionLogger.sampleCount)" : "Log",
                    systemImage: sessionLogger.isLogging ? "stop.circle" : "record.circle"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(sessionLogger.isLogging ? .red : .secondary)

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
