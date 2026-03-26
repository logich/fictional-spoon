# App Store Readiness — Dressage Caller

Audit performed 2026-03-19. Issues listed in priority order.

---

## BLOCKERS — Will cause rejection

- [x] **B-1** `PrivacyInfo.xcprivacy` missing — binary rejected at App Store Connect upload before any human review. Must declare required reasons for UserDefaults (CA92.1), file timestamp APIs (C617.1), and disk space APIs (E174.1). ✅ Created `DressageCaller/PrivacyInfo.xcprivacy`.
- [x] **B-2** Empty entitlements file — `allowsBackgroundLocationUpdates = true` is set in `BeaconRangingService` but `com.apple.developer.location.background-location` is absent from the entitlements. Runtime crash on device; Guideline 5.1.1 violation. ✅ Added entitlement to `DressageCaller.entitlements`.
- [x] **B-3** Two-step location escalation (WhenInUse → Always) silently fails on iOS 13+ without the background-location entitlement. Screen lock stops all ranging. Follows from B-2. ✅ Resolved by B-2 fix.
- [x] **B-4** `audio` background mode declared in `project.yml` without justification. TTS does not require it. Reviewers flag under Guideline 2.5.4 (background modes must be necessary). ✅ Removed `audio` from `UIBackgroundModes` in `project.yml`.

---

## RISKS — Likely flagged or poor review experience

- [ ] **R-1** No demo mode — reviewer has no beacons, no arena. App appears non-functional on device (Guideline 2.1). Minimum fix: App Review Notes with hardware requirements and video link.
- [x] **R-2** "Show Debug" / "Hide Debug" button visible in production builds of `RideView`. ✅ Debug panel and toggle wrapped in `#if DEBUG` in `RideView.swift`.
- [x] **R-3** ~15 `print()` calls in `BeaconRangingService` signal a dev build; logs Kontakt factory UUID on every ranging start. ✅ Replaced with `OSLog` `Logger` (subsystem `com.dressagecaller.app`, category `BeaconRanging`); `.info`/`.debug`/`.error` levels; `privacy: .public` on interpolated values.
- [x] **R-4** Hardcoded Kontakt factory UUID (`F7826DA6-...`) shared by all unconfigured Kontakt beacons worldwide — phantom beacons in any office near Kontakt hardware. ✅ Replaced with a fixed app-specific UUID (`74648DDD-D39B-4263-9DE5-4D18C8CF4D83`) pre-programmed into all Dressage Caller hardware sold. Users install the app and beacons work automatically — no UUID configuration required.
- [x] **R-5** `urls(for:in:)[0]` force-subscript in `TestLibrary.swift` line 11. Use `.first` with a guard instead. ✅ Replaced with `guard let docs = ...urls.first`.
- [ ] **R-6** `NSMotionUsageDescription` declared but accelerometer never triggers a permission prompt (only `CMMotionActivity` would). Harmless but may draw scrutiny.
- [ ] **R-9** App Store privacy nutrition label not configured in App Store Connect (separate from the PrivacyInfo.xcprivacy manifest).
- [x] **R-10** Countdown overlay in `RideView` has no VoiceOver labels — `Image`, `Text` views with no `accessibilityLabel`; screen-blocking overlay gives no context to assistive technology. ✅ Background `Color` marked `.accessibilityHidden(true)`; content `VStack` grouped with `.accessibilityElement(children: .combine)` + label.

---

## POLISH — Before public release

- [ ] **P-1** Verify app icon is not a placeholder (visual inspection required).
- [ ] **P-2** Accessibility gaps: `ArenaView` Canvas invisible to VoiceOver; timing `Slider` in `HomeView` has no `accessibilityLabel`; status bar elements in `RideView` unlabelled.
- [ ] **P-3** `.system(size: 96)` in `PositionVerificationView` ignores Dynamic Type. Use a relative font size or `@ScaledMetric`.
- [x] **P-4** Debug panel and its toggle button should be compiled out with `#if DEBUG`. (Same code as R-2.) ✅ Fixed with R-2.
- [ ] **P-5** App Store category: submit under **Sports** or **Health & Fitness**, not Utilities.
- [ ] **P-6** No pre-prompt UI before the background location upgrade request (iOS expects explanation before the second system prompt).
- [ ] **P-7** `audio` background mode + `.playback` audio session may suspend between TTS utterances when screen locks. Consider silent keepalive track or rely solely on `location` background mode.
- [ ] **P-8** No MetricKit or crash reporter for post-release diagnostics.

---

## Progress Log

| Date | Item | Action |
|------|------|--------|
| 2026-03-19 | B-1 | Created `DressageCaller/PrivacyInfo.xcprivacy` with UserDefaults (CA92.1), file timestamp (C617.1), disk space (E174.1) reasons |
| 2026-03-19 | B-2/B-3 | Added `com.apple.developer.location.background-location` entitlement to `DressageCaller.entitlements` |
| 2026-03-19 | B-4 | Removed `audio` from `UIBackgroundModes` in `project.yml` |
| 2026-03-19 | R-2/P-4 | Wrapped debug panel and toggle button in `#if DEBUG` in `RideView.swift` |
| 2026-03-19 | R-5 | Replaced `urls(for:in:)[0]` with `guard let … .first` in `TestLibrary.swift` |
| 2026-03-19 | R-3 | Replaced all `print()` in `BeaconRangingService` with `OSLog` `Logger` at appropriate levels |
| 2026-03-19 | R-10 | Countdown overlay: background hidden from VoiceOver, content VStack combined with accessibility label |
| 2026-03-20 | R-4 | Fixed app-specific UUID `74648DDD-...` in `ArenaConfiguration.beaconProximityUUID`; pre-programmed into all sold hardware; no user configuration needed |
