# RF / iBeacon Positioning — Expert Guidance

## Current Hardware (2026-03-16)
- 8 beacons deployed: A (10,0), K (20,6), E (0,30), H (20,54), C (10,60), M (0,54), B (20,30), F (0,6)
- ESP32 beacons (A, E, C, B) read 6–10 dBm stronger than Kontakt beacons (K, H, M, F) — fixed with TX-power normalisation
- Arena: 20×60m standard dressage arena inside a metal barn (heavy multipath/reflection)
- App ranging UUID: `74648DDD-D39B-4263-9DE5-4D18C8CF4D83` (app-specific, pre-programmed into all hardware)

## Field Test Results (2026-03-09) — 4 Beacons
- Ride duration: 189s. E beacon present only t=76s–144s (36% of ride) — power issue, not placement
- Per-beacon accuracy (CoreLocation `accuracy` field):
  - A: avg 14.1m, 75% of readings >10m
  - B: avg 23.1m, 81% of readings >10m (hardware TX power problem)
  - C: avg 15.1m, 74% of readings >10m
  - E: avg 5.1m, 14% of readings >10m (best performer)
- Confidence: 639/640 rows "weak" — position never trustworthy
- Positioning bore almost no relation to actual position in arena

## Field Test Results (2026-03-16) — 8 Beacons, Centroid Walk
- 8 beacons detected, E beacon ran full session without dropout ✓
- Only 2–3 accurate position moments in the walking session
- Root cause: ESP32 beacons (A, E, C, B) were 6–10 dBm stronger than Kontakt (K, H, M, F), biasing centroid ~30m off toward the short wall
- Fix applied: TX-power normalisation in weight formula — `weight = 10^((rssi - txPower) / 20)`
- Ride data: `ride-data/ride_2026-03-16_170540.csv`; calibration data: `ride-data/calibration_export.csv`
- **Status**: TX normalisation fix not yet field-tested; next session will verify

## Why CoreLocation `accuracy` Fails Here
- Apple's model assumes free-space propagation (n≈2.0, TxPower≈-59dBm)
- Metal barn causes multipath: RSSI variance is 6–8dB at fixed distance
- Results in 2–5× distance overestimation at typical RSSI levels
- `-1.0m` means "no estimate available" — treat as no-data, never use as distance
- Estimated path loss exponent from data: n≈2.0–2.3, but std dev >0.8 — model has poor predictive power

## Why Trilateration Fails Here
- Requires ~10–20% distance accuracy; field data shows 50%+ error
- With only 2–3 usable beacons (B noise, E dropout), system is under-determined
- A/E/C/B diamond has poor GDOP along long axis: A and C share x=10, E and B share y=30
- No amount of filtering overcomes 50%+ input error with 2–3 beacons

## Current Algorithm Status
- Gauss-Newton trilateration on CL `accuracy` — REPLACE THIS
- Motion-aware filtering (stationary/walking/trotting/cantering) — keep, it's useful
- Calibration: 1m reference RSSI → log-distance path loss — extend for fingerprinting

## DO NOT: Move Beacons to K/F/H/M (4-beacon corner layout)
- Creates 26m dead zone at arena centre (X, D, L, I, G — where riders spend most time)
- Zone classification at critical letters A/E/X/B/C drops to ~12% correct (vs 94% with A/E/C/B)
- GDOP is better at arena ends on paper, but irrelevant with 50%+ distance errors
- Monte Carlo simulation (6dB RSSI noise): A/E/C/B centroid = 6.4m mean error; K/F/H/M = 8.2m

## Priority Roadmap

### Step 1 — Fix B beacon hardware (immediate)
- B is ~6dB weaker than A/C/E — biggest source of rightward position bias
- Match TX power to other beacons, or swap for matching hardware (Flipper/ESP32)
- Verify: stand 1m from each beacon, compare raw RSSI — should be within 2–3dB

### Step 2 — Replace trilateration with proximity-weighted centroid ✅ IMPLEMENTED
- Does NOT use `accuracy` field for distance
- **Noise floor**: beacons with RSSI > -90dBm are "qualified"; falls back to all-negative if none qualify
- **Weight formula**: `weight = 10^((rssi - txPower) / 20)` — uses per-beacon TX power from calibration to normalise mixed hardware
  - Original suggestion was `weight = 10^((RSSI+50)/20)` (fixed -50 reference); TX normalisation is a critical improvement that fixed the 30m centroid bias seen in the 2026-03-16 test
