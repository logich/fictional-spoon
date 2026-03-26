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
        // Fingerprint phases
        case fingerprintInstructions
        case fingerprintWalking
        case fingerprintRecorded
        case fingerprintPassComplete   // Between pass 1 and pass 2
        case fingerprintComplete
    }

    static let fingerprintDuration: Double = 10.0

    /// Clockwise perimeter order starting at A.
    /// Lets the rider walk a continuous loop during calibration without backtracking.
    private static let clockwiseOrder: [ArenaLetter] = [
        .A, .K, .V, .E, .S, .H, .C, .M, .R, .B, .P, .F
    ]

    private(set) var phase: Phase = .instructions
    private(set) var rssiSamples: [Int] = []
    private(set) var calibration: BeaconCalibration = .uncalibrated
    private(set) var currentIndex: Int = 0

    // Fingerprint state
    private(set) var fingerprintIndex: Int = 0
    private(set) var fingerprintElapsed: Double = 0
    private(set) var fingerprintPass: Int = 1
    /// Beacon count from the most recently recorded fingerprint position (safe to show in .fingerprintRecorded phase).
    private(set) var fingerprintLastRecordedBeaconCount: Int = 0

    let beaconService: BeaconRangingService
    let beaconLetters: [ArenaLetter]
    let onComplete: (BeaconCalibration) -> Void

    /// Pass 1 letter order: clockwise starting at A.
    private let fingerprintPass1Letters: [ArenaLetter]
    /// Pass 2 letter order: counterclockwise starting at A (i.e. reverse of clockwise minus A, prepended with A).
    private let fingerprintPass2Letters: [ArenaLetter]

    private var sampleTimer: Timer?
    private var fingerprintWalkTimer: Timer?
    private var fingerprintAccumulator: [ArenaLetter: [Double]] = [:]
    private var pass1Data: [ArenaLetter: [ArenaLetter: [Double]]] = [:]
    private var pass2Data: [ArenaLetter: [ArenaLetter: [Double]]] = [:]

    init(
        configuration: ArenaConfiguration,
        existingCalibration: BeaconCalibration = .uncalibrated,
        onComplete: @escaping (BeaconCalibration) -> Void
    ) {
        self.beaconService = BeaconRangingService(configuration: configuration)
        let sorted = configuration.beaconMappings.map(\.letter).sorted {
            let li = Self.clockwiseOrder.firstIndex(of: $0) ?? Int.max
            let ri = Self.clockwiseOrder.firstIndex(of: $1) ?? Int.max
            return li < ri
        }
        self.beaconLetters = sorted

        // Pass 1: clockwise order (same as TX calibration order)
        fingerprintPass1Letters = sorted

        // Pass 2: counterclockwise — A first, then the remaining letters in reverse clockwise order
        if let aIdx = sorted.firstIndex(of: .A) {
            var rest = sorted
            rest.remove(at: aIdx)
            fingerprintPass2Letters = [.A] + rest.reversed()
        } else {
            fingerprintPass2Letters = sorted.reversed()
        }

        self.onComplete = onComplete

        // Skip to the complete screen if a prior calibration already exists.
        if !existingCalibration.readings.isEmpty {
            calibration = existingCalibration
            currentIndex = sorted.count
            phase = .complete
        }
    }

    var currentLetter: ArenaLetter? {
        guard currentIndex < beaconLetters.count else { return nil }
        return beaconLetters[currentIndex]
    }

    var isLastBeacon: Bool { currentIndex >= beaconLetters.count - 1 }

    private var currentFingerprintLetters: [ArenaLetter] {
        fingerprintPass == 1 ? fingerprintPass1Letters : fingerprintPass2Letters
    }

    var fingerprintCurrentLetter: ArenaLetter? {
        guard fingerprintIndex < currentFingerprintLetters.count else { return nil }
        return currentFingerprintLetters[fingerprintIndex]
    }

    var isFingerprintLastInPass: Bool { fingerprintIndex >= currentFingerprintLetters.count - 1 }

    // MARK: - TX Calibration Actions

    func startCalibrationForCurrentBeacon() {
        rssiSamples = []
        phase = .waitingForSignal

        if !beaconService.isRanging {
            beaconService.startRanging()
        }

        sampleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func advanceToNext() {
        currentIndex += 1
        if currentIndex < beaconLetters.count {
            phase = .instructions
        } else {
            phase = .complete
        }
    }

    func cancelSampling() {
        stopTimer()
        phase = .instructions
    }

    func finish() {
        beaconService.stopRanging()
        onComplete(calibration)
    }

    func stopRanging() {
        stopTimer()
        stopFingerprintTimer()
        beaconService.stopRanging()
    }

    // MARK: - Fingerprinting Actions

    func startFingerprinting() {
        fingerprintPass = 1
        fingerprintIndex = 0
        pass1Data = [:]
        pass2Data = [:]
        fingerprintAccumulator = [:]
        phase = .fingerprintInstructions
        if !beaconService.isRanging {
            beaconService.startRanging()
        }
    }

    func startFingerprintForCurrentLetter() {
        fingerprintElapsed = 0
        fingerprintAccumulator = [:]
        phase = .fingerprintWalking
        fingerprintWalkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.fingerprintTick() }
        }
    }

    func advanceFingerprintToNext() {
        fingerprintAccumulator = [:]
        fingerprintIndex += 1
        if fingerprintIndex < currentFingerprintLetters.count {
            phase = .fingerprintInstructions
        } else if fingerprintPass == 1 {
            // Pass 1 complete — transition to pass 2
            phase = .fingerprintPassComplete
        } else {
            // Both passes complete — merge and store
            mergeAndStoreFingerprints()
            beaconService.stopRanging()
            phase = .fingerprintComplete
        }
    }

    func startPass2() {
        fingerprintPass = 2
        fingerprintIndex = 0
        fingerprintAccumulator = [:]
        phase = .fingerprintInstructions
    }

    // MARK: - Private TX

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

    // MARK: - Private Fingerprint

    private func fingerprintTick() {
        fingerprintElapsed += 0.5
        for beacon in beaconService.detectedBeacons where beacon.rssi != 0 {
            fingerprintAccumulator[beacon.letter, default: []].append(Double(beacon.rssi))
        }
        if fingerprintElapsed >= Self.fingerprintDuration {
            finishCurrentFingerprintLetter()
        }
    }

    private func finishCurrentFingerprintLetter() {
        stopFingerprintTimer()
        guard let letter = fingerprintCurrentLetter else { return }

        // Store raw samples into the appropriate pass dictionary (not yet merged into calibration).
        if fingerprintPass == 1 {
            pass1Data[letter] = fingerprintAccumulator
        } else {
            pass2Data[letter] = fingerprintAccumulator
        }

        fingerprintLastRecordedBeaconCount = fingerprintAccumulator.count
        phase = .fingerprintRecorded
    }

    /// Merge pass1 and pass2 data by averaging all samples for each (position, beacon) pair.
    private func mergeAndStoreFingerprints() {
        let allPositions = Set(pass1Data.keys).union(pass2Data.keys)
        for position in allPositions {
            let p1 = pass1Data[position] ?? [:]
            let p2 = pass2Data[position] ?? [:]
            let allBeacons = Set(p1.keys).union(p2.keys)
            var rssiByBeacon: [ArenaLetter: Double] = [:]
            for beacon in allBeacons {
                let combined = (p1[beacon] ?? []) + (p2[beacon] ?? [])
                guard !combined.isEmpty else { continue }
                rssiByBeacon[beacon] = combined.reduce(0.0, +) / Double(combined.count)
            }
            calibration.fingerprints[position] = FingerprintVector(letter: position, rssiByBeacon: rssiByBeacon)
        }
    }

    private func stopFingerprintTimer() {
        fingerprintWalkTimer?.invalidate()
        fingerprintWalkTimer = nil
    }
}
