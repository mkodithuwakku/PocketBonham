# PocketBonham — current context for AI agents

Last updated: **2026-09-17**. Start with [AGENTS.md](AGENTS.md); use this file as a compact handoff, not as a substitute for reading the code you change.

## What the owner is building

A native, offline iPhone drum machine with a focused hardware-inspired interface. The original request was to implement the application from [the software specification](docs/PocketBonham-Software-Specification.md), then integrate owner-provided drum folders. The owner has tested the working app, supplied Drum Kit 1, and requested a correction to simultaneous hi-hat playback.

The repository is intended for portfolio presentation. The root README introduces the product, screenshots and engineering. Detailed build instructions live under `docs/`, and this file provides continuity for future development.

Repository: `https://github.com/mkodithuwakku/PocketBonham.git`. Main branch: `main`. Local build caches and device identifiers are intentionally not part of the published project.

## Current implementation

- SwiftUI application with UIKit touch-down pads, AVAudioEngine/AVAudioSourceNode and a C++17 renderer.
- iOS 18 deployment baseline; verified with Xcode 26.3, Swift 6.2.4, iOS 26.2 SDK and an iOS 26.3 iPhone 16 simulator.
- 16-step, 4/4 patterns; 40–240 BPM; 50–75% swing; mandatory four-click count-in; audio-frame scheduling.
- Per-hit levels/retriggers, track pitch/decay, step locks, motion capture, quantized pad overdub, undo/redo and transient mute/solo.
- Explicit pattern/chain saving, recovery drafts, revision protection, previous-revision backups and corruption handling.
- Independent looping chains with up to 64 entries, 1–16 repeats, per-entry tempo overrides and preloaded kit transitions.
- Optional short room, metronome, audio-route status, accessible control alternatives and foreground lifecycle handling.
- No backend, account, microphone access, third-party runtime package, MIDI, audio export, background playback or in-app sample importer.

## Owner decisions that matter

### Same-step hats must layer

The owner reported that two hats placed on the same step muted one another and asked for a fix. This overrides SND-02/T-08 in the original specification, which gave a closed hat priority over a simultaneous open hat.

Current behavior: all hats beginning at the same absolute render frame sound together. A later hat releases only voices with an earlier `startedFrame`, using the existing 3 ms ramp. Live commands processed in one callback likewise layer. Both closed-hat variants, either open/closed ordering, unequal rolls and later-hit choking have regression coverage.

Implementation: `Voice.startedFrame` and `PBEngine::trigger` in `Sources/BonhamRender/BonhamRender.cpp`; simultaneous-open suppression was removed from live and scheduled paths. See [fix record](docs/Hat-Layering-Fix.md). Do not “repair” this back to the original spec behavior.

### Owner kits are preserved, not replaced

Drum Kit 1 is bundled at `PocketBonham/Resources/Kits/kit-1`, version 1. Its reviewed source mapping is `scripts/kit-mappings/kit-1.json`.

| Instrument | Stable ID |
|---|---|
| Kick | `kick` |
| Snare | `snare` |
| Closed Hat 1 | `closedHat` |
| Closed Hat 2 | `closedHat2` |
| Open Hat | `openHat` |
| Tom 1 | `tomExtra1` |
| Tom 2 | `tomExtra2` |
| Tom 3 | `tomExtra3` |
| Ride | `ride` |

There is no supplied crash. Tom numbering is preserved without guessing pitch ordering. All nine files are byte-identical to the owner originals and carry SHA-256 hashes. Eight are Float32 WAV and Ride is PCM24 WAV, all 44.1 kHz; Closed Hat 1 is mono and the rest stereo. Explicit `hatType` metadata handles the second closed-hat variant; optional metadata retains compatibility with older manifests.

Drum Kit 1 sorts ahead of fixtures and is the fresh-library default. Existing kit preferences/drafts remain respected. The ninth pad is on page two. `Development` is a separately labeled synthetic kit retained until all three owner kits are ready; it is not counted as an owner kit.

## Verification at this handoff

- Latest ordinary package run after the hat fix: **29 discovered, 28 passed, one opt-in hour test skipped, zero failures**.
- Latest simulator UI run: **4 passed, zero failures**, approximately 86 seconds.
- The earlier full offline hour passed with every measured onset within one frame. It is accelerated musical time, not an hour of physical-phone stability.
- All nine supplied samples decode at both 44.1 and 48 kHz. Kit 1 is 1.31 MiB of stereo PCM at 48 kHz; combined with fixtures, 3.26 MiB / 192 MiB preparation budget.
- Simulator app built, installed and launched. Signed iPhone Release build and signature verification succeeded locally.
- Physical installation was attempted but blocked by a locked phone (`kAMDMobileImageMounterDeviceLocked`, CoreDevice 12040). Do not describe the device build as installed.

Evidence: [latest core](docs/evidence/hat-layering-core-tests.txt), [latest UI](docs/evidence/hat-layering-ui-tests.txt), [kit validation](docs/evidence/kit-1-validation.txt), [historical full hour](docs/evidence/offline-hour-tests.txt).

## Remaining work

1. Integrate the owner's other two kit folders when provided. Preserve originals and map ambiguities explicitly; use the preparation script and full combined-kit validator.
2. Complete listening acceptance for the real samples, hats, room and cross-kit chains.
3. Install and launch on an unlocked physical device. The available paired phone during development was iPhone 16 Plus; the original spec nominally names iPhone 16. Record actual hardware for measurements.
4. Perform physical acoustic latency, visual phase, multitouch, route/interruption, memory/startup, low-storage and sustained 60-minute checks. See [Testing](docs/Testing.md).
5. Once all real kits are ready, remove the synthetic Development kit from shipping resources deliberately. Preserve test fixtures under `Tests`; do not remap old development patterns to an unrelated real kit.
6. Select source/sample distribution terms with the owner before declaring an open-source license or an App Store release.

## Where to make changes

| Task | Entry points |
|---|---|
| Pattern UI / instrument selection | `PocketBonham/Features/RootView.swift` |
| Pads and shared controls | `PocketBonham/Features/Components.swift` |
| Editing state / recording / recovery | `PocketBonham/App/AppStore.swift` |
| Audio preparation, kit catalog and C bridge | `PocketBonham/Audio/AudioHost.swift` |
| Timing, sample voices, choking, DSP | `Sources/BonhamRender/BonhamRender.cpp` |
| Model contracts and quantization | `Sources/BonhamCore/Models.swift` |
| Saved-file integrity | `Sources/BonhamCore/Repository.swift` |
| Decoder / sample validation | `Sources/BonhamCore/SampleDecoder.swift`, `Sources/KitValidator/main.swift` |
| Regression coverage | `Tests/BonhamCoreTests/CoreTests.swift`, `PocketBonhamUITests/PocketBonhamUITests.swift` |
| Xcode project changes | `scripts/generate_project.py` and its generated project/scheme |

## Quick verification commands

```sh
swift test -c release
swift run -c release bonham-validate-kit PocketBonham/Resources/Kits
xcrun simctl list devices available
```

Use a locally available simulator UUID and the commands in [Development](docs/Development.md) / [Testing](docs/Testing.md). Do not embed a developer's team ID, device UUID or absolute home path in committed commands. No GitHub Actions pipeline or App Store distribution is configured in this handoff.