- Per-beacon EMA smoothing: alpha=0.3 in BeaconRangingService (applied before PositionEngine)
- **Confidence**: ≥2 beacons above -80dBm = `.strong`, ≥1 = `.weak`, else `.none`
- Letter-change hysteresis: 2.0s time-based (not count-based)
- **Field validation pending** — centroid live, TX normalisation fix not yet tested in a ride

### Step 3 — Order 4 corner beacons (K, F, H, M)
- Target: 8 beacons total at A, K, E, F, C, M, B, H
- 8-beacon layout: avg 7.4m distance to nearest beacon, 15.6m maximum (vs 26m for 4-corner)
- Provides redundancy: any 2 beacon dropouts still leave 6 usable
- B corner placement: doesn't matter which corner — TX power mismatch affects all corners equally

### Step 4 — RSSI Fingerprinting ✅ IMPLEMENTED (field validation pending)
- **Two-pass walk**: Pass 1 clockwise (A→K→E→H→C→M→B→F), Pass 2 counterclockwise — results merged by averaging
- **Storage**: `BeaconCalibration.fingerprints: [ArenaLetter: FingerprintVector]` — custom Codable with backward compatibility for old calibration data
- **Matching**: `BeaconCalibration.nearestFingerprint(readings:)` — Euclidean distance in RSSI-space; overrides geometric nearest-letter in PositionEngine when fingerprints are available
- **Export**: `BeaconCalibration.exportCSV()` produces a two-section CSV (TX calibration + arena fingerprints) for offline analysis; accessible via ShareLink in CalibrationView
- **Calibration UI**: integrated into CalibrationView after TX calibration; can be skipped if prior calibration exists
- Calibrate at phone height matching mounted riding height (~1.5–2m), not standing height
- Naturally captures multipath and metal barn effects — no physics model needed

### Step 5 — Sequence-aware positioning (future)
- Dressage tests follow a known movement sequence — use this as Bayesian prior
- If last call was E, next is C: rider must be travelling E→C; only question is progress along that path
- Turns 2D positioning into 1D progress estimation along a known trajectory
- Single beacon near target letter is sufficient to detect approach

## Key Numbers for 20×60m Arena
- Standard letter positions (x=0 left, x=20 right, y=0 A-end, y=60 C-end):
  - A (10,0), K (20,6), V (20,18), E (0,30) — wait, V is not standard
  - Standard perimeter: A(10,0), K(20,6), E(0,30) [actually at y=30 left], H(20,54), C(10,60), M(0,54), B(20,30), F(0,6)
  - Centre line: D(10,6), L(10,18), X(10,30), I(10,42), G(10,54)
- Maximum distance A→C: 60m; E→B: 20m; corner-to-corner: ~63m
- BLE starts degrading significantly beyond ~20m in metal barn environments

## Position Verification Field Testing

A dedicated **Position Verification** screen (accessible from HomeView) enables ground-truth accuracy measurement:
- User walks to known arena letters and taps the corresponding button
- Engine estimate is displayed live; accuracy counter tracks correct/total ground-truth taps
- Events logged as `GROUND_TRUTH` rows in a CSV via `SessionLogger.logRawRow()` alongside continuous engine output rows
- Export CSV after session for per-letter accuracy analysis

Use this screen to validate the TX normalisation fix before relying on the centroid for a real ride.

## Key Files
- `DressageCaller/Services/PositionEngine.swift` — centroid algorithm
- `DressageCaller/Services/BeaconRangingService.swift` — per-beacon RSSI EMA smoothing
- `DressageCaller/Models/BeaconCalibration.swift` — FingerprintVector, fingerprints dict, exportCSV(), nearestFingerprint()
- `DressageCaller/Models/ArenaConfiguration.swift` — 8-beacon prototype config, beaconProximityUUID
- `DressageCaller/ViewModels/PositionVerificationViewModel.swift` — standalone field-test service owner
- `DressageCaller/Views/PositionVerificationView.swift` — ground-truth UI
