# RF / iBeacon Positioning — Expert Guidance

## Current Hardware (2026-03-09)
- 4 beacons: A (10,0), E (0,30), C (10,60), B (20,30) — diamond layout
- Beacon B is different hardware (ESP32 vs Flipper Zero), ~6dB weaker TX power than A/C/E
- Arena: 20×60m standard dressage arena inside a metal barn (heavy multipath/reflection)

## Field Test Results (2026-03-09)
- Ride duration: 189s. E beacon present only t=76s–144s (36% of ride) — power issue, not placement
- Per-beacon accuracy (CoreLocation `accuracy` field):
  - A: avg 14.1m, 75% of readings >10m
  - B: avg 23.1m, 81% of readings >10m (hardware TX power problem)
  - C: avg 15.1m, 74% of readings >10m
  - E: avg 5.1m, 14% of readings >10m (best performer)
- Confidence: 639/640 rows "weak" — position never trustworthy
- Positioning bore almost no relation to actual position in arena

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

### Step 2 — Replace trilateration with proximity-weighted centroid (next code sprint)
- Do NOT use `accuracy` field for distance
- Use smoothed RSSI directly as proximity weights: `weight = 10 ^ ((RSSI + 50) / 20)`
- Weighted centroid of beacon positions using these weights
- Add per-beacon exponential moving average RSSI smoothing: alpha=0.3, updated each ranging callback
- Add letter-change hysteresis: require new letter dominant for 2–3 consecutive seconds before announcing
- Note: previous weighted centroid collapsed to centreline — this was because only centreline beacons existed; with A/E/C/B the side beacons will pull toward walls

### Step 3 — Order 4 corner beacons (K, F, H, M)
- Target: 8 beacons total at A, K, E, F, C, M, B, H
- 8-beacon layout: avg 7.4m distance to nearest beacon, 15.6m maximum (vs 26m for 4-corner)
- Provides redundancy: any 2 beacon dropouts still leave 6 usable
- B corner placement: doesn't matter which corner — TX power mismatch affects all corners equally

### Step 4 — RSSI Fingerprinting (after 8 beacons)
- During calibration: walk to each letter position, record 10s of RSSI from all 8 beacons
- Store mean RSSI vector per letter as fingerprint
- At ride time: compare smoothed RSSI vector to all fingerprints (Euclidean distance in RSSI-space)
- Closest fingerprint = rider's zone
- Naturally captures multipath and metal barn effects — no physics model needed
- Calibration cost: ~5 min (stand 10s at each of 12 letters)
- Calibrate at phone height matching mounted riding height (~1.5–2m), not standing height

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

## Files to Modify for Algorithm Change
- `DressageCaller/Services/PositionEngine.swift` — replace Gauss-Newton with weighted centroid
- `DressageCaller/Services/BeaconRangingService.swift` — add per-beacon RSSI EMA smoothing
- `DressageCaller/Models/BeaconCalibration.swift` — extend to store fingerprint vectors per letter
- `DressageCaller/Models/ArenaConfiguration.swift` — add corner beacon mappings when hardware arrives
