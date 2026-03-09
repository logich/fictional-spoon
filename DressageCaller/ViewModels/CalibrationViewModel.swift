import Foundation

@MainActor
@Observable
final class CalibrationViewModel {

    enum Phase {
        case instructions
        case waitingForSignal
        case sampling
        case recorded
        case complete
    }

    private(set) var phase: Phase = .instructions
    private(set) var rssiSamples: [Int] = []
    private(set) var calibration: BeaconCalibration = .uncalibrated
    private(set) var currentIndex: Int = 0

    let beaconService: BeaconRangingService
    let beaconLetters: [ArenaLetter]
    let onComplete: (BeaconCalibration) -> Void

    private var sampleTimer: Timer?

    init(configuration: ArenaConfiguration, onComplete: @escaping (BeaconCalibration) -> Void) {
        self.beaconService = BeaconRangingService(configuration: configuration)
        self.beaconLetters = configuration.beaconMappings.map(\.letter).sorted { $0.rawValue < $1.rawValue }
        self.onComplete = onComplete
    }

    var currentLetter: ArenaLetter? {
        guard currentIndex < beaconLetters.count else { return nil }
        return beaconLetters[currentIndex]
    }

    var isLastBeacon: Bool { currentIndex >= beaconLetters.count - 1 }

    // MARK: - Actions

    func startCalibrationForCurrentBeacon() {
        rssiSamples = []
        phase = .waitingForSignal

        if !beaconService.isRanging {
            beaconService.startRanging()
        }

        sampleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self] _ in
            self.tick()
        }
    }

    func advanceToNext() {
        currentIndex += 1
        if currentIndex < beaconLetters.count {
            phase = .instructions
        } else {
            beaconService.stopRanging()
            phase = .complete
        }
    }

    func cancelSampling() {
        stopTimer()
        phase = .instructions
    }

    func finish() {
        onComplete(calibration)
    }

    func stopRanging() {
        stopTimer()
        beaconService.stopRanging()
    }

    // MARK: - Private

    private func tick() {
        guard let letter = currentLetter else { return }

        if let beacon = beaconService.detectedBeacons.first(where: { $0.letter == letter }),
           beacon.rssi != 0 {
            if phase == .waitingForSignal {
                phase = .sampling
            }
            rssiSamples.append(beacon.rssi)

            if rssiSamples.count >= BeaconCalibration.samplesPerReading {
                finishCurrentBeacon(letter: letter)
            }
        }
    }

    private func finishCurrentBeacon(letter: ArenaLetter) {
        stopTimer()
        guard !rssiSamples.isEmpty else { return }
        let average = Double(rssiSamples.reduce(0, +)) / Double(rssiSamples.count)
        calibration.readings[letter] = average
        phase = .recorded
    }

    private func stopTimer() {
        sampleTimer?.invalidate()
        sampleTimer = nil
    }
}
