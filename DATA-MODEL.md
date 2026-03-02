# Data Model

## Entity Relationship Overview

```
Rider (1) ──── has many ──── Horse (n)
Rider (1) ──── has many ──── Arena (n)
Rider (1) ──── has many ──── SavedTest (n)
Arena  (1) ──── has many ──── BeaconMapping (n)
Arena  (1) ──── has many ──── Calibration (n)
Horse  (1) ──── has many ──── GaitProfile (n)  [one per arena]
Test   (1) ──── has many ──── Movement (n)
Rider  (1) ──── has many ──── RideSession (n)
RideSession (1) ── ref ──── Test, Horse, Arena
RideSession (1) ── has many ── PositionSample (n)
```

---

## Core Entities

### Rider
The app user. Single-user for MVP (no accounts, no cloud sync).

```
Rider
  id: UUID
  name: String
  preferredVoice: VoiceConfig
  defaultArena: Arena?
  defaultHorse: Horse?
```

### Horse
Stride length and gait signatures vary by horse. Linda rides two.

```
Horse
  id: UUID
  name: String                    // "Duke"
  breed: String?                  // "Hanoverian"
  gaitProfiles: [GaitProfile]     // one per arena (signal environment differs)

GaitProfile
  id: UUID
  horse: Horse
  arena: Arena
  walkStrideLength: Double        // meters, measured during calibration/rides
  trotStrideLength: Double
  canterStrideLength: Double
  walkSignature: IMUSignature     // accelerometer pattern for classification
  trotSignature: IMUSignature
  canterSignature: IMUSignature
  lastUpdated: Date               // profiles refine over time with more rides

IMUSignature
  sampleRate: Int                 // Hz (50)
  dominantFrequency: Double       // Hz — distinguishes gaits
  amplitudeRange: (min: Double, max: Double)
  templateData: Data              // serialized reference waveform for classifier
```

### Arena

```
Arena
  id: UUID
  name: String                    // "Linda's Outdoor"
  type: ArenaSize                 // .small_20x40 | .full_20x60
  isIndoor: Bool                  // affects default timing offset
  beacons: [BeaconMapping]
  calibrations: [Calibration]
  timingOffset: Int               // strides before letter to announce (user slider)
                                  // stored per arena since indoor/outdoor differ

ArenaSize
  case small_20x40               // 8 letters: A, K, E, H, C, M, B, F
  case full_20x60                // 12 letters: A, K, V, E, S, H, C, M, R, B, P, F

  // Each size defines:
  letters: [Letter]               // ordered list with known coordinates
  perimeterLength: Double         // 120m or 160m
```

### Letter
Fixed positions in the arena. Known geometry, never changes.

```
Letter
  id: String                     // "A", "K", "E", etc.
  position: ArenaPoint           // (x, y) in meters from arena origin
  isOnRail: Bool                 // true for perimeter letters, false for centerline (D, X, G, etc.)

ArenaPoint
  x: Double                      // 0–20m (width)
  y: Double                      // 0–40m or 0–60m (length)
```

### BeaconMapping
Links a physical BLE beacon to an arena letter.

```
BeaconMapping
  id: UUID
  letter: Letter
  beaconUUID: UUID               // iBeacon proximity UUID
  major: UInt16                  // iBeacon major value
  minor: UInt16                  // iBeacon minor value
  rssiAtLetter: Int?             // calibrated RSSI when standing at the letter
  lastSeen: Date?
  batteryLevel: Int?             // if beacon reports it
```

### Calibration
Captured during the guided perimeter walk. One per arena, can be re-run.

```
Calibration
  id: UUID
  arena: Arena
  horse: Horse?                  // if ridden during calibration
  date: Date
  letterReadings: [LetterReading]

LetterReading
  letter: Letter
  beaconRSSI: [BeaconRSSI]       // signal from ALL beacons at this position
  imuSnapshot: IMUSnapshot       // device orientation and motion at this point

BeaconRSSI
  beacon: BeaconMapping
  rssi: Int                      // signal strength from this beacon at this letter position
  distance: Double               // estimated distance in meters

IMUSnapshot
  heading: Double                // magnetic heading in degrees
  acceleration: (x: Double, y: Double, z: Double)
  rotation: (roll: Double, pitch: Double, yaw: Double)
```

---

## Test Entities

### Test
A dressage test definition. Immutable reference data.

```
Test
  id: UUID
  name: String                   // "Training Level Test 1"
  organization: Organization     // .usdf | .westernDressage | .fei | .usef
  level: String                  // "Training", "First", "Basic", etc.
  arenaSize: ArenaSize           // which arena this test requires
  year: Int                      // test version year (e.g., 2023)
  effectiveThrough: Date?        // "effective through November 2026"
  movements: [Movement]          // ordered sequence

Organization
  case usdf                      // USDF Traditional Dressage
  case westernDressage           // Western Dressage
  case fei                       // FEI international
  case usef                      // USEF
```

### Movement
A single step in the test sequence. The heart of the calling logic.

```
Movement
  id: UUID
  sequence: Int                  // 1, 2, 3... order in test
  triggerLetter: Letter          // where this movement is called
  triggerZone: TriggerZone       // how to match rider position to trigger
  spokenText: String             // "A — Enter working trot"
  directiveText: String?         // full official text for display/preview
  expectedGait: Gait?            // what gait the rider should be in after this movement
  expectedHeading: HeadingRange  // which direction rider should be traveling

TriggerZone
  letter: Letter                 // target letter
  approachHeading: Double        // expected heading toward this letter (degrees)
  headingTolerance: Double       // ± degrees (default 45°)
  // Trigger distance is NOT stored here — it's computed at runtime from:
  //   rider velocity × stride length × timingOffset (strides from arena settings)

HeadingRange
  center: Double                 // degrees, 0 = north along arena
  tolerance: Double              // ± degrees

Gait
  case halt
  case walk
  case trot
  case canter
```

