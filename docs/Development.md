# Developer guide

## Requirements

Use a Mac with full Xcode installed and an iPhone simulator runtime. The verified toolchain is Xcode 26.3 (17C529), Apple Swift 6.2.4 and the iOS 26.2 SDK. The app's deployment target is iOS 18; verification has used an iOS 26.3 simulator. Deployment compatibility is not a claim that every supported OS version has been manually tested.

The local package uses Swift 6 language mode. The app target uses Swift 5 compatibility mode, and the renderer uses C++17. There are no remote Swift package dependencies, backend services, secrets or API keys required to run the app. Apple audio frameworks mean the package tests require macOS; this is not a Linux package.

## Run in Xcode

```sh
git clone https://github.com/mkodithuwakku/PocketBonham.git
cd PocketBonham
open PocketBonham.xcodeproj
```

Select the **PocketBonham** scheme, choose an iPhone simulator and press Run. The checked-in Xcode project references the Swift package in the same repository. A fresh library starts on Drum Kit 1. Existing preferences and recovery drafts are preserved between launches.

The application bundle identifier is `com.mkodi.PocketBonham`. The app is configured for portrait iPhone use. Development Sounds remains visibly labeled and separate from the supplied owner kit.

## Command-line builds

Confirm that Xcode's developer directory is selected:

```sh
xcode-select -p
xcodebuild -version
swift --version
xcrun simctl list devices available
```

Choose an available iPhone UUID from the last command. Substitute it for `SIMULATOR_UUID` below; do not copy a UUID from another developer's machine.

```sh
xcodebuild -project PocketBonham.xcodeproj -scheme PocketBonham \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

The simulator app is produced at `build/DerivedData/Build/Products/Debug-iphonesimulator/PocketBonham.app`. See [Testing](Testing.md) for package and UI test commands.

## Physical iPhone installation

In Xcode, select the app target and configure your development team under Signing & Capabilities. Automatic signing is enabled, but no personal team ID or provisioning profile is checked in. Change the bundle identifier for your own fork if provisioning requires it.

Connect and unlock the iPhone, trust the Mac if requested, enable Developer Mode as required by iOS, and select the device in Xcode. Keep it unlocked while Xcode mounts developer services and installs the app. Run from Xcode.

For a signed device build, replace `YOUR_TEAM_ID` with your configured team:

```sh
xcodebuild -project PocketBonham.xcodeproj -scheme PocketBonham \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build/DeviceData DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  -allowProvisioningUpdates build
```

Output: `build/DeviceData/Build/Products/Release-iphoneos/PocketBonham.app`. A successful signed build is separate from installation, launch and acoustic acceptance. The last recorded physical installation attempt was blocked by a locked phone; no successful physical run is claimed in the published evidence.

## Source map

| Location | Responsibility |
|---|---|
| `PocketBonham/App/PocketBonhamApp.swift` | Application scene and foreground lifecycle |
| `PocketBonham/App/AppStore.swift` | Main-actor editing state, histories, recording, saves and recovery |
| `PocketBonham/Audio/AudioHost.swift` | Bundle catalog, session negotiation, off-thread preparation and C bridge |
| `PocketBonham/Features/RootView.swift` | Pattern workspace, instrument selection, step grid and pads |
| `PocketBonham/Features/Components.swift` | Shared controls, transport and UIKit touch-down pads |
| `PocketBonham/Features/Editors.swift` | Step details, mixer, settings and help |
| `PocketBonham/Features/LibraryView.swift` | Saved patterns/chains and recoverable drafts |
| `PocketBonham/Features/ChainView.swift` | Arrangement editor and entry controls |
| `Sources/BonhamCore/Models.swift` | Validated models, musical timing and edit history |
| `Sources/BonhamCore/Repository.swift` | Actor-isolated storage, revisions, backups and reference checks |
| `Sources/BonhamCore/SampleDecoder.swift` | Codec checks, hashing, trims and sample-rate conversion |
| `Sources/BonhamRender/BonhamRender.cpp` | Sample-clock scheduler, polyphony, resampling and room |
| `Sources/BonhamRender/include/BonhamRender.h` | C ABI for plans, commands, status and test traces |
| `Sources/KitValidator/main.swift` | Offline kit validation executable |
| `Tests/BonhamCoreTests` | Model, repository, decoder and renderer regressions |
| `PocketBonhamUITests` | Application workflow automation |

The full ownership and timing design is in [Audio Architecture](Audio-Architecture.md).

## Project generation and resources

After adding, moving or removing app Swift source files, regenerate the Xcode project:

```sh
python3 scripts/generate_project.py
```

The generator discovers app Swift files and writes stable identifiers and the shared scheme. It defines one UI test source file explicitly; adding another UI test file requires updating the generator. Keep project setting changes in the generator as well as the generated project so regeneration does not erase them. Review generated diffs before committing.

The entire `PocketBonham/Resources/Kits` directory is bundled as a folder reference. Adding a validated kit there does not require regeneration. New package source files under the existing `Sources` target directories are discovered by Swift Package Manager.

The developer scripts also include:

| Script | Use |
|---|---|
| `prepare_kit.py` | Stage, map, hash, decode-validate and install an owner kit |
| `generate_fixtures.py` | Recreate the eight synthetic development samples |
| `generate_codec_fixtures.py` | Recreate codec test files; MP3 generation additionally needs `lameenc==1.8.1` |
| `generate_icon.swift` | Generate the project icon assets |

Generated audio fixtures and icon assets are already committed. Their generation tools are not app runtime dependencies. Do not regenerate owner samples; their original bytes and manifest hashes are deliberately preserved.

## Normal change workflow

1. Read the relevant module and current owner decisions in [AI_CONTEXT.md](../AI_CONTEXT.md).
2. Reproduce a reported defect at the smallest meaningful boundary. Audio bugs should check PCM or exact frame events, not only whether a button changed state.
3. Make the focused change, preserving saved-file and asset identity contracts.
4. Run relevant tests and a build; use simulator UI checks for affected workflows.
5. Update behavior documentation and record what was actually verified. Do not translate an offline render or simulator result into a physical-device claim.
6. Keep build caches, signing files and user libraries out of commits. The repository `.gitignore` covers normal generated products.

There is no automated GitHub Actions workflow configured in this version. The commands and committed evidence describe local verification.
