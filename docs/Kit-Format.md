# Bundled kit format and integration

Kits live in `PocketBonham/Resources/Kits/<folder>/`. Xcode bundles the directory without flattening it. Each folder has one `manifest.json` and 1–16 named samples. Drum Kit 1 is integrated; two owner kits remain pending. `Development` contains deterministic synthetic fixtures, marked `developmentFixture: true` and visibly labeled in the application.

```json
{
  "schemaVersion": 1,
  "id": "kit-1",
  "name": "Kit One",
  "assetVersion": 1,
  "instruments": [
    {
      "id": "kick",
      "name": "Kick",
      "file": "kick.wav",
      "order": 0,
      "sha256": "sha256-of-the-original-file"
    }
  ]
}
```

Instrument identity is a stable role (`kick`, `snare`, `closedHat`, `openHat`, `tomLow`, `tomMid`, `tomHigh`, `crash`, `ride`, or explicitly assigned extra roles). Display name and order are independent of identity. Hats declare `chokeGroup: "hats"` and may explicitly specify `hatType: "closed"` or `hatType: "open"`. This supports multiple hat variants with distinct IDs and the same shared choke behavior. Same-frame hats layer together; later hats release earlier hat tails. Existing manifests without `hatType` retain the standard `closedHat`/`openHat` role behavior. Both sequencer playback and live pads use this metadata. No instrument is invented for an absent role. Custom role IDs without hat metadata remain playable as ordinary samples.

Input matrix: uncompressed PCM WAV (16/24-bit integer or 32-bit Float) and decodable MP3, mono or stereo, 44.1/48 kHz, duration greater than zero and at most 30 seconds. Actual decoder format is checked, not just extension. Stereo is preserved; mono is duplicated. Apple AVAudioConverter performs maximum-quality rate conversion to the negotiated stereo Float format. Nonfinite samples fail preparation. Relative paths reject absolute paths and `..` traversal.

Optional `startFrame` and `endFrame` describe a non-destructive region in the decoded source-rate PCM. End is exclusive. The default is the complete file. Encoder priming/leading silence is preserved; do not automatically trim MP3 attacks. The validator reports the first sample exceeding −80 dB to support inspecting supplied files. Hashes cover the original file, even when trim metadata is present.

## Integration workflow

1. Inspect each supplied folder. Run `scripts/prepare_kit.py` without `--install` to propose a manifest. Name matching ignores spaces, hyphens, underscores and case, using the aliases in the specification.
2. Resolve unknown roles, duplicate aliases and ambiguous numbered toms. The tool refuses to guess `tom1` pitch order. Pass an explicit mapping file for those cases:

   ```json
   {
     "tom1.wav": {"id": "tomExtra1", "name": "Tom 1", "order": 4},
     "tom2.wav": {"id": "tomExtra2", "name": "Tom 2", "order": 5}
   }
   ```

3. Repeat with `--mapping /path/to/mapping.json --install`. This stages copies, generates hashes, runs the actual Swift decoder validator, then copies the validated directory into bundled resources. Original filenames are retained. This is a developer tool, not an in-app importer.
4. Run `swift run -c release bonham-validate-kit PocketBonham/Resources/Kits` against all delivered kits together. Combined decoded memory must be ≤192 MiB. Listen to all samples, check hat identities and sample attacks, and audition cross-kit chains.
5. Remove the development-kit folder from the shipping resources once the three real kits are ready. Development patterns will then identify their old kit as unavailable, rather than silently substituting a real kit. Retain test fixtures under `Tests` for automated checks.

Replacing an existing sound is deliberate: retain the stable kit/role IDs, increment `assetVersion`, refresh hashes and record the change. Existing patterns with a mismatched asset version are rejected with an actionable diagnostic; choose a documented migration or retain the old version instead of silently changing their sound. The integration tool refuses to overwrite an existing kit ID automatically.