---

## Session Entities

### RideSession
One test run-through. Records everything for post-ride replay.

```
RideSession
  id: UUID
  date: Date
  test: Test
  horse: Horse
  arena: Arena
  mode: SessionMode              // .competition | .practice
  startTime: Date
  endTime: Date?
  duration: TimeInterval?
  movementsCalled: Int           // how many of the test's movements were triggered
  totalMovements: Int
  positionLog: [PositionSample]  // high-frequency tracking data for replay
  movementLog: [MovementEvent]   // when each movement was actually called
  gaitLog: [GaitSegment]         // gait classification over time

SessionMode
  case competition               // bell + countdown, no pausing
  case practice                  // no bell, pauses on halt

PositionSample
  timestamp: TimeInterval        // seconds from session start
  position: ArenaPoint           // estimated (x, y)
  heading: Double                // degrees
  velocity: Double               // m/s
  gait: Gait
  confidence: Double             // 0–1, how sure are we of this position
  sources: [PositionSource]      // which beacons contributed

PositionSource
  beacon: BeaconMapping
  rssi: Int
  estimatedDistance: Double

MovementEvent
  movement: Movement
  calledAt: TimeInterval         // when the audio played
  riderPosition: ArenaPoint      // where the rider was when it triggered
  riderHeading: Double
  riderVelocity: Double
  distanceFromLetter: Double     // how far from the trigger letter when called

GaitSegment
  gait: Gait
  startTime: TimeInterval
  endTime: TimeInterval
  averageVelocity: Double
  strideCount: Int?              // if stride detection is reliable
```

---

## Settings / Preferences

```
AppSettings
  preferredVoice: VoiceConfig
  offCourseAssist: Bool          // default: false
  competitionCountdownAudio: Bool // "30 seconds", "15 seconds" announcements
  language: Locale

VoiceConfig
  voiceIdentifier: String        // AVSpeechSynthesisVoice identifier
  rate: Float                    // speech rate 0.0–1.0
  pitchMultiplier: Float         // default 1.0
```

---

## Test Import

### Import Sources
```
TestImport
  source: ImportSource
  rawText: String                // extracted text before parsing
  parsedMovements: [Movement]    // result of parsing
  needsReview: Bool              // true if parser confidence is low on any movement
  importDate: Date

ImportSource
  case pdf(url: URL)             // PDF file from Files app, email, Safari download
  case camera                    // scanned with VisionKit document camera
  case manual                    // typed in by user (fallback)
  case bundled                   // shipped with the app
```

### PDF Import Flow
1. User taps "Add Test" → "Import from PDF"
2. iOS document picker opens (Files app, iCloud, email attachments)
3. **PDFKit** extracts text from the digital PDF (no OCR needed — USDF PDFs have real text layers)
4. Parser extracts: test name, organization, level, arena size, and movement list
5. User reviews parsed movements, can edit any that parsed incorrectly
6. Save to My Tests

### Camera Scan Flow
1. User taps "Add Test" → "Scan with Camera"
2. **VisionKit VNDocumentCameraViewController** opens — built-in scanner UI
3. User photographs the test sheet (auto-crops, perspective correction)
4. **Vision VNRecognizeTextRequest** (`.accurate` mode) extracts text with bounding boxes
5. Same parser runs on extracted text
6. User reviews and corrects → save

### Test Sheet Format (Highly Consistent)
USDF traditional and WDAA western dressage tests follow the same structure:
```
Movement line format:
  "{number}. {letter(s)}   {directive text}"

Examples:
  "1. A    Enter working trot"
  "3. C    Track left"
  "5. E    Circle left 20 meters"
  "7. K-X-M  Change rein, free walk"
  "9. Between C & M  Working canter left lead"
```

### Parsing Strategy
- **Simple cases** (single letter): Regex `^(\d+)\.\s+([A-Z])\s+(.+)$` → sequence, letter, directive
- **Letter ranges** (K-X-M): Split on hyphens, first letter is approach, last is completion
- **Compound locations** ("Between C & M"): Map to midpoint between the two letters
- **Gait inference**: Keyword scan for "walk", "trot", "canter", "halt", "jog", "lope" in directive text
- **Heading inference**: Keywords like "track left", "track right", "circle left", "change rein" → derive expected direction

### Review Screen
After parsing, show the movement list with confidence indicators:
- ✅ High confidence — parsed cleanly
- ⚠️ Needs review — ambiguous letter or directive (highlighted for user to tap and correct)
- User can edit trigger letter, spoken text, or expected gait for any movement
- "Looks good" → save

---

## Storage Notes

- **Local-first**: All data on device using SwiftData (Core Data successor)
- **No cloud sync for MVP** — avoids account creation friction
- **Test definitions**: Bundled in app or downloaded from a test catalog
- **Position logs**: Can get large (1 sample/sec × 7 min = 420 samples per session). Store recent sessions, auto-prune older ones, option to export.
- **Calibration data**: Small, keep indefinitely per arena
- **Gait profiles**: Refine over time — each ride updates the horse's stride/gait model with new data
