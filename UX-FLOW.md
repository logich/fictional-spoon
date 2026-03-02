# App UX Flow

## First-Time Experience (One-Time Setup, ~10 minutes)

### 1. Welcome & Arena Setup
Screen: Welcome message, "Let's set up your arena"

- Select arena size: 20×40m or 20×60m
- App explains: "You'll need to attach a beacon to each letter marker"
- Shows diagram of letter positions with beacon placement guide
- "When your beacons are placed, tap Next"

### 2. Beacon Discovery
Screen: List of detected beacons, auto-populating

- App scans for BLE beacons in range
- Each detected beacon shows signal strength
- If any expected letters are missing: "We can't detect a beacon for letter V. Check that it's powered on."

### 3. Guided Calibration Walk
Screen: Arena diagram highlighting current target letter

Audio-guided, hands-free after tapping "Start Calibration":

> "Walk to letter A and pause."
> *(detects proximity + halt)* "A confirmed."
> "Continue along the rail to K."
> *(detects K)* "K confirmed."
> "Continue to V."
> ... around the full perimeter ...
> "All letters confirmed. Your arena is ready."

- Assigns each beacon to its letter automatically based on walk order
- Records RSSI profile at each known position
- Captures IMU baseline at walk
- ~2.5 minutes for 20×60m at walk pace

### 4. Add Your First Test
Screen: Test library

- Browse by organization: USDF Traditional / Western Dressage
- Browse by level: Intro, Training, First, Second...
- Select test → preview movement list
- "Add to My Tests"

Setup complete. This never needs to happen again unless she changes arenas or adds beacons.

---

## Pre-Ride Flow (Every Session, <30 seconds)

Linda is at the barn. Horse is tacked. Pivo is on the tripod. She pulls out her phone.

### 5. App Launch → Home Screen
Screen: "My Tests" list, most recent at top

What she sees:
```
┌─────────────────────────────┐
│  Good morning, Linda        │
│                             │
│  MY TESTS                   │
│  ┌─────────────────────┐    │
│  │ ★ Training Test 1   │    │  ← last used, highlighted
│  │   USDF Traditional  │    │
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │   Western Basic 1   │    │
│  │   Western Dressage  │    │
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │   First Level Test 3│    │
│  │   USDF Traditional  │    │
│  └─────────────────────┘    │
│                             │
│  [+ Add Test]               │
│                             │
│  Horse: Duke 🐴  ▾          │
│  Arena: Linda's Outdoor ✓   │
│  Beacons: 12/12 connected   │
└─────────────────────────────┘
```

- Beacon status shown at bottom — green checkmark if all connected, warning if any missing
- One tap on a test to select it

### 6. Test Ready Screen
Screen: Selected test with "Start" button

```
┌─────────────────────────────┐
│  Training Level Test 1      │
│  USDF Traditional Dressage  │
│                             │
│  20 movements · ~5:30       │
│                             │
│  Timing: ◀━━━━━●━━━━━▶     │
│          Earlier    Later    │
│                             │
│  ┌─────────────────────┐    │
│  │                     │    │
│  │    🔔 START TEST    │    │
│  │                     │    │
│  └─────────────────────┘    │
│                             │
│  [Preview Movements]        │
│  [Practice Mode]            │
└─────────────────────────────┘
```

- **Timing slider**: Persists per arena — set once, stays
- **Start Test**: Competition simulation with bell + 45-second countdown
- **Practice Mode**: No bell, calling starts immediately when rider enters at A, pauses if rider stops
- **Preview Movements**: Scrollable list of all movements (like reading the paper test)

Linda taps **Start Test**. Phone goes in her pocket. She walks to the mounting block.

---

## Riding Flow (Hands-Free, ~5–7 minutes per test)

### 7. Bell & Countdown
Audio sequence after "Start Test":

> *🔔 Bell sound*
> *(45-second countdown begins)*
> *"30 seconds."*
> *"15 seconds."*

App is tracking position. Waiting for rider to approach A.

### 8. Test Calling — Active Ride
The core experience. App tracks position + heading + gait continuously.

**Calling logic:**
- App knows the next movement in sequence
- Calculates trigger distance based on: rider velocity (from gait/IMU) × timing preference (slider)
- When rider is within trigger distance of next letter, heading matches expected direction → speak

**Example sequence, Training Level Test 1:**

> *(rider approaches A from outside the arena)*
> "A — Enter working trot."
> *(rider trots down centerline, app triangulates from side beacons)*
> "X — Halt. Salute."
> *(detects halt via IMU)*
> "Proceed working trot."
> "C — Track right."
> ...

**What the rider hears** is just the movement text — clean, clear, well-paced. No beeps, no "movement 3 of 20", no UI noise.

**Between movements:**
- App is silently tracking, estimating position, waiting for next trigger
- If rider deviates from expected path (e.g., wrong turn), app does NOT correct — just like a real caller, it reads what's next, not what you did wrong

**Test Progress Indicator:**
A glanceable "where am I in the test" display for moments when the rider blanks. Available on:

- **Lock screen Live Activity** — shows on iPhone lock screen without unlocking. Rider can glance at phone briefly if needed (e.g., at halt or walk).
  ```
  ┌─────────────────────────────┐
  │ Training Test 1    7 of 20  │
  │ ━━━━━━━━━●━━━━━━━━━━━━━━━━  │
  │ Next: E — Circle left 20m   │
  └─────────────────────────────┘
  ```
- **Apple Watch complication** (V2) — even quicker wrist glance. Shows movement number and next movement text.

