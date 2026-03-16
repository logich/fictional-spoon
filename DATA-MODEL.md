# Data Model

This document describes the data model for Dressage Caller. Each entity is annotated with its implementation status:

- ✅ **Implemented** — Swift type exists in the codebase
- 🔲 **Planned** — documented here but no Swift code exists yet

---

## Arena & Beacon Entities

### `ArenaSize` ✅
```swift
enum ArenaSize: String, Sendable, Codable, CaseIterable {
    case small    // 20×40m — 8 perimeter letters: A, K, E, H, C, M, B, F
    case standard // 20×60m — 12 perimeter letters: A, K, V, E, S, H, C, M, R, B, P, F
}
```

### `ArenaLetter` ✅
All standard arena letters, including centerline. Implements `position(for: ArenaSize) -> CGPoint` returning (x, y) coordinates in meters from the bottom-left origin (A end, left side when facing C).

```
Perimeter letters: A, K, V, E, S, H, C, M, R, B, P, F
Centerline letters: D, L, X, I, G
```

Small arena (20×40m) perimeter positions:
```
A (10, 0) — bottom center
K  (0, 6) — left wall
E  (0, 20) — left center
H  (0, 34) — left wall
C  (10, 40) — top center
M  (20, 34) — right wall
B  (20, 20) — right center
F  (20, 6)  — right wall
```

### `BeaconMapping` ✅
Links a BLE beacon's iBeacon identity to an arena letter.

```swift
struct BeaconMapping: Sendable {
    let letter: ArenaLetter
    let major: UInt16
    let minor: UInt16
}
```

> **Note**: The iBeacon proximity UUID is shared across all beacons in a configuration; it lives on `ArenaConfiguration`, not per `BeaconMapping`.

> **Planned but not in code**: `rssiAtLetter: Int?`, `lastSeen: Date?`, `batteryLevel: Int?`

### `ArenaConfiguration` ✅
Configuration for a single arena. Holds the shared iBeacon UUID, arena dimensions, and the beacon-to-letter mapping table.

```swift
struct ArenaConfiguration: Sendable {
    let beaconUUID: UUID         // shared iBeacon proximity UUID for all beacons in this arena
    let arenaSize: ArenaSize
    let beaconMappings: [BeaconMapping]

    func letter(forMajor major: UInt16, minor: UInt16) -> ArenaLetter?
    var beaconLetters: Set<ArenaLetter>

    static let prototype: ArenaConfiguration  // 4-beacon placeholder — see note below
}
```

**`prototype` constant**: Uses the Kontakt factory-default UUID (`F7826DA6-4FA2-4E98-8024-BC5B71E0893E`) with 4 beacons at A, E, C, B and **placeholder major/minor values** (1/0, 1/1, 1/2, 1/3). Must be replaced with real values once Beacon Diagnostic is run on device with powered beacons.

**Production configuration**: 8 beacons required (A, K, E, H, C, M, B, F). Field testing confirmed that 4 beacons are insufficient in a metal building due to multipath noise. See `TEST-RESULTS.md`.

> **Relationship to documented `Arena` type**: The original `DATA-MODEL.md` described an `Arena` entity with fields for `name`, `isIndoor`, and `timingOffset`. These are planned features; the current implementation uses the simpler `ArenaConfiguration` struct. The `timingOffset` concept is planned for Sprint 3 as a user-adjustable slider.

### `BeaconCalibration` ✅
RSSI reference values captured during the guided perimeter walk. Used by `PositionEngine` to improve ranging accuracy for a specific physical environment.

```swift
struct BeaconCalibration {
    let readings: [ArenaLetter: Double]  // calibrated RSSI at each letter position
    static let uncalibrated: BeaconCalibration

    func estimatedDistance(from beacon: BeaconMapping, rssi: Double) -> Double
}
```

Persisted to UserDefaults as JSON after each calibration run; loaded on startup.

---

## Test Entities

### `DressageTest` ✅ (Codable)
An ordered sequence of movements. Immutable reference data.

```swift
struct DressageTest: Identifiable, Sendable, Codable {
    let id: UUID
    let name: String                      // "Training Level Test 1"
    let organization: DressageOrganization
    let level: String                     // "Training", "First", "Basic", etc.
    let arenaSize: ArenaSize
    let year: Int                         // test version year, e.g. 2023
    let movements: [Movement]

    func movement(after sequence: Int) -> Movement?
}
```

> **Planned but not in code**: `effectiveThrough: Date?`

### `DressageOrganization` ✅ (Codable)
```swift
enum DressageOrganization: String, Sendable, Codable, CaseIterable {
    case usdf            // USDF Traditional Dressage
    case usef            // USEF
    case fei             // FEI International
    case westernDressage // Western Dressage
}
```

### `Movement` ✅ (Codable)
A single step in a dressage test sequence.

```swift
struct Movement: Identifiable, Sendable, Codable {
    let id: UUID
    let sequence: Int                // 1-based position in test
    let location: MovementLocation   // where this movement triggers
    let spokenText: String           // "A — Enter working trot"
    let directiveText: String        // full official directive text
    let expectedGait: Gait?          // gait the rider should be in after this movement
    let path: PathShape?             // expected path shape for canvas visualization
}
```

