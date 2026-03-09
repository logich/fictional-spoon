# Dressage Caller — Pending Verifications

## Sprint 1 — Ready to Ride Reliably
- [ ] Remove power from one beacon mid-walk → drops from canvas within 3s
- [ ] Ride at trot → movements called ~2 strides before the letter
- [ ] Deny Always location → red banner appears with Open Settings link
- [ ] Screen stays on for 10+ minutes during active ride
- [ ] After final movement → app speaks "Test complete" and plays chime

## Sprint 2 — Solid Foundation
- [ ] Complete calibration walk → force-quit → relaunch → calibration data restored
- [ ] Navigate in/out of ride three times → no service state leaks, ranging restarts cleanly
- [ ] `JSONEncoder().encode(SampleTests.trainingLevel1)` round-trips without loss
- [ ] Zero new Swift 6 strict-concurrency warnings

## Sprint 3 — Competition Day UX
- [ ] Competition mode → bell sounds → 30s/15s spoken → rider enters at A → first call triggers
- [ ] Practice mode → no bell → halt for 6s → calling pauses → resume → picks up same movement
- [ ] Move slider to Earlier → movement called noticeably before letter vs centre position
- [ ] Slider position restored after relaunch
- [ ] Preview Movements shows all 17 movements with correct text and gait badges
- [ ] Device vibrates briefly at each movement trigger

## Sprint 4 — Home Screen and Profiles
- [ ] Two arena profiles with different calibrations — switching retains each calibration independently
- [ ] Two horse profiles — horse name shows correctly in RideView per selection
- [ ] Home screen shows last-used test highlighted; beacon status "4/4 connected" or warning
- [ ] Complete a test → post-ride summary appears automatically with correct gait breakdown
- [ ] Simulator: mock rider triggers movement announcements in correct sequence
- [ ] VoiceOver: arena canvas announces nearest letter; all buttons have labels

## Sprint 5 — Polish, Tests, and Live Activity
- [ ] Start test, lock screen → Live Activity shows movement number + next text, updates as movements progress
- [ ] `xcodebuild test` passes: trilateration within 0.5m of ground truth, path loss within 5%
- [ ] Fresh install → onboarding appears → complete calibration walk → arena profile saved → home screen
- [ ] Post-ride summary: tap a movement marker on path replay → shows directive text and timestamp
- [ ] App submits to TestFlight cleanly
