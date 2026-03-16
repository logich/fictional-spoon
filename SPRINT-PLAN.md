# Dressage Caller — Development Plan

---

## Completed — Sprints 1 & 2 (March 2026)

All P0 bugs from `REVIEW.md` are resolved. The app builds, runs on device, and performs the core calling function.

| Sprint | Theme | Completed |
|--------|-------|-----------|
| P0 pre-work | Critical bugs | RideSessionController wired to movements, beacon ranging stops on dismiss, CalibrationViewModel timer fix, audio background mode |
| Sprint 1 | Ready to Ride Reliably | Stale beacon eviction, MotionService thread fix, idle timer, look-ahead timing, background auth UX banner, "test complete" announcement |
| Sprint 2 | Solid Foundation | `[ArenaLetter: Double]` calibration keys, BeaconCalibration persistence, Codable test types, SessionLogger async I/O, ShareLink, RideSession service refactor |

---

## Prerequisites Before Sprint 3 Field Testing

These must be resolved before any arena field testing of Sprint 3 features:

- [ ] Purchase 4 additional Kontakt Anchor Beacon 2 units (or production weatherproof equivalent) — 4 total in hand, **8 required**
- [ ] Run Beacon Diagnostic on device with all 8 beacons powered — record real major/minor values for each device ID
- [ ] Update `ArenaConfiguration` from 4-beacon placeholder to 8-beacon production config
- [ ] Run Sprint 1 & 2 verification checklist (`VERIFICATIONS.md`) once 8-beacon config is in place

---

## Sprint 3 — "Competition Day UX"
**Theme:** The ride experience from UX-FLOW.md §6–9. Bell, countdown, timing control, practice mode, movement preview. Makes it feel like a real caller.
**Field test:** Yes — first full competition-simulation ride.
**Effort:** Large (~2 weeks)

| Item | Source | Effort |
|------|--------|--------|
| Bell sound + 45-second countdown (speak "30 seconds", "15 seconds") before test | UX-FLOW §7 | M |
| Practice Mode toggle: no bell/countdown, pauses sequence on halt >5s | UX-FLOW §241 | M |
| Timing slider (Earlier/Later) on test-ready screen, persisted per arena ID | UX-FLOW §6 | M |
| "Preview Movements" scrollable list view (sequence, location, directive text, gait badge) | UX-FLOW §6 | S |
| Haptic feedback (`UIImpactFeedbackGenerator`) at each movement trigger | REVIEW #18 P3 | XS |
| Import dressage test from URL: PDF download → PDFKit text extraction → parser → review screen → save | Test import | M |
| `TestLibrary`: persist imported tests as JSON in `Documents/tests/` | Test import | XS |

**Dependencies:**
- `RideSession` (Sprint 2) required for timing slider to cleanly set `triggerDistance`
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
| App icon redesign — current placeholder insufficient for App Store | Design | M |
| Camera OCR import: photograph printed test → Vision `VNRecognizeTextRequest` → same parser pipeline | Test import | M |

**Dependencies:**
- Arena profiles require `BeaconCalibration` Codable + persisted (Sprint 2 ✅)
- Post-ride summary requires `RideSession` (Sprint 2 ✅) accumulating gait time during ride
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
3. Home screen shows last-used test highlighted; beacon status "8/8 connected" or warning
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
- Live Activity needs `ActivityKit` widget extension in `project.yml` + `DressageTest` Codable (Sprint 2 ✅)
- Live Activity data sourced from `RideSession` (Sprint 2 ✅)
- Onboarding saves result to named arena profile (Sprint 4)
- Path replay uses `SessionLogger` data keyed to a `RideSession` + post-ride summary (Sprint 4)
- Test target added to `project.yml`

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
Sprint 1: (complete) velocity → look-ahead
Sprint 2: (complete) [ArenaLetter] → persist calibration
                     Codable → arena profiles (S4), Live Activity (S5)
                     RideSession → timing slider (S3), practice mode (S3), post-ride (S4), Live Activity (S5)
Sprint 3: RideSession(S2✅) → timing slider, practice mode
Sprint 4: Codable+persist(S2✅), RideSession(S2✅) → arena profiles, post-ride
          arena profiles(S4) → onboarding(S5)
          post-ride(S4) → path replay(S5)
Sprint 5: widget extension → Live Activity, Watch (Sprint 6)
```

---

## Post-Sprint 5 — Production Roadmap

### App Store Submission (after Sprint 5)
- Privacy policy (location data usage — ranges beacons, no GPS, no cloud upload)
- App Store screenshots: all required device sizes, including iPad if supported
- App Review notes: explain the Bluetooth/location permissions usage clearly
- Entitlements review: Background Modes (audio, location, bluetooth-central), ActivityKit
- TestFlight external testing before full submission

### Sprint 6 — Apple Watch Complication
Natural extension of Sprint 5 widget work. The `ActivityKit` attribute types and Live Activity infrastructure are already in place. Watch complication shows current movement number and next text on the watch face — useful for riders who prefer a glance over reaching for the phone.

### Sprint 7 — Recorded Human-Voice Caller
Premium feature. Pre-recorded human voice files for each movement, selectable as an alternative to TTS. Requires:
- Recording session with a native English-speaking caller
- File storage strategy (bundled vs. downloadable)
- Business model decision (one-time IAP vs. subscription)

### Sprint 8 — Off-Course Assist
Detect when the rider is significantly off the expected path and offer a verbal re-orientation cue ("You're approaching E — your next movement is at C, tracking left"). Needs field data from real test rides (Sprint 3+) to design a non-annoying trigger threshold.

### Sprint 9 — USDF Partnership / Test Catalog
Copyright-safe path to providing test content without requiring every user to import PDFs:
- Contact USDF (copyright@usdf.org) about linking policy and potential data partnership
- Contact WDAA for their Website Link Usage Policy
- Explore app-level "guided download" that deep-links to the official PDF and auto-imports on return

### Ongoing / Deferred
- **Stride-based timing calibration per horse** — per-horse stride length from `GaitProfile` (Sprint 4 data model) refines look-ahead distance; accumulates over multiple rides
- **Multi-arena auto-detect by beacon UUID** — if multiple arenas are configured, detect which arena the rider is in by which beacon cluster responds
- **Full 20×60m arena support** — all 12 letters beaconed; tested on Linda's full-size arena configuration

---

## Copyright Note

**Bundled test data is not possible.** USDF, USEF, FEI, and WDAA tests are copyrighted regardless of format (PDF, XML, text). The import flow (Sprint 3/4) is the only legal path for providing test content. Users obtain PDFs from their governing body; the app parses locally (fair use). The app must never host, cache, or redistribute test content on any server.
