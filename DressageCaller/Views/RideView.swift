import SwiftUI

/// Active ride screen — arena diagram, beacon status, and ride controls.
struct RideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var beaconService: BeaconRangingService
    @State private var positionEngine: PositionEngine
    @State private var motionService = MotionService()
    @State private var announcementService = AnnouncementService()
    @State private var sessionController: RideSessionController?
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
        if let test {
            self._sessionController = State(initialValue: RideSessionController(test: test, configuration: configuration))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Test info + movement progress
            if let test {
                testInfoBar(test)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                if let sc = sessionController {
                    movementProgressBar(sc, test: test)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }
                Divider()
            }

            // Arena diagram
            ArenaView(
                configuration: configuration,
                riderState: positionEngine.riderState,
                detectedBeacons: beaconService.detectedBeacons,
                currentMovement: sessionController.flatMap { sc in
                    sc.isFinished ? nil : sc.test.movements[safe: sc.currentMovementIndex]
                }
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    sessionController?.reset()
                    dismiss()
                } label: {
                    Label("End Ride", systemImage: "xmark")
                }
            }
        }
        .onChange(of: beaconService.detectedBeacons) { _, newBeacons in
            positionEngine.update(from: newBeacons, motionState: motionService.motionState)
            let state = positionEngine.riderState
            if let sc = sessionController {
                sc.checkAndAnnounce(riderState: state)
            } else {
                announcementService.checkAndAnnounce(state: state)
            }
            if sessionLogger.isLogging {
                sessionLogger.log(
                    beacons: newBeacons,
                    riderState: state,
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
            beaconService.stopRanging()
            motionService.stop()
            sessionLogger.stop()
            sessionController?.reset()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = sessionLogger.logFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Status bar

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

    // MARK: - Test info

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

    private func movementProgressBar(_ sc: RideSessionController, test: DressageTest) -> some View {
        let index = sc.currentMovementIndex
        let total = test.movements.count
        let movement = index < total ? test.movements[index] : nil

        return VStack(alignment: .leading, spacing: 6) {
            if sc.isFinished {
                HStack {
                    Text("Test complete")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Spacer()
                }
            } else if let m = movement {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        // Movement number, letter, and gait badge
                        HStack(spacing: 6) {
                            Text("\(index + 1)/\(total)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(m.location.label)
                                .font(.caption.bold())
                            if let gait = m.expectedGait {
                                Text(gait.rawValue.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(gaitColor(gait).opacity(0.15), in: Capsule())
                                    .foregroundStyle(gaitColor(gait))
                            }
                        }
                        // Directive text
                        Text(m.directiveText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        sc.skipMovement()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            ProgressView(value: Double(index), total: Double(total))
                .tint(.blue)
        }
    }

    private func gaitColor(_ gait: Gait) -> Color {
        switch gait {
        case .halt:    return .primary
        case .walk:    return .blue
        case .trot:    return .orange
        case .canter:  return .red
        }
    }

    // MARK: - Motion state color

    private var motionStateColor: Color {
        switch motionService.motionState {
        case .stationary: .secondary
        case .walking:    .blue
        case .trotting:   .orange
        case .cantering:  .red
        }
    }

    // MARK: - Control bar

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
