import Foundation

/// Owns all services required for an active ride.
///
/// Created by HomeView and passed into RideView, so services survive
/// navigation events and are never accidentally recreated mid-ride.
@MainActor
@Observable
final class RideSession {

    let configuration: ArenaConfiguration
    let calibration: BeaconCalibration
    let test: DressageTest?
    let horseName: String?

    let beaconService: BeaconRangingService
    let positionEngine: PositionEngine
    let motionService: MotionService
    let announcementService: AnnouncementService
    let sessionLogger: SessionLogger
    private(set) var sessionController: RideSessionController?

    init(
        configuration: ArenaConfiguration,
        calibration: BeaconCalibration = .uncalibrated,
        test: DressageTest? = nil,
        horseName: String? = nil
    ) {
        self.configuration = configuration
        self.calibration = calibration
        self.test = test
        self.horseName = horseName

        beaconService = BeaconRangingService(configuration: configuration)
        positionEngine = PositionEngine(configuration: configuration, calibration: calibration)
        motionService = MotionService()
        announcementService = AnnouncementService()
        sessionLogger = SessionLogger()

        if let test {
            sessionController = RideSessionController(test: test, configuration: configuration)
        }
    }

    // MARK: - Lifecycle

    func start() {
        beaconService.requestAuthorization()
        motionService.start()
    }

    func stop() {
        beaconService.stopRanging()
        motionService.stop()
        sessionLogger.stop()
        sessionController?.reset()
    }

    // MARK: - Per-frame update

    /// Called each time detected beacons change. Runs the full position → announcement → logging pipeline.
    func update() {
        let beacons = beaconService.detectedBeacons
        positionEngine.update(from: beacons, motionState: motionService.motionState)
        let state = positionEngine.riderState

        if let sc = sessionController {
            sc.checkAndAnnounce(riderState: state, velocity: positionEngine.velocity)
        } else {
            announcementService.checkAndAnnounce(state: state)
        }

        if sessionLogger.isLogging {
            sessionLogger.log(
                beacons: beacons,
                riderState: state,
                motionState: motionService.motionState,
                accelerationMagnitude: motionService.accelerationMagnitude
            )
        }
    }
}