The progress indicator is passive — it updates as movements are called but never interrupts or makes sound. It's a safety net, not the primary interface.

### 9. Test Complete
After the final halt and salute:

> "Test complete."

A gentle chime. That's it while mounted.

---

## Post-Ride Flow (Optional, Dismounted)

### 10. Summary Screen
When Linda opens the app after her ride:

```
┌─────────────────────────────┐
│  Training Level Test 1      │
│  Completed · 5:42           │
│                             │
│  Gaits detected:            │
│   Walk: 0:38                │
│   Trot: 4:12                │
│   Canter: 0:52              │
│                             │
│  All 20 movements called ✓  │
│                             │
│  [Run Again]                │
│  [Switch Test]              │
│  [Done]                     │
└─────────────────────────────┘
```

- Simple stats, not overwhelming
- No scores, no judgment — this isn't a judging app

#### Path Replay
Below the stats, an interactive arena diagram showing:
- Rider's actual path drawn as a line on the arena
- Movement markers at each trigger point (numbered dots)
- Tap a marker to see the movement text and timestamp
- Color-coded by gait (e.g., blue=walk, green=trot, orange=canter)
- Pinch to zoom for centerline straightness, circle shape, etc.

```
┌─────────────────────────────┐
│  ┌───────────────────────┐  │
│  │ H ·    ·    ·    · M  │  │
│  │   ·              ·    │  │
│  │ E · · ·╌╌╌╌· · · B  │  │
│  │   ·    ╱    ╲   ·    │  │
│  │ K ·   ╱  ●4  ╲  · F  │  │
│  │   ·  ╱        ╲ ·    │  │
│  │   · 3╌╌╌╌╌╌╌╌╌2 ·    │  │
│  │       ·  ↑  ·         │  │
│  │          1 A          │  │
│  └───────────────────────┘  │
│                             │
│  ● 1: A – Enter w. trot    │
│  ● 2: C – Track right      │
│  ● 3: E – Circle left 20m  │
│  ● 4: X – Trot             │
│                             │
└─────────────────────────────┘
```

Data is already being collected during the ride (position estimates, gait, timestamps) — no extra work to capture, just needs the visualization layer.

---

## Practice Mode (Variation)

For when Linda wants to work parts of the test, not simulate competition:

- No bell, no countdown
- Calling starts when she enters the arena near any letter
- If she halts for more than 5 seconds mid-test → app pauses calling
- When she resumes → app picks up from where she left off
- She can restart from any movement by voice: "Start from movement 8" (V2 feature)

---

## Multiple Arena Support

Linda has an outdoor arena. Her friend's barn has an indoor. Her trainer has a different outdoor.

- Each arena is a saved profile with its own calibration data and timing preference
- Switching arenas: Settings → Arenas → select → done
- Could auto-detect arena by which beacons are in range (each arena's beacons have unique IDs)

---

## Edge Cases

| Situation | App Behavior |
|-----------|-------------|
| Rider goes off-course | Default: keeps calling next expected movement. Optional: "Off-course assist" detects deviation and re-orients (see below) |
| Rider halts unexpectedly | Practice mode: pauses. Competition mode: keeps sequence going (like a real test) |
| Beacon battery dies mid-ride | Falls back to remaining beacons + IMU. If coverage is too degraded, audio alert: "Beacon at letter E not responding" after the ride, not during |
| Phone call comes in | iOS audio interruption — resume calling after call ends. Note: recommend Do Not Disturb |
| Two riders in arena | Each runs their own app/phone. Beacons are passive transmitters, support unlimited simultaneous receivers |
| Rider exits arena mid-test | Detects departure from beacon range, pauses. Resumes when rider re-enters. |

---

## Design Decisions Log

### Off-Course Behavior
- **Default**: Silent — keeps calling next expected movement, like a real caller
- **Optional setting**: "Off-course assist" — detects when rider deviates from expected path and re-orients to the correct next movement
- **Rationale**: Needs real user testing. Some riders will find correction helpful during practice; others will find it distracting or patronizing. Ship as a toggle, default off.

### Timing Slider — Strides, Not Seconds
- Riders think in strides, not meters or seconds
- "Call 3 strides before the letter" is more intuitive than "call 8 meters before"
- **Challenge**: Stride length is horse-dependent. A 17hh warmblood has a much longer stride than a 14.2hh quarter horse.
- **Approach**: During calibration walk (and first few rides), app measures the specific horse's stride length per gait from IMU data. Slider then maps strides → distance using that horse's measured stride.
- Could allow multiple horse profiles (Linda rides two horses in the same arena)
- **Fallback**: If stride detection isn't reliable enough for MVP, use "Earlier/Later" with unlabeled notches and refine to strides in a later version

### Voice & Language
- **MVP**: iOS built-in TTS voices (AVSpeechSynthesizer)
  - Free multilingual support out of the box
  - Multiple voice options per language (gender, accent)
  - User can pick their preferred voice in settings
  - No recording, licensing, or storage costs
- **Future**: Recorded human caller voices as a premium feature
  - Could partner with well-known dressage callers/judges
  - Sells as a pack: "Called by [Name]"
  - Would need per-test recordings — significant production effort

### Horse Profiles
Since stride length and gait signatures are horse-dependent:
- Linda selects which horse she's riding before starting a test
- Each horse stores: name, stride calibration data, gait signatures
- "Linda's Outdoor Arena" + "Duke" = specific timing calibration
- Switching horses: one tap on the home screen
