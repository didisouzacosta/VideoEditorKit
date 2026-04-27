# VideoEditorKit

`VideoEditorKit` is a package-first iOS video editor built with SwiftUI,
Observation, AVFoundation, PhotosUI, Core Image, and Swift Testing.

It provides a ready-to-present editor for local videos, plus a small set of
public configuration, persistence, transcription, canvas, and export APIs.

## Requirements

- iOS 18.6+ app target
- Swift 6
- Xcode with Swift Package Manager
- iPhone UI today; iPad support is not the current contract

## Features

- Local video editing from a file URL or async import resolver
- Trim, playback speed, crop presets, canvas zoom/pan, explicit rotation, mirror
- One recorded audio track mixed with the source audio
- Brightness, contrast, and saturation adjustments
- Frame/background styling
- Optional transcript generation and editable caption overlays
- Manual save that creates an edited copy while preserving the original video
- Export to `.mp4` with `original`, `low`, `medium`, and `high` quality choices

## Install

Add the package in Xcode:

```text
https://github.com/didisouzacosta/VideoEditorKit.git
```

Or add it to `Package.swift`:

```swift
.package(
    url: "https://github.com/didisouzacosta/VideoEditorKit.git",
    branch: "main"
)
```

Then link the `VideoEditorKit` product to your app target.

## Quick Start

```swift
import SwiftUI
import VideoEditorKit

struct EditorHostView: View {

    @State private var configuration = VideoEditingConfiguration.initial
    @State private var savedEditedVideoURL: URL?
    @State private var exportedVideoURL: URL?

    let sourceVideoURL: URL

    var body: some View {
        VideoEditorView(
            "Editor",
            sourceVideoURL: sourceVideoURL,
            editingConfiguration: configuration,
            configuration: .allToolsEnabled,
            onSavedVideo: { savedVideo in
                configuration = savedVideo.editingConfiguration
                savedEditedVideoURL = savedVideo.url
            },
            onDismissed: { latestConfiguration in
                if let latestConfiguration {
                    configuration = latestConfiguration
                }
            },
            onExportedVideoURL: { url in
                exportedVideoURL = url
            }
        )
    }
}
```

## Integration Rules

- Pass a local playable file URL into the editor.
- Keep the original video, saved edited copy, and exported output as separate files.
- Persist `SavedVideo.url` and `SavedVideo.editingConfiguration` after `onSavedVideo`.
- Use `onExportedVideoURL` only for explicit export/share output.
- Do not treat `onSaveStateChanged` as continuous autosave.
- Do not overwrite the original source video with a saved or exported video.
- Do not block `.original`; original export is always available.

## Sessions

Use `VideoEditorSession` when reopening saved projects or resolving the source
asynchronously:

```swift
let session = VideoEditorSession(
    source: .fileURL(originalVideoURL),
    editingConfiguration: savedConfiguration,
    preparedOriginalExportVideo: savedEditedVideoMetadata
)
```

Use `.importedFile` only when a local URL must be produced asynchronously before
the editor can load the video.

## Transcription

Transcription is optional. Enable it by passing a transcription configuration:

```swift
let configuration = VideoEditorConfiguration(
    tools: ToolAvailability.enabled(ToolEnum.all),
    exportQualities: ExportQualityAvailability.allEnabled,
    transcription: .openAIWhisper(
        apiKey: resolvedAPIKey(),
        preferredLocale: "en"
    )
)
```

For custom backends, implement `VideoTranscriptionProvider` and return ordered
segments with word timings whenever possible.

## Public API Map

- Editor entry: `VideoEditorView`, `VideoEditorSession`, `VideoEditorCallbacks`
- Host policy: `VideoEditorConfiguration`, `ToolAvailability`, `ExportQualityAvailability`
- Persistence: `VideoEditingConfiguration`, `SavedVideo`, `VideoEditorSaveState`
- Export: `VideoQuality`, `ExportedVideo`
- Transcription: `VideoTranscriptionProvider`, `Transcript*`, `Transcription*`
- Canvas/crop: `VideoCanvas*`, `VideoCrop*`

See also:

- [Docs/FEATURES.md](Docs/FEATURES.md)
- [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md)
- [Docs/VALIDATION.md](Docs/VALIDATION.md)
- [Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md](Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md)

## Repository Layout

```text
Package.swift
Sources/VideoEditorKit/
Tests/VideoEditorKitTests/
Example/VideoEditor/
Example/VideoEditorTests/
Example/VideoEditor.xcworkspace
```

## Development

Use iOS Simulator validation:

```bash
scripts/format-swift.sh
scripts/test-ios.sh
```

Targeted validation:

```bash
xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditorKit-Package \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test

xcodebuild \
  -workspace Example/VideoEditor.xcworkspace \
  -scheme VideoEditor \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```
