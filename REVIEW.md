# iOS Craft Expert Review — Dressage Caller

Reviewed: 2026-03-09

---

## P0 — Critical (will break real rides)

### 1. DressageTest movements are never announced
`AnnouncementService.checkAndAnnounce` only says "Approaching [letter]". The `DressageTest`, `Movement`, and `spokenText` fields exist but are completely unused during a ride. The app cannot function as a caller without a movement sequence controller.

**Fix:** Create a `RideSessionController` (`@Observable` class) that holds the active test, tracks the current movement index, and speaks `movement.spokenText` when the rider enters the trigger zone. Advance the index after each announcement.

### 2. Beacon ranging never stops on back navigation
`RideView.onDisappear` stops motion and session logging but does **not** call `BeaconRangingService.stopRanging()`. The `CLLocationManager` keeps ranging indefinitely, draining battery.

**Fix:** Add `beaconService.stopRanging()` to `RideView.onDisappear`.

### 3. CalibrationView timer captures `self` as a value type
`Timer.scheduledTimer` captures `[self]` inside a SwiftUI `View` struct. Mutations to `rssiSamples` and `phase` inside the callback modify a stale copy, not live state. Calibration is likely broken on device.

**Fix:** Extract calibration logic into an `@Observable` class (`CalibrationViewModel`) so the timer captures a reference type.

### 4. `audio` background mode is missing
`UIBackgroundModes` includes `location` and `bluetooth-central` but not `audio`. `AVSpeechSynthesizer` utterances will be silenced when the phone is pocketed and the screen locks.

**Fix:** Add `audio` to `UIBackgroundModes` in `project.yml`.

---

## P1 — High (significantly affects reliability or UX)

### 5. Announcements need look-ahead timing
A human caller announces the *upcoming* movement before the rider reaches the letter — typically 2–3 seconds ahead. The current distance-threshold approach triggers at the letter, which is too late.

**Fix:** Use the velocity vector (already computed in `PositionEngine`) to predict ETA at the next movement's trigger location. Announce when ETA is within a configurable window (default: 4 seconds).

### 6. `PositionEngine.velocity` is private
The smoothed velocity vector is computed but not exposed. Both look-ahead prediction and direction-of-travel display on `ArenaView` need it.

**Fix:** Expose `velocity: CGVector` as a `private(set)` published property.

### 7. No stale beacon eviction
When a beacon goes out of range, `detectedBeacons` retains the last snapshot forever. `PositionEngine` continues computing positions from stale data.

**Fix:** In `BeaconRangingService.didRange`, filter out any `DetectedBeacon` whose `lastSeen` is older than 3 seconds. Clear `detectedBeacons` if nothing fresh remains.

### 8. `MotionService` has a double main-thread hop
`CMMotionManager.startAccelerometerUpdates(to: .main)` already delivers on the main queue. The `Task { @MainActor }` wrapper inside the callback is redundant and creates a Swift 6 Sendable issue with `CMAcceleration`.

**Fix:** Remove the `Task { @MainActor }` wrapper; the callback is already on main.

### 9. `SessionLogger` does synchronous disk I/O on `@MainActor`
4 synchronous `FileHandle.write` calls per beacon update per second on the main thread. Fine for the prototype but will cause frame drops as update rate increases.

**Fix:** Buffer rows in memory and flush to disk on a background actor/queue every 2–5 seconds.

### 10. No UI for failed background location authorization
The app silently fails if the user denies `.authorizedAlways`. The rider gets no ranging in the background with no indication why.

**Fix:** When `authorizationStatus == .authorizedWhenInUse`, show a banner in `RideView` explaining that background access is needed, with a "Open Settings" button.

---

## P2 — Medium (code quality, maintainability)

### 11. Extract `RideSession` as an `@Observable` class
All ride services (`BeaconRangingService`, `PositionEngine`, `MotionService`, `AnnouncementService`, `SessionLogger`) are created as `@State` in a `View`. Navigating away and back creates new instances, losing state.

