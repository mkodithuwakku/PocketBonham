# Implementation checklist

- [x] M0: Native Xcode application, local Swift/C++ package, domain models, deterministic fixtures, repeatable project generator, automated test targets.
- [x] M1 implementation: Sample-clock transport, four-count, swung 16-step editing, polyphonic pads, lifecycle stop and awake foreground screen.
- [x] M2 implementation: Kit catalog, explicit pattern saves, recoverable drafts, undo/redo, per-hit parameters, locks, audio-clock motion capture, live recording, mute/solo and hats.
- [x] M3 implementation: Separate chain library, arbitrary saved pattern references, reordering/repeats, per-entry tempos, preload/snapshot playback, reference integrity and recovery.
- [x] M4 implementation: Short room, metronome, compact visual design, accessible controls, corruption restoration, output/session status and in-app help.
- [x] Simulator build and tested create/save/play/chain/relaunch workflows.
- [x] Domain, decoder, persistence, exact-event and long offline clock verification.
- [x] Signed iPhone Release build.
- [x] Integrate Drum Kit 1: nine original samples, preserved hashes, explicit hat variants, decode validation.
- [ ] Integrate the remaining two owner kits and complete listening acceptance for all three.
- [ ] Install/launch on the physical phone (developer-image mount rejected while the phone was locked).
- [ ] Physical iPhone acceptance: four-finger pads, acoustic latency, visual phase, route/interruption matrix, real-kit memory/startup, sustained 60-minute foreground playback and Instruments checks.

Implementation includes the first owner kit and is ready for the remaining kits and device acceptance. The specification's final release definition remains open until those external dependencies and physical measurements are completed. No fixture kit or accelerated offline timeline is counted as final owner-kit/device acceptance.
