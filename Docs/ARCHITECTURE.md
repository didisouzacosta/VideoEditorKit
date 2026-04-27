# Architecture

`VideoEditorKit` is a Swift Package with an example iOS app. It is not yet a
fully decomposed SDK made of pure layout, player, and export engines.

## Structure

```text
Package.swift
Sources/VideoEditorKit/
Tests/VideoEditorKitTests/
Example/VideoEditor/
Example/VideoEditorTests/
Example/VideoEditor.xcworkspace
```

## Runtime Shape

- `VideoEditorView` is the main public editor surface.
- `EditorViewModel` owns most editing state.
- `VideoPlayerManager` owns playback and preview coordination.
- Export and save rendering still live in helper/model code rather than a
  standalone export engine.
- The example app owns project persistence, sharing, and saved-project UI.

## Main Flows

### Open

1. Host passes a local file URL or a `VideoEditorSession`.
2. The editor loads the source video.
3. The editor applies any saved `VideoEditingConfiguration`.

### Edit

1. User changes tools in the editor.
2. The editor tracks unsaved changes against the last saved snapshot.
3. Preview updates through player, canvas, transcript, and tool state.

### Manual Save

1. User taps Save.
2. Editor renders an edited copy.
3. `onSavedVideo` returns the saved edited video and configuration.
4. The host persists the edited copy separately from the original.

### Export

1. User selects an export quality.
2. Pending edits are saved first when needed.
3. Export renders the chosen output.
4. `onExportedVideoURL` returns the exported file.

## Important Implementation Areas

- Public editor: `Sources/VideoEditorKit/Views/Editor/VideoEditorView.swift`
- Editor state: `Sources/VideoEditorKit/Internal/ViewModels/EditorViewModel.swift`
- Player: `Sources/VideoEditorKit/Internal/Managers/Player/VideoPlayerManager.swift`
- Export: `Sources/VideoEditorKit/Internal/Models/Enums/VideoEditor.swift`
- Manual save: `Sources/VideoEditorKit/Internal/Editing/VideoEditorManualSaveRenderer.swift`
- Canvas: `Sources/VideoEditorKit/Canvas/`
- Canvas gestures: `Sources/VideoEditorKit/Internal/Gestures/`
- Example projects: `Example/VideoEditor/Data/Projects/`

## Persistence Model

The package exposes `VideoEditingConfiguration` as the resumable edit state.

The example app persists:

- original copied video filename
- saved edited video filename
- exported video filename, when present
- creation date
- trim, speed, rotation, mirror, adjustments, frame, audio, and canvas state
- project thumbnail data

## Known Boundaries

- Do not assume preview equals export for every feature.
- Do not assume export jobs are isolated in a pure engine.
- Do not assume export can handle every freeform crop path.
- Do not assume concurrent export is globally guarded.
- Do not assume the export input snapshot is immutable.
