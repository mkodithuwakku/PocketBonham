# Simultaneous hi-hat fix — 2026-09-17

The owner reported that two hats on the same step silenced one another and requested that both play. This supersedes the original specification's SND-02/T-08 rule that a closed hat wins a simultaneous open/closed collision.

The original renderer explicitly suppressed simultaneous open hats, and its general choke also shortened the first of two closed-hat variants to 3 ms. A regression reproduced the lost closed-hat tail in both the sequencer and live pads. Ordinary drum polyphony already passed a 16-track audio-sum check.

Each voice now records its starting audio frame. A hat hit releases only hats that started on an earlier frame. All same-frame hats layer, including open/closed pairs and both closed-hat variants. Live commands arriving in one render callback likewise play together. Later hats still apply the existing 3 ms release to older hats. No sample, saved pattern, kit ID, or asset version changes are needed.

Verification checks actual mixed PCM beyond the old 3 ms cutoff, active voice counts, both open/closed track orders, live pads, later-hit choking, a muted closed hat alongside an audible open hat, unequal retrigger grids, and 16 simultaneous non-hat voices. Core suite: 28 passed, one opt-in hour test skipped, zero failures. See [test evidence](evidence/hat-layering-core-tests.txt).

The signed iPhone Release build succeeds and passes code-signature verification. A physical update was attempted but the phone remains locked (`kAMDMobileImageMounterDeviceLocked`); the new device build is ready to install once unlocked.

All four simulator UI regression tests also pass: pad paging/audition, steps/recording/lifecycle, save/chain/relaunch, and accessibility sizing. See [UI evidence](evidence/hat-layering-ui-tests.txt).
