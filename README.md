# VideoEditorKit

`VideoEditorKit` is a package-first iOS video editor framework built with SwiftUI, Observation, AVFoundation, and PhotosUI.

It ships a full-screen editor that already includes trimming, playback speed changes, crop presets, audio recording and mixing, color adjustments, transcript overlays, frame/background styling, and `.mp4` export.

The repository is structured around a Swift Package at the root and an example iOS app in `Example/` that exercises the package as a real integration client.

## What The Framework Provides

- A ready-to-embed SwiftUI editor surface through `VideoEditorView`
- A serializable editing snapshot through `VideoEditingConfiguration`
- Host-controlled feature gating for tools and export qualities
- Continuous save callbacks so your app can persist work-in-progress state
- Optional transcript generation through a custom `VideoTranscriptionProvider`
- Reusable public canvas, export, transcript, and layout utilities for advanced integrations

## Requirements

- iOS 26.0+
- Swift 6
- Xcode with Swift Package Manager support

## Installation

### Swift Package Manager in Xcode

1. Open your app project in Xcode.
2. Go to `File > Add Package Dependencies...`.
3. Paste the repository URL:

```text
https://github.com/didisouzacosta/VideoEditorKit.git
```

4. Add the `VideoEditorKit` library product to your app target.

### Swift Package Manager in `Package.swift`

```swift
dependencies: [
    .package(
        url: "https://github.com/didisouzacosta/VideoEditorKit.git",
        branch: "main"
    )
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "VideoEditorKit", package: "VideoEditorKit")
        ]
    )
]
```

## Quick Start

```swift
import SwiftUI
import VideoEditorKit

struct EditorHostView: View {

    @State private var savedConfiguration = VideoEditingConfiguration.initial

    let sourceVideoURL: URL

    var body: some View {
        VideoEditorView(
            "Editor",
            sourceVideoURL: sourceVideoURL,
            editingConfiguration: savedConfiguration,
            configuration: .init(
                tools: ToolAvailability.enabled(ToolEnum.all),
                exportQualities: ExportQualityAvailability.allEnabled
            ),
            onSaveStateChanged: { saveState in
                savedConfiguration = saveState.editingConfiguration
            },
            onDismissed: { latestConfiguration in
                if let latestConfiguration {
                    savedConfiguration = latestConfiguration
                }
            },
            onExportedVideoURL: { exportedVideoURL in
                print("Exported video:", exportedVideoURL)
            }
        )
    }
}
```

## Integration Concepts

### `VideoEditorView`

This is the main public entry point. Present it inside a navigation flow, a sheet, or a full-screen cover, and the package handles the editor UI, preview, tools, and export flow.

### `VideoEditorSession`

Use a `VideoEditorSession` when you want the host app to control:

- which source video is edited
- whether the source is already available as a `URL` or must be resolved asynchronously
- whether the editor should start from a previously saved `VideoEditingConfiguration`

### `VideoEditingConfiguration`

This is the package's persistent editing snapshot. Save it in your app whenever `onSaveStateChanged` fires, and pass it back into the editor later to resume an existing project.

### `VideoEditorConfiguration`

This is the host-facing runtime configuration for:

- visible and blocked tools
- visible and blocked export qualities
- transcription provider injection
- maximum allowed source duration
- blocked-action callbacks for premium or upsell flows

### `VideoEditorCallbacks`

The callback bundle allows the host app to react to:

- continuous save state updates
- asynchronous source resolution completion
- editor dismissal
- successful export completion

## Installing In A Vibe-Coded (AI-Generated) App

If your app was scaffolded by an AI coding tool, installation is still the normal Swift Package Manager flow.

The easiest path is:

1. Add the package in Xcode first.
2. Make sure your app target links the `VideoEditorKit` product.
3. Ask your coding assistant to import `VideoEditorKit` and present `VideoEditorView`.
4. Persist `VideoEditingConfiguration` in your app state or storage layer so edits can resume cleanly.
5. Wire `onExportedVideoURL` into your share, save-to-library, or upload flow.

