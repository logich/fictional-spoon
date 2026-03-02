# Test Plan — Prototype Validation

## Phase 1: Beacon Positioning Proof of Concept (CRITICAL PATH)

**Goal**: Prove that BLE beacons at arena letters can reliably detect which letter a rider is approaching.

### Hardware Needed
- 4× rugged BLE beacons (iBeacon compatible, IP67+)
  - Recommended: BeaconTrax Trax10234 or similar (~$30–50 each)
  - Total: ~$120–200
- iPhone 11 or later
- Access to a dressage arena (20×40m or 20×60m)
- Mounting supplies (zip ties or VHB tape for letter posts)

### Beacon Placement
Place beacons at the 4 cardinal arena letters:
```
        ┌──────── C ────────┐
        │                   │
        E                   B
        │                   │
        └──────── A ────────┘
```
These are the maximum distance apart (20m across, 40–60m long), so if ranging works at these positions, denser placement will only be better.

### Test App — Minimal Build
A single-screen iOS app that:
1. Ranges all 4 beacons continuously (CoreLocation iBeacon ranging)
2. Displays raw data: RSSI, estimated distance, proximity zone for each beacon
3. Computes estimated (x, y) position via weighted trilateration
4. Draws position as a dot on a simple arena rectangle
5. Announces "Approaching [letter]" via TTS when within threshold distance

### Test Protocol

#### Test 1.1: Static Accuracy
- Stand at each of the 4 beacon letters, record estimated position for 30 seconds
- Stand at centerline points (X, no beacon), record estimated position
- Stand at corners (no beacon), record estimated position
- **Pass criteria**: Estimated position within 5m of actual position at beacon letters, within 8m at non-beacon points

#### Test 1.2: Walk-Through Detection
- Walk the perimeter at normal walking pace
- Record which beacon the app identifies as "nearest" at each moment
- **Pass criteria**: Correctly identifies nearest beacon >90% of the time when within 10m of a letter

#### Test 1.3: Mounted Ride — Walk
- Ride the perimeter at walk (~1.5 m/s), phone in jacket pocket
- Record trigger events and actual position
- **Pass criteria**: "Approaching [letter]" announces within ±5m of each letter, no false triggers

#### Test 1.4: Mounted Ride — Trot
- Ride the perimeter at working trot (~3.4 m/s), phone in pocket
- Same recording as 1.3
- **Pass criteria**: Same as 1.3. Verify that faster speed doesn't cause missed triggers or announce too late.

#### Test 1.5: Centerline Test
- Ride down centerline (A to C) at walk and trot
- No beacons on centerline — position must be triangulated from side beacons
- **Pass criteria**: App can distinguish "rider is on centerline" from "rider is on the rail" at E/B latitude

#### Test 1.6: Indoor Arena (if available)
- Repeat tests 1.1–1.5 inside a metal-roofed arena
- Compare RSSI stability and position accuracy to outdoor results
- **Pass criteria**: Triggering still works, even if accuracy is degraded. Note how much worse.

### What We Learn
- Is 4-beacon accuracy sufficient, or do we need all 8–12 letters?
- How stable are RSSI readings outdoors vs indoors?
- What trigger distance works best at walk vs trot?
- Does phone-in-pocket affect ranging significantly vs phone-in-hand?

---

## Phase 2: Gait Detection Feasibility

**Goal**: Prove that phone accelerometer data can distinguish halt/walk/trot/canter from the rider's pocket.

### Hardware Needed
- Same iPhone from Phase 1
- Secure phone mount (armband, tight jacket pocket, or belt clip)
- Horse at walk, trot, and canter

### Test App — Data Recorder
A simple app that:
1. Records CoreMotion accelerometer + gyroscope at 50Hz
2. Timestamps each sample
3. Rider manually marks gait transitions (tap a button at each change) for ground truth labeling
4. Exports CSV for offline analysis

### Test Protocol

#### Test 2.1: Data Collection Rides
- 3–5 rides on at least 2 different horses
- Each ride: walk 2 min → trot 3 min → canter 2 min → walk 1 min → halt → repeat
- Phone secured in jacket pocket
- Rider taps gait buttons at transitions for labeling