> **Note on design divergence**: The original `DATA-MODEL.md` described `triggerLetter: Letter`, `triggerZone: TriggerZone`, and `expectedHeading: HeadingRange`. The implementation uses `location: MovementLocation` and `path: PathShape` instead. `TriggerZone` and `HeadingRange` are not in the codebase.

### `MovementLocation` ✅ (Codable)
```swift
enum MovementLocation: Sendable, Equatable, Codable {
    case letter(ArenaLetter)
    case between(ArenaLetter, ArenaLetter)

    func position(for size: ArenaSize) -> CGPoint
    var label: String  // "A" or "Between B & M"
}
```

### `PathShape` ✅ (Codable)
The geometric path the rider traces for a movement, used for the arena canvas.

```swift
enum PathShape: Sendable, Codable {
    case line(to: MovementLocation)
    case circle(diameterMeters: Double)
    case track(waypoints: [ArenaLetter])
}
```

### `Gait` ✅ (Codable)
```swift
enum Gait: String, Sendable, Codable, CaseIterable, Identifiable {
    case halt
    case walk
    case trot
    case canter
}
```

---

## Session Entities

### `RideSession` ✅
Owns all services required for an active ride. Created by `HomeView`, passed into `RideView`. `@MainActor @Observable`.

```swift
final class RideSession {
    let configuration: ArenaConfiguration
    let calibration: BeaconCalibration
    let test: DressageTest?
    let horseName: String?

    // Owned services
    let beaconService: BeaconRangingService
    let positionEngine: PositionEngine
    let motionService: MotionService
    let announcementService: AnnouncementService
    let sessionLogger: SessionLogger
    private(set) var sessionController: RideSessionController?

    func start()
    func stop()
    func update()   // called each time detected beacons change
}
```

> **Relationship to documented session entities**: The original `DATA-MODEL.md` described `RideSession` as a data record with `positionLog`, `movementLog`, and `gaitLog`. The current implementation of `RideSession` is a service container, not a data record. Session log data is written to CSV by `SessionLogger`. The data-record version (`PositionSample`, `MovementEvent`, `GaitSegment`) is planned for a future sprint when post-ride summary and path replay are implemented (Sprint 4).

### `RiderState` ✅
Current estimated position and motion state, produced by `PositionEngine` each update cycle.

```swift
struct RiderState {
    let position: CGPoint?    // (x, y) in meters; nil if no fix
    let nearestLetter: ArenaLetter?
    let nearestDistance: Double?
}
```

---

## Rider / Horse Entities — 🔲 Planned, Not Yet Implemented

The following entities are fully designed but have no Swift code yet. They are targeted for Sprint 4.

### `Rider` 🔲
```
Rider
  id: UUID
  name: String
  preferredVoice: VoiceConfig
  defaultArena: ArenaConfiguration?
  defaultHorse: Horse?
```
Single-user for MVP (no accounts, no cloud sync).

### `Horse` 🔲
```
Horse
  id: UUID
  name: String
  breed: String?
  gaitProfiles: [GaitProfile]   // one per arena
```

### `GaitProfile` 🔲
Per-horse, per-arena motion signature. Stride length and gait patterns vary by horse and arena.

```
GaitProfile
  id: UUID
  horse: Horse
  arena: ArenaConfiguration
  walkStrideLength: Double      // meters
  trotStrideLength: Double
  canterStrideLength: Double
  walkSignature: IMUSignature
  trotSignature: IMUSignature
  canterSignature: IMUSignature
  lastUpdated: Date
```

### `IMUSignature` 🔲
Serialized reference waveform for gait classification.

```
IMUSignature
  sampleRate: Int               // Hz (50)
  dominantFrequency: Double     // Hz — distinguishes gaits
  amplitudeRange: (min, max)
  templateData: Data            // serialized reference waveform
```

---

## Settings

### `VoicePreference` ✅
```swift
// Persisted in UserDefaults
struct VoicePreference {
    var voiceIdentifier: String?  // AVSpeechSynthesisVoice identifier
    var rate: Float               // speech rate 0.0–1.0
}
```

### `AppSettings` 🔲
```
AppSettings
  offCourseAssist: Bool         // default: false (deferred feature)
  competitionCountdownAudio: Bool
  language: Locale
```

---

## Test Import — 🔲 Planned (Sprint 3)

### `ImportSource`
```
ImportSource
  case pdf(url: URL)     // PDFKit text extraction
  case camera            // VisionKit document scan + Vision OCR
  case manual            // user-typed fallback
```

**PDF Import Flow**: User selects PDF from Files app → PDFKit extracts text → parser finds movement lines by regex → user reviews parsed output → save to `Documents/tests/`

**Parser approach**: Regex `^(\d+)\.\s+([A-Z])\s+(.+)$` for single-letter movements; special handling for ranges (K-X-M), "between" positions, gait keyword extraction.

---

## Storage

- **Local-first**: all data on device
- **Current implementation**: UserDefaults + JSON for `BeaconCalibration` and test data; CSV for session logs
- **Planned**: SwiftData migration (deferred — current JSON approach is sufficient for MVP)
- **No cloud sync for MVP**: avoids account creation friction
- **Session logs**: stored as CSV files in Documents; can grow large (1 sample/sec × 7 min = ~420 rows/session); auto-prune or export options planned for Sprint 4
