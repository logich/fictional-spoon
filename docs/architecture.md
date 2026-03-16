# Architecture & File Map

## Directory Structure
```
DressageCaller/
├── App/DressageCallerApp.swift        # @main entry point → HomeView
├── Models/
│   ├── ArenaLetter.swift              # 17 enum cases with (x,y) positions for 20×40 and 20×60
│   ├── ArenaConfiguration.swift       # ArenaSize, BeaconMapping, prototype config (4 beacons at A,E,C,B)
│   ├── RiderState.swift               # Position + nearest letter + confidence
│   ├── DressageTest.swift             # DressageTest, Movement, MovementLocation, Gait, DressageOrganization (Codable)
│   ├── SampleTests.swift              # Bundled USEF Training Level Test 1 (2023, 17 movements)
│   └── BeaconCalibration.swift        # Per-beacon RSSI at 1m, log-distance path loss model, [ArenaLetter: Double] keys
├── Services/
│   ├── BeaconRangingService.swift     # CLLocationManager iBeacon ranging (real) + Timer mock (simulator); per-beacon RSSI EMA
│   ├── PositionEngine.swift           # Position estimation (Gauss-Newton trilateration — needs replacement with centroid)
│   ├── MotionService.swift            # CoreMotion accelerometer → motion state classification
│   ├── AnnouncementService.swift      # AVSpeechSynthesizer, trigger threshold, cooldown
│   ├── RideSession.swift              # @Observable class owning all ride services; passed into RideView
│   ├── RideSessionController.swift    # Bell/countdown, movement sequencing, practice pause, look-ahead timing
│   ├── SessionLogger.swift            # Async I/O: buffers rows, flushes every 3s on background actor
│   ├── BeaconDiagnosticService.swift  # RSSI diagnostics, beacon health monitoring
│   ├── TestLibrary.swift              # Persists imported tests as JSON in Documents/tests/
│   └── PDFTestParser.swift            # PDFKit text extraction → Movement structs
├── Views/
│   ├── HomeView.swift                 # Landing: arena size, horse, test selection, calibration, mode toggle, start ride
│   ├── TestSelectionView.swift        # Pick bundled or imported test, filtered by arena size
│   ├── CalibrationView.swift          # Guided walk: stand 1m from each beacon, record RSSI
│   ├── RideView.swift                 # Active ride: status bar, arena, debug panel, start/stop; bell/countdown overlay
│   ├── ArenaView.swift                # Canvas-drawn arena with letter markers + rider dot + movement path
│   ├── BeaconStatusView.swift         # Debug panel: RSSI, distance, proximity per beacon
│   ├── BeaconDiagnosticView.swift     # Detailed beacon health diagnostics
│   ├── PreviewMovementsView.swift     # Scrollable list: sequence, location, directive text, gait badge
│   ├── TestImportView.swift           # URL/PDF import → review screen → save to TestLibrary
│   └── VoicePickerView.swift          # AVSpeechSynthesisVoice picker with premium/enhanced auto-selection
├── ViewModels/
│   └── CalibrationViewModel.swift     # Timer captures reference type for calibration walk
├── Extensions/
│   └── Collection+Safe.swift          # Safe subscript
├── Resources/
│   └── bell.caf                       # Bell sound for competition countdown
└── Info.plist                         # Location, Bluetooth, Motion permission strings + background modes

DressageCallerTests/
└── PDFParserTests.swift               # Unit tests for PDF parsing pipeline
```

## Key Patterns
- **State flow**: BeaconRangingService → PositionEngine.update(motionState:) → RiderState → RideSessionController.checkAndAnnounce()
- **All services are @MainActor @Observable** — observed directly in SwiftUI views
- **RideSession** owns all services and is created by HomeView, passed into RideView
- **ArenaView** uses SwiftUI Canvas for drawing, transforms arena meters → screen points

## Position Engine — Current State (Needs Replacement)

Currently uses Gauss-Newton trilateration + motion-aware filter. **Failed in field tests** — CL `accuracy` averages 14–23m in metal barn, confidence never above "weak".

**Sprint 4 replacement**: proximity-weighted centroid on smoothed RSSI
- Weight formula: `weight = 10^((RSSI+50)/20)`
- Per-beacon EMA smoothing: alpha=0.3 in BeaconRangingService
- Letter-change hysteresis: 2–3s dominance before zone change
- Fingerprint matching when 8-beacon calibration available

## Motion-Aware Filter (on current trilateration — applies to centroid too)
Three-layer filter on position output:
1. **Speed cap** — displacement limited by gait max speed × dt
2. **Direction continuity** — heading change clamped per gait
3. **Adaptive blend** — stationary α=0.05 (locks position), canter α=0.7 (trusts new readings)

Turn rate caps: stationary=unconstrained, walk=360°/s, trot=180°/s, canter=90°/s — all standard dressage figures fall within these caps.

## Build System
- `project.yml` (XcodeGen) defines the iOS app target, signing (GKLUN877QD), schemes
- `xcodegen generate` rewrites .xcodeproj — always run after project.yml changes; **clears signing team**
- System frameworks: CoreLocation, AVFoundation, CoreMotion, PDFKit
- Xcode MCP available: `BuildProject(tabIdentifier: "windowtab1")`
