# Troubleshooting

## Audio and editing

| Symptom | Check and resolution |
|---|---|
| Silence after pressing Play | Wait for the four-click count-in, enable at least one step, check system and master volume, then clear temporary mutes/solos. Inspect Settings → Audio Status for the output route. |
| A pad is silent | A muted track or another soloed track can suppress pads as well as sequenced notes. Selecting a track alone never solos it. |
| One hat seems missing | Use the latest build containing the hat-layering fix. Same-frame hats now layer; a later hat intentionally releases older tails. Also check each track's level, decay and step locks. |
| Only one drum's steps are visible | The grid edits one selected instrument at a time. Switch instruments to see their own notes; all enabled tracks play together. |
| Ride is missing from pads | Drum Kit 1 has nine sounds. Ride is on pad page two. |
| Taps feel delayed on Bluetooth | Inspect the route and try the built-in speaker or a wired route. The reported output latency is an estimate, not a measured touch-to-audible result. |
| Play starts with clicks even when metronome is off | The four-click count-in is mandatory. The metronome toggle applies only after music starts. |
| Tempo does not change instantly | During pattern playback, tempo/swing updates latch at the next bar boundary. Chain arrangement edits apply on the next Play. |
| A chain ignores the latest pattern edit | Save the pattern, then restart the chain. Chains use saved patterns and a fixed snapshot for each run. |
| Returning to the app is silent | Foreground return never restarts transport automatically. Press Play when ready. |

## Kit validation

Run `swift run -c release bonham-validate-kit PocketBonham/Resources/Kits`. The diagnostic identifies the kit, instrument and file where possible.

- **Unknown filename or duplicate alias:** provide an explicit mapping to `scripts/prepare_kit.py`. Keep numbered tom labels unless their pitch roles are confirmed. Do not drop a duplicate-sounding variant just to make IDs unique.
- **Hash mismatch:** compare against the approved original. A changed file requires a deliberate asset update and version decision, not simply removal of its hash.
- **Unsupported codec/rate/channel count:** consult [Kit Format](Kit-Format.md). A `.wav` extension does not guarantee supported PCM content.
- **Kit already exists:** the preparation script refuses overwrites. Review whether you are adding a new kit or deliberately replacing a versioned asset; preserve existing pattern references.
- **Pattern requires another kit version:** restore matching assets or implement an explicit migration. Never substitute a different kit silently.
- **Memory budget exceeded:** validation covers combined decoded stereo PCM, not compressed file sizes. Reassess the approved assets/preload design; raising the limit also needs device-memory validation.

## Saved work and recovery

A recovery draft is not a canonical save. If a draft's base revision is stale, recover it as a copy. If a pattern cannot be deleted, remove its references from saved chains and chain drafts first.

Use Settings → **Restore Damaged Items from Backups** when a damaged record has a valid prior revision. This preserves the damaged original in quarantine and does not overwrite healthy or future-version records. Backups hold one previous revision; they are not unlimited history.

Do not reset or delete the app's library as a routine debugging step. First reproduce against an isolated test directory or a copy. An uninstall can remove app-local data; it is not necessary to update a build.

## Build and installation

| Symptom | Resolution |
|---|---|
| `xcodebuild` cannot find the SDK | Use full Xcode rather than only Command Line Tools; inspect `xcode-select -p` and select the intended Xcode in its settings. |
| Simulator destination unavailable | Run `xcrun simctl list devices available` and use a UUID installed on this Mac. |
| A newly added Swift file is absent from the app | Run `python3 scripts/generate_project.py` and review the generated project diff. |
| Result bundle already exists | Give `-resultBundlePath` a new path rather than overwriting an earlier run's evidence. |
| Signing requires a development team | Configure your team in Xcode or pass your team ID at build time. No personal team is embedded in this repository. |
| `kAMDMobileImageMounterDeviceLocked` / CoreDevice 12040 | Unlock the physical iPhone and keep it awake while developer services mount, then retry installation. |
| App installs but cannot run development code | Check trust, Developer Mode and provisioning in Xcode's device diagnostics. Preserve the library while diagnosing. |

Collect the exact error, app configuration, toolchain, route and reproduction steps before changing unrelated code. Use [Testing](Testing.md) to choose the smallest useful verification.