For AI-generated host apps, this prompt usually works well:

```text
Add VideoEditorKit through Swift Package Manager, import VideoEditorKit, present VideoEditorView for a local video URL, persist VideoEditingConfiguration on save callbacks, and keep the exported video URL in host state so the app can share it later.
```

If your generated app already has a media picker, map its result into one of these session sources:

- `VideoEditorSessionSource.fileURL` when you already have a local file
- `VideoEditorSessionSource.importedFile` when the file must be resolved asynchronously

## Public API Guide

The package exposes more than just the main editor view. The public surface is grouped roughly as:

- host integration: `VideoEditorView`, `VideoEditorSession`, `VideoEditorCallbacks`, `VideoEditorConfiguration`
- persisted editing state: `VideoEditingConfiguration` and its nested models
- tool and export gating: `ToolEnum`, `ToolAvailability`, `VideoQuality`, `ExportQualityAvailability`
- canvas and crop helpers: `VideoCanvas*`, `VideoCrop*`
- transcript helpers: `Transcript*`, `VideoTranscriptionProvider`, `EditorTranscript*`
- reusable SwiftUI building blocks: player, timeline, export, canvas, and tool-sheet views

For a full grouped reference of the public API that ships in the module, see [`Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md`](Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md).

## Current Capabilities

- Import and edit a local video
- Trim a selected playback range
- Change playback speed from `0.1x` to `8.0x`
- Apply crop presets
- Rotate and mirror the video
- Record one extra audio track and mix it with the source track
- Adjust brightness, contrast, and saturation
- Add a colored frame/background treatment
- Export asynchronously to `.mp4`

## Repository Layout

```text
Package.swift
Sources/VideoEditorKit/
Tests/VideoEditorKitTests/
Example/VideoEditor/
Example/VideoEditorTests/
Example/VideoEditor.xcodeproj
Example/VideoEditor.xcworkspace
```

## Development And Validation

This repository is iOS-only. The supported validation flow is iOS Simulator based.

Preferred commands:

```bash
scripts/format-swift.sh
scripts/lint-swift.sh
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

Open the example app from:

```text
Example/VideoEditor.xcworkspace
```

## Current Architectural Reality

`VideoEditorKit` currently behaves like a package-backed app framework with a monolithic editor flow, not yet like a fully decomposed engine-based SDK.

That means:

- preview and export are conceptually aligned, but not guaranteed by one shared engine
- freeform crop is not fully exported today
- export still works directly from live `Video` state rather than a detached immutable export snapshot
- advanced features such as multi-track audio, multi-layer video composition, or normalized subtitle coordinates are not part of the current public contract

## Screenshots

### Projects and editor views

<div align="center">
  <img src="screenshots/mainScreen.png" height="350" alt="Projects screen"/>
  <img src="screenshots/editor_screen.png" height="350" alt="Editor screen"/>
  <img src="screenshots/fullscreen.png" height="350" alt="Fullscreen editor"/>
  <img src="screenshots/export_screen.png" height="350" alt="Export screen"/>
</div>

### Editor tools

<div align="center">
  <img src="screenshots/tool_cut.png" height="350" alt="Trim tool"/>
  <img src="screenshots/tool_speed.png" height="350" alt="Speed tool"/>
  <img src="screenshots/tool_audio.png" height="350" alt="Audio tool"/>
  <img src="screenshots/tool_filters.png" height="350" alt="Filters tool"/>
  <img src="screenshots/tool_crop.png" height="350" alt="Crop tool"/>
  <img src="screenshots/tool_frame.png" height="350" alt="Frame tool"/>
  <img src="screenshots/tool_text.png" height="350" alt="Transcript tool"/>
  <img src="screenshots/tool_corrections.png" height="350" alt="Adjustments tool"/>
</div>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
