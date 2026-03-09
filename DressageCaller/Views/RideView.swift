import SwiftUI
import UIKit

/// Active ride screen — arena diagram, beacon status, and ride controls.
struct RideView: View {
    @Environment(\.dismiss) private var dismiss
    let session: RideSession

    @State private var showDebugPanel = false
    @State private var shareURL: URL? = nil

    private var beaconService: BeaconRangingService { session.beaconService }
    private var positionEngine: PositionEngine      { session.positionEngine }
    private var motionService: MotionService        { session.motionService }
    private var sessionLogger: SessionLogger        { session.sessionLogger }
    private var sc: RideSessionController?          { session.sessionController }

    var body: some View {
        VStack(spacing: 0) {
            // Background location auth warning
            if beaconService.authorizationStatus == .authorizedWhenInUse {
                authorizationBanner
            }

            // Status bar
            statusBar
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Test info + movement progress
            if let test = session.test {
                testInfoBar(test)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                if let sc {
                    movementProgressBar(sc, test: test)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }
                Divider()
            }

            // Arena diagram
            ArenaView(
                configuration: session.configuration,
                riderState: positionEngine.riderState,
                detectedBeacons: beaconService.detectedBeacons,
                currentMovement: sc.flatMap { s in
                    s.isFinished ? nil : s.test.movements[safe: s.currentMovementIndex]
                }
            )
            .frame(maxHeight: .infinity)

            Divider()

            // Debug panel (collapsible)
            if showDebugPanel {
                ScrollView {
                    BeaconStatusView(
                        beacons: beaconService.detectedBeacons,
                        expectedCount: session.configuration.beaconMappings.count
                    )
                }
                .frame(maxHeight: 200)
                .transition(.move(edge: .bottom))
            }

            // Controls
            controlBar.padding()
        }
        .navigationTitle(session.test?.name ?? "Ride")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    session.stop()
                    dismiss()
                } label: {
                    Label("End Ride", systemImage: "xmark")
                }
            }
        }
        .onChange(of: beaconService.detectedBeacons) { _, _ in
            session.update()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            session.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            session.stop()
        }
    }

    // MARK: - Auth banner

    private var authorizationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.orange)
            Text("Background location access required for ranging when screen is locked.")
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.bold())
            .foregroundStyle(.orange)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.12))
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack {
            if beaconService.isRanging {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.green)
                Text("Ranging... \(beaconService.beaconsDetectedCount)/\(session.configuration.beaconMappings.count) beacons")
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
            if let horse = session.horseName {
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
                        Text(m.directiveText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button { sc.skipMovement() } label: {
                        Image(systemName: "forward.fill").font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            ProgressView(value: sc.isFinished ? Double(total) : Double(index), total: Double(total))
                .tint(.blue)
        }
    }

    private func gaitColor(_ gait: Gait) -> Color {
        switch gait {
        case .halt:   return .primary
        case .walk:   return .blue
        case .trot:   return .orange
        case .canter: return .red
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

            if let url = shareURL {
                ShareLink(item: url) {
                    Label("Share Log", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    if sessionLogger.isLogging {
                        sessionLogger.stop()
                        shareURL = sessionLogger.logFileURL
                    } else {
                        shareURL = nil
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
            }

            Button {
                withAnimation { showDebugPanel.toggle() }
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
