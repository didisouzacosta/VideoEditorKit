# VideoEditorKit

`VideoEditorKit` is the public module for embedding the iOS video editor.

## Start Here

- `VideoEditorView`: main SwiftUI editor entry point
- `VideoEditorSession`: source video plus resume state
- `VideoEditorConfiguration`: host policy for tools, export qualities,
  transcription, and duration limits
- `VideoEditingConfiguration`: serializable editing snapshot
- `SavedVideo`: payload emitted after manual save

## Save And Export Model

The host should keep three files separate:

- original source video
- saved edited copy from `onSavedVideo`
- exported/share output from `onExportedVideoURL`

`onSaveStateChanged` is not continuous autosave. It reports saved state after an
explicit manual save.

## Public API Groups

- Editor/session: `VideoEditorView`, `VideoEditorSession`,
  `VideoEditorSessionSource`, `VideoEditorImportedFileSource`,
  `VideoEditorCallbacks`
- Configuration: `VideoEditorConfiguration`, `ToolAvailability`,
  `ExportQualityAvailability`
- Persistence: `VideoEditingConfiguration`, `VideoEditorSaveState`, `SavedVideo`
- Export: `VideoQuality`, `ExportedVideo`
- Canvas/crop: `VideoCanvas*`, `VideoCrop*`
- Transcription: `VideoTranscriptionProvider`, `VideoTranscriptionInput`,
  `VideoTranscriptionResult`, `Transcript*`, `Transcription*`

## AI Integration Prompt

```text
Integrate VideoEditorKit from a local video URL. Present VideoEditorView, persist
SavedVideo.url and SavedVideo.editingConfiguration from onSavedVideo, keep the
original source video separate, and use onExportedVideoURL only for explicit
share/export output. Do not overwrite the original and do not treat
onSaveStateChanged as per-edit autosave.
```
