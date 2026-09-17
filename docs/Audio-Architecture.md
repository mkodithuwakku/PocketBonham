# Audio architecture

## Ownership and rendering

`BonhamCore` contains Codable models, validation, the serialized repository, swing/quantization math and Apple-framework sample decoding. `AudioHost` is the main-actor control surface. It prepares an `AudioRig` on a worker task, negotiating the session's rate and requesting approximately 5 ms I/O. Actual route, buffer duration and reported output latency appear in Settings.

A single AVAudioEngine source node renders stereo Float PCM through `BonhamRender`. The source callback obtains the two buffers and host timestamp and calls C. It does not allocate, decode, access files, log, dispatch, lock, invoke UI code or destroy Swift objects. The C++ kernel owns fixed voice/event/command/snapshot storage. Compile-time assertions require its atomic scalar types to be lock-free. A source node is used rather than constructing one player per hit.

Samples are copied into kernel-owned storage only while an engine is stopped. The rig remains alive until its engine has stopped; no voice can outlive its sample storage. Preparing another set of kits releases the stopped old rig before decoding the new one. All required chain kits are preloaded. A 192 MiB decoded-stereo budget is enforced; preparation reports the exact kit/instrument/file on failure. Transient decode input/output buffers add temporary overhead, so total resident memory still requires physical-device measurement.

The producer copies each playback plan into a free slot of an eight-slot pool. An atomic mailbox publishes the latest complete plan; superseded unread plans are reclaimed by the producer, and the callback releases the prior slot only after switching to the new one. Neither thread modifies the other's live slot. A separate generation counter invalidates stale starts and makes Stop independent of queue capacity. Live pad/motion commands use a bounded 512-entry single-producer/single-consumer ring. The main actor is the sole producer. Motion feedback uses a separate 1,024-entry ring back to the editor.

## Sample clock and event order

The transport maintains a Float64 absolute bar origin in frames. Quarter-note frame duration is `sampleRate * 60 / BPM`. Each swung onset and retrigger is rounded from its absolute origin. Rounded step/bar durations are never accumulated. Event placement and bar transitions happen inside the callback; CADisplayLink reads position but schedules no notes.

Each explicit start has four quarter-note clicks at frames `round(k * quarterFrames)` for `k=0...3`. Music starts at `round(4 * quarterFrames)`. At a bar boundary, the old unrounded duration advances the origin, then the incoming tempo determines the new duration. Chain repeats/entries/wrap never add count-ins. The complete saved-pattern chain snapshot remains fixed for the run. Standalone future-step content updates use the latest snapshot; BPM and swing latch at the next bar boundary.

Stop cancels future sequencing and count-ins via the generation counter. A 3 ms release/output transition clears drum and click voices and room energy. The visible playhead resets immediately. Inactivation/interruption/route changes also stop the AVAudioEngine and require an explicit subsequent Play.

Simultaneous scheduled events are resolved deterministically. Following the owner’s simultaneous-hat correction, all hats at the same absolute frame play together, including open/closed pairs and unequal retrigger grids. Each voice records its onset frame. A new hat applies a 3 ms release only to hat voices from an earlier frame. Non-hat voices may overlap across steps, bars and entries. Live commands received in one render buffer resolve simultaneous hats as a group.

## Voices, pitch, decay and output

There are 64 primary sample voices and 64 bounded, short retirement slots for voice-steal crossfades. Saturation chooses the smallest gain/tail-envelope estimate, with oldest voice as the deterministic tie-break. A stolen voice retires over 3 ms while the replacement starts. The pool cannot grow in the callback.

Playback ratio is `2^(semitones/12)`. Unity pitch reads exact sample positions. Other ratios use a precomputed 32-tap Hann-windowed sinc table, 256 fractional phases and 65 cutoff bands; upward pitch reduces the cutoff to suppress aliasing. Tables are constructed on the preparation thread. No per-sample sine/cosine resampler work occurs in the callback. The spectral regression test checks +12 semitones against an input above the resulting Nyquist cutoff.

A voice's output duration is `floor(sourceFrames / ratio * decay)`. Its final 3 ms (or the entire voice for shorter hits) ramps to zero. At decay 1 it plays the complete pitch-adjusted sample, with this final de-click ramp. There is no onset shift or loudness normalization. Hit level/127 multiplies track gain. Per-step locks are resolved independently for each step and inherited by that step's retriggers.

The fixed `smallRoom-v1` is a short stereo feedback-comb room network. Wet proportion is 0–30%, smoothed per sample. Off transitions smoothly to dry and clears the room when its contribution reaches silence. Kit/chain boundaries preserve room energy while moving to the incoming amount. Clicks are mixed after the room. Master gain is smoothed. A linked instantaneous peak guard is unity below 0.98 and scales only overloads; it adds zero frames of lookahead latency. It intentionally protects output under pathological density, where audible peak reduction is possible. It is not a user-facing creative effect.

## Recording and control feedback

UIKit drum buttons act on `touchesBegan` and retain the UITouch monotonic timestamp. Buttons are nonexclusive and can receive independent fingers. The touch timestamp is correlated with the render's host timestamp/frame pair. Quantization compares swung onsets across previous/current/next bars; exact ties choose the later onset. A new note carries an eligible loop number so its immediate audition is not duplicated by the sequencer on the same quantized pass. Existing programmed hits are allowed to sound during overdub.

Each recording bar/partial pass records one edit snapshot. A control gesture owns one edit group; beginning another control gesture closes the current recording group. Mute/solo edit snapshots include transient performance state but do not dirty persisted music.

Record Motion sends pitch/decay values through the control ring. At each enabled step's audio-clock onset, the callback applies the active motion value to that hit and writes a feedback record. The main actor drains feedback into the pattern's locks. No enabled notes are created by motion. Gesture completion waits for a render acknowledgement before finalizing its ordinary undo group; explicit save/recovery waits briefly for any outstanding feedback. This avoids making motion capture depend on display refreshes.

Display feedback estimates presentation frames from the render clock, monotonic current time and reported output latency, retaining recent bar metadata around tempo changes. This is an estimate, not an acoustic latency measurement. Real speaker/wired response, Bluetooth delay and visual phase require device observation.

## Persistence and lifecycle

A repository actor serializes canonical saves, drafts, deletes and reference checks. JSON uses UUID identities, explicit schema 1 and UTC ISO-8601 dates. Atomic same-volume replacement writes preserve the old canonical file on failure, and one previous revision is retained per saved entity. Library indexes are rebuilt from files. Failed/future records stay untouched and are surfaced. Restoring a damaged canonical record quarantines the damaged original first; healthy and future-version records are never rolled back. Deletion also removes its obsolete backup so restoration cannot resurrect intentionally deleted items.

Draft autosave is debounced 300 ms. It does not update saved pattern content used by chains. A revision mismatch prevents overwriting a changed save; the UI offers recovery as a copy. Explicit Save only reports saved status after the actor returns. All audio preparation and storage operations remain outside the render callback.

The audio category is playback/default, without background capabilities or microphone permission. Leaving the active scene releases the idle-timer override and audio session; returning prepares pads but never starts transport. The app listens for route changes, interruptions, configuration changes and media-services reset.
