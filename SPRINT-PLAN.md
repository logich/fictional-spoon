# Dressage Caller — Unified Project Sprint Plan

**Created:** 2026-03-09
**Context:** All P0 bugs from REVIEW.md are resolved. Kontakt.io beacons arriving for comparison testing. Goal: take the app from working prototype to competition-ready product, sprint by sprint.

---

## Completed (P0 — Done This Session)
- ✅ RideSessionController wired to movement announcements
- ✅ Beacon ranging stops on dismiss
- ✅ CalibrationViewModel (timer captures reference type)
- ✅ Audio background mode in UIBackgroundModes
- ✅ Voice picker with premium/enhanced auto-selection
- ✅ Movement path drawn on arena canvas (line, circle, track)
- ✅ Progress bar fills to 100% on test complete
- ✅ End Ride button resets test

---

## Sprint 1 — "Ready to Ride Reliably"
**Theme:** Close the remaining gaps that cause incorrect behaviour on a real ride.
**Field test:** Yes — take Kontakt.io beacons to barn after this sprint.
**Effort:** Medium (~1 week)

| Item | Source | Effort |
|------|--------|--------|
| Stale beacon eviction: filter `lastSeen` > 3s in `BeaconRangingService.didRange` | REVIEW #7 P1 | S |
| MotionService: remove redundant `Task @MainActor` in CMMotionManager callback | REVIEW #8 P1 | XS |
| Idle timer disabled when ride starts, restored on End Ride | REVIEW #17 P3 | XS |
| Look-ahead timing: velocity-based ETA in `RideSessionController.checkAndAnnounce` | REVIEW #5 P1 | M |
| Background auth UX: banner + Open Settings when `.authorizedWhenInUse` in `RideView` | REVIEW #10 P1 | S |
| "Test complete" spoken announcement + chime after final movement | UX-FLOW §9 | S |

**Dependencies:**
- `PositionEngine.velocity` is already `private(set)` — look-ahead can use it directly
- Stale eviction and idle timer are independent, can land in any order

**Key files:**
- `DressageCaller/Services/BeaconRangingService.swift` — stale eviction
- `DressageCaller/Services/RideSessionController.swift` — look-ahead timing, test complete
- `DressageCaller/Services/MotionService.swift` — thread hop fix
- `DressageCaller/Views/RideView.swift` — idle timer, auth banner

**Verification:**
1. Remove power from one beacon mid-walk → drops from canvas within 3s
2. Ride at trot → movements called ~2 strides before the letter
3. Deny Always location → red banner appears with Open Settings link
4. Screen stays on for 10+ minutes during active ride
5. After final movement → app speaks "Test complete" and plays chime

---

## Sprint 2 — "Solid Foundation"
**Theme:** Architectural cleanup that all persistence, post-ride, and Live Activity features depend on. No new UX — behaviour identical before and after.
**Field test:** Yes — regression test only.
**Effort:** Medium-Large (~1–2 weeks)

| Item | Source | Effort |
|------|--------|--------|
| `BeaconCalibration.readings` → `[ArenaLetter: Double]` (type-safe keys) | REVIEW #14 P2 | XS |
| Persist `BeaconCalibration` to UserDefaults as JSON (load on startup) | REVIEW #16 P3 | S |
| `DressageTest`, `Movement`, `MovementLocation`, `PathShape` Codable conformance | REVIEW #12 P2 | S |
| `SessionLogger` async I/O: buffer rows, flush every 3s on background actor | REVIEW #9 P1 | S |
| Replace `ShareSheet` with `ShareLink` | REVIEW #13 P2 | XS |
| Extract `RideSession: @Observable` class owning all ride services; pass into `RideView` | REVIEW #11 P2 | M |

