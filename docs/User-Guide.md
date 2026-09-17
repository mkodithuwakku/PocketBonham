# Player guide

## Make your first pattern

1. Open **Pattern**. A new library starts with **Drum Kit 1** at 120 BPM.
2. Select **Kick** in the horizontal instrument row, then tap steps **1, 5, 9 and 13**.
3. Select **Snare** and enable steps **5 and 13**. The kick notes remain in their own track.
4. Select a hat and add a rhythm. Several instruments can share a step, including two hats.
5. Press **Play**. Four quarter-note clicks lead into the looping pattern. **Stop** ends playback and resets the transport.
6. Press **Save**, enter a name and save the pattern to the library.

Every pattern is one 16-step bar in 4/4. The grid shows the selected instrument's steps. Selecting another drum changes what you are editing; it does not solo that drum. Swipe the instrument row horizontally to reach the rest of the kit.

## Transport, tempo and swing

Tempo ranges from 40 to 240 BPM. Swing ranges from 50% (straight) to 75%. Move a slider or tap its numeric value to enter an exact number. During ordinary pattern playback, tempo and swing changes take effect at the next bar boundary.

Every explicit Play begins with a four-click count-in. The metronome setting controls clicks during the music; it does not remove the count-in. A looping chain does not count in again between entries or at its wrap point.

Leaving the app stops playback. Returning to the foreground prepares the instrument but never automatically restarts it. While active, the app keeps the display awake.

## Shape a hit

Long-press a step, or select it and open **Step Details**. You can enable the hit, adjust its level, choose a retrigger count, and override pitch or decay for that step.

| Control | Range | Effect |
|---|---|---|
| Hit level | 1–127 | Scales the selected hit relative to the track level |
| Retriggers | 1, 2, 4, 8 or 16 | Distributes repeated hits inside that step's swung interval |
| Pitch | −12 to +12 semitones | Changes sample playback rate and pitch |
| Decay | 5–100% | Shortens the pitch-adjusted sample tail |

Pitch and decay overrides are **parameter locks**. A locked step uses its override; another step still inherits the track's base value. Retriggers inherit the values of their parent step. Resetting a step clears its settings; clearing locks leaves the note pattern available for further editing.

The **Mixer** exposes track level, base pitch, base decay, transient mute/solo controls and the short drum-room effect. The room is optional and can blend up to 30% wet signal.

## Play and record pads

Select **Play Pads**. Sound begins on touch-down. Drum Kit 1 has eight pads on the first page and **Ride** on the second; use the page arrows to move between them. Accent selects a stronger pad hit level.

To record, arm **Record**, press Play and wait for the count-in. Perform your rhythm on the pads. Taps overdub onto the nearest swung step. A newly recorded hit is auditioned immediately and becomes eligible for sequenced playback on its following pass, avoiding an unintended doubled onset from that new note. A note that was already programmed can still coincide with your live tap.

Stop disarms recording. Each recording bar or partial pass is grouped for Undo. Recording adds notes; it does not erase the rest of the pattern.

The pads support independent touches in the implementation. Physical four-finger response and measured acoustic latency remain device acceptance checks; a simulator does not establish them.

## Record motion

Enable **Record Motion** in the mixer and move the selected track's pitch or decay control during pattern playback. The audio engine captures the parameter value at enabled-step onsets and writes parameter locks back into the pattern. It does not create notes on disabled steps.

A control gesture is grouped into one undoable edit. Existing locks can be cleared from the detail or mixer controls when you want the track to inherit its base sound again.

## How hats behave

Hats scheduled at the **same audio frame play together**. This includes Closed Hat 1 with Closed Hat 2, and open/closed pairs. A later hat hit releases earlier hat tails over a short ramp. Retriggers follow the same rule: shared onsets layer, later onsets choke earlier tails.

This behavior was changed after the owner's playback feedback. The original specification's simultaneous closed-hat priority is no longer the application behavior.

## Mute, solo and audition

Mute and solo are temporary performance controls. They affect both programmed notes and pad audition. Multiple tracks can be soloed; mute wins if a track is both muted and soloed. Use **Clear Mutes / Solos** to return to ordinary playback. Existing shared room energy can finish ringing after its source is muted.

The speaker button near the instrument row auditions the selected drum. Simply selecting an instrument does not mute any other instrument.

## Save, recover and manage your library

**Save** updates the named pattern or chain. A recovery draft is separate: it protects unfinished work but does not update the saved version used by chains. A successful save is only reported after the storage operation completes.

The **Library** provides patterns and chains, search, ordering, rename, duplicate, open and delete actions. Copying produces a new identity so the original remains independent. Undo is in the transport; Redo is available in the workspace actions.

On launch, a recoverable draft can be offered. If the saved original changed since that draft was opened, recover it as a copy instead of overwriting the newer save. Settings includes **Restore Damaged Items from Backups** for damaged records with a valid previous revision. Corrupt originals are preserved during restoration.

A pattern referenced by a saved chain or chain draft cannot be deleted until those references are removed. This keeps arrangements from silently losing their source patterns.

## Arrange patterns into a chain

Save the patterns you want first, then open **Chains** and add them as entries. A chain supports up to 64 entries. Each entry can repeat 1–16 times and can inherit its saved pattern's tempo or use a 40–240 BPM override. Reorder entries with the provided controls; you can also set or reset all entry tempos.

Save the chain independently from its patterns. Pressing Play resolves a snapshot of the referenced saved patterns and prepares their samples before playback. Edits to the arrangement apply on the next Play. The chain loops, and transitions occur on bar boundaries.

An unsaved pattern edit is not part of a chain. Save the pattern and restart chain playback to hear its updated saved version. Missing patterns or unavailable kit versions produce a diagnostic rather than a substitute sound.

## Kits and current scope

Drum Kit 1 contains kick, snare, two closed hats, open hat, three numbered toms and ride. No crash was supplied. The numbered tom labels preserve the source filenames without guessing low/mid/high roles. Development Sounds is a separate synthetic test kit.

Choose a kit while stopped. Matching stable instrument roles can retain their track data. If a kit change would remove notes on roles absent from the destination, the app identifies those tracks before applying the change.

Kits are bundled by a developer; this version has no in-app sample importer, MIDI, export, cloud synchronization or background playback. See [Troubleshooting](Troubleshooting.md) if the app is silent or a saved item cannot play.
