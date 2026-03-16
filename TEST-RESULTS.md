# Test Results

This document records the outcomes of actual testing sessions. For the pre-test protocol (what to run), see `TEST-PLAN.md`. For the code-level verification checklist, see `VERIFICATIONS.md`.

---

## Beacon Field Test — March 2026

### Setup
- **Date**: 2026-03-09
- **Hardware**: 4× Kontakt Anchor Beacon 2, USB-powered
- **Environment**: Indoor arena, **metal building** (Linda's barn)
- **Beacon placement**: Cardinal letters only — A, E, C, B
- **Phone**: iPhone (pocket position during mounted tests)
- **Software**: `ArenaConfiguration.prototype` with corrected Kontakt UUID (`F7826DA6-4FA2-4E98-8024-BC5B71E0893E`)

Raw sensor logs are in `field-data/2026-03-indoor-metal/`. See `field-data/README.md` for column descriptions and test protocol details.

### Results

#### UUID Fix Verified
The app was previously hardcoded to an Estimote UUID. After correcting to the Kontakt factory default, all 4 beacons were detected via CoreBluetooth (`FE6A` service scan) and CoreLocation (iBeacon ranging). BLE device IDs confirmed: C01U, U01V, P01V, J01U.

#### 4-Beacon Trilateration — Insufficient
**Finding: 4 beacons at cardinal letters (A, E, C, B) are not sufficient for reliable position detection in this metal building.**

The metal structure produces multipath reflections that make RSSI readings highly variable. With only 4 beacons, there are large coverage gaps (the corners and intermediate letters K, H, M, F have no nearby anchor). The combination of coverage gaps and noisy readings made position estimates unstable.

#### Gaussian Smoothing — Rejected
Applied Gaussian smoothing to the position estimates to reduce noise. **Result: wild oscillation.** Gaussian methods amplified the underlying noise rather than suppressing it in this environment. The position dot jumped erratically even when the rider was standing still.

#### Motion-Gating — Adopted
**Fix implemented**: position is only updated when the iPhone's measured speed (from CoreMotion) indicates the phone is actually moving. When the phone is stationary, the last valid position is held.

**Result**: eliminated phantom jitter when the rider is halted or walking slowly. Position updates are now gated to genuine motion events.

**Current algorithm status**: motion-gating is the production baseline. It is a known-good floor, not a temporary fix. Future algorithm improvements (Kalman filter, particle filter, ML-based) should be validated against the raw field-data logs and must outperform motion-gating before being adopted.

### Decision: 8 Beacons Required

One beacon at each of the 8 perimeter letters (A, K, E, H, C, M, B, F) is required for reliable operation in this metal building. This:
- Eliminates the large coverage gaps between cardinal letters
- Provides better trilateration geometry (more ranging measurements per update)
- Reduces the weight of any single noisy reading

**Current inventory**: 4 Kontakt Anchor Beacon 2 units in hand. **4 more must be purchased** before production-quality testing can continue.

### iBeacon Major/Minor Values
Not yet recorded. Requires running the Beacon Diagnostic screen with all beacons powered. The `ArenaConfiguration.prototype` still uses placeholder values (major=1, minor=0–3). This must be resolved before any 8-beacon configuration can be built.

---

## Sprint 1 & 2 Code Verifications — March 2026

All Sprint 1 and Sprint 2 code is complete and builds cleanly. **Device-on-hardware verification is pending** — requires all 8 beacons configured with real major/minor values.

### Sprint 1 — Ready to Ride Reliably
- [ ] Remove power from one beacon mid-walk → drops from canvas within 3s
- [ ] Ride at trot → movements called ~2 strides before the letter
- [ ] Deny Always location → red banner appears with Open Settings link
- [ ] Screen stays on for 10+ minutes during active ride
- [ ] After final movement → app speaks "Test complete" and plays chime

### Sprint 2 — Solid Foundation
- [ ] Complete calibration walk → force-quit → relaunch → calibration data restored
- [ ] Navigate in/out of ride three times → no service state leaks, ranging restarts cleanly
- [ ] `JSONEncoder().encode(SampleTests.trainingLevel1)` round-trips without loss
- [ ] Zero new Swift 6 strict-concurrency warnings

---

## Upcoming Test Priorities

### Before Sprint 3 testing can begin:
1. **Purchase 4 additional Kontakt Anchor Beacon 2 units** (or production-grade weatherproof equivalent)
2. **Discover major/minor values**: power on all 8 beacons, open Beacon Diagnostic, record major/minor for each BLE device ID → letter assignment
3. **Update `ArenaConfiguration`**: replace `prototype` placeholder with real 8-beacon production config

### Once 8-beacon config is in place:
4. **Sprint 1 & 2 verification session**: run all checklist items above on device at the barn
5. **Phase 1 test protocol** (TEST-PLAN.md): static accuracy at each letter, walk-through detection, mounted ride at walk and trot
6. **Timing calibration**: tune the look-ahead trigger distance for Linda's gait profile in this arena

### Algorithm research (lower urgency):
- Evaluate Kalman filter on the `field-data/` logs — may outperform motion-gating for in-motion accuracy
- Consider whether a particle filter is worth the complexity given the constrained arena geometry