**Dependencies (must sequence in order):**
1. `[ArenaLetter: Double]` (#14) before persistence (#16) — changes serialisation format
2. Codable (#12) before arena profiles (Sprint 4) and Live Activity (Sprint 5)
3. `RideSession` (#11) before timing slider and practice mode (Sprint 3)

**Key files:**
- `DressageCaller/Models/BeaconCalibration.swift` — key type + persistence
- `DressageCaller/Models/DressageTest.swift` — Codable
- `DressageCaller/Models/SampleTests.swift` — update for Codable
- `DressageCaller/Services/SessionLogger.swift` — async I/O
- `DressageCaller/Views/RideView.swift` — receives RideSession instead of creating services
- `DressageCaller/Views/HomeView.swift` — creates and owns RideSession
- `DressageCaller/Views/ShareSheet.swift` — delete; replace with ShareLink inline

**Verification:**
1. Complete calibration walk → force-quit → relaunch → calibration data restored
2. Navigate in/out of ride three times → no service state leaks, ranging restarts cleanly
3. `JSONEncoder().encode(SampleTests.trainingLevel1)` round-trips without loss
4. Zero new Swift 6 strict-concurrency warnings

---

## Sprint 3 — "Competition Day UX"
**Theme:** The ride experience from UX-FLOW.md §6–9. Bell, countdown, timing control, practice mode, movement preview. This is what makes it feel like a real caller.
**Field test:** Yes — first full competition-simulation ride.
**Effort:** Large (~2 weeks)

| Item | Source | Effort |
|------|--------|--------|
| Bell sound + 45-second countdown (speak "30 seconds", "15 seconds") before test | UX-FLOW §7 | M |
| Practice Mode toggle: no bell/countdown, pauses sequence on halt >5s | UX-FLOW §241 | M |
| Timing slider (Earlier/Later) on test-ready screen, persisted per arena ID | UX-FLOW §6 | M |
| "Preview Movements" scrollable list view (sequence, location, directive text, gait badge) | UX-FLOW §6 | S |
| Haptic feedback (`UIImpactFeedbackGenerator`) at each movement trigger | REVIEW #18 P3 | XS |

**Dependencies:**
- `RideSession` (#11, Sprint 2) required for timing slider to cleanly set `triggerDistance`
- Practice mode pause uses `MotionService.motionState` — available via `RideSession`
- Bell audio: bundle a `.caf` file; play with `AVAudioPlayer` before handing off to `AVSpeechSynthesizer`

**Key files:**
- `DressageCaller/Services/RideSessionController.swift` — bell/countdown, practice pause, timing offset
- `DressageCaller/Views/HomeView.swift` — timing slider, mode toggle, Preview Movements navigation
- New: `DressageCaller/Views/PreviewMovementsView.swift`
- New: `DressageCaller/Resources/bell.caf`

**Verification:**
1. Competition mode → bell sounds → 30s/15s spoken → rider enters at A → first call triggers
2. Practice mode → no bell → halt for 6s → calling pauses → resume → picks up same movement
3. Move slider to Earlier → movement called noticeably before letter vs centre position
4. Slider position restored after relaunch
5. Preview Movements shows all 17 movements with correct text and gait badges
6. Device vibrates briefly at each movement trigger

---

## Sprint 4 — "Home Screen and Profiles"
**Theme:** Pre-ride flow from UX-FLOW.md §5. My Tests list, arena profiles, horse profiles, post-ride summary. A returning rider is ready to ride in one tap.
**Field test:** Yes — first multi-session test with saved arena calibration.
**Effort:** X-Large (~2 weeks; consider splitting horse profiles to Sprint 5 if needed)

| Item | Source | Effort |
|------|--------|--------|
| Home screen redesign: "My Tests" list, last-used highlighted, beacon status count | UX-FLOW §5 | L |
| Named arena profiles: multiple arenas with saved calibration, timing preference | UX-FLOW §253 | M |
| Horse profiles: multiple horses, stored, selectable on home screen | UX-FLOW §302 | M |
| Post-ride summary: duration, gait time breakdown, movements called count | UX-FLOW §10 | M |
| Simulator: mock follows `DressageTest.movements` in sequence (not perimeter loop) | REVIEW #19 P3 | S |
| Accessibility: arena canvas labels, control button labels, beacon status accessibility | REVIEW #15 P2 | M |

**Dependencies:**
- Arena profiles require `BeaconCalibration` Codable + persisted (Sprint 2)
- Post-ride summary requires `RideSession` (Sprint 2) accumulating gait time during ride
- Home screen replaces `HomeView.swift` entirely — implement as new file, swap at app root

**Key files:**
- `DressageCaller/Views/HomeView.swift` — full rewrite
- New: `DressageCaller/Views/PostRideSummaryView.swift`
- New: `DressageCaller/Models/ArenaProfile.swift`
- New: `DressageCaller/Models/HorseProfile.swift`
- `DressageCaller/Services/BeaconRangingService.swift` — simulator path fix
- `DressageCaller/Views/ArenaView.swift` — accessibility labels

**Verification:**
1. Two arena profiles with different calibrations — switching retains each calibration independently
2. Two horse profiles — horse name shows correctly in RideView per selection
3. Home screen shows last-used test highlighted; beacon status "4/4 connected" or warning
4. Complete a test → post-ride summary appears automatically with correct gait breakdown
5. Simulator: mock rider triggers movement announcements in correct sequence
6. VoiceOver: arena canvas announces nearest letter; all buttons have labels

---

## Sprint 5 — "Polish, Tests, and Live Activity"
**Theme:** App Store quality. Lock screen Live Activity, first-time onboarding, unit tests, path replay.
**Field test:** Yes — submit to TestFlight.
**Effort:** X-Large (~2 weeks)

| Item | Source | Effort |
|------|--------|--------|
| Lock screen Live Activity: movement number + next movement text | UX-FLOW §8 | L |
| Unit tests: trilateration, motion filter, path loss, movement trigger | REVIEW #20 P3 | M |
| First-time onboarding: welcome, beacon placement guide, audio-guided calibration walk | UX-FLOW §1–3 | L |
| Path replay: rider's actual path on arena canvas, gait-colored, tappable markers | UX-FLOW §10 | M |

**Dependencies:**
- Live Activity needs `ActivityKit` widget extension in `project.yml` + `DressageTest` Codable (Sprint 2)
- Live Activity data sourced from `RideSession` (Sprint 2 #11)
- Onboarding saves result to named arena profile (Sprint 4)
- Path replay uses `SessionLogger` data keyed to a `RideSession` + post-ride summary (Sprint 4)
- Test target added to `project.yml`; pure functions in `PositionEngine` and `BeaconCalibration` extracted for testing

**Key files:**
- New widget extension target in `project.yml`
- New: `DressageCallerWidget/` — ActivityKit attributes + Live Activity view
- New: `DressageCaller/Views/OnboardingView.swift`
- `DressageCaller/Views/PostRideSummaryView.swift` — add path replay canvas
- New: `DressageCallerTests/` — test target

**Verification:**
1. Start test, lock screen → Live Activity shows movement number + next text, updates as movements progress
2. `xcodebuild test` passes: trilateration within 0.5m of ground truth, path loss within 5%
3. Fresh install → onboarding appears → complete calibration walk → arena profile saved → home screen
4. Post-ride summary: tap a movement marker on path replay → shows directive text and timestamp
5. App submits to TestFlight cleanly

---

## Sprint Dependency Chain

```
Sprint 1: velocity(done) → look-ahead
Sprint 2: [ArenaLetter] → persist calibration
          Codable → arena profiles (S4), Live Activity (S5)
          RideSession → timing slider (S3), practice mode (S3), post-ride (S4), Live Activity (S5)
Sprint 3: RideSession(S2) → timing slider, practice mode
Sprint 4: Codable+persist(S2), RideSession(S2) → arena profiles, post-ride
          arena profiles(S4) → onboarding(S5)
          post-ride(S4) → path replay(S5)
Sprint 5: widget extension → Live Activity, Watch (future)
```

---

## Deferred (Post-Sprint 5)
- Apple Watch complication (shares widget extension from Sprint 5 — natural Sprint 6)
- Off-course assist / re-orientation (UX-FLOW design decision: default off, needs field data first)
- Recorded human caller voices premium feature (UX-FLOW §296)
- Stride-based timing calibration per horse (UX-FLOW §284)
- Multi-arena auto-detect by beacon UUID (UX-FLOW §253)
