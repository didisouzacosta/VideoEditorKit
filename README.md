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
- Saved preview metadata and thumbnail generated from the rendered saved copy
- Save button stays available after load; without unsaved changes it only closes
  the editor
- Export to `.mp4` with `original`, `low`, `medium`, and `high` quality choices
- Reusable export-quality sheet for list and share flows outside the editor

## Screenshots

| Editor | Crop |
| --- | --- |
| ![Editor](Screenshots/1%20-%20editor.PNG) | ![Crop](Screenshots/2%20-%20crop.PNG) |

| Presets | Adjusts |
| --- | --- |
| ![Presets](Screenshots/3%20-%20presets.PNG) | ![Adjusts](Screenshots/4%20-%20adjusts.PNG) |

| Audio | Speed | Export |
| --- | --- | --- |
| ![Audio](Screenshots/5%20-%20audio.PNG) | ![Speed](Screenshots/6%20-%20speed.PNG) | ![Export](Screenshots/7%20-%20export.PNG) |

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
            onDismissed: {},
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
- Use `onDismissed` only as a close event; it does not publish editing state.
- Use `onExportedVideoURL` only for explicit export/share output.
- Do not overwrite the original source video with a saved or exported video.
- Do not block `.original`; original export is always available.

## Save Behavior

The save button is available once the editor content is loaded. If the current
edit has unsaved changes, tapping save renders a new edited copy and then calls
`onSavedVideo`. If there are no unsaved changes, tapping save only dismisses the
editor and does not emit another `SavedVideo`.

`SavedVideo` contains:

- `url`: the rendered edited copy
- `originalVideoURL`: the preserved source video
- `editingConfiguration`: the snapshot that produced the saved copy
- `thumbnailData`: a JPEG thumbnail generated from the saved copy
- `metadata`: `ExportedVideo` metadata loaded from the saved copy

Manual save renders with the native save profile. When a canvas/crop preset,
social destination, or freeform crop is active, the saved video uses that
canvas size, normalized to even pixels for encoder compatibility. With the
original canvas, the saved video keeps the source presentation size. The saved
preview metadata and thumbnail are loaded from the rendered copy, so project
lists can display the same positioning and preset framing that the editor saved.

`onSaveStateChanged` and `VideoEditorSaveState` are no longer part of the public
save contract. Hosts should rely on `onSavedVideo` for persisted edits and use
`onDismissed` only to react to closure.

## Sessions

Use `VideoEditorSession` when reopening saved projects or resolving the source
asynchronously:

```swift
let session = VideoEditorSession(
    source: .fileURL(originalVideoURL),
    editingConfiguration: savedConfiguration,
    preparedOriginalExportVideo: savedEditedVideoMetadata,
    preparedOriginalExportEditingConfiguration: savedConfiguration
)
```

Use `.importedFile` only when a local URL must be produced asynchronously before
the editor can load the video. During that bootstrap, the editor shows the
loader only; it does not briefly display the navigation title before content is
loaded.

## External Export Sheet

Use `videoExportSheet` when a host screen needs the same export-quality picker
outside `VideoEditorView`, such as a saved-video list share button. The modifier
uses `VideoEditorConfiguration.exportQualities`, including blocked qualities,
then renders the selected quality before returning an `ExportedVideo`.

```swift
@State private var exportingProject: Project?
@State private var sharedVideoURL: URL?

var body: some View {
    ProjectsList(
        onShare: { project in
            exportingProject = project
        }
    )
    .videoExportSheet(
        item: $exportingProject,
        configuration: .allToolsEnabled,
        request: { project in
            VideoExportSheetRequest(
                id: project.id.uuidString,
                sourceVideoURL: project.originalVideoURL,
                editingConfiguration: project.editingConfiguration ?? .initial,
                preparedOriginalExportVideo: project.preparedOriginalExportVideo
            )
        },
        onExported: { exportedVideo, _ in
            sharedVideoURL = exportedVideo.url
        }
    )
}
```

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
- Persistence: `VideoEditingConfiguration`, `SavedVideo`
- Export: `VideoQuality`, `ExportedVideo`, `VideoExportSheetRequest`
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
