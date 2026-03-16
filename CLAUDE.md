# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Dressage Caller** — an iOS app that automatically calls a dressage test for a rider. It tracks the rider's position in a lettered arena using BLE beacons and announces the next movement through the rider's headphones, replacing the need for a human caller during solo practice.

### Core Concepts

- **Dressage tests**: Standardized movement sequences performed in a lettered arena (letters A, K, E, H, C, M, B, F mark perimeter positions in a 20×40m small arena)
- **Caller**: Someone who reads the next movement aloud so the rider doesn't have to memorize the test
- **Arena letters**: Fixed positions around the arena; BLE beacons are mounted at each letter
- **Movement trigger**: An announcement fires when the rider's estimated position is within a computed distance of the next movement's letter

### Target User

**Linda** — mid-50s, 30+ years riding, USDF and Western Dressage, outdoor 20×60m arena with a **metal building** overhead. Rides with Beats wireless headphones. Zero tolerance for friction or failure. Full persona in `PERSONA.md`.

---

## Current Status (as of March 2026)

**The app exists, builds, and runs on device.** This is not a planning-stage project.

- ✅ **Sprint 1 complete**: Look-ahead timing, stale beacon eviction, idle timer, background auth UX, test-complete announcement
- ✅ **Sprint 2 complete**: Codable test types, BeaconCalibration persistence, SessionLogger async I/O, RideSession refactor, type-safe calibration keys
- 🔲 **Sprint 3** (Competition Day UX): bell/countdown, practice mode, timing slider, test import — not yet started
- 🔲 **Sprints 4–5**: Profiles, onboarding, Live Activity — not yet started

See `SPRINT-PLAN.md` for the full forward plan.

---

## Hardware

**Beacons in hand**: 4× Kontakt Anchor Beacon 2 (USB-powered, used for initial field testing)

**Beacons required for production**: **8** — one at each perimeter letter (A, K, E, H, C, M, B, F)

**Why 8**: Field tests in March 2026 (indoor metal building) showed that 4-beacon trilateration is too noisy in a metal structure due to multipath reflections. 8 beacons provide denser coverage and better trilateration geometry.

**iBeacon UUID**: `F7826DA6-4FA2-4E98-8024-BC5B71E0893E` (Kontakt factory default — confirmed correct)

**Major/minor values**: ⚠️ Still placeholder values in code. Must run the Beacon Diagnostic screen on a physical device with all beacons powered to discover real values. See `BEACONS.md`.

**4 additional beacons**: Not yet purchased. This is a prerequisite before Sprint 3 field testing.

---

## Architecture

- **Platform**: iOS 18+, Swift 6, SwiftUI
- **Concurrency**: `@Observable` services, Swift strict concurrency throughout
- **Position tracking**: CoreLocation iBeacon ranging → `BeaconRangingService` → `PositionEngine` (trilateration + motion-gating)
- **Motion**: CoreMotion via `MotionService` (gait classification, velocity estimation)
- **Audio**: `AVSpeechSynthesizer` via `AnnouncementService`; audio background mode enabled
- **Ride orchestration**: `RideSession` owns all services; `RideSessionController` sequences movements
- **Persistence**: UserDefaults + JSON (calibration data); SwiftData deferred

### Key Algorithm Note

The position engine uses **motion-gating**: position is only updated when the iPhone's measured speed indicates the phone is actually moving. Earlier Gaussian smoothing produced wild oscillation in the metal building environment. Motion-gating is the current baseline. See `field-data/` and `TEST-RESULTS.md` for context.

---

## Key Documents

| File | Contents |
|------|----------|
| `PERSONA.md` | Full profile of Linda — the target user |
| `PROJECT.md` | Project overview, current status, hardware, open questions |
| `DATA-MODEL.md` | Swift data model — entities, fields, what's implemented vs. planned |
| `RESEARCH.md` | Competitive landscape, competition rules, positioning tech comparison, beacon hardware options |
| `UX-FLOW.md` | Full UX flow from app launch through post-ride summary |
| `BEACONS.md` | Beacon hardware details, UUID history, diagnostic tool, field test findings |
| `TEST-PLAN.md` | Prototype validation test protocol (Phases 1–4) |
| `TEST-RESULTS.md` | Actual test outcomes, algorithm findings, pending verifications |
| `SPRINT-PLAN.md` | Completed sprints + active forward plan (Sprints 3–5) + post-Sprint 5 roadmap |
| `VERIFICATIONS.md` | Sprint verification checklist (all items pending device testing) |
| `REVIEW.md` | iOS Craft Expert code review from 2026-03-09 (P0–P3 issues) |
| `field-data/` | Raw sensor CSV logs from March 2026 indoor field tests |

---

## Open Blockers

1. **Major/minor beacon values** — placeholders in `ArenaConfiguration.prototype`; must be discovered on device
2. **4 additional beacons** — needed to reach the required 8 before production-quality testing
3. **Sprint 3 prerequisites** — beacons + major/minor values must be resolved before field-testing Sprint 3 features
