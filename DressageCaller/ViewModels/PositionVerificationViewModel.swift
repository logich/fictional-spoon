import Foundation

/// Drives the Position Verification screen.
/// Owns all services, polls at 0.5s, logs ground-truth taps alongside normal position rows.
@MainActor
@Observable
final class PositionVerificationViewModel {

    let beaconService: BeaconRangingService
    let positionEngine: PositionEngine
    let motionService: MotionService
    let sessionLogger: SessionLogger

    private(set) var nearestLetter: ArenaLetter = .X
    private(set) var confidence: RiderState.Confidence = .none
    private(set) var groundTruthCount: Int = 0
    private(set) var correctCount: Int = 0
    private(set) var shareURL: URL?

    var isLogging: Bool { sessionLogger.isLogging }

    private var updateTimer: Timer?
    private var startTime: Date?

    init(configuration: ArenaConfiguration, calibration: BeaconCalibration) {
        beaconService = BeaconRangingService(configuration: configuration)
        positionEngine = PositionEngine(
            configuration: configuration,
            calibration: calibration
        )
        motionService = MotionService()
        sessionLogger = SessionLogger()
    }

    // MARK: - Session control

    func startSession() {
        guard !sessionLogger.isLogging else { return }
        shareURL = nil
        groundTruthCount = 0
        correctCount = 0
        startTime = Date()

        beaconService.requestAuthorization()
        beaconService.startRanging()
        motionService.start()
        sessionLogger.start()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func stopSession() {
        updateTimer?.invalidate()
        updateTimer = nil
        beaconService.stopRanging()
        motionService.stop()
        sessionLogger.stop()
        shareURL = sessionLogger.logFileURL
    }

    // MARK: - Ground-truth recording

    /// Records where the user actually is. Increments correctCount if the engine agreed.
    func recordGroundTruth(letter: ArenaLetter) {
        guard sessionLogger.isLogging, let start = startTime else { return }
        if nearestLetter == letter { correctCount += 1 }
        groundTruthCount += 1

        let elapsed = String(format: "%.2f", Date().timeIntervalSince(start))
        // 14 columns matching the CSV header; beacon/position fields are empty for event rows.
        let row = ([elapsed, "GROUND_TRUTH", letter.rawValue] + Array(repeating: "", count: 11))
            .joined(separator: ",") + "\n"
        sessionLogger.logRawRow(row)
    }

    // MARK: - Private

    private func tick() {
        let beacons = beaconService.detectedBeacons
        let motionState = motionService.motionState
        positionEngine.update(from: beacons, motionState: motionState)
        nearestLetter = positionEngine.riderState.nearestLetter
        confidence = positionEngine.riderState.confidence
        sessionLogger.log(
            beacons: beacons,
            riderState: positionEngine.riderState,
            motionState: motionState,
            accelerationMagnitude: motionService.accelerationMagnitude
        )
    }
}
