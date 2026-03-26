# Next Steps

## Immediate — Sprint 4: RF Positioning & 8 Beacons
This is the single largest blocker to a usable app. CL `accuracy` is unusable in the metal barn.

**Code items** — all implemented ✅:
1. ~~Implement proximity-weighted centroid in `PositionEngine`~~ ✅ — TX-power-normalised, -90dBm noise floor, 2.0s hysteresis
2. ~~Add per-beacon RSSI EMA (alpha=0.3) in `BeaconRangingService`~~ ✅
3. ~~Add letter-change hysteresis~~ ✅ — 2.0s time-based
4. ~~RSSI fingerprinting calibration walk~~ ✅ — two-pass (CW + CCW), FingerprintVector stored in BeaconCalibration
5. ~~Update `CalibrationView` / `CalibrationViewModel` for fingerprinting walk~~ ✅ — CSV export added
6. ~~Position Verification screen~~ ✅ — ground-truth tap logging, accuracy counter, CSV export (see rf-positioning.md)

**Field validation** (current priority):
- Run Position Verification walk to confirm TX normalisation fix — stand at each letter, tap button, check accuracy CSV
- Fingerprint walk — collect two-pass fingerprint data; verify nearestFingerprint() overrides improve accuracy

**Hardware items**:
- Fix B beacon TX power (~6dB weaker than others) — hardware fix needed
- E beacon power supply — ran full session 2026-03-16 without dropout ✅; monitor next session
- Deploy all 8 beacons for each ride

## Field Verification Pending — Sprint 3
Sprint 3 is code-complete (2026-03-10) but not yet verified in the arena:
- Competition mode bell/countdown
- Practice mode pause-on-halt
- Timing slider (Earlier/Later) and persistence
- Preview Movements view
- Haptic feedback

## Medium-term — Sprint 5: Home Screen and Profiles
- Home screen redesign: "My Tests" list, last-used highlighted, beacon status
- Named arena profiles: multiple arenas with saved calibration and timing preference
- Horse profiles: multiple horses, selectable on home screen
- Post-ride summary: duration, gait time breakdown, movements called count
- SwiftData migration: replace UserDefaults with SwiftData for arena profiles, horse profiles, ride sessions
- App icon redesign (current exists but needs App Store quality)

## Later — Sprint 6: Polish, Tests, and Live Activity
- Lock screen Live Activity (ActivityKit)
- First-time onboarding with audio-guided calibration walk
- Unit tests: centroid math, RSSI fingerprint matching, motion filter, movement trigger
- Path replay post-ride canvas
- TestFlight submission

## Completed (no longer action items)
- ~~Dressage test data model~~ — DressageTest, Movement, SampleTests
- ~~Setup flow~~ — HomeView with arena/horse/test config + CalibrationView
- ~~Gait detection~~ — MotionService classifies stationary/walking/trotting/cantering
- ~~PDF test parser~~ — PDFTestParser + TestLibrary + TestImportView
- ~~Practice vs competition mode~~ — bell/countdown, pause-on-halt
- ~~Movement preview~~ — PreviewMovementsView
- ~~Timing slider~~ — UserDefaults persistence per arena ID
