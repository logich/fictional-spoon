import Foundation

/// Handles file I/O on a background thread so the main actor is never blocked.
private actor LogWriter {
    private var fileHandle: FileHandle?

    func open(at url: URL, header: String) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        fileHandle = try FileHandle(forWritingTo: url)
        fileHandle?.write(Data(header.utf8))
    }

    func write(_ rows: [String]) {
        guard let handle = fileHandle, !rows.isEmpty else { return }
        let data = Data(rows.joined().utf8)
        handle.write(data)
    }

    func close() {
        fileHandle?.closeFile()
        fileHandle = nil
    }
}

/// Records raw beacon, position, and motion data during a ride for post-session analysis.
/// Buffers rows in memory and flushes to disk every 3 seconds on a background actor.
@MainActor
@Observable
final class SessionLogger {
    private(set) var isLogging = false
    private(set) var sampleCount = 0

    private let writer = LogWriter()
    private var rowBuffer: [String] = []
    private var flushTask: Task<Void, Never>?
    private var filePath: URL?
    private var startTime: Date?

    // MARK: - Public API

    func start() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "ride_\(formatter.string(from: Date())).csv"

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let logDir = docs.appendingPathComponent("RideLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let path = logDir.appendingPathComponent(filename)

        let header = [
            "elapsed_s",
            "beacon_letter", "rssi", "accuracy_m", "proximity",
            "pos_x", "pos_y",
            "nearest_letter", "distance_to_nearest",
            "confidence",
            "motion_state", "accel_magnitude",
            "filtered_pos_x", "filtered_pos_y"
        ].joined(separator: ",") + "\n"

        Task {
            try? await writer.open(at: path, header: header)
        }

        filePath = path
        startTime = Date()
        sampleCount = 0
        rowBuffer = []
        isLogging = true

        // Flush buffer to disk every 3 seconds.
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await self?.flush()
            }
        }
    }

    func log(
        beacons: [DetectedBeacon],
        riderState: RiderState,
        motionState: MotionState,
        accelerationMagnitude: Double
    ) {
        guard isLogging, let start = startTime else { return }

        let elapsed = String(format: "%.2f", Date().timeIntervalSince(start))
        let px = String(format: "%.2f", riderState.position.x)
        let py = String(format: "%.2f", riderState.position.y)
        let nearest = riderState.nearestLetter.rawValue
        let dist = String(format: "%.2f", riderState.distanceToNearest)
        let conf = "\(riderState.confidence)"
        let motion = motionState.rawValue
        let accel = String(format: "%.4f", accelerationMagnitude)

        if beacons.isEmpty {
            rowBuffer.append([elapsed, "", "", "", "", px, py, nearest, dist, conf, motion, accel, px, py].joined(separator: ",") + "\n")
            sampleCount += 1
        } else {
            for beacon in beacons {
                rowBuffer.append([
                    elapsed,
                    beacon.letter.rawValue, "\(beacon.rssi)",
                    String(format: "%.2f", beacon.accuracy), beacon.proximityLabel,
                    px, py, nearest, dist, conf, motion, accel, px, py
                ].joined(separator: ",") + "\n")
                sampleCount += 1
            }
        }
    }

    func stop() {
        flushTask?.cancel()
        flushTask = nil
        isLogging = false
        let pending = rowBuffer
        rowBuffer = []
        Task {
            await writer.write(pending)
            await writer.close()
        }
    }

    var logFileURL: URL? { filePath }

    // MARK: - Private

    private func flush() async {
        guard !rowBuffer.isEmpty else { return }
        let rows = rowBuffer
        rowBuffer = []
        await writer.write(rows)
    }
}
