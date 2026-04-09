# VideoEditorKit

`VideoEditorKit` is now organized as a package-first repository.

- the Swift package lives at the repository root
- the example iOS app lives under `Example/`

The package provides a video editor with tools for trimming, playback changes, crop presets, audio, corrections, transcript overlays, and export flows.

## Features

- **Creating a video project and saving its progress**
- **Cropping video**
- **Changing the video duration**
- **Adding filters and effects to videos**
- **Adding text to a video**
- **Recording and editing audio**
- **Adding frames to videos**
- **Saving or share videos in different sizes**

## Includes

- SwiftUI
- iOS 16+
- MVVM
- Combine
- Core Data
- AVFoundation
- AVKit

## Development

Package validation is iOS-only. `swift test` at the repository root is not a supported validation path because the package depends on iOS-only frameworks and UI runtime behavior.

The official validation flow for this repository is:

- `xcodebuild test` on an iOS Simulator destination
- `scripts/test-ios.sh` for local terminal use
- `build_sim` / `test_sim` when validating through `xcodebuildmcp`

Open the example app from:

```text
Example/VideoEditor.xcworkspace
```

Format the project Swift files with the repository configuration:

```bash
scripts/format-swift.sh
```

Lint without changing files:

```bash
scripts/format-swift.sh --lint
```

Run the full Swift quality gate:

```bash
scripts/lint-swift.sh
```

Run the supported test/build validation on iOS Simulator:

```bash
scripts/test-ios.sh
```

Equivalent `xcodebuild` commands:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test

xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditor \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Install `SwiftLint` locally if needed:

```bash
brew install swiftlint
```

The git `pre-commit` hook formats staged `.swift` files automatically, and `pre-push` runs the full formatter + SwiftLint checks.

## Screenshots 📷

### Projects and editor views

  <div align="center">
  <img src="screenshots/mainScreen.png" height="350" alt="Screenshot"/>
  <img src="screenshots/editor_screen.png" height="350" alt="Screenshot"/>
  <img src="screenshots/fullscreen.png" height="350" alt="Screenshot"/>
  <img src="screenshots/export_screen.png" height="350" alt="Screenshot"/>
  </div>
  
  
### Editor tools

  <div align="center">
  <img src="screenshots/tool_cut.png" height="350" alt="Screenshot"/>
  <img src="screenshots/tool_speed.png" height="350" alt="Screenshot"/>
  <img src="screenshots/tool_audio.png" height="350" alt="Screenshot"/>
  <img src="screenshots/tool_filters.png" height="350" alt="Screenshot"/>
  <img src="screenshots/tool_crop.png" height="350" alt="Screenshot"/>
  <img src="screenshots/tool_frame.png" height="350" alt="Screenshot"/>
  <img src="screenshots/tool_text.png" height="350" alt="Screenshot"/>
  <img src="screenshots/tool_corrections.png" height="350" alt="Screenshot"/>
  </div>
  
  


###
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

  
  
