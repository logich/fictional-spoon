# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dressage Caller — an iOS app that acts as an automated dressage test caller for horse riders. It tracks the rider's position in the arena using iBeacons and announces upcoming movements through audio cues, replacing the need for a human caller.

### Core Concepts

- **Dressage tests**: Standardized sequences of movements performed in a lettered arena (letters like A, K, E, H, C, M, B, F mark positions around the arena)
- **Caller**: Someone who reads the next movement aloud so the rider doesn't need to memorize the test
- **Arena letters**: Fixed positions around the arena used as reference points for movements

## Current Status

**Sprint 3 code-complete (2026-03-10); field test pending.** Sprints 1–2 field-verified. Sprint 4 (RF Positioning) is the current priority — the largest blocker to a usable app. Sprints 5–6 follow. See `SPRINT-PLAN.md` for full plan.

**Active blockers:**
- RF accuracy in metal barn — CL `accuracy` is unusable; centroid algorithm needed
- B beacon TX power ~6dB weaker than A/C/E — hardware fix before next test
- E beacon dropped out 70% of last ride — power supply needs investigation

## Architecture Summary

```
DressageCaller/
├── App/DressageCallerApp.swift
├── Models/         ArenaLetter, ArenaConfiguration, DressageTest, BeaconCalibration, RiderState
├── Services/       BeaconRangingService, PositionEngine, MotionService, RideSession,
│                   RideSessionController, AnnouncementService, SessionLogger,
│                   BeaconDiagnosticService, TestLibrary, PDFTestParser
├── Views/          HomeView, RideView, ArenaView, TestSelectionView, CalibrationView,
│                   BeaconStatusView, BeaconDiagnosticView, PreviewMovementsView,
│                   TestImportView, VoicePickerView
├── ViewModels/     CalibrationViewModel
└── Extensions/     Collection+Safe
```

See `docs/architecture.md` for the full file map and key patterns.

## Key Technical Decisions

- iOS 18+ only, Swift 6, SwiftUI + `@Observable`
- 4 beacons at A, E, C, B; expanding to 8 (+ K, F, H, M) in Sprint 4
- Position engine: Gauss-Newton trilateration **currently in use but failing** — replacement is proximity-weighted centroid on smoothed RSSI (Sprint 4)
- Motion service: CoreMotion accelerometer → stationary/walking/trotting/cantering → speed caps on position updates
- TTS: `AVSpeechSynthesizer` with English-US voice picker
- Storage: `UserDefaults` JSON for calibration and preferences; SwiftData planned for Sprint 5
- Local-first; no backend

## Build & Run

**XcodeGen:** `project.yml` defines the project. Run `xcodegen generate` after any `project.yml` change.
> **IMPORTANT**: `xcodegen generate` clears the signing team — re-select it in Xcode's target settings after each run.

**Simulator:**
```
xcodebuild -scheme DressageCaller -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO build
```
BLE ranging is mocked in `BeaconRangingService.swift` via `#if targetEnvironment(simulator)`.

**Device:** Set destination in Xcode toolbar, then use `mcp__xcode__BuildProject` with `tabIdentifier: "windowtab1"`.
> After `BuildProject` completes, press ▶ (Cmd+R) in Xcode — the MCP tool has no run/launch capability.

**Xcode MCP tools available:** `BuildProject`, `GetBuildLog`, `XcodeListNavigatorIssues`, `RenderPreview`

## Keeping Docs In Sync

The files in `docs/` are the committed, portable source of truth for project context. The auto-memory system also maintains copies under `~/.claude/projects/.../memory/` — those are machine-local and may lag.

**Rule:** Whenever you write or update a memory file (`architecture.md`, `rf-positioning.md`, `next-steps.md`, `kontakt-sdk-research.md`), also update the corresponding file in `docs/`. The two sets of files should always be identical in content (minus the memory frontmatter, which is stripped in `docs/`).

## Key Docs

| Doc | Purpose |
|-----|---------|
| `SPRINT-PLAN.md` | Full sprint plan: completed sprints, current Sprint 4 (RF), Sprints 5–6 |
| `VERIFICATIONS.md` | Field-test checklist per sprint |
| `BEACONS.md` | iBeacon hardware notes, placement, Kontakt anchor beacon specs |
| `docs/architecture.md` | Detailed file map, patterns, position engine analysis |
| `docs/rf-positioning.md` | Full RF expert analysis, field test data, centroid algorithm design |
| `docs/next-steps.md` | Current priority list and sprint blockers |
| `docs/kontakt-sdk-research.md` | Kontakt iOS SDK evaluation notes |
