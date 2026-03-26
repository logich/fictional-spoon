# Architecture & File Map

## Directory Structure
```
DressageCaller/
├── App/DressageCallerApp.swift        # @main entry point → HomeView
├── Models/
│   ├── ArenaLetter.swift              # 17 enum cases with (x,y) positions for 20×40 and 20×60
│   ├── ArenaConfiguration.swift       # ArenaSize, BeaconMapping, prototype config (8 beacons A,K,E,H,C,M,B,F); beaconProximityUUID constant
│   ├── RiderState.swift               # Position + nearest letter + confidence
│   ├── DressageTest.swift             # DressageTest, Movement, MovementLocation, Gait, DressageOrganization (Codable)
│   ├── SampleTests.swift              # Bundled USEF Training Level Test 1 (2023, 17 movements)
│   └── BeaconCalibration.swift        # Per-beacon RSSI at 1m; FingerprintVector per letter; exportCSV(); nearestFingerprint()
├── Services/
│   ├── BeaconRangingService.swift     # CLLocationManager iBeacon ranging (real) + Timer mock (simulator, 8-beacon route); per-beacon RSSI EMA
│   ├── PositionEngine.swift           # TX-power-normalised proximity-weighted centroid; -90dBm noise floor; 2s time-based hysteresis; fingerprint override
│   ├── MotionService.swift            # CoreMotion accelerometer → motion state classification
│   ├── AnnouncementService.swift      # AVSpeechSynthesizer, trigger threshold, cooldown
│   ├── RideSession.swift              # @Observable class owning all ride services; passed into RideView
│   ├── RideSessionController.swift    # Bell/countdown, movement sequencing, practice pause, look-ahead timing
│   ├── SessionLogger.swift            # Async I/O: buffers rows, flushes every 3s on background actor; logRawRow() for ground-truth events
│   ├── BeaconDiagnosticService.swift  # RSSI diagnostics, beacon health monitoring
│   ├── TestLibrary.swift              # Persists imported tests as JSON in Documents/tests/
│   └── PDFTestParser.swift            # PDFKit text extraction → Movement structs
├── Views/
│   ├── HomeView.swift                 # Landing: arena size, horse, test selection, calibration, mode toggle, start ride; Position Verification link
│   ├── TestSelectionView.swift        # Pick bundled or imported test, filtered by arena size
│   ├── CalibrationView.swift          # TX calibration + two-pass fingerprint walk (clockwise then counterclockwise); CSV export
│   ├── RideView.swift                 # Active ride: Calling/Next movement rows, arena, debug panel (#if DEBUG only), bell/countdown overlay
│   ├── ArenaView.swift                # Canvas-drawn arena with letter markers + rider dot + movement path
│   ├── BeaconStatusView.swift         # Debug panel: RSSI, distance, proximity per beacon
│   ├── BeaconDiagnosticView.swift     # Detailed beacon health diagnostics
│   ├── PreviewMovementsView.swift     # Scrollable list: sequence, location, directive text, gait badge
│   ├── TestImportView.swift           # URL/PDF import → review screen → save to TestLibrary
│   ├── VoicePickerView.swift          # AVSpeechSynthesisVoice picker with premium/enhanced auto-selection
│   └── PositionVerificationView.swift # Field-testing screen: letter-tap ground truth, live estimate, accuracy stats, CSV export
├── ViewModels/
│   ├── CalibrationViewModel.swift     # Timer captures reference type for calibration walk; fingerprint two-pass state machine
│   └── PositionVerificationViewModel.swift  # Owns its own services (BeaconRangingService, PositionEngine, MotionService, SessionLogger); 0.5s poll; records GROUND_TRUTH events
├── Extensions/
│   └── Collection+Safe.swift          # Safe subscript
├── Resources/
│   └── bell.caf                       # Bell sound for competition countdown
├── Info.plist                         # Location, Bluetooth, Motion permission strings + background modes
└── PrivacyInfo.xcprivacy              # Privacy manifest: no tracking; required-reason APIs (UserDefaults CA92.1, file timestamps C617.1, disk space E174.1)

DressageCallerTests/
└── PDFParserTests.swift               # Unit tests for PDF parsing pipeline
```

## Key Patterns
- **State flow**: BeaconRangingService → PositionEngine.update(motionState:) → RiderState → RideSessionController.checkAndAnnounce()
- **All services are @MainActor @Observable** — observed directly in SwiftUI views
- **RideSession** owns all services and is created by HomeView, passed into RideView
- **ArenaView** uses SwiftUI Canvas for drawing, transforms arena meters → screen points

## Position Engine — Current Implementation (Sprint 4)

Gauss-Newton trilateration replaced. Now uses **TX-power-normalised proximity-weighted centroid**:

- **Noise floor**: only beacons with RSSI > -90dBm are "qualified"; falls back to all-negative beacons if none qualify
- **Weight formula**: `weight = 10^((rssi - txPower) / 20)` — normalises for mixed hardware (ESP32 vs Kontakt have different TX power, causing up to 30m centroid bias without this)
- **Per-beacon EMA smoothing**: alpha=0.3 in BeaconRangingService (applied before PositionEngine sees values)
- **Confidence**: counts beacons with RSSI > -80dBm as "strong"; ≥2 strong = `.strong`, ≥1 = `.weak`, else `.none`
- **Hysteresis**: time-based, 2.0s — new letter must dominate before zone changes
- **Fingerprint override**: when `BeaconCalibration.fingerprints` is populated, `nearestFingerprint()` overrides the geometric nearest-letter result

**Still under field validation** — TX normalisation fix applied after 2026-03-16 session; next ride will confirm.

See `docs/rf-positioning.md` for full algorithm rationale and field test data.

## Motion-Aware Filter (on current trilateration — applies to centroid too)
Three-layer filter on position output:
1. **Speed cap** — displacement limited by gait max speed × dt
2. **Direction continuity** — heading change clamped per gait
3. **Adaptive blend** — stationary α=0.05 (locks position), canter α=0.7 (trusts new readings)

Turn rate caps: stationary=unconstrained, walk=360°/s, trot=180°/s, canter=90°/s — all standard dressage figures fall within these caps.

## CSV Schemas

**Ride log** (written by SessionLogger, stored in Documents/RideLogs/):
14 columns: timestamp, lat, lon, posX, posY, nearestLetter, confidence, motionState, currentMovement, nextMovement, beaconCount, strongBeaconCount, eventType, notes

**Calibration export** (written by BeaconCalibration.exportCSV(), shared via ShareLink in CalibrationView):
Two sections:
1. `# TX Calibration (RSSI at 1m)` — columns: beacon, rssi_at_1m
2. `# Arena Fingerprints` — columns: position, beacon, avg_rssi

**Position verification log** (written by PositionVerificationViewModel via SessionLogger.logRawRow()):
Same 14 columns as ride log; eventType = "GROUND_TRUTH" for user taps; notes = tapped letter name

## Build System
- `project.yml` (XcodeGen) defines the iOS app target, signing (GKLUN877QD), schemes
- `xcodegen generate` rewrites .xcodeproj — always run after project.yml changes; **clears signing team**
- System frameworks: CoreLocation, AVFoundation, CoreMotion, PDFKit
- Debug panel in RideView is wrapped in `#if DEBUG` — hidden in release builds
- Xcode MCP available: `BuildProject(tabIdentifier: "windowtab1")`