#### Test 2.2: Offline Classification
- Analyze collected data for frequency and amplitude patterns per gait
- Train a simple classifier (decision tree or small neural net)
- **Pass criteria**: >85% accuracy distinguishing halt/walk/trot/canter on held-out data

#### Test 2.3: Stride Length Estimation
- From trot and canter segments, estimate stride count and length
- Compare to known values for the horse (or video count)
- **Pass criteria**: Stride length estimate within ±20% of actual

### What We Learn
- Is phone-in-pocket data clean enough, or does it need armband/belt?
- Do different horses produce different enough signatures to need per-horse calibration?
- Can we estimate velocity from gait classification alone (without GPS)?

---

## Phase 3: TTS Calling Experience

**Goal**: Validate that spoken test movements sound natural and are well-timed enough to be useful.

### Hardware Needed
- iPhone + Bluetooth headphones (Beats or similar)
- No beacons needed — this test uses manual triggering

### Test App — Audio Caller Prototype
A simple app that:
1. Loads a hardcoded test (Training Level Test 1)
2. Plays each movement via AVSpeechSynthesizer when user taps "Next"
3. Settings: voice selection, speech rate, pitch
4. Logs which voice/rate combination the tester prefers

### Test Protocol

#### Test 3.1: Voice Comparison
- Play the same 5 movements with 3–4 different iOS voices (male/female, different accents)
- Ask 3–5 riders to rank: clarity, naturalness, "would I ride to this voice?"
- **Pass criteria**: At least one voice rated acceptable by >80% of testers

#### Test 3.2: Timing Perception
- Rider listens to movement calls while riding (manual trigger by ground person at letters)
- Vary announcement lead time: 2, 4, 6, 8 meters before the letter
- **Pass criteria**: Riders identify a preferred window; likely 4–8m depending on gait

#### Test 3.3: Full Test Ride with Manual Caller
- Ground person triggers movements in the app as rider approaches each letter
- Rider experiences the full test called by TTS through headphones
- Post-ride interview: Was the pacing natural? Any movements cut off? Too fast? Too slow?
- **Pass criteria**: Rider says "I would use this instead of my husband calling"

### What We Learn
- Which iOS voice works best for dressage terminology
- Optimal speech rate for comprehension while riding
- Whether TTS quality is good enough for MVP or if we need to prioritize recorded voices

---

## Phase 4: PDF Import Parser

**Goal**: Validate that we can reliably parse USDF and WDAA test PDFs into structured movement data.

### No Hardware Needed — Desktop/Simulator Testing

### Test Protocol

#### Test 4.1: Collect Test PDFs
- Download 10 tests spanning:
  - USDF Intro A, Intro B, Training 1, Training 2, Training 3, First Level 1
  - WDAA Basic 1, Basic 2, Level 1 Test 1, Level 1 Test 2

#### Test 4.2: Build Parser
- Extract text with PDFKit
- Parse movement lines with regex + keyword matching
- Output structured movement list

#### Test 4.3: Accuracy Check
- Compare parsed output to manually entered ground truth for each test
- **Pass criteria**: >95% of movements parsed correctly (right sequence number, letter, directive text) across all 10 tests
- Document any edge cases that need special handling

### What We Learn
- How many test format variations exist in practice
- Which edge cases (compound letters, "between" locations) need special parsing rules
- Whether OCR path (camera scan) needs different parsing than PDF text extraction

---

## Phase Sequencing

```
Phase 1 (Beacons)──────► GATE: Does positioning work?
   │                         │
   │ YES                     │ NO → Rethink approach
   ▼
Phase 2 (Gait) ──┐
Phase 3 (TTS)  ──┼──► Can run in parallel
Phase 4 (Parser)──┘
   │
   ▼
All phases pass → Build integrated MVP
```

Phase 1 is the critical gate. Phases 2–4 can run in parallel after Phase 1 succeeds. If Phase 1 fails, we need to reconsider the positioning approach before investing in anything else.

---

## Prototype Timeline Estimate
- **Phase 1**: 1–2 weekends (order beacons, build test app, run arena tests)
- **Phase 2**: 1 weekend (collect data) + 1 week (offline analysis)
- **Phase 3**: 1 weekend (build TTS app, rider testing)
- **Phase 4**: 2–3 evenings (parser development and validation)
- **Gate decision**: ~3–4 weeks from start
