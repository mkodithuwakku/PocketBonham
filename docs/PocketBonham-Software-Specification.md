# PocketBonham — Software Specification and Development Kickoff

Version: 1.0 — complete implementation specification incorporating owner clarifications  
Prepared: 2026-09-17  
Platform: native iPhone application, Swift and SwiftUI  
Primary acceptance device: iPhone 16  
Audience: the owner and the Codex agent implementing the application

## 1. Purpose and authority

Build a playable, reliable drum machine inspired by the Teenage Engineering PO-12, adapted for an easier touchscreen workflow. The user supplies three drum kits. The app creates one-bar drum patterns, saves them by name, loads them later, and assembles any saved patterns into separately saved chains.

This document defines the intended complete first version, its implementation stages, and acceptance criteria. It is an implementation brief, not an instruction to start coding during the specification task. A running interface without dependable audio, persistence, and chain playback is not completion.

Requirement language: **MUST** is required for completion; **SHOULD** is the preferred approach and deviations need a documented reason; **MAY** is optional. Requirements below are normative unless explicitly labeled provisional or future scope. Numerical limits and interaction rules not specified by the owner are deliberate engineering defaults, not claims about the PO-12.

Priority order: subsequent owner decisions, confirmed requirements in this document, then engineering defaults. Do not silently add excluded features or turn an intermediate milestone into the final product.

## 2. Confirmed product decisions

| Area | Confirmed requirement |
|---|---|
| Musical unit | Exactly 16 sixteenth-note steps, one 4/4 bar per pattern |
| Arrangement | Saved patterns can be chained in a chosen order |
| Libraries | Patterns and chains are saved separately; chains can use any saved pattern |
| Chain tempo | Entries may use different kits and BPMs; each entry can override BPM without changing its saved source pattern |
| Appearance | Strong PO-12 inspiration with original PocketBonham branding and simpler touch controls |
| Platform | Native Swift application for the owner's iPhone 16 |
| Kits | Three folders of instrument-named one-shot WAV/MP3 files, supplied through Codex and bundled for every installation |
| Available instruments | Only instruments present in the selected kit are playable |
| Expected instruments | Kick, snare, closed hi-hat, open hi-hat, at least two toms with variable count, crash, ride |
| Playing and editing | Step editing, live recording, BPM, swing, per-hit level, pitch, decay, per-step parameter changes, retriggers, copying, chaining |
| Effects | No distortion, delay, filter, or stutter performance effects; optional drum-room reverb |
| Count-in | Audible four-count once per explicit Play; none between repeated bars or chain entries |
| Editing assistance | Visible undo action; instrument mute and solo |
| Persistence | Name, save, and load patterns and chains locally |
| Sharing | No audio export, project export, or sharing |
| Lifecycle | No playback outside the app; keep the screen awake while the app is open |

