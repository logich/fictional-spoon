# Kontakt iOS SDK — Evaluation Notes (2026-03-11)

## Summary
SDK can configure beacons, but requires cloud + API key. Worth revisiting for a polished multi-arena setup flow, but not needed for the field test.

## What it can do
- `KTKDeviceConnection.writeConfiguration` writes major, minor, TX power, advertising interval to a beacon over BLE
- Requires BLE proximity to the beacon + cloud auth
- This is the **only iOS-side way** to configure Kontakt beacons — standard GATT writes are blocked by Kontakt Secure protocol

## Constraints
- **Cloud mandatory**: v6.0+ uses `KTKConfigProfileGeneratorUsingCloud` — all config calls hit `api.kontakt.io`. Cannot be disabled.
- **Account required**: Needs a Kontakt.io cloud account + API key (free tier exists)
- **Install**: CocoaPods `pod 'KontaktSDK'` + manual `CBORCoding v1.4.0` sub-dep; SPM also available
- **No RSSI improvement**: `KTKBeaconManager` wraps CoreLocation — same update rate as our current stack
- **No simulator support**
- **iOS 13.0+ minimum** (compatible with our iOS 18+ target)

## Barn WiFi note
The arena barn has reliable WiFi — cloud dependency is NOT a blocker if SDK is integrated.

## Decision
- **Field test**: Use standalone Kontakt.io app to assign unique minor values (1/2/3/4) to beacons A/E/C/B. One-time setup, ~5 min.
- **Future sprint**: Consider integrating SDK for in-app "Configure Beacons" flow in `BeaconDiagnosticView`, useful when supporting multiple arenas or handing off to non-technical riders.
