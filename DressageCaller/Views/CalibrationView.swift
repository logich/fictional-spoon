import SwiftUI

/// Guided calibration walk: stand 1 meter from each beacon to record signal strength.
struct CalibrationView: View {
    let configuration: ArenaConfiguration
    let onComplete: (BeaconCalibration) -> Void

    @State private var beaconService: BeaconRangingService
    @State private var currentIndex = 0
    @State private var rssiSamples: [Int] = []
    @State private var calibration = BeaconCalibration.uncalibrated
    @State private var phase: Phase = .instructions
    @State private var sampleTimer: Timer?

    private var beaconLetters: [ArenaLetter] {
        configuration.beaconMappings.map(\.letter).sorted { $0.rawValue < $1.rawValue }
    }

    private var currentLetter: ArenaLetter? {
        guard currentIndex < beaconLetters.count else { return nil }
        return beaconLetters[currentIndex]
    }

    enum Phase {
        case instructions
        case waitingForSignal
        case sampling
        case recorded
        case complete
    }

    init(configuration: ArenaConfiguration, onComplete: @escaping (BeaconCalibration) -> Void) {
        self.configuration = configuration
        self.onComplete = onComplete
        self._beaconService = State(initialValue: BeaconRangingService(configuration: configuration))
    }

    var body: some View {
        VStack(spacing: 24) {
            // Progress
            progressHeader

            Spacer()

            // Main content
            switch phase {
            case .instructions:
                instructionsContent
            case .waitingForSignal:
                waitingContent
            case .sampling:
                samplingContent
            case .recorded:
                recordedContent
            case .complete:
                completeContent
            }

            Spacer()

            // Actions
            actionButtons
        }
        .padding()
        .navigationTitle("Calibrate Beacons")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            beaconService.requestAuthorization()
        }
        .onDisappear {
            stopSampling()
            beaconService.stopRanging()
        }
    }

    // MARK: - Progress

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(currentIndex), total: Double(beaconLetters.count))
                .tint(.blue)

            Text("\(currentIndex) of \(beaconLetters.count) beacons calibrated")
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

            if let letter = currentLetter {
                Text("Stand approximately 1 meter from beacon **\(letter.rawValue)** and tap **Start**.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var waitingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            if let letter = currentLetter {
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
            if let letter = currentLetter {
                Text("Recording beacon \(letter.rawValue)")
                    .font(.headline)
            }

            Text("\(rssiSamples.count) / \(BeaconCalibration.samplesPerReading)")
                .font(.system(.title, design: .monospaced))
                .foregroundStyle(.blue)

            if let latest = rssiSamples.last {
                Text("RSSI: \(latest) dBm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(rssiSamples.count),
                         total: Double(BeaconCalibration.samplesPerReading))
                .tint(.green)
        }
    }

    private var recordedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            if let letter = currentLetter {
                let avg = calibration.rssiAt1m(for: letter)
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
                ForEach(beaconLetters) { letter in
                    HStack {
                        Text(letter.rawValue)
                            .font(.system(.body, design: .monospaced).bold())
                        Spacer()
                        Text("\(Int(calibration.rssiAt1m(for: letter))) dBm")
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
        switch phase {
        case .instructions:
            Button {
                startCalibrationForCurrentBeacon()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

        case .waitingForSignal, .sampling:
            Button(role: .cancel) {
                stopSampling()
                phase = .instructions
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

        case .recorded:
            Button {
                advanceToNext()
            } label: {
                Label(
                    currentIndex + 1 < beaconLetters.count ? "Next Beacon" : "Finish",
                    systemImage: currentIndex + 1 < beaconLetters.count ? "arrow.right" : "checkmark"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

        case .complete:
            Button {
                onComplete(calibration)
            } label: {
                Label("Done", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Calibration logic

    private func startCalibrationForCurrentBeacon() {
        rssiSamples = []
        phase = .waitingForSignal

        if !beaconService.isRanging {
            beaconService.startRanging()
        }

        // Poll for the target beacon to appear, then start sampling
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self] _ in
            Task { @MainActor in
                guard let letter = currentLetter else { return }

                if let beacon = beaconService.detectedBeacons.first(where: { $0.letter == letter }),
                   beacon.rssi != 0 {
                    if phase == .waitingForSignal {
                        phase = .sampling
                    }
                    rssiSamples.append(beacon.rssi)

                    if rssiSamples.count >= BeaconCalibration.samplesPerReading {
                        finishCurrentBeacon()
                    }
                }
            }
        }
    }

    private func finishCurrentBeacon() {
        stopSampling()

        guard let letter = currentLetter, !rssiSamples.isEmpty else { return }

        let average = Double(rssiSamples.reduce(0, +)) / Double(rssiSamples.count)
        calibration.readings[letter.rawValue] = average
        phase = .recorded
    }

    private func advanceToNext() {
        currentIndex += 1
        if currentIndex < beaconLetters.count {
            phase = .instructions
        } else {
            beaconService.stopRanging()
            phase = .complete
        }
    }

    private func stopSampling() {
        sampleTimer?.invalidate()
        sampleTimer = nil
    }
}
