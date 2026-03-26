# Beacon Hardware & Detection

## Hardware

**Minew i3 Robust Beacon** × 8, battery-powered (2× AA alkaline).

- BLE 5.0, nRF52 series chipset
- TX Power: 0 dBm (factory default; configurable -40 to +4 dBm)
- Measured Power (RSSI at 1 m in iBeacon frame): -59 dBm (0xC5) — Apple standard reference
- Advertising interval: **350 ms** (configured via BeaconSET+; factory default is 900 ms)
- IP67 waterproof and dustproof — suitable for barn/outdoor use
- Battery life: ~2.6 years at 350 ms on AA alkaline; replace annually as maintenance
- Configuration tool: **BeaconSET+** (iOS & Android)

**Deployed beacon positions** (8 total): A (10,0), K (20,6), E (0,30), H (20,54), C (10,60), M (0,54), B (20,30), F (0,6)

These beacons broadcast two simultaneous advertisement types:
- **iBeacon** — the CoreLocation ranging format (UUID + major + minor)
- **Minew Device Info** — a proprietary frame on GATT service UUID `FFE1`; contains battery level, MAC address, and device name

The `FFE1` frames are what CoreBluetooth sees in `BeaconDiagnosticService`; iOS intercepts iBeacon advertisements at the system level and routes them exclusively to CoreLocation.

### Minew Device Info frame (`FFE1` service)

CoreBluetooth delivers the service data payload with the leading UUID header bytes stripped:

| Byte(s) | Content |
|---------|---------|
| 0 | Frame type: `0xA1` |
| 1 | Version: `0x08` |
| 2 | Battery level (0–100) |
| 3–8 | MAC address (6 bytes, little-endian) |
| 9+ | Device name (ASCII) |

`BeaconDiagnosticService` verifies `data[0] == 0xA1`, extracts battery and MAC (reversed to big-endian for display), and surfaces them in the BLE Devices list.

### iBeacon major/minor values

Configured via **BeaconSET+**. All beacons use the app-specific UUID and the following assignments:

| Letter | Major | Minor |
|--------|-------|-------|
| H | 1 | 0 |
| M | 1 | 1 |
| K | 1 | 2 |
| F | 1 | 3 |
| A | 1 | 4 |
| E | 1 | 5 |
| C | 1 | 6 |
| B | 1 | 7 |

Once beacons are configured and identified via Beacon Diagnostic, update the MAC address table above.

---

## iBeacon UUID

**App ranging UUID:** `74648DDD-D39B-4263-9DE5-4D18C8CF4D83`

This is the app-specific UUID programmed into all deployed beacons via BeaconSET+. It is stored as `ArenaConfiguration.beaconProximityUUID` — the single source of truth in code.

**Minew factory default:** `E2C56DB5-DFFB-48D2-B060-D0F5A71096E0`

The factory default is only relevant if a beacon is factory-reset and needs to be re-programmed. If a beacon appears in the BLE Devices section but not in the iBeacon section, it may have been reset — re-programme the UUID via BeaconSET+.

---

## Beacon Diagnostic

`BeaconDiagnosticService` + `BeaconDiagnosticView` provide two-channel verification:

1. **CoreLocation iBeacon ranging** — scans for `ArenaConfiguration.beaconProximityUUID` with no major/minor filter; all 8 beacons surface with their major/minor values and RSSI
2. **CoreBluetooth BLE scan** — scans for service `FFE1`; shows MAC address, RSSI, and battery level for each beacon

Use the Beacon Diagnostic screen to:
- Confirm all 8 beacons are detected before a ride
- Verify major/minor assignments match the table above
- Check battery levels (replace any beacon below 20%)

---

## Next steps for an implementing agent

1. [DONE] Beacon hardware: replaced with 8× Minew i3
2. [DONE] UUID configured via BeaconSET+ to `74648DDD-...`
3. [DONE] Advertising interval set to 350 ms via BeaconSET+
4. [DONE] `BeaconDiagnosticService` updated to scan `FFE1` and parse Minew Device Info frame
5. [DONE] `ArenaConfiguration.prototype` maps all 8 beacons with correct major/minor values
6. **TODO**: After first power-on, open Beacon Diagnostic and record MAC addresses for each letter; fill in the table above
7. **TODO**: Consider persisting arena configuration — currently `prototype` is a compile-time constant; planned for Sprint 5 SwiftData migration
