# Field Test Logs — Indoor Metal Arena, March 2026

Raw sensor data from the first arena field tests of the Dressage Caller app.

## Test Conditions

| Parameter | Value |
|-----------|-------|
| Date | 2026-03-09 |
| Environment | Indoor arena, **metal building** |
| Arena size | 20×60m (standard/full) |
| Beacons | 4× Kontakt Anchor Beacon 2, USB-powered |
| Beacon placement | Cardinal letters only: A (10,0), E (0,30), C (10,60), B (20,30) |
| Phone position | Rider's jacket pocket |
| Software | DressageCaller prototype, Sprints 1 & 2 complete |

## Files

| File | Description | Duration | Rows |
|------|-------------|----------|------|
| `ride_2026-03-09_01.csv` | Perimeter ride with centerline passes — primary test session | ~189s | 640 |
| `ride_2026-03-09_02.csv` | Short static test near B (app launch/abort) | ~3s | 3 |

## CSV Column Reference

| Column | Type | Description |
|--------|------|-------------|
| `elapsed_s` | float | Seconds since session start |
| `beacon_letter` | string | Arena letter this beacon row belongs to (A, B, C, E in this test) |
| `rssi` | int (dBm) | Raw RSSI from CoreLocation ranging; 0 = beacon not detected this cycle |
| `accuracy_m` | float (m) | CoreLocation estimated distance; -1.00 = unknown/not detected |
| `proximity` | string | CoreLocation proximity zone: Immediate / Near / Far / Unknown |
| `pos_x` | float (m) | Raw trilateration position estimate, x-axis (0–20m) |
| `pos_y` | float (m) | Raw trilateration position estimate, y-axis (0–60m); negative values = outside arena bounds |
| `nearest_letter` | string | Arena letter nearest to estimated position |
| `distance_to_nearest` | float (m) | Distance from estimated position to nearest letter |
| `confidence` | string | Position confidence: strong / weak / none |
| `motion_state` | string | Gait classification: stationary / walking / trotting / cantering |
| `accel_magnitude` | float (g) | Accelerometer magnitude deviation from 1g (used for gait classification) |
| `filtered_pos_x` | float (m) | Motion-gated position (held when stationary) |
| `filtered_pos_y` | float (m) | Motion-gated position (held when stationary) |

**Note**: Multiple rows share the same `elapsed_s` timestamp — one row per beacon detected in that ranging update cycle.

**Note**: `pos_x`/`pos_y` values outside arena bounds (negative y, x > 20) occur when trilateration extrapolates beyond the calibrated region. The `filtered_pos_x/y` columns apply motion gating but not arena-bounds clamping in this dataset.

## Key Observations from ride_2026-03-09_01

- **4 beacons only active for first ~75 seconds** (A, B, C only; E appears at t=76s)
- **All confidence values are `weak`** — never reached `strong` with 4 beacons in this environment
- **RSSI variance**: A ranges from -54 to -93 dBm at similar positions; B ranges from -47 to -93 dBm — confirms high multipath noise
- **Beacon dropout**: B drops to `rssi=0` / `accuracy=-1.00` at multiple points, particularly on the far side of the arena (t=20–25s, t=63s, t=97–98s, t=109s, t=129s, t=139–144s, t=168s, t=171–178s)
- **Position jitter**: raw `pos_x/pos_y` varies by 2–5m between consecutive 1-second samples even when rider is stationary (visible at t=74–76s where motion_state=stationary but raw pos still fluctuating slightly)
- **Motion gating works**: `filtered_pos_x/y` holds stable during stationary periods (t=74–116s near X, showing consistent ~11.5, 29.3)
- **Path is traceable** despite noise: the filtered position path roughly follows the expected perimeter route and centerline pass
- **E beacon appears late** (t=76s) — likely powered on mid-session or took time to be detected

## Conclusions from This Data

1. **4 beacons insufficient** — `weak` confidence throughout; coverage gaps cause frequent single-beacon or dual-beacon fallback
2. **Gaussian smoothing was tried first and rejected** — amplified the RSSI noise rather than suppressing it
3. **Motion gating adopted** as the production approach — stable position during stationary phases
4. **8 beacons required** — one at each perimeter letter (A, K, E, H, C, M, B, F) for full small-arena coverage
5. **Algorithm research opportunity**: Kalman filter or particle filter may improve in-motion accuracy vs. current motion-gating; validate against this data before adopting

## Using This Data for Algorithm Development

To load and analyze in Python:
```python
import pandas as pd

df = pd.read_csv('ride_2026-03-09_01.csv')

# One row per beacon per timestamp — pivot to get all beacons per timestamp
pivot = df.pivot_table(index='elapsed_s', columns='beacon_letter',
                       values=['rssi', 'accuracy_m'], aggfunc='first')

# Unique position estimates (one per timestamp)
positions = df.drop_duplicates('elapsed_s')[
    ['elapsed_s', 'pos_x', 'pos_y', 'filtered_pos_x', 'filtered_pos_y',
     'nearest_letter', 'confidence', 'motion_state', 'accel_magnitude']
]
```

Ground truth positions are not available in this dataset (no separate reference tracking was used). The nearest-letter column provides approximate ground truth for positions when the rider was known to be near a specific letter.
