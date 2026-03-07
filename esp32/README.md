# ESP32 iBeacon Firmware

Arduino sketch that turns an ESP32 into an iBeacon transmitter for the Dressage Caller app.

## Quick Start

1. **Install Arduino IDE** (2.x) and add ESP32 board support:
   - Preferences → Additional Board Manager URLs:
     `https://espressif.github.io/arduino-esp32/package_esp32_index.json`
   - Board Manager → install **esp32 by Espressif Systems**

2. **Flash each device** with a different `BEACON_MINOR` value:

   | Device | Letter | `BEACON_MINOR` | Placement |
   |--------|--------|----------------|-----------|
   | ESP32 #1 | A | `0` | Bottom center of arena |
   | ESP32 #2 | E | `1` | Left wall, halfway |
   | ESP32 #3 | B | `3` | Right wall, halfway |

   Open `ibeacon/ibeacon.ino`, change `#define BEACON_MINOR` to the value above, select your board, and Upload.

3. **Power** — any USB power bank works. The sketch uses ~80 mA.

4. **Verify** — open Serial Monitor (115200 baud) to confirm the letter and UUID.

## Beacon Parameters

| Parameter | Value |
|-----------|-------|
| UUID | `B9407F30-F5F8-466E-AFF9-25556B57FE6D` |
| Major | `1` |
| Minor | `0`=A, `1`=E, `2`=C, `3`=B |
| Measured Power | `-59` dBm (calibrate if needed) |
| Adv Interval | 100 ms |

## Calibration

`MEASURED_POWER` should be the RSSI your phone reads at exactly 1 meter from the beacon. To calibrate:

1. Hold your phone 1 meter from the ESP32
2. Use a BLE scanner app (e.g. nRF Connect) to read the RSSI
3. Average several readings and update `MEASURED_POWER` in the sketch

Typical values range from -55 (strong) to -65 (weak) depending on the ESP32 module and antenna.

## Placement Tips

- Mount at a consistent height (~1.5 m) on a post or fence rail
- Keep the antenna (usually the PCB antenna end) facing the arena center
- Avoid placing inside metal enclosures — metal blocks BLE signals
- The 3-beacon setup (A, E, B) gives a triangle covering most of the arena; adding C later improves accuracy at the far end
