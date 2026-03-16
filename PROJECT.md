# Dressage Caller

## Problem

Dressage riders must memorize complex test patterns — sequences of 15–20 movements performed at specific lettered positions in a standardized arena. Forgetting a movement mid-test costs points at competitions and breaks concentration during practice. A human "caller" reads each movement aloud as the rider approaches, but:

- Callers aren't always available for solo practice sessions
- Family members who call often get the timing wrong
- Remote coaches on video calls have audio lag and are focused on training, not calling
- Existing caller apps require the rider to tap or say "next" — that's not hands-free and isn't realistic practice

## Solution

An iOS app that automatically calls the test. The app tracks the rider's position in the arena using BLE beacons mounted at the arena letters and announces the next movement through Bluetooth headphones — no manual interaction required during the ride.

## Target User

**Linda** — mid-50s, 30+ years of experience, USDF traditional dressage and Western Dressage, Training through Second Level. Rides 5–6 days a week at her private barn. Outdoor 20×60m arena under a metal roof. Already uses Beats wireless headphones and a Pivo auto-tracking camera. Zero tolerance for setup friction or in-ride failures.

Full persona: see `PERSONA.md`.

**Use case**: Practice only. USDF/USEF rules prohibit electronic devices (earpieces, phones) during competition. This app is a training tool that builds test memory through repetition — not a competition-day device.

## Current Status (March 2026)

The app is working and has been field-tested. **Sprints 1 and 2 are complete.**

### What the app can do today
- Range 4 iBeacons via CoreLocation and estimate rider position via trilateration
- Draw the rider's estimated position as a dot on an arena canvas in real time
- Load a dressage test (Training Level Test 1 sample), display all movements, and advance through the sequence as the rider approaches each letter
- Announce each movement via TTS (AVSpeechSynthesizer) with look-ahead timing (fires before the letter based on velocity)
- Classify gait (halt/walk/trot/canter) via phone accelerometer
- Run in the background with the screen locked; disable the idle timer during rides
- Guided beacon calibration walk (RSSI reference capture at each letter)
- Persist calibration data across launches
- Voice picker (premium/enhanced voices auto-selected)
- Session logging (CSV export)

### What's not yet built
- Bell/countdown, practice mode, timing slider (Sprint 3)
- Test import from PDF or camera (Sprint 3)
- Named arena/horse profiles (Sprint 4)
- Post-ride summary and path replay (Sprint 4)
- Lock screen Live Activity (Sprint 5)
- First-time onboarding (Sprint 5)
- Unit tests (Sprint 5)

## Hardware

### Beacons

**Required for production**: 8× BLE beacons — one at each perimeter letter of a 20×40m small arena (A, K, E, H, C, M, B, F). A 20×60m full arena requires 12.

**In hand**: 4× Kontakt Anchor Beacon 2 (USB-powered, used for initial prototype testing)

**Why 8 and not 4**: Field tests in March 2026 inside a metal building showed that 4-beacon trilateration (cardinal letters A, E, C, B only) produces too much position noise in a metal structure due to multipath reflections. 8 beacons covering all perimeter letters give denser coverage and better trilateration geometry, reducing the impact of any single noisy reading. See `TEST-RESULTS.md` and `field-data/` for details.

**iBeacon UUID**: `F7826DA6-4FA2-4E98-8024-BC5B71E0893E` — Kontakt factory default, confirmed correct

**Major/minor values**: Not yet recorded. Must run the Beacon Diagnostic screen on a physical device with beacons powered. Currently placeholders in `ArenaConfiguration.prototype`.

**Recommended production beacon**: BeaconTrax Trax10234 or equivalent (IP68+, -40°C to 85°C, replaceable battery, shock-resistant). See `RESEARCH.md` for hardware comparison table. The Kontakt Anchor Beacon 2 units in hand are USB-powered development hardware, not weatherproof.

### Phone & Audio

- iPhone in rider's jacket pocket during rides
- Beats wireless headphones (or any Bluetooth audio output)
- No additional hardware required

## Arena Environment

Linda's arena is **outdoor 20×60m with a metal building** (covered but sides open or partially open). The metal structure is the primary source of BLE multipath noise. Algorithm design must assume this environment, not an open-field baseline.

## Data Model

Full model: see `DATA-MODEL.md`.

Summary of implemented entities:
- `DressageTest` / `Movement` / `MovementLocation` / `PathShape` — fully implemented and Codable
- `ArenaLetter` / `ArenaSize` / `ArenaConfiguration` / `BeaconMapping` — implemented
- `RideSession` / `PositionSample` / `MovementEvent` — implemented
- `BeaconCalibration` — implemented and persisted
- `Rider` / `Horse` / `GaitProfile` — **planned, not yet implemented**

## Open Questions

1. **Major/minor beacon values** — must be read from powered hardware before any production configuration is possible
2. **4 additional beacons** — purchasing 4 more Kontakt Anchor Beacon 2 units (or switching to a weatherproof production model) is the next hardware step
3. **Letter post mounting** — permanent mount solution for 8 beacons at arena letter boards (Linda wants one-time setup, no re-pairing)
4. **Timing calibration** — the look-ahead trigger distance needs per-arena, per-gait tuning once 8-beacon testing begins
5. **Full-arena test** — all testing to date has been in a 20×60m arena; the small 20×40m test arena letters are closer together (12–14m vs. 6m), which may require beacon spacing adjustments

## Key Documents

| File | Contents |
|------|----------|
| `PERSONA.md` | Full user persona for Linda |
| `DATA-MODEL.md` | Complete data model with implementation status |
| `RESEARCH.md` | Competitive landscape, competition rules, positioning tech, beacon hardware options |
| `UX-FLOW.md` | Full UX flow from first launch through post-ride summary |
| `BEACONS.md` | Beacon hardware, UUID history, diagnostic tool, field test findings |
| `TEST-PLAN.md` | Prototype validation test protocol (Phases 1–4) |
| `TEST-RESULTS.md` | Actual test outcomes and algorithm findings |
| `SPRINT-PLAN.md` | Development plan — completed sprints, active forward plan, post-Sprint 5 roadmap |
| `VERIFICATIONS.md` | Sprint verification checklist |
| `REVIEW.md` | iOS code review (all P0–P1 issues resolved in Sprints 1–2) |
| `field-data/` | Raw BLE/IMU sensor logs from March 2026 indoor field tests |
