# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dressage Caller — an iOS app that acts as an automated dressage test caller for horse riders. It tracks the rider's position in the arena and announces upcoming movements through audio cues, replacing the need for a human caller.

### Core Concepts

- **Dressage tests**: Standardized sequences of movements performed in a lettered arena (letters like A, K, E, H, C, M, B, F mark positions around the arena)
- **Caller**: Someone who reads the next movement aloud so the rider doesn't need to memorize the test
- **Arena letters**: Fixed positions around the arena used as reference points for movements

### Key Technical Challenges

- Rider position tracking inside arenas (GPS may not work in metal barns; BLE beacons at letters and video analysis are being explored)
- Text-to-speech or pre-recorded audio for calling movements
- Parsing publicly published dressage test data

## Status

Early planning stage — no application code yet. See `PROJECT.md` for requirements and open questions.