“Inspired by PO-12” does not require hardware button combinations, copied graphics, stock hardware sounds, synthesis emulation, clock/alarm functions, or its complete effects catalog. The owner has explicitly narrowed that scope. Hardware-reference features come from the [official PO-12 guide](https://teenage.engineering/guides/po-12/en); all app-specific behavior below is our product design.

## 3. Resolved clarifications and implementation defaults

### 3.1 Owner-confirmed clarifications

The owner answered all three final product questions before finalization:

| ID | Decision | Required behavior |
|---|---|---|
| D-01 | Count-in once when pressing Play | Four clicks at the starting BPM; none at loop or chain boundaries |
| D-02 | Chains may combine different kits and BPMs, with tempo adjustment while arranging | Each entry inherits its pattern BPM unless an entry-specific override is set; overrides belong to the chain and leave source patterns unchanged |
| D-03 | Personal iPhone app; three default kits delivered through Codex | Integrate supplied files as bundled resources; every installed copy includes all three kits without another download |

No product clarification remains open. Actual sound files, ambiguous filenames, device access, and signing configuration are implementation dependencies. A **Set All Entry Tempos** action is an engineering default supporting the requested ability to make patterns fit together.

### 3.2 Other chosen defaults

- Product and app name: PocketBonham.
- Portrait-first iPhone UI; landscape and iPad-specific layouts are outside version 1.
- Deployment baseline: iOS 18.0, using APIs compatible with that baseline. The implementation agent must verify the owner's installed iOS and installed SDK before device deployment. Xcode 26.3 is installed on the specification workspace as of the preparation date; that is an environment observation, not a required fixed toolchain version.
- Entirely offline; no backend, accounts, analytics, subscriptions, or advertising.
- BPM range: integer 40–240, default 120. This is an app choice.
- Swing: 50–75%, default 50% (straight timing), defined mathematically below.
- Maximum 16 playable instruments per kit; accept variable counts without dummy instruments.
- Pattern/chain library: no arbitrary product cap; target at least 1,000 patterns and 200 chains within ordinary local-storage limits.
- Chain capacity: 64 entries, each repeating its referenced pattern 1–16 times; chains loop until Stop. This deliberately exceeds the hardware's compact arrangement model.
- Room reverb is included as an optional, off-by-default control in the full first version, after core timing is verified.
- Metronome after the count-in is optional and off by default. Count-in itself is required.
- Undo is required; Redo is a small companion control in the edit menu.
- No external synchronization, MIDI, AUv3 hosting, microphone recording, or mixing instruments from different kits in one pattern.

## 4. Product outcomes and user journeys

### 4.1 Create and save a loop

1. Launch the app and select New Pattern.
2. Choose one available kit and enter a pattern name when saving.
3. Select an instrument; toggle steps in its 4 × 4 step grid.
4. Repeat for other instruments, retaining simultaneous hits across tracks.
5. Set BPM and optionally swing, hit level, pitch, decay, or retriggers.
6. Press Play; hear four quarter-note count-in clicks, then the bar continuously.
7. Adjust the pattern while listening, use Undo when needed, and press Save.
8. Relaunch the app, open the pattern from the pattern library, and hear the same saved arrangement and sound settings.

### 4.2 Record by tapping pads

1. Open a pattern and switch to Play Pads.
2. Arm Record, then press Play.
3. After the count-in, tap instrument pads; hear immediate feedback.
4. Hits are quantized to the pattern's swung sixteenth-note grid and overdubbed across passes.
5. Disarm Record without stopping playback, or press Stop.
6. Undo a recording pass as one useful action, then save.

### 4.3 Assemble a chain

1. Open Chains and create a new chain.
2. Choose patterns from the complete saved pattern library.
3. Add the same pattern more than once, reorder entries, or change entry repeat counts.
4. Name the chain; keep each pattern BPM, override individual entries, or set all entry tempos together.
5. Press Play; one count-in leads into continuous bars in the selected order.
6. Highlight the active chain entry and repeat; loop from the last entry to the first without a gap.
7. Save and later load the chain independently of the pattern editor.

### 4.4 Perform without modifying the composition

During playback, mute the snare or solo the kick and toms. These performance controls do not erase programmed notes. Stop, reopen the item, and hear its saved musical content with transient mute/solo states reset.

## 5. Terminology and state ownership

| Term | Meaning |
|---|---|
| Kit | A named collection of available one-shot instrument assets |
| Instrument | One playable part of a kit with a stable role ID and one sample |
| Track | An instrument's 16 steps plus its base sound parameters within a pattern |
| Step | One sixteenth-note position, shown as 1–16; stored as index 0–15 |
| Hit | An enabled track step with level, retrigger count, and optional pitch/decay overrides |
| Parameter lock | A saved per-step override of the track's normal sound parameter |
| Pattern | One named 4/4 bar with kit, tracks, BPM, swing, and room setting |
| Chain | A named ordered list of references to saved patterns plus repeat counts and optional entry BPM overrides |
| Draft | Recoverable editing state that has not necessarily been explicitly saved to the library |
| Snapshot | An immutable playback representation prepared outside the audio callback |
| Transport | The common clock and playback state for either a pattern or a chain |

Ownership rules:

- Kit owns sample identity and asset metadata; patterns never embed decoded PCM.
- Pattern owns note data, sound parameters, swing, and preferred standalone tempo.
- Chain references pattern UUIDs, not library positions or names, and owns entry-specific tempo overrides.
- App preferences own master level, metronome volume, and UI selections.
- Mute/solo, playhead, count-in progress, and Record-armed state are transient.
- Changing a kit's display name or a pattern's name never breaks references.

## 6. Interface specification

### 6.1 Visual direction

Use a compact instrument-panel composition: warm neutral casing, dark high-contrast display area, restrained colored LEDs/highlights, crisp labels, and satisfying pad states. The small display can show name, tempo, beat position, and count-in. Original graphics and typography must remain legible rather than reproducing tiny hardware markings.

No required operation may depend on simultaneously holding two virtual buttons. Rotary-looking controls must also support direct value editing or accessible increment/decrement actions. Distinguish selected instrument, enabled step, currently playing step, muted track, and soloed track by shape/text as well as color.

### 6.2 Navigation and screens

Use three primary destinations: **Pattern**, **Library**, and **Chains**. Kit selection, step detail, mixer, and preferences can be sheets. Transport is available on the pattern and chain screens; switching tabs never starts a second transport.

Pattern screen, top to bottom:

1. Pattern name, saved/unsaved indicator, New and Save actions.
2. Display panel: kit name, BPM, swing, beat/count-in state.
3. Instrument selector showing actual kit instruments only; selected instrument remains obvious.
4. Explicit **Steps / Play Pads** mode selector.
5. Steps mode: 4 × 4 grid, reading 1–4, 5–8, 9–12, 13–16; label rows as beats 1–4. All 16 touch targets are usable without horizontal scrolling.
6. Play Pads mode: instrument pads, ordered consistently; more than eight may scroll vertically or use a compact second page, without shrinking touch targets.
7. Play/Stop, Record, Undo; accessible Step Details and Mixer actions.

In Steps mode, tapping an instrument selector selects its track; a dedicated audition action plays it. In Play Pads mode, touching a pad triggers sound on touch-down. Scrolling/selecting controls must not insert notes accidentally.

Step detail sheet: selected step and instrument, enable toggle, level 1–127, retriggers, pitch override, decay override, and Reset Step. Long-press is a shortcut; an explicit Details action must offer the same function. Disabling a step preserves its settings until Reset Step.

Mixer sheet: instrument label, base level, pitch, decay, Mute, Solo. Provide **Clear Mutes/Solos**. Show “Muted” or “Solo” status on the main screen so a silent kit is explainable.

Pattern library: name, kit, BPM, modified date; search by name, sort by name/recent, open, rename, duplicate, delete. Chains use a separate list or library segment and show name, number of entries, expanded bars, and either one effective BPM or “Mixed tempo”. No tiny one-bar preview is required.

Chain editor: name, ordered entry cards showing pattern name, kit, inherited/effective BPM, optional tempo override, repeat count, drag handle, remove action, Add Pattern, Set All Entry Tempos, total bar count/duration, Save, Play/Stop, Undo. Provide accessible move-up/down alternatives to dragging. Display progress such as “Entry 2/4 · Repeat 1/3 · Beat 3”.

### 6.3 Interaction and accessibility

- Primary controls MUST have at least 44 × 44 point hit areas.
- Respect safe areas and the iPhone 16 display cutout.
- Standard and accessibility text sizes must not hide Play, Stop, Save, or Undo; sheets may scroll.
- VoiceOver announces instrument, step number, enabled state, current value, and mute/solo states.
- Do not announce every running step automatically through VoiceOver; expose position on demand.
- Reduced Motion removes decorative animation while retaining essential position feedback.
- Multitouch pad performance must support at least four simultaneous fingers; entering a chord across different drums must not serialize into obvious flams.
- No destructive action is hidden behind a single accidental pad tap.

## 7. Pattern and sound requirements

### 7.1 Sequencing

**PAT-01:** Every track has exactly 16 steps. Each pattern spans four quarter notes. Multiple instruments may trigger on the same step.

**PAT-02:** Step edits work while stopped or playing. An edit to a future step takes effect at its next not-yet-rendered occurrence. An already-rendered hit is not replayed; if its onset has passed, the edit is heard next bar.

**PAT-03:** New patterns are empty, at 120 BPM and straight swing, with the last selected usable kit, neutral pitch, natural sample decay, no retriggers, and room off.

**PAT-04:** Copy Pattern creates a distinct UUID with the same musical contents. Clear Track and Clear Pattern are undoable; Clear Pattern clears notes and locks but keeps kit, tempo, swing, and base track settings. Offer clear labels for each scope.

**PAT-05:** A pattern uses exactly one kit. Changing kits is allowed only while stopped. Map matching instrument role IDs; if active notes would lose their instrument, show the affected tracks and offer Cancel or Change Kit and Remove Those Tracks. The entire switch is one undoable operation. Never silently substitute another instrument.

### 7.2 Parameters

| Parameter | Scope | Range/default | Semantics |
|---|---|---|---|
| BPM | Pattern; optional chain-entry override | 40–240 / pattern default 120 | Quarter notes per minute; an unset override follows the source pattern |
| Swing | Pattern | 50–75% / 50% | First portion of each adjacent sixteenth pair |
| Hit level | Enabled step | 1–127 / 100 | Linear amplitude multiplier `level / 127`; no hidden random variation |
| Track level | Track | 0–1 / 0.8 | Additional linear gain |
| Pitch | Track + step override | −12 to +12 semitones / 0 | Sample-rate playback ratio `2^(semitones/12)`; duration changes with pitch |
| Decay | Track + step override | 0.05–1 / 1 | Fraction of pitch-adjusted natural sample duration; 1 preserves its natural tail |
| Retriggers | Step | 1, 2, 4, 8, 16 / 1 | Total equally spaced hits within that swung step interval |
| Room amount | Pattern | 0–30% / 0, Off | Wet/dry proportion with one short drum-room preset |
| Master level | App preference | 0–1 / 0.7 | Applies to all audible output including clicks |
| Click level | App preference | 0–1 / 0.35 | Separate click gain before master |

At decay below 1, shorten the pitch-adjusted sample duration to the selected fraction and use a short release ramp to avoid a cutoff click. Do not implement decay by shifting note timing. Exact ramp design must be documented and verified with both short kicks and long cymbals.

### 7.3 Parameter locks and automation

**PAR-01:** Each hit may have optional pitch and decay overrides. No override means use the track value; a lock applies only to that hit and its retriggers and never leaks to another step.

**PAR-02:** Level and retrigger count are stored directly on each step. Lock indicators appear on steps with pitch/decay overrides. Provide reset for one lock, all locks on a track, and all locks on a pattern, each undoable.

**PAR-03:** Support recording pitch/decay changes while a pattern plays. A clearly labeled **Record Motion** mode writes the selected track's control value into each triggered step encountered during the gesture. It does not create hits on disabled steps. A step visited multiple times retains the latest recorded value. Outside Record Motion, adjusting a track control changes its base value only.

**PAR-04:** One control drag is one undo action, even if it writes multiple locks. Existing locks retain priority over base values until cleared. Chain mode is playback/arrangement only; pattern note recording and motion recording are disabled there.

### 7.4 Retriggers, overlap, and hats

**SND-01:** Ordinary sample tails may cross step, bar, and chain boundaries. Repeated snare, tom, and cymbal hits can overlap; a single player per instrument that cuts every preceding hit is not sufficient.

**SND-02:** Closed and open hats share a choke group. Either hat trigger releases any prior hat voice over a short ramp. If both are scheduled at precisely the same time, the closed hat wins and the open-hat onset is suppressed. If only one hat exists, it remains playable.

**SND-03:** Retriggers inherit that step's level and parameters. They do not add extra grid steps, change bar length, or imply a stutter audio effect.

**SND-04:** Use at least 64 concurrent sample voices. If saturated, steal the quietest releasable tail first, then the oldest voice, deterministically, with a short ramp. No crash, allocation burst, or unbounded voice growth is acceptable. Polyphony saturation is documented in stress testing.

## 8. Transport, clock, and recording

### 8.1 Transport state machine

```text
Stopped → Preparing → CountingIn → Playing
                    ↘ Error → Stopped
Preparing / CountingIn / Playing → Stop → Stopped
Any active state → app inactive / interruption / route loss → Stopped
```

- Only one pattern or chain can own transport.
- Preparing resolves a complete usable playback snapshot and preloads required samples before any count-in.
- Play is disabled while preparing; Stop/Cancel remains available. Repeated taps cannot enqueue extra starts.
- Stop always resets the playhead to the start. Version 1 has no Pause/Resume ambiguity.
- Starting a different item stops the current one and begins its own count-in.
- Stop cancels scheduled future hits, releases voices briefly, clears reverb tails, and disarms recording.
- Loading, deleting, or replacing the active item stops transport before the change. Navigation within the app may keep playback running.

### 8.2 Four-count behavior — confirmed D-01

**CLK-01:** On every explicit Play from Stopped, produce four audible quarter-note clicks and display **1, 2, 3, 4**. At 120 BPM these occur at 0.0, 0.5, 1.0, 1.5 seconds relative to the first click; the first pattern step occurs at 2.0 seconds. The delay for initial sample preparation is separate.

**CLK-02:** Count-in uses the standalone pattern BPM or the first chain entry's effective BPM, is not swung, and is independent of the optional ongoing metronome setting. No drum notes sound automatically during count-in. Pads may be auditioned, but count-in taps are not recorded or quantized into the previous bar.

**CLK-03:** Loop wraps, repeat entries, and chain transitions have no count-in. Stop followed by Play has a new count-in. Tempo editing is disabled during count-in; Stop remains available.

**CLK-04:** Ongoing metronome, if enabled, ticks on all quarter notes and accents beat 1; it bypasses room reverb and does not become pattern data. Turning it off does not disable the mandatory count-in. The user may adjust click level above zero; device/master volume still affects audibility.

### 8.3 Musical time and swing

Let `B` be quarter-note BPM and `s` be swing as a fraction between 0.50 and 0.75:

```text
quarterDuration = 60 / B seconds
barDuration = 4 * quarterDuration
pairDuration = quarterDuration / 2
stepOnset(2k) = k * pairDuration
stepOnset(2k + 1) = k * pairDuration + s * pairDuration
k = 0...7
```

The even step's interval is `s * pairDuration`; the following step's interval is `(1 - s) * pairDuration`. Beat onsets remain fixed at steps 1, 5, 9, and 13. At 120 BPM and 50% swing, steps are 125 ms apart and the bar is 2 seconds. At 66⅔% swing, alternating intervals are approximately 166.667 and 83.333 ms.

For retrigger count `r`, schedule hits at `stepStart + j * stepInterval / r`, for `j = 0...(r-1)`. The last step uses the bar boundary as its end. Retriggers never spill past their step due to interval calculation, although their sample tails may ring.

**CLK-05:** Musical timing is driven by the audio sample clock, not SwiftUI refreshes, `Timer`, `sleep`, or one async task per hit. Convert absolute musical times into integer frame positions with rounding of absolute positions or carried fractional remainder. Repeatedly rounding a duration and accumulating it is prohibited because it causes drift.

**CLK-06:** During standalone pattern playback, BPM and swing edits queue for the next bar boundary with a visible Pending indicator. The old bar completes at its old settings. Multiple pending changes coalesce to the latest value; Undo updates or cancels them. During chain playback, arrangement edits, including entry tempo overrides, apply on the next Play; show “Changes apply next playback”. The current run uses its start-time tempo plan.

**CLK-07:** At a chain entry boundary, the preceding bar completes at its own BPM and the next bar starts immediately at the incoming entry's effective BPM. No tempo ramp, inserted silence, extra click, or count-in occurs. Repeats keep their entry tempo; chain wrap restores the first entry's tempo. Accumulate absolute bar durations with fractional-frame precision even when BPM changes. Existing sample tails retain their original pitch; tempo changes subsequent scheduling, not sample playback speed.

### 8.4 Live recording

**REC-01:** Arm Record while stopped, then Play, or arm while already playing. Recording begins after the count-in or on the next not-yet-rendered event when armed during playback. It is an overdub; existing hits remain.

**REC-02:** Capture touch-down timestamps on a monotonic clock correlated to the audio clock. Quantize to the nearest swung sixteenth onset on the continuous timeline, including adjacent bars; ties choose the later onset. Near the end of a bar, a hit can quantize to step 1 of the next pass. Do not use callback arrival time as the timestamp when the original touch timestamp is available.

**REC-03:** Live taps are heard immediately using the same sampler, independent of their saved quantized position. A tap's newly recorded step is not separately played again on the same pass after its live audition. Its stored trigger becomes eligible on the following loop pass. An already-existing scheduled hit may still sound; describe this overdub behavior in help.

**REC-04:** Multiple taps into the same instrument/step on one pass result in a single enabled step, using the most recent level. They do not automatically infer rolls. Explicit retrigger settings remain unchanged unless edited.

**REC-05:** Touch pressure is not a requirement. Pads use a selected recording level, default 100, with optional normal/accent selection. Record by touch-down, not touch-up.

**REC-06:** Each completed recording bar is one undo group; a partial pass becomes a group when stopped/disarmed. Undo during recording first commits and disarms the current pass, then reverts that pass, leaving playback running. If no change occurred, revert the prior edit. Stop, app interruption, and scene deactivation end the current group without losing already-recorded hits.

## 9. Kits and sample asset contract

### 9.1 Delivery — confirmed D-03

The owner provides three folders through this Codex conversation. The implementation agent inspects the supplied files, places the sounds under bundled resources, and prepares a validated manifest per kit. The owner should not have to hand-author JSON. Every installed copy, including a copy used by a friend, includes the three default kits and works offline. Version 1 has no in-app importer. Personal-device installation is the initial distribution target; runtime assets must never depend on temporary attachment paths or the developer's computer.

```text
Resources/Kits/
  Kit 1/
    kick.wav
    snare.wav
    highhat.mp3
    openhat.mp3
    lowtom.wav
    hightom.wav
    crash.wav
    ride.wav
  Kit 2/
    ...
  Kit 3/
    ...
```

**KIT-01:** Each kit has a stable ID, display name, version, and 1–16 valid instruments. Expected delivery is at least eight roles; do not reject an otherwise usable kit only because a listed role is absent. The UI shows exactly the supplied instruments. There is no fallback instrument borrowed from another kit.

**KIT-02:** Normalize names case-insensitively, ignoring spaces, underscores, and hyphens when proposing role mappings. Preserve original filenames. Suggested aliases:

| Role ID | Recognized examples |
|---|---|
| `kick` | kick, bassdrum, bd |
| `snare` | snare, snaredrum, sd |
| `closedHat` | highhat, hihat, closedhat, closedhihat, chh |
| `openHat` | openhat, openhihat, ohh |
| `tomLow` | lowtom, tomlow, floortom |
| `tomMid` | midtom, tommid |
| `tomHigh` | hightom, tomhigh |
| `crash` | crash, crashcymbal |
| `ride` | ride, ridecymbal |

Numbered or additional toms get distinct explicit stable IDs, such as `tomExtra1`; the manifest defines their order and labels. Do not guess pitch ordering from `tom1` versus `tom2`. Resolve ambiguous mappings once during asset integration and report the result. Duplicate files mapped to the same role must be resolved, not silently overridden.

**KIT-03:** Initial supported formats: uncompressed PCM WAV (16/24-bit integer or 32-bit float) and decodable MP3; mono/stereo; 44.1 or 48 kHz; duration above zero and at most 30 seconds per instrument. Other sample rates may be converted if validated, but are outside the required input matrix. Files outside limits produce a named diagnostic. Do not infer codec validity solely from extension.

**KIT-04:** Decode files off the audio thread into the chosen runtime float PCM format. Preserve stereo samples; duplicate mono appropriately. Normalize sample rate, not loudness, by default. Preserve intentional silence/tails. MP3 may carry encoder padding or leading silence; inspect supplied assets and use explicit non-destructive start/end metadata if needed, rather than trimming attacks automatically.

**KIT-05:** At a kit failure, identify kit, instrument, filename, and reason. A failed required asset makes that kit unavailable for playback until corrected. Other valid kits remain usable. Missing a role that was never declared in a kit is normal, not an error.

**KIT-06:** Never rename stable kit or instrument IDs casually after patterns exist. Keep bundled asset contents/version/hash in the catalog; a replacement that changes an existing sound must be deliberate and recorded. Avoid shipping absolute development-machine paths.

**KIT-07:** During development before owner assets arrive, use clearly labeled synthetic test fixtures. Do not represent placeholder sounds as the three finished kits. Final audio acceptance requires the actual owner-supplied assets.

Illustrative manifest shape:

```json
{
  "schemaVersion": 1,
  "id": "kit-1",
  "name": "Kit 1",
  "assetVersion": 1,
  "instruments": [
    {"id": "kick", "name": "Kick", "file": "kick.wav", "order": 0},
    {"id": "closedHat", "name": "Closed Hat", "file": "highhat.mp3", "order": 2, "chokeGroup": "hats"},
    {"id": "openHat", "name": "Open Hat", "file": "openhat.mp3", "order": 3, "chokeGroup": "hats"}
  ]
}
```

This manifest is an abbreviated structural example, not the final three kits. Path entries must remain relative to the kit directory and be validated against traversal.

## 10. Independent pattern and chain libraries

### 10.1 Naming, saving, and drafts

**LIB-01:** New/Save/Rename/Duplicate/Open/Delete exist for both patterns and chains. Names contain 1–64 visible characters after trimming surrounding whitespace; reject an all-whitespace name. Preserve Unicode. Stable UUIDs determine identity; names are not filesystem paths. Duplicate names are allowed, with kit/date information to distinguish them. Duplicate initially proposes a “Copy” suffix.

**LIB-02:** Explicit Save commits the current draft to the library and reports success only after durable replacement completes. A failed save leaves the previous saved version intact and the unsaved draft recoverable. Save is not a fake UI acknowledgement of a queued write.

**LIB-03:** Debounced draft recovery writes occur within 500 ms after editing settles, with a best-effort flush on scene deactivation. Explicit Save remains distinct from recovery autosave: editing a pattern must not silently update every chain that references its saved version.

**LIB-04:** Leaving an unsaved draft for another item offers Save, Keep Draft, or Discard. Recovery records are keyed by entity UUID/draft UUID and survive relaunch. Opening an item with a recovery draft offers Resume Draft or Open Saved Version; discarding recovery never deletes its saved item. New unnamed drafts receive a temporary label and ask for a name only at explicit Save.

**LIB-05:** On relaunch, restore the last selected workspace and recoverable data but keep transport stopped, record disarmed, and mute/solo reset. App suspension/termination cannot guarantee a final write; the recovery debounce bounds the ordinary loss window. Do not promise immunity to OS termination or device failure.

### 10.2 Chain behavior — confirmed D-02

**CHN-01:** A chain is an ordered list of 1–64 entries, each storing its own entry UUID, a saved pattern UUID, a repeat count from 1–16, and an optional integer BPM override from 40–240. The same pattern can appear multiple times. An empty chain can exist as a draft, but Play is disabled and explicit Save requires at least one entry.

**CHN-02:** The Add Pattern picker searches the entire saved pattern library. A pattern has no project/bank membership restriction. Unsaved pattern drafts must be saved before they can be referenced.

**CHN-03:** A new entry defaults to **Use Pattern BPM**. Effective tempo is `entry.bpmOverride ?? savedPattern.bpm`, resolved in the playback snapshot. An explicit override changes only that entry and its repeats. Two entries referencing the same pattern may have different overrides. Each retains its source pattern's kit, swing, notes, track settings, and room setting. Entry tempo never changes sample pitch or the source pattern BPM.

**CHN-04:** Repeat count expands an entry into that many consecutive bars. The final bar loops directly into the first entry. There is no count-in between entries, repeats, or chain wraps.

**CHN-05:** Resolve a playback snapshot of every referenced saved pattern before Play. If a referenced pattern is edited and saved while a chain is running, the current run retains its start-time snapshot; next Play picks up the saved revision. Show that updated content will take effect next playback. Chain structure and entry-tempo edits likewise take effect on the next Play; immediate mute/solo is the explicit exception.

**CHN-06:** Pattern rename updates chain labels; content changes appear on the next resolved run. Deleting a referenced pattern is blocked with the names/count of referencing saved chains and chain drafts. Offer Cancel or navigation to edit those chains, not silent cascading deletion. Pattern duplication leaves existing references unchanged.

**CHN-07:** A missing reference or unavailable kit detected through corruption/assets must disable chain playback with an actionable list; do not silently skip bars or substitute sounds. Other unaffected library items remain usable.

**CHN-08:** Preload all unique sample assets required by the chain within the declared memory budget. Kit changes happen at bar boundaries with no file I/O, decoder creation, graph rebuild, or preparation gap on the audio thread. Outgoing tails may ring through the boundary under the same voice/choke rules. Room amount is smoothed into the incoming pattern value; existing room energy is not reset at each bar.

**CHN-09:** Chain mute/solo is transient, keyed by kit ID plus instrument ID. When switching kits, show that kit's controls; previous temporary choices for that kit persist for the current run. At each kit, solo eligibility considers only that kit's instruments. Restart/load resets all overrides.

**CHN-10:** Provide **Set All Entry Tempos**: write one chosen BPM override to all current entries as one undoable action. Newly added entries still inherit their pattern BPM; label the action to clarify its one-time scope. Provide **Reset All to Pattern BPMs** and per-entry **Use Pattern BPM**. Overrides survive save/relaunch. There is no conflicting global chain BPM field.

**CHN-11:** Show inherited and overridden tempos explicitly, e.g. “Pattern: 95 BPM · Play at: 110 BPM”. Total musical duration is `sum(repeatCount * 4 * 60 / effectiveBPM)` seconds, excluding the count-in. Example: A at 100 BPM repeated twice, then B at 140 BPM once, has 6.514286 seconds of music. Overriding both entries to 120 BPM gives 6 seconds and leaves A saved at 100 and B at 140. The count-in adds four beats at the first effective BPM once.

### 10.3 Undo/redo

**UND-01:** Visible Undo works for step edits, parameter changes, motion gestures, recording passes, clear actions, kit swaps, names in a draft, and chain entry edits. Maintain at least 100 user-level edit groups per open draft during the session.

**UND-02:** A slider drag and a drag-reorder are single groups. A new edit clears redo. Save does not clear undo: undoing after Save produces a new unsaved draft. Undo may restore note content but must never restart transport or replay a live hit.

**UND-03:** Mute/solo changes are undoable in the current editor session, but remain transient and do not dirty the saved composition. Play/Stop, navigation, previews, and library sort/filter changes are not undoable musical actions.

**UND-04:** Persisted-library deletion is outside ordinary edit undo. Require an explicit confirmation showing the item name. Referenced-pattern protection takes priority. Redo and undo history need not survive application termination; recovered musical state must.

## 11. Mute, solo, and room sound

**MIX-01:** Multiple instruments can be soloed. Effective audibility is `notMuted && (noSoloInActiveKit || isSolo)`. Mute wins when an instrument is both muted and soloed. Visually expose both states.

**MIX-02:** Mute and solo change audibility within the next available audio buffer with a short gain ramp. They suppress both sequenced and live-pad sound for the affected instrument; recording a muted pad may still write its step, with visible feedback. Existing dry voices are ramped out. Already-created shared reverb energy may decay naturally; do not claim per-track removal from a shared room tail.

**MIX-03:** The room effect has Off/On and an Amount control, using a short, restrained room preset. No user-facing delay, distortion, filter, stutter, or expanded multi-effect page is included. Internal anti-aliasing, gain ramps, and transparent output protection are implementation details, not excluded creative effects.

**MIX-04:** Room is post drum mix and before master level. Clicks bypass it. Smooth amount changes to avoid zipper noise. Off is audibly dry and clears leftover room energy using a short transition. Persist the pattern's room preference.

## 12. Foreground and audio-session behavior

**LIFE-01:** While the main app scene is foreground-active, disable the system idle timer so the visible instrument remains available even without touches. Restore the idle timer when the scene becomes inactive/background. This prevents ordinary auto-lock; it cannot prevent manual lock, OS termination, or system interruption. Apple exposes this through [UIApplication.isIdleTimerDisabled](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled).

**LIFE-02:** On leaving the active scene, stop all drum and click playback, cancel count-in, disarm recording, flush recovery best-effort, and release the idle-timer override. Return to Stopped when active again. Never automatically resume an interrupted groove. A new Play includes the full count-in. The same rule applies to Control Center and other inactive-scene transitions for predictable behavior.

**LIFE-03:** Do not enable background audio capability, lock-screen transport, or background keepalive. In-app sheets and navigation remain within the app and are not reasons to stop unless the operation explicitly changes transport ownership.

**LIFE-04:** Configure `AVAudioSession` for `.playback`, mode `.default`, nonmixing by default. Output should remain available with the phone's silent switch enabled. Activate when audio is needed, release when leaving the app, and restore other audio on deactivation as appropriate. Follow [Apple's audio-session model](https://developer.apple.com/documentation/avfaudio/avaudiosession); do not request microphone permissions for sample playback.

**LIFE-05:** Observe interruptions, audio engine configuration changes, media-services resets, and route changes. Stop on interruption or output-route change, rebuild/preload outside the callback if necessary, and let the user restart. Do not suddenly redirect an ongoing performance from disconnected headphones to the speaker. See [Apple's interruption guidance](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions).

**LIFE-06:** Support the built-in speaker and system-supported wired/USB and Bluetooth output. Bluetooth latency is route-dependent; do not promise wired-like finger-drumming response. Show the route in an audio status sheet, with a brief Bluetooth latency note when relevant. Musical scheduling stays consistent; output latency affects feedback and playhead compensation.

## 13. Technical architecture

### 13.1 Stack and boundaries

- Native Swift app with SwiftUI presentation, plus narrowly scoped UIKit touch handling if needed for reliable multitouch/timestamps.
- AVFoundation/AVFAudio for decoding, engine, session, and room effect.
- Codable value models and local JSON files for versioned library data; no database/server is needed for this scale.
- XCTest or Swift Testing for domain/scheduling/persistence tests; XCUITest for essential workflows.
- Prefer Apple frameworks. Any added dependency needs a concrete benefit, supported deployment target, pinned version, and documented license; do not add a large audio/UI framework for convenience alone.

Separate modules or folders:

```text
PocketBonham/
  App/                  App lifecycle, composition root, navigation
  Domain/               Pattern, Chain, Kit, validation, edit commands
  Audio/                Transport, render clock, sampler, voices, room, session
  Persistence/          Repositories, atomic writes, migrations, recovery
  Features/Pattern/     Step editor, live pads, motion recording
  Features/Library/     Pattern and chain browsing
  Features/Chain/       Arrangement editor and playback progress
  Features/Mixer/       Instrument parameters, mute/solo, room
  SharedUI/             Pads, display panel, accessible value controls
  Resources/Kits/       Three folders and generated/curated manifests
PocketBonhamTests/
PocketBonhamUITests/
docs/
```

### 13.2 Audio engine recommendation

Preferred path: `AVAudioEngine` with an `AVAudioSourceNode` rendering a preallocated polyphonic sampler, drum-room processing, a dry click path, and master output. App and control logic remain Swift. The real-time sample-rendering implementation must be allocation-free and have explicit ownership; if a tiny C/C++ render kernel is required to guarantee this with the selected Swift toolchain, document the rationale and keep that bridge isolated. Do not rewrite the application in another language.

The implementation may choose a proven scheduled-player alternative only if it demonstrates all required per-hit parameters, overlap, retriggers, live edits, and frame-level timing within the same performance limits. Do not create a new `AVAudioPlayer` for every note.

Apple's [source-node render callback documentation](https://developer.apple.com/documentation/avfaudio/avaudiosourcenode/init(renderblock:)) establishes the real-time constraint. Our stricter design rules are: no file access, decoding, logging, locks, actor hops, dispatch, heap allocation, UI access, or object destruction in the render path. Inspect generated behavior and profile rather than assuming Swift code is automatically safe.

### 13.3 Threading and command delivery

- Main actor owns UI state; a control layer serializes edits into immutable playback snapshots and bounded commands.
- Render thread owns the sample cursor, active voices, event execution, and current playback snapshot.
- Preallocate voice pools, click data, queues, and event scratch space before Play.
- Use a bounded, audited nonblocking handoff. Coalesce parameter updates when necessary; transport Stop must not be lost behind ordinary control traffic.
- Never free a sample buffer/snapshot while a render voice can reference it. Retire resources only after a render acknowledgement, and deallocate outside the audio callback.
- UI reads a lightweight published playhead snapshot; it does not drive the clock.
- Use generation IDs to reject stale pending work after Stop, route changes, or a new Play.
- Define deterministic simultaneous-event ordering: transport changes, snapshot changes, choke resolution, then ordered instrument triggers.

### 13.4 Formats, preloading, and gain

Use float PCM internally, with a preferred 48 kHz engine configuration but adapt to the negotiated hardware rate. Request a low I/O buffer duration around 5 ms; inspect actual values after activation. Preferences are requests, not guarantees, as [Apple's audio preference guidance](https://developer.apple.com/library/archive/qa/qa1631/_index.html) explains.

Decode via supported Apple APIs into buffers and convert on a worker queue. [AVAudioFile](https://developer.apple.com/documentation/avfaudio/avaudiofile) exposes PCM buffers irrespective of the readable source format. Validate actual WAV/MP3 fixtures before treating compatibility as complete.

Cache decoded assets by stable kit/instrument/version identity and runtime format. Limit decoded PCM cache to 192 MiB, with inactive-kit eviction while stopped. If a requested playback snapshot exceeds budget, fail preparation with a clear asset-size message instead of risking termination; the delivery validator must verify all three real kits together fit within the supported budget for cross-kit chains.

Preserve natural attacks. Use band-limited resampling or equivalent validated pitch conversion, short gain ramps, and mix headroom. A transparent output limiter/peak guard prevents invalid or clipped output on dense mixes; measure its latency and include it in visual timing/latency reporting. Do not normalize every hit to equal loudness. Reject nonfinite decoded samples or sanitize them during preparation.

## 14. Data model and persistence contract

### 14.1 Required model fields

| Model | Fields |
|---|---|
| Pattern | schemaVersion, UUID, revision, name, createdAt, updatedAt, kitID, kitAssetVersion, bpm, swing, tracks, room |
| Track | instrumentID, baseLevel, basePitchSemitones, baseDecay, exactly 16 Steps |
| Step | enabled, level, retriggerCount, optional pitchLock, optional decayLock |
| Room | enabled, amount; fixed preset identifier/version |
| Chain | schemaVersion, UUID, revision, name, createdAt, updatedAt, ordered entries |
| ChainEntry | UUID, patternID, repeatCount, optional bpmOverride |
| RecoveryDraft | schemaVersion, entityType, draftID, optional savedEntityID, baseRevision, updatedAt, complete working model |
| Preferences | schemaVersion, masterLevel, clickLevel, metronomeEnabled, lastKitID, lastWorkspace |

Use UUID strings, UTC ISO-8601 timestamps, finite numeric values, and explicit schema versions. Track order is driven by the selected kit manifest. Unknown instruments, out-of-range values, wrong step counts, duplicate IDs, and invalid references fail validation with useful diagnostics; do not force-decode unchecked data.

No persistence fields for transient voices, mute/solo, active record state, playhead, or transport state. Chain references use the current saved pattern revision at each new playback start; they do not permanently pin historical revisions.

### 14.2 Files and transactions

```text
Application Support/PocketBonham/
  patterns/<uuid>.json
  chains/<uuid>.json
  recovery/<draft-uuid>.json
  preferences.json
  backups/              Bounded previous valid saved revisions
  quarantine/           Unreadable/corrupt records retained for diagnosis
```

**DAT-01:** Write a temporary file on the same volume, validate encoding, atomically replace the destination, then update in-memory saved status. Serialize saves per entity to prevent older writes overwriting newer edits. Retain one prior valid revision per entity as local recovery support; this is not a user-facing export feature.

**DAT-02:** An index may accelerate lists but is rebuildable from canonical files. Interrupted index updates must never make intact patterns disappear permanently. File deletion and reference checks use the same serialized repository boundary to avoid creating dangling chains during concurrent saves.

**DAT-03:** A malformed file does not crash library loading or erase other records. Preserve the original, surface an item-level problem, and offer restoration from a valid local backup. Unknown future schema versions remain untouched and are reported as unsupported.

**DAT-04:** Migration reads and validates old data, writes a new copy, and retains the original until success. Include migration fixtures from the first schema change. A no-op version-1 migration framework is enough initially; invented migration complexity is not required.

**DAT-05:** If the saved revision differs from a recovery draft's base revision, do not silently overwrite. Offer opening the saved version or recovering the draft as a separate copy. Serial repository writes and main-actor state updates must make Save/Undo races deterministic.

## 15. Performance and reliability acceptance targets

These are product targets requiring measurement, not claims of existing performance. Test Release configuration on an actual iPhone 16, recording iOS version, output route, sample rate, and I/O duration.

| Area | Required gate or target |
|---|---|
| Sequencer placement | Offline event onsets within one frame of the defined absolute-frame schedule, including noninteger step lengths |
| Clock drift | No cumulative arithmetic drift beyond one frame against the expected timeline across at least 10 minutes at 137 BPM |
| Loop/chain continuity | No unintended inserted frames, count-ins, missed first hits, or duplicated boundary hits |
| Live response | Target median touch-to-audible onset ≤25 ms and p95 ≤40 ms on speaker/wired output; report actual method/results; Bluetooth excluded |
| Visual position | Target within 50 ms of audible position on speaker/wired output using route latency compensation |
| Stability | At least 60 minutes of continuous foreground playback without crash, stuck transport, or detected render underruns in the defined test workload |
| Memory | ≤192 MiB decoded cache; target total resident memory <300 MiB with the delivered kits; no sustained growth after warm-up |
| UI | Responsive editing and scrolling during playback; target display-native smoothness without blocking main-thread audio preparation |
| Startup | Target ready-to-edit within 2 seconds and ordinary kit readiness within 1 second on the test device |
| Library | Target open/search under 500 ms for 1,000 patterns after index load; persistence must remain asynchronous to audio |
| Save | Durable ordinary-item save under 500 ms in normal storage conditions; visible recovery path on failure |

Record empirical metrics honestly. If a target fails, profile, repair, and retest or document the concrete device/route limitation before marking the release complete. Do not claim acoustic latency from a timestamp recorded only inside the UI. Event scheduling tests and audible-output measurements answer different questions.

Stress workload: all 16 synthetic instrument tracks enabled, maximum tempo, swing extremes, dense retriggers, long sample tails, room on, frequent mute/solo, and repeated chain kit changes. Voice stealing under this deliberately saturated workload is permitted as specified; timing drift, unbounded memory, crashes, and accidental silence are not.

## 16. Validation plan and acceptance scenarios

### 16.1 Automated domain/audio checks

| Test ID | Scenario | Expected result |
|---|---|---|
| T-01 | Straight pattern at 120 BPM | 16 onsets at 125 ms spacing; 2-second bar |
| T-02 | Swing at 50%, 66⅔%, 75% | Formula respected, beat boundaries and total bar unchanged |
| T-03 | Four-count at 40, 120, 240 BPM | Exactly four clicks, first downbeat one beat after click 4 |
| T-04 | Repeated loops and chains | No extra count-in or boundary hit duplication |
| T-05 | 137 BPM, 10-minute frame timeline | No accumulating truncation error |
| T-06 | Retriggers 1/2/4/8/16 | Correct count within each swung step; no onset beyond boundary |
| T-07 | Parameter lock then unlocked step | Override does not leak; base parameter used next |
| T-08 | Hat overlap and same-time hats | Prior hats choke; closed hat wins exact collision |
| T-09 | Multiple simultaneous drums | All intended voices trigger at the same frame |
| T-10 | Recording near step/bar boundary | Nearest swung onset chosen, later tie wins, no duplicated new hit this pass |
| T-11 | Count-in cancellation and fast Play/Stop | No residual clicks, stale hits, or competing transports |
| T-12 | Undo recording pass/slider/clear/kit swap | Exactly the intended group reverses; no transport restart |
| T-13 | Chain with repeated/cross-kit entries | Correct order, repeats, pattern swing, inherited/overridden tempos, and sample identity |
| T-14 | Save/load/duplicate round trip | All musical values identical; duplicate identity distinct |
| T-15 | Rename/edit/delete referenced pattern | Rename follows; next run resolves new save; deletion blocked |
| T-16 | Failed/interrupting write | Prior save intact, draft retained, no false success |
| T-17 | Corrupt/unsupported schema record | Other library items load; original record preserved |
| T-18 | WAV/MP3, mono/stereo, 44.1/48 kHz | Correct decode, duration, pitch, channels, and validation failures |
| T-19 | Mute/solo combinations | Formula holds, including mute+solo and different-kit transitions |
| T-20 | Change standalone BPM/swing while playing | Latest pending values apply exactly at next bar, with no phase jump |
| T-21 | Chain A at 100 BPM ×2 then B at 140 BPM ×1 | Music duration 6.514286 seconds; tempo changes at entry boundary without gaps |
| T-22 | Override one occurrence; Set All Entry Tempos; Reset; Undo | Overrides persist independently; source pattern BPMs stay unchanged |
| T-23 | Edit entry tempo during chain playback | Current snapshot remains stable; next Play uses new tempo and first-entry count-in |

Use synthetic impulse fixtures and offline rendering/event inspection for exact onset assertions. Internal rendered test buffers are permitted; there is no user-facing export feature. Avoid brittle tests that assert only private implementation details.

### 16.2 Device and user-interface checks

- Install a signed build on the owner's iPhone 16 and complete all three primary journeys with the real kits.
- Verify pad touch-down timing, four-finger input, no accidental notes from scrolling, and immediate visual feedback.
- Save a named pattern, terminate/relaunch, load it, then construct/save/reload a cross-kit chain.
- Keep the app foregrounded untouched beyond normal auto-lock time, both stopped and playing; screen stays awake. Test at least 60 minutes of looping.
- Manually lock, switch apps, open Control Center, accept/decline an interruption, and disconnect headphones; sound stops and remains stopped after return.
- Confirm silent-switch playback, speaker, a wired/USB route where available, and Bluetooth output; document Bluetooth response separately.
- Test missing kit asset, malformed file, low-storage simulated save failure, and a stale recovery draft.
- Inspect room tails and off transitions, cymbal overlap, hats, and dense mixes by listening as well as automated checks.
- Verify VoiceOver labels, accessibility text, Reduced Motion, contrast, safe areas, and visible Undo.
- Observe performance with Instruments or equivalent profiling. Simulator success alone does not establish real-device audio quality or latency.

## 17. Implementation milestones and deliverables

### M0 — Project and test foundation

Deliver an Xcode project, app target, tests, stable domain models, provisional kit manifests/fixtures, and documented build steps. Verify simulator build and decoding fixtures. Record unresolved kit delivery/device-signing items. Do not spend this stage recreating decorative hardware details.

### M1 — Reliable playable sequencer

Deliver one working kit, multitouch pads, 16-step editing across instruments, sample-clock transport, mandatory count-in, Play/Stop, BPM/swing, lifecycle stop, and idle-timer handling. Pass timing tests and listen on a physical device. This is the first vertical slice, not the finished application.

### M2 — Patterns and editing

Deliver three-kit catalog support, naming, Save/Load/New/Duplicate/Delete, explicit Save versus draft recovery, undo/redo, level/pitch/decay, locks, motion recording, retriggers, live record, mute/solo, and hat choke. Validate actual kits when available.

### M3 — Independent chains

Deliver chain library, selection from every saved pattern, repeats/reordering, per-entry tempo inheritance/overrides, seamless kit transitions, snapshots, reference integrity, deletion protection, and saved-chain recovery. Demonstrate a chain using all three kits.

### M4 — Room, interface polish, and resilience

Deliver optional room, optional ongoing metronome, complete PO-inspired visual design, accessibility, corruption handling, audio-route recovery, memory limits, and complete help text. Run performance and long-session gates.

### M5 — Device handoff

Deliver a reproducible source checkout, passing automated checks, measured device report, actual three-kit validation report, known limitations, and concise Xcode signing/install instructions for the owner's phone. Do not claim device installation or hardware verification unless actually performed.

Required project documentation after implementation:

- `README.md`: setup, build/run/test, personal-device installation, required toolchain, asset placement.
- `docs/Audio-Architecture.md`: clock, rendering, queues, resource ownership, latency, gain and voice decisions.
- `docs/Kit-Format.md`: filenames, aliases, manifests, supported inputs, replacement/version procedure.
- `docs/Validation-Report.md`: automated results, device/OS/routes, actual measurements, unresolved issues.
- This specification, updated only when decisions change, with a short change log.

## 18. Definition of done

The complete first version is done only when all required milestones and acceptance gates are satisfied, or a specific deviation is explicitly accepted by the owner:

- All three owner-provided kits are integrated with correct instrument names and mappings.
- Every available instrument can be played and programmed into a 16-step bar.
- Count-in, continuous looping, swing, live recording, locks, retriggers, mute/solo, and Undo work together.
- Independently named patterns and chains survive relaunch; chains may reference any saved pattern.
- Cross-kit chain transitions have no preparation gaps and respect the saved entry-specific tempo policy.
- Excluded creative effects and export/sharing features are absent; optional room works and defaults off.
- Foreground screen stays awake; leaving the app stops sound and returning never auto-starts.
- Missing assets, failed saves, and broken references have recoverable, understandable states.
- Real iPhone 16 testing and required audio/performance evidence are recorded.
- No placeholder button, fake save operation, unavailable kit presented as working, hidden TODO in core behavior, or substituted demo sound is counted as finished.

## 19. Known dependencies and risk controls

| Dependency/risk | Required response |
|---|---|
| Actual sound folders not yet supplied | Build with marked fixtures; final sound validation waits for owner files |
| Ambiguous sample filenames/tom order | Propose mapping from inspected files; resolve actual ambiguity before final asset manifest |
| MP3 leading padding or quiet attack | Inspect timing; allow explicit sample start metadata; prefer supplied WAV when equivalent |
| Swift render-path allocations | Audit/profiling and preallocation; isolate any necessary lower-level kernel |
| Large cymbal files across kits | Enforce preparation budget and validate total real-kit footprint |
| Device signing/access | Complete simulator/domain work first; record exact remaining device step rather than claiming success |
| Bluetooth response | Report route limitation; retain accurate musical clock and wired/speaker acceptance route |
| Persistent references | UUID-based chains, serialized repository checks, blocked referenced deletion |
| Overly dense controls | Prioritize pad size and explicit modes; use sheets for secondary controls |
| Feature expansion | New effects, export, MIDI, sync, accounts, and importer remain outside scope unless requested |

## 20. Codex kickoff prompt

Use the following prompt to start the implementation task:

> Implement PocketBonham from `docs/PocketBonham-Software-Specification.md` in this repository. Treat its confirmed scope and behavioral rules as the acceptance contract. Inspect the repository and installed Xcode environment first, preserve any existing work, and build a native Swift/SwiftUI iPhone application. Begin with the reliable audio-and-sequencer vertical slice, then complete the persistence, independent chains, editing/performance controls, room option, and device polish milestones. Drive musical time from the audio clock, keep work out of the render callback, and test boundary behavior and persistence failures. Use clearly labeled development sound fixtures until I provide the three kit folders; integrate my actual WAV/MP3 files without inventing missing instruments. Do not add excluded effects, export/sharing, accounts, background playback, MIDI, or an importer unless this document authorizes it. Maintain a milestone checklist, meaningful tests, and short progress updates. Continue through the authorized implementation work; do not stop at a UI mockup or the first playable milestone. Report actual build/test/device results and concrete remaining blockers honestly. Ask only about choices that cannot be resolved from this specification or the inspected assets.

## 21. Technical sources and design provenance

Sources checked on 2026-09-17. Platform API usage must still be verified against the actual deployment SDK during implementation. Product limits, architecture choices, timing formulas, and acceptance targets are our specification decisions rather than vendor promises.

- [Teenage Engineering PO-12 guide](https://teenage.engineering/guides/po-12/en): reference for the original step workflow and performance concepts; the owner's explicit exclusions take precedence.
- [AVAudioSourceNode render initialization](https://developer.apple.com/documentation/avfaudio/avaudiosourcenode/init(renderblock:)): source-node callback and real-time constraints.
- [AVAudioFile](https://developer.apple.com/documentation/avfaudio/avaudiofile): decoding into PCM buffers.
- [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession): audio category/session model.
- [Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions): interruption notifications and lifecycle handling.
- [Audio session preference requests](https://developer.apple.com/library/archive/qa/qa1631/_index.html): requested versus actual sample rate/buffer settings.
- [UIApplication.isIdleTimerDisabled](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled): foreground display wakefulness.
- [AVAudioUnitReverb](https://developer.apple.com/documentation/avfaudio/avaudiounitreverb) and [small-room preset](https://developer.apple.com/documentation/avfaudio/avaudiounitreverbpreset/smallroom): candidate room implementation APIs.

## 22. Change log

- 1.0 / 2026-09-17: Incorporated all final owner answers: one count-in per Play; mixed-tempo, mixed-kit chains with entry BPM overrides; three bundled kits supplied through Codex for personal installation.
- 0.9 / 2026-09-17: Initial comprehensive draft based on the owner's scope decisions.
