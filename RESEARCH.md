# Dressage Caller App — Research Notes

## Competitive Landscape

Existing products — none do automatic position-based calling:

| App | Price | What it does | Gap |
|-----|-------|-------------|-----|
| **Dressage TestPro** | $2.49/mo | Audio playback, draw-to-learn, score tracking | Rider manually advances |
| **Rider Guider** | £9.99/mo (caller) | AI voice recognition — rider says "next" | Still manual trigger |
| **FEI EquiTests** | Free/Paid | Official FEI test reference with animations | No calling while riding |
| **Pivo** | £126-259 hardware | Auto-tracking camera for video review | Filming only, no test calling |

**Our differentiator**: Automatic position-aware calling — no manual trigger needed.

## Competition Rules & Use Context

### USDF/USEF (U.S. Competitions)
- **Human callers ARE allowed** with restrictions: read each movement once, no extra conversation, or risk elimination
- **Electronic devices banned during competition** (DR120.16) — earpieces, headphones, radios = elimination
- Earbuds allowed in warm-up only; exception for medical hearing aids
- Callers commonly used at lower levels (Intro–Training)

### FEI (International)
- **No callers at all** — tests must be performed from memory
- Any unauthorized assistance = elimination

### Implication
- **Practice use has zero rule constraints** — any technology is fine during training
- **Competition use is a dead end for electronics** — cannot use earpiece/phone at shows
- **Product positioning**: Training tool that builds muscle memory, not a competition-day device

## Arena Dimensions & Letter Positions

### Small Arena (20m × 40m)
Letters: A, K, E, H, C, M, B, F

| Letter | Coordinates (x, y) |
|--------|-------------------|
| A | (10, 0) |
| K | (20, 6) |
| E | (20, 20) |
| H | (20, 34) |
| C | (10, 40) |
| M | (0, 34) |
| B | (0, 20) |
| F | (0, 6) |

### Full Arena (20m × 60m)
Letters: A, K, V, E, S, H, C, M, R, B, P, F

| Letter | Coordinates (x, y) |
|--------|-------------------|
| A | (10, 0) |
| K | (20, 6) |
| V | (20, 24) |
| E | (20, 30) |
| S | (20, 54) |
| H | (20, 54) |
| C | (10, 60) |
| M | (0, 54) |
| R | (0, 36) |
| B | (0, 30) |
| P | (0, 12) |
| F | (0, 6) |

Centerline letters (D, L, X, I, G) are unmarked but at known positions along the centerline (x=10).

- 6m from each corner to nearest letter
- 12–14m between letters along long sides

## Positioning Technologies

| Technology | Accuracy | Cost | Indoor? | iOS Support | Verdict |
|-----------|----------|------|---------|-------------|---------|
| **GPS** | ~5m | Free | No — fails in metal barns | Built-in | Outdoor-only fallback |
| **BLE Beacons** | 1.5–5m | €300–500/arena | Yes | CoreLocation/iBeacon | Best cost/feasibility balance |
| **UWB** | 10–30cm | €2,000–9,000 | Yes | U1/U2 chip (iPhone 11+) | Best accuracy, high cost |
| **IMU** | Drifts alone | €20–100 | Yes | Built-in accelerometer | Supplement only |
| **Computer Vision** | 10–50cm | €200–2,000 | Controlled lighting | Heavy processing | Complex setup |

**Recommended MVP approach**: BLE beacons at arena letters + phone's built-in IMU. BLE gives periodic position fixes; IMU fills gaps between updates. For a 20×60m arena where movements trigger at letters 12–14m apart, 1.5–5m accuracy is likely sufficient.

### Indoor Metal Arena Considerations
- Metal walls and roof cause **multipath reflections** — RSSI readings are noisier indoors
- Accuracy degrades from 1.5–5m (outdoor) to roughly 3–8m (indoor metal building)
- **Still workable** because: letters are 12–14m apart, IMU smooths noisy readings, calibration walk captures the specific reflection environment, and test sequence is known (only need to confirm approach to the *next* expected letter, not solve position from scratch)
- May need denser beacon placement in severe cases (2 per letter)
- Bluetooth audio (phone in pocket → headphones) is unaffected indoors — short path, not an issue
- **Announcement timing may need to be earlier indoors** to account for less precise triggering
- Provide a **user-adjustable timing slider** ("call earlier / call later") so riders can fine-tune announcement lead time to their arena, gait, and personal preference — this also accommodates riders who simply prefer more or less warning regardless of environment

## BLE Beacon Hardware

### MVP Decision
BLE beacons first (~$400 for full arena). UWB deferred to V2 — price point ($3,000–18,000) too high to validate concept. iPhone's Nearby Interaction framework does support third-party UWB anchors (NXP, Qorvo) for future upgrade path.

### Recommended Devices

| Beacon | IP Rating | Temp Range | Battery Life | Weight | Price | Notes |
|--------|-----------|-----------|-------------|--------|-------|-------|
| **BeaconTrax Trax10234** | IP68 + IK09 | -40°C to 85°C | 44 months | 52g | ~$30–50 | Smallest, shockproof, replaceable battery |
| **TennaBLE Steel Puck** | IP68/IP69K | Extreme | 3 years | ~50g | ~$40–70 | Steel casing, survives impacts |
| **GAO RFID Long Range** | IP67 | -40°C to 85°C | 5+ years | 98–108g | ~$30–50 | Replaceable AA, 900m range |
| **Zebra Outdoor** | IP67 + UV | -40°C to 60°C | ~5 years | 143g | ~$40–60 | Longest battery, screw-mount |
| **GAO Solar** | IP67 | -20°C to 70°C | Self-charging | ~80g | ~$50–80 | No battery changes |

### Arena Kit Costs
- Small arena (8 beacons): ~$240–400
- Full arena (12 beacons): ~$360–600

### Key Requirements
- **Shock resistance**: Horses bump letter markers — need IK09 or steel casing
- **Replaceable batteries**: Easier to maintain 8–12 units; lithium preferred for cold weather
- **Lithium in cold**: 80–90% capacity at 0°C, 60–80% at -20°C (alkaline drops much faster)
- **Mounting**: VHB tape or zip tie to letter boards, stake-mount, or magnetic mount on metal rails

### No Custom Hardware Needed
All devices are portable, battery-powered, weatherproof, and iBeacon-compatible. Off-the-shelf is sufficient for MVP.

## Dressage Test Data

- **USDF/USEF/FEI tests are copyrighted** — cannot freely redistribute test text
- Tests available as PDFs from governing body websites (USDF tests free to download)
- No open-source machine-readable test database exists (opportunity)
- Third-party apps (TestPro, etc.) include tests via subscription/licensing
- Current USDF tests effective through November 2026

### Copyright & Linking Strategy
- **Linking to official download pages is fine** — pointing to their server is not reproduction
- Link to the test listing pages, not directly to individual PDF URLs
- USDF copyright contact: copyright@usdf.org — worth requesting permission to link and exploring partnership
- WDAA has a formal "Website Link Usage Policy" — review and request permission
- **Never host, cache, or redistribute** test content on our servers
- User imports their own copy (PDF download or camera scan) — we parse it locally on their device
- Test text is only stored on the user's device, only visible to them

### Official Test Download Pages
- USDF: usdf.org/downloads/forms → Tests section
- WDAA: westerndressageassociation.org/wdaa-tests
- USEF Eventing: useventing.com → Dressage Tests
