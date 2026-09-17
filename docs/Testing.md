# Testing and acceptance

Tests are split between the macOS Swift package, the iPhone simulator application and manual physical-device acceptance. Choose the layer that can actually establish the behavior being changed.

## Package regression suite

From the repository root on macOS:

```sh
swift test -c release
```

The latest post-fix run discovered **29 tests: 28 passed, one intentionally skipped, zero failures**. The skipped test renders an hour of musical time and is enabled explicitly:

```sh
PB_LONG_TESTS=1 swift test -c release
```

The hour test passed before the hat-layering change. Its historical result remains valid evidence for that run, not a claim that the latest full suite was rerun with the opt-in flag. Output is in [evidence](evidence/offline-hour-tests.txt).

Useful focused runs:

```sh
swift test -c release --filter ModelTests
swift test -c release --filter RepositoryTests
swift test -c release --filter DecoderTests
swift test -c release --filter RenderTests.testSimultaneousHatPairsKeepBothTails
```

| Area | Meaningful checks |
|---|---|
| Timing | Four-click count-in, swing, absolute event frames, tempo boundaries and drift |
| Polyphony | Mixed PCM and active voices for 16 simultaneous tracks |
| Hat layering | Open/closed in either order, two closed hats, sequencer and live pads, tails beyond the choke ramp |
| Later hat hits | Earlier voices release while a same-frame chord remains intact |
| Retriggers and motion | Per-step distributions, eligibility on a later pass, audio-clock motion feedback |
| DSP | Pitch rejection above the new Nyquist limit, decay, bounded voices and finite output |
| Decoding | PCM16/24/Float WAV and MP3; mono/stereo at 44.1/48 kHz; hashes, trims and budget |
| Supplied kit | Every Drum Kit 1 sample decodes at both supported rates and retains its role |
| Storage | Revision conflicts, references, recovery, backups, malformed/future data and injected write failure |

Trace events prove that an onset was scheduled, but do not prove its tail survived mixing. The hat regression therefore inspects actual PCM after the former 3 ms cutoff. Preserve that distinction when adding audio tests.

## Validate bundled assets

```sh
swift run -c release bonham-validate-kit PocketBonham/Resources/Kits
```

Current result: one owner kit and one development fixture kit, totaling **3.26 MiB** decoded stereo PCM at 48 kHz against a 192 MiB budget. Drum Kit 1 alone is **1.31 MiB**. The CLI reports durations and first samples above −80 dB, and checks each file through the actual app decoder.

This checks technical validity, not whether a sample has the intended musical identity or sounds good. Listening acceptance remains separate. Never silently normalize, trim, rename or replace a supplied sample to make validation pass.

## Simulator UI tests

List available devices with `xcrun simctl list devices available`. Replace `SIMULATOR_UUID`, and use a fresh result-bundle path for each run:

```sh
xcodebuild -project PocketBonham.xcodeproj -scheme PocketBonham \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/UITests.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

The full vintage/velocity run passed all six workflows in about 130 seconds:

1. Drum Kit 1 is selected for a fresh library; all nine pads can be auditioned across both pages.
2. Create and save a pattern, play it, save/play a chain, relaunch and find the saved pattern.
3. Reach all sixteen steps, toggle/undo, open locks, record pads, then verify foreground return stays stopped.
4. At accessibility XXXL text size, transport, Save, Undo and the instrument selector remain available.
5. The dropdown exposes every instrument, preserves independent steps and jumps to the selected pad page.
6. Hold/slide on Snare step 5 changes only its velocity, clamps to 1–127, groups Undo, preserves a simultaneous kick, survives save/reopen and keeps normal tap-to-toggle behavior.

After final layout refinements, the pad and accessibility tests passed again; the pad test also asserts that all eight pads fit above the transport at standard text size.

See the [vintage/velocity verification summary](evidence/vintage-velocity-verification.txt).

A separate enclosure regression checks that the fixed top cap reaches the screen edge, clears the header, and stays in place while scrolling and switching workspaces. It runs alongside the pad, recording/lifecycle and large-text checks for the top-casing update: [four passing tests and build evidence](evidence/enclosure-verification.txt).

Every test gets its own Debug support directory through `PB_TEST_SESSION`; never erase an ordinary user library to get a test to pass. Screenshots and full result bundles are written locally under `build/`. Selected screenshots and concise result summaries are committed under `docs/`.

## Physical acceptance still required

A signed build, simulator run and accelerated offline render establish different facts. Before a release, use the intended iPhone and record:

- Speaker and wired/USB touch-to-audible median/p95 latency, measured externally; specification targets are ≤25/40 ms.
- Visual/audio phase and actual route, sample rate and buffer settings; the visual-phase target is ≤50 ms.
- Four-finger pad chords, hat combinations, cymbal/room/decay behavior and sample attacks by listening.
- Route changes, unplug/reconnect, Bluetooth, calls, Control Center, lock/unlock and audio-service reset.
- Sixty minutes of real-time foreground playback with CPU, memory, thermal and underrun observation; confirm display awake behavior.
- Startup and kit readiness, save durability, low-storage handling, draft conflicts and backup restoration.
- VoiceOver reading order, contrast and reduced-motion behavior.

The specification nominally names iPhone 16. The available paired device during development was iPhone 16 Plus; record the actual hardware when running acceptance. Its last installation attempt failed while locked. No physical latency, sustained stability or resident-memory result is currently claimed.

## Recording results

Keep concise, dated evidence with toolchain, command, scenario, pass/fail and limitations. Preserve historical results without relabeling them as current. Local device UUIDs, machine paths, signing files and full build caches do not belong in a portfolio commit. Do not report the simulator's output-latency estimate as a measured touch-to-sound result.

See [Validation Report](Validation-Report.md) for historical details and [Hat Layering Fix](Hat-Layering-Fix.md) for the latest behavior correction.
