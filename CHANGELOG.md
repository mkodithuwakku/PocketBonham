# Changelog

## Unreleased — 2026-09-17

### Application

- Added the native SwiftUI drum-machine interface, 16-step sequencing, touch-down pads and four-click count-in.
- Implemented sample-frame scheduling, swing, retriggers, polyphonic playback, pitch/decay, parameter locks, motion capture and a short room.
- Added pattern and chain libraries, explicit saves, undo/redo, recoverable drafts, revision checks and backup restoration.
- Added chain ordering, repeats, tempo overrides and preloaded kit transitions.
- Added foreground lifecycle handling, audio status, accessible control alternatives and simulator workflow tests.

### Drum Kit 1

- Bundled all nine supplied samples with hashes and reproducible mappings.
- Preserved both closed-hat variants and the three numbered toms; no absent crash was substituted.
- Made the owner kit the default for fresh libraries and supported its ninth pad on a second page.

### Fixes

- Fixed same-step hats cutting each other off: simultaneous open/closed hats and closed-hat variants now layer; later hits still choke earlier tails.
- Added actual-PCM regressions for hat tails, muted live hats and sixteen simultaneous drum tracks.

### Documentation

- Replaced the build-focused root README with a portfolio overview and real app screenshots.
- Added player, development, testing, troubleshooting, data-model and asset-provenance guides.
- Added `AGENTS.md` and `AI_CONTEXT.md` for future AI-assisted development, including owner decisions that supersede the original specification.

Two owner kits and physical-device acceptance remain outstanding. This changelog does not designate an App Store release.
