import SwiftUI

/// Guided calibration walk: stand 1 meter from each beacon to record signal strength.
struct CalibrationView: View {
    @State private var vm: CalibrationViewModel

    init(configuration: ArenaConfiguration, onComplete: @escaping (BeaconCalibration) -> Void) {
        self._vm = State(initialValue: CalibrationViewModel(configuration: configuration, onComplete: onComplete))
    }

    var body: some View {
        VStack(spacing: 24) {
            progressHeader

            Spacer()

            switch vm.phase {
            case .instructions:  instructionsContent
            case .waitingForSignal: waitingContent
            case .sampling:      samplingContent
            case .recorded:      recordedContent
            case .complete:      completeContent
            }

            Spacer()

            actionButtons
        }
        .padding()
        .navigationTitle("Calibrate Beacons")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.beaconService.requestAuthorization()
        }
        .onDisappear {
            vm.stopRanging()
        }
    }

    // MARK: - Progress

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(vm.currentIndex), total: Double(vm.beaconLetters.count))
                .tint(.blue)
            Text("\(vm.currentIndex) of \(vm.beaconLetters.count) beacons calibrated")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Phase content

    private var instructionsContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Beacon Calibration")
                .font(.title2.bold())
            if let letter = vm.currentLetter {
                Text("Stand approximately 1 meter from beacon **\(letter.rawValue)** and tap **Start**.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var waitingContent: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            if let letter = vm.currentLetter {
                Text("Searching for beacon \(letter.rawValue)...")
                    .font(.headline)
            }
            Text("Make sure you are within 1 meter of the beacon.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var samplingContent: some View {
        VStack(spacing: 16) {
            if let letter = vm.currentLetter {
                Text("Recording beacon \(letter.rawValue)")
                    .font(.headline)
            }
            Text("\(vm.rssiSamples.count) / \(BeaconCalibration.samplesPerReading)")
                .font(.system(.title, design: .monospaced))
                .foregroundStyle(.blue)
            if let latest = vm.rssiSamples.last {
                Text("RSSI: \(latest) dBm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(vm.rssiSamples.count),
                         total: Double(BeaconCalibration.samplesPerReading))
                .tint(.green)
        }
    }

    private var recordedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            if let letter = vm.currentLetter {
                let avg = vm.calibration.rssiAt1m(for: letter)
                Text("Beacon \(letter.rawValue) recorded")
                    .font(.headline)
                Text("Average RSSI at 1m: \(Int(avg)) dBm")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var completeContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Calibration Complete")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 4) {
                ForEach(vm.beaconLetters) { letter in
                    HStack {
                        Text(letter.rawValue)
                            .font(.system(.body, design: .monospaced).bold())
                        Spacer()
                        Text("\(Int(vm.calibration.rssiAt1m(for: letter))) dBm")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        switch vm.phase {
        case .instructions:
            Button {
                vm.startCalibrationForCurrentBeacon()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

        case .waitingForSignal, .sampling:
            Button(role: .cancel) {
                vm.cancelSampling()
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

        case .recorded:
            Button {
                vm.advanceToNext()
            } label: {
                Label(
                    vm.isLastBeacon ? "Finish" : "Next Beacon",
                    systemImage: vm.isLastBeacon ? "checkmark" : "arrow.right"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

        case .complete:
            Button {
                vm.finish()
            } label: {
                Label("Done", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
