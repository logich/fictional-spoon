import SwiftUI

/// Guided calibration walk: stand 1 meter from each beacon to record signal strength,
/// then optionally walk two circuits (clockwise + counterclockwise) to capture arena fingerprints.
struct CalibrationView: View {
    @State private var vm: CalibrationViewModel
    @State private var exportURL: URL?

    init(
        configuration: ArenaConfiguration,
        existingCalibration: BeaconCalibration = .uncalibrated,
        onComplete: @escaping (BeaconCalibration) -> Void
    ) {
        self._vm = State(initialValue: CalibrationViewModel(
            configuration: configuration,
            existingCalibration: existingCalibration,
            onComplete: onComplete
        ))
    }

    var body: some View {
        VStack(spacing: 24) {
            progressHeader

            Spacer()

            switch vm.phase {
            case .instructions:              instructionsContent
            case .waitingForSignal:          waitingContent
            case .sampling:                  samplingContent
            case .recorded:                  recordedContent
            case .complete:                  completeContent
            case .fingerprintInstructions:   fingerprintInstructionsContent
            case .fingerprintWalking:        fingerprintWalkingContent
            case .fingerprintRecorded:       fingerprintRecordedContent
            case .fingerprintPassComplete:   fingerprintPassCompleteContent
            case .fingerprintComplete:       fingerprintCompleteContent
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
            switch vm.phase {
            case .fingerprintInstructions, .fingerprintWalking, .fingerprintRecorded, .fingerprintPassComplete, .fingerprintComplete:
                let total = vm.beaconLetters.count
                let completed = vm.fingerprintPass == 1
                    ? vm.fingerprintIndex
                    : total + vm.fingerprintIndex
                ProgressView(value: Double(completed), total: Double(total * 2))
                    .tint(.purple)
                Text("Pass \(vm.fingerprintPass) — \(vm.fingerprintIndex) of \(vm.beaconLetters.count) positions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            default:
                ProgressView(value: Double(vm.currentIndex), total: Double(vm.beaconLetters.count))
                    .tint(.blue)
                Text("\(vm.currentIndex) of \(vm.beaconLetters.count) beacons calibrated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - TX Calibration phase content

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

    // MARK: - Fingerprint phase content

    private var fingerprintInstructionsContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text("Arena Fingerprinting — Pass \(vm.fingerprintPass)")
                .font(.title2.bold())
            if let letter = vm.fingerprintCurrentLetter {
                Text("Stand at arena letter **\(letter.rawValue)** and tap **Start**. Stay still for \(Int(CalibrationViewModel.fingerprintDuration)) seconds.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("Face in the direction you are travelling — not toward any beacon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var fingerprintWalkingContent: some View {
        VStack(spacing: 16) {
            if let letter = vm.fingerprintCurrentLetter {
                Text("Recording at \(letter.rawValue) — Pass \(vm.fingerprintPass)")
                    .font(.headline)
            }
            Text("\(Int(vm.fingerprintElapsed))s / \(Int(CalibrationViewModel.fingerprintDuration))s")
                .font(.system(.title, design: .monospaced))
                .foregroundStyle(.purple)
            ProgressView(value: vm.fingerprintElapsed, total: CalibrationViewModel.fingerprintDuration)
                .tint(.purple)
            Text("Stand still at this letter position")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var fingerprintRecordedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            if let letter = vm.fingerprintCurrentLetter {
                Text("Position \(letter.rawValue) recorded — Pass \(vm.fingerprintPass)")
                    .font(.headline)
                Text("\(vm.fingerprintLastRecordedBeaconCount) beacons recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fingerprintPassCompleteContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text("Pass 1 Complete")
                .font(.title2.bold())
            Text("Now walk the arena counterclockwise — starting at A, going to F, B, M, C, H, E, K. Face in your direction of travel at each letter.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var fingerprintCompleteContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text("Fingerprinting Complete")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 4) {
                ForEach(vm.beaconLetters) { letter in
                    if let fp = vm.calibration.fingerprints[letter] {
                        HStack {
                            Text(letter.rawValue)
                                .font(.system(.body, design: .monospaced).bold())
                            Spacer()
                            Text("\(fp.rssiByBeacon.count) beacons")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Export

    private func makeExportURL() -> URL? {
        let csv = vm.calibration.exportCSV()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("calibration_export.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
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
            VStack(spacing: 12) {
                Button {
                    vm.startFingerprinting()
                } label: {
                    Label("Fingerprint Arena", systemImage: "map.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)

                exportButton

                Button {
                    vm.finish()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

        case .fingerprintInstructions:
            Button {
                vm.startFingerprintForCurrentLetter()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)

        case .fingerprintWalking:
            EmptyView()

        case .fingerprintRecorded:
            Button {
                vm.advanceFingerprintToNext()
            } label: {
                let isLast = vm.isFingerprintLastInPass
                let isPass1 = vm.fingerprintPass == 1
                let label = isLast ? (isPass1 ? "Complete Pass 1" : "Finish") : "Next Position"
                let icon  = isLast ? "checkmark" : "arrow.right"
                Label(label, systemImage: icon)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)

        case .fingerprintPassComplete:
            Button {
                vm.startPass2()
            } label: {
                Label("Start Pass 2", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)

        case .fingerprintComplete:
            VStack(spacing: 12) {
                Button {
                    vm.finish()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                exportButton
            }
        }
    }

    @ViewBuilder
    private var exportButton: some View {
        if let url = exportURL {
            ShareLink(item: url) {
                Label("Share CSV", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        } else {
            Button { exportURL = makeExportURL() } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}
