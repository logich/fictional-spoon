import SwiftUI

/// Field-validation screen for position tracking accuracy.
/// Tap a letter button when you physically arrive at that arena position.
/// The app logs both the engine's estimate and the ground-truth tap to CSV,
/// and scores accuracy as correct / total taps.
struct PositionVerificationView: View {
    @State private var vm: PositionVerificationViewModel

    private let perimeterLetters: [ArenaLetter]
    private let centerlineLetters: [ArenaLetter] = [.D, .L, .X, .I, .G]
    private let gridColumns = Array(repeating: GridItem(.flexible()), count: 4)

    private static let clockwiseOrder: [ArenaLetter] = [
        .A, .K, .V, .E, .S, .H, .C, .M, .R, .B, .P, .F
    ]

    init(configuration: ArenaConfiguration, calibration: BeaconCalibration) {
        self._vm = State(initialValue: PositionVerificationViewModel(
            configuration: configuration,
            calibration: calibration
        ))
        self.perimeterLetters = configuration.beaconMappings.map(\.letter).sorted {
            let li = Self.clockwiseOrder.firstIndex(of: $0) ?? Int.max
            let ri = Self.clockwiseOrder.firstIndex(of: $1) ?? Int.max
            return li < ri
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                nearestLetterDisplay
                letterGrids
                controlButton
                if vm.groundTruthCount > 0 {
                    accuracyDisplay
                }
                if let url = vm.shareURL {
                    ShareLink("Share CSV Log", item: url)
                        .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("Position Verification")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            vm.stopSession()
        }
    }

    // MARK: - Nearest letter display

    private var nearestLetterDisplay: some View {
        VStack(spacing: 4) {
            Text(vm.nearestLetter.rawValue)
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(confidenceColor)

            Text(vm.confidence.label.uppercased())
                .font(.subheadline)
                .foregroundStyle(confidenceColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Currently estimating \(vm.nearestLetter.rawValue), confidence \(vm.confidence.label)")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Letter grids

    private var letterGrids: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Perimeter")
                .font(.caption.uppercaseSmallCaps())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(perimeterLetters) { letter in
                    letterButton(letter: letter, tint: .blue)
                }
            }

            Text("Centerline")
                .font(.caption.uppercaseSmallCaps())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(centerlineLetters) { letter in
                    letterButton(letter: letter, tint: .purple)
                }
            }
        }
    }

    private func letterButton(letter: ArenaLetter, tint: Color) -> some View {
        Button {
            vm.recordGroundTruth(letter: letter)
        } label: {
            Text(letter.rawValue)
                .font(.title.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(!vm.isLogging)
        .accessibilityLabel("Ground truth: \(letter.rawValue)")
        .accessibilityHint("Mark current position as \(letter.rawValue)")
    }

    // MARK: - Control button

    private var controlButton: some View {
        Button {
            if vm.isLogging { vm.stopSession() } else { vm.startSession() }
        } label: {
            Label(
                vm.isLogging ? "Stop Logging" : "Start Logging",
                systemImage: vm.isLogging ? "stop.circle.fill" : "record.circle"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(vm.isLogging ? .red : .green)
        .accessibilityHint(vm.isLogging ? "Ends logging and exports CSV" : "Begins position logging")
    }

    // MARK: - Accuracy display

    private var accuracyDisplay: some View {
        Text("\(vm.correctCount)/\(vm.groundTruthCount) correct")
            .font(.title2.bold())
            .foregroundStyle(accuracyColor)
            .accessibilityLabel("\(vm.correctCount) of \(vm.groundTruthCount) positions correct")
    }

    // MARK: - Helpers

    private var confidenceColor: Color {
        switch vm.confidence {
        case .strong: .green
        case .weak:   .orange
        case .none:   .secondary
        }
    }

    private var accuracyColor: Color {
        guard vm.groundTruthCount > 0 else { return .primary }
        let ratio = Double(vm.correctCount) / Double(vm.groundTruthCount)
        if ratio >= 0.75 { return .green }
        if ratio >= 0.50 { return .orange }
        return .red
    }
}

// MARK: - RiderState.Confidence label

private extension RiderState.Confidence {
    var label: String {
        switch self {
        case .strong: "strong"
        case .weak:   "weak"
        case .none:   "none"
        }
    }
}
