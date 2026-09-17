# Drum Kit 1 integration — 2026-09-17

Bundled as `kit-1`, asset version 1, from `/path/to/Drum Kit 1/`. All nine originals are byte-identical to their bundled copies. No normalization, trimming, renaming or destructive conversion was applied. The manifest records SHA-256 for every file.

| Display name | Stable role | Original file | Source format |
|---|---|---|---|
| Kick | kick | Kick.wav | Float32 stereo, 44.1 kHz |
| Snare | snare | Snare.wav | Float32 stereo, 44.1 kHz |
| Closed Hat 1 | closedHat | ClosedHat1.wav | Float32 mono, 44.1 kHz |
| Closed Hat 2 | closedHat2 | ClosedHat2.wav | Float32 stereo, 44.1 kHz |
| Open Hat | openHat | OpenHat.wav | Float32 stereo, 44.1 kHz |
| Tom 1 | tomExtra1 | Tom1.wav | Float32 stereo, 44.1 kHz |
| Tom 2 | tomExtra2 | Tom2.wav | Float32 stereo, 44.1 kHz |
| Tom 3 | tomExtra3 | Tom3.wav | Float32 stereo, 44.1 kHz |
| Ride | ride | Ride.wav | PCM24 stereo, 44.1 kHz |

The toms retain the source numbering without assigning unconfirmed high/mid/low pitch roles. No crash sample was supplied, so no crash track is added. Both closed hats use explicit `hatType: "closed"` metadata and share the `hats` choke group with the open hat, in both pads and sequencer playback. Existing standard-role manifests remain compatible. The later [simultaneous-hat fix](Hat-Layering-Fix.md) lets same-frame hats layer while preserving choking of earlier tails.

Drum Kit 1 appears first in the catalog and is the default for fresh libraries. Existing saved kit preferences and recovery drafts remain respected. The ninth pad (Ride) is on page two. Development Sounds remains separately labeled until the remaining two owner kits are ready.

## Reproducible mapping

`scripts/kit-mappings/kit-1.json` is the reviewed mapping. The installed manifest and audio are in `PocketBonham/Resources/Kits/kit-1/`. The integration command used was:

```sh
python3 scripts/prepare_kit.py '/path/to/Drum Kit 1' \
  --id kit-1 --name 'Drum Kit 1' \
  --mapping scripts/kit-mappings/kit-1.json --install
```

The tool intentionally refuses to overwrite an already installed kit ID.

## Verification

- All nine supplied samples decode successfully at 44.1 and 48 kHz, contain audible-level PCM, and pass original-file hash checks.
- Decoded stereo PCM at 48 kHz: **1.31 MiB** for Drum Kit 1; **3.26 MiB** including Development Sounds, against the 192 MiB preparation budget.
- Core suite: **25 passed, one opt-in hour test skipped, zero failures**. The hour test was already run before this asset integration; no rendering clock code changed.
- Legacy hat manifest compatibility and explicit second-closed-hat metadata validation pass.
- All four simulator UI tests pass (86.437 s): nine-pad paging and audition, pattern/chain saving and relaunch, recording/lifecycle, and accessibility sizing.
- Signed iPhone Release build succeeds; code signature verifies. Physical installation was retried and remains blocked by the locked phone (`kAMDMobileImageMounterDeviceLocked`).

Evidence: [sample validation](evidence/kit-1-validation.txt), [core tests](evidence/kit-1-core-tests.txt), [UI tests](evidence/kit-1-ui-tests.txt). Automated decoding and simulator pad interaction do not establish physical-device acoustic quality or latency. Listening acceptance and the remaining two kits are still pending.
