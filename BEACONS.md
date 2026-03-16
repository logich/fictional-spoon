# Beacon Hardware & Detection

## Hardware

**Kontakt Anchor Beacon 2** × 4, powered via USB.

These beacons broadcast two simultaneous advertisement types:
- **iBeacon** — the CoreLocation ranging format (UUID + major + minor)
- **Kontakt telemetry** — a proprietary Eddystone-style frame on GATT service UUID `FE6A`

The `FE6A` frames are what CoreBluetooth sees; iOS intercepts iBeacon advertisements at the system level and routes them exclusively to CoreLocation.

### Known device IDs (from FE6A service data)

| Beacon | Device ID |
|--------|-----------|
| 1 | C01U |
| 2 | U01V |
| 3 | P01V |
| 4 | J01U |

The service data format observed from Anchor Beacon 2 (bytes, after the 2-byte service UUID header):

```
07 64 F4 26 22 00   — Kontakt frame header (common to all 4)
XX XX XX XX         — device-specific bytes (address fragment)
XX FF               — calibration / status
FF                  — separator
31 35 6D XX XX XX XX XX   — "15m" + ASCII device ID string
```

### iBeacon major/minor values

**Not yet discovered.** Run the Beacon Diagnostic screen (see below) on a real device to reveal them. Once known, update `ArenaConfiguration.prototype` in `ArenaConfiguration.swift`.

---

## iBeacon UUID

**Kontakt factory default:** `F7826DA6-4FA2-4E98-8024-BC5B71E0893E`

The app was originally hardcoded to the Estimote default UUID (`B9407F30-F5F8-466E-AFF9-25556B57FE6D`), which is why no beacons were detected. This was corrected in `ArenaConfiguration.swift`.

If beacons are visible in the BLE section of the diagnostic but not in the iBeacon section, it means the UUID was changed from the factory default via Kio Cloud and needs to be reset there.

---

## Code changes (merged to main, March 2026)

### `DressageCaller/Models/ArenaConfiguration.swift`
- Changed `prototype.beaconUUID` from the Estimote default to the Kontakt factory default UUID
- Major/minor values in `prototype.beaconMappings` are **placeholders** (1/0, 1/1, 1/2, 1/3) pending real hardware discovery

### `DressageCaller/Services/BeaconDiagnosticService.swift` *(new)*
Two-channel diagnostic service:

1. **CoreLocation ranging** — `CLBeaconIdentityConstraint(uuid: kontaktDefaultUUID)` with no major/minor filter, so all 4 beacons surface with their real major/minor values
2. **CoreBluetooth scan** — `scanForPeripherals(withServices: [CBUUID("FE6A")])`, which filters specifically to Kontakt hardware and works independently of iBeacon UUID configuration

Key types:
- `RawBeaconResult` — iBeacon ranging result with uuid/major/minor/proximity/accuracy/rssi
- `NearbyBLEDevice` — BLE peripheral with parsed Kontakt device ID from service data

### `DressageCaller/Views/BeaconDiagnosticView.swift` *(new)*
Diagnostic UI accessible from HomeView. Shows:
- Pass/fail counter (N of 4 iBeacons detected)
- Location authorization status
- Bluetooth state
- Live iBeacon ranging results (major, minor, proximity zone, distance, RSSI)
- Live BLE device list with Kontakt device IDs

### `DressageCaller/Views/HomeView.swift`
- Added **Beacons** section containing `Beacon Diagnostic` NavigationLink above the existing `Calibrate Beacons` link

### `DressageCaller.xcodeproj/project.pbxproj`
- Added `CoreBluetooth.framework` to Frameworks build phase and group
- Registered `BeaconDiagnosticService.swift` in Services group and Sources build phase
- Registered `BeaconDiagnosticView.swift` in Views group and Sources build phase

---

---

## Field Test Results — March 2026

**Environment**: Indoor arena, metal building (Linda's barn)
**Beacons used**: 4 (A, E, C, B only)
**Result**: **4 beacons are insufficient in a metal building.**

Metal structure multipath reflections made RSSI readings too noisy for stable trilateration with only 4 anchors. Position estimates were unstable for reliable movement triggering.

**Decision: 8 beacons required** — one at each perimeter letter (A, K, E, H, C, M, B, F).

Full test details and algorithm findings: see `TEST-RESULTS.md`.
Raw sensor logs: see `field-data/2026-03-indoor-metal/`.

---

## Next Steps for an Implementing Agent

1. **Purchase 4 additional beacons** — 4 more Kontakt Anchor Beacon 2 units (or weatherproof production equivalent) to reach the required 8
2. **Discover major/minor values** — power on all 8 beacons, open Beacon Diagnostic on a physical device, record the major/minor pair shown for each BLE device ID (C01U, U01V, P01V, J01U, plus 4 new units)
3. **Update `ArenaConfiguration`** — replace `prototype` with a full 8-beacon production configuration assigning each major/minor pair to its arena letter (A, K, E, H, C, M, B, F)
4. **Persist arena configuration** — currently `prototype` is a compile-time constant. Sprint 4 adds named arena profiles with saved calibration; configuration will move to a settings/storage layer at that point.