**Fix:** Introduce `RideSession: @Observable` that owns all services. Pass it into `RideView`. This also enables a future Live Activity and post-ride replay.

### 12. `DressageTest` and `Movement` are not `Codable`
Tests cannot be serialized to JSON, stored in SwiftData, or imported from files.

**Fix:** Conform `DressageTest`, `Movement`, `MovementLocation`, `Gait`, `DressageOrganization`, and `ArenaSize` to `Codable`.

### 13. Replace `ShareSheet` with `ShareLink`
`UIActivityViewController` wrapped in `UIViewControllerRepresentable` is unnecessary on iOS 16+. The app targets iOS 18+.

**Fix:** Replace `ShareSheet` with `ShareLink(item: url)`.

### 14. `BeaconCalibration.readings` uses `[String: Double]`
String keys lose type safety — a typo silently produces a cache miss.

**Fix:** Change to `[ArenaLetter: Double]`. `ArenaLetter` is `RawRepresentable<String>` so `Codable` conformance is automatic.

### 15. No accessibility support
`ArenaView` Canvas is opaque to VoiceOver. Control buttons and beacon status rows lack accessibility labels. Important for gloved riders who may rely on VoiceOver or Voice Control.

**Fix:** Add `accessibilityElement` and `accessibilityLabel` to the rider dot, letter markers, and control buttons. Expose arena state as an accessibility announcement.

---

## P3 — Polish and future-proofing

### 16. Persist calibration data
`BeaconCalibration` is created fresh on every launch. A calibration walk takes time — losing it on force-quit is a poor experience.

**Fix:** Encode to JSON and save to `UserDefaults` or a file after each calibration run. Load on startup.

### 17. Disable idle timer during rides
The screen will auto-lock during a 10–15 minute ride. The `ArenaView` becomes useless.

**Fix:** Set `UIApplication.shared.isIdleTimerDisabled = true` when a ride starts; restore on stop.

### 18. Haptic feedback
For riders who cannot look at the screen, haptic feedback via `UIImpactFeedbackGenerator` at movement triggers provides a valuable secondary cue alongside TTS.

### 19. Simulator mock doesn't follow the test path
The mock loops through perimeter letters at a fixed interval and never visits centerline letters (X, D, G). Testing announcement logic requires hardware.

**Fix:** Add a test-path simulation mode that walks through the movement locations of the active `DressageTest` in sequence.

### 20. No unit tests
The trilateration solver, motion filter, bilateral estimate, `BeaconCalibration.estimatedDistance`, and movement trigger logic are pure or near-pure functions. A test target would catch regressions during field tuning.

---

## Summary table

| # | Area | Priority | Effort |
|---|------|----------|--------|
| 1 | Wire DressageTest to announcements | P0 | Large |
| 2 | Stop ranging on view disappear | P0 | Trivial |
| 3 | CalibrationView timer / ViewModel | P0 | Small |
| 4 | Add `audio` background mode | P0 | Trivial |
| 5 | Look-ahead announcement timing | P1 | Medium |
| 6 | Expose velocity from PositionEngine | P1 | Trivial |
| 7 | Stale beacon eviction | P1 | Small |
| 8 | Fix MotionService main-thread hop | P1 | Trivial |
| 9 | SessionLogger async I/O | P1 | Small |
| 10 | Background auth UX | P1 | Small |
| 11 | RideSession class | P2 | Medium |
| 12 | Codable test types | P2 | Small |
| 13 | ShareLink replacement | P2 | Trivial |
| 14 | Type-safe calibration keys | P2 | Trivial |
| 15 | Accessibility | P2 | Medium |
| 16 | Persist calibration | P3 | Small |
| 17 | Idle timer | P3 | Trivial |
| 18 | Haptic feedback | P3 | Small |
| 19 | Test-path simulator | P3 | Small |
| 20 | Unit tests | P3 | Medium |
