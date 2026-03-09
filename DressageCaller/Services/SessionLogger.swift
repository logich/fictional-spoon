import Foundation

/// Records raw beacon, position, and motion data during a ride for post-session analysis.
/// Writes a timestamped CSV file that can be pulled from the device via Files app or Xcode.
@MainActor
@Observable
final class SessionLogger {
    private(set) var isLogging = false
    private(set) var sampleCount = 0

    private var fileHandle: FileHandle?
    private var filePath: URL?
    private var startTime: Date?

    /// Start logging to a new CSV file.
    func start() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "ride_\(formatter.string(from: Date())).csv"

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let logDir = docs.appendingPathComponent("RideLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        let path = logDir.appendingPathComponent(filename)
        FileManager.default.createFile(atPath: path.path, contents: nil)

        guard let handle = FileHandle(forWritingAtPath: path.path) else { return }

        // CSV header
        let header = [
            "elapsed_s",
            "beacon_letter", "rssi", "accuracy_m", "proximity",
            "pos_x", "pos_y",
            "nearest_letter", "distance_to_nearest",
            "confidence",
            "motion_state", "accel_magnitude",
            "filtered_pos_x", "filtered_pos_y"
        ].joined(separator: ",") + "\n"

        handle.write(Data(header.utf8))

        self.fileHandle = handle
        self.filePath = path
        self.startTime = Date()
        self.sampleCount = 0
        self.isLogging = true
    }

    /// Log one frame of data. Called each time beacons are updated.
    func log(
        beacons: [DetectedBeacon],
        riderState: RiderState,
        motionState: MotionState,
        accelerationMagnitude: Double
    ) {
        guard isLogging, let handle = fileHandle, let start = startTime else { return }

        let elapsed = String(format: "%.2f", Date().timeIntervalSince(start))

        if beacons.isEmpty {
            // Log a position-only row when no beacons visible
            let row = [
                elapsed,
                "", "", "", "",
                String(format: "%.2f", riderState.position.x),
                String(format: "%.2f", riderState.position.y),
                riderState.nearestLetter.rawValue,
                String(format: "%.2f", riderState.distanceToNearest),
                "\(riderState.confidence)",
                motionState.rawValue,
                String(format: "%.4f", accelerationMagnitude),
                String(format: "%.2f", riderState.position.x),
                String(format: "%.2f", riderState.position.y)
            ].joined(separator: ",") + "\n"
            handle.write(Data(row.utf8))
            sampleCount += 1
        } else {
            // One row per beacon per update — easier to analyse per-beacon RSSI over time
            for beacon in beacons {
                let row = [
                    elapsed,
                    beacon.letter.rawValue,
                    "\(beacon.rssi)",
                    String(format: "%.2f", beacon.accuracy),
                    beacon.proximityLabel,
                    String(format: "%.2f", riderState.position.x),
                    String(format: "%.2f", riderState.position.y),
                    riderState.nearestLetter.rawValue,
                    String(format: "%.2f", riderState.distanceToNearest),
                    "\(riderState.confidence)",
                    motionState.rawValue,
                    String(format: "%.4f", accelerationMagnitude),
                    String(format: "%.2f", riderState.position.x),
                    String(format: "%.2f", riderState.position.y)
                ].joined(separator: ",") + "\n"
                handle.write(Data(row.utf8))
                sampleCount += 1
            }
        }
    }

    /// Stop logging and close the file.
    func stop() {
        fileHandle?.closeFile()
        fileHandle = nil
        isLogging = false
    }

    /// URL of the current or most recent log file, for sharing.
    var logFileURL: URL? { filePath }
}
