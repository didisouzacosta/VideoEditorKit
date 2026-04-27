# Features

This file is the current feature and resource map for `VideoEditorKit`.

## Editor Features

- Import and edit a local video file.
- Resume a saved edit with `VideoEditingConfiguration`.
- Trim a playback range.
- Change speed from `0.1x` to `8.0x`.
- Apply crop presets and social formats.
- Zoom the canvas with pinch and pan by moving the pinch center; one-finger drag
  still pans. Pinch must not rotate the video.
- Rotate explicitly through editor controls.
- Mirror horizontally.
- Record one extra audio track and mix it with the video track.
- Adjust brightness, contrast, and saturation.
- Add a colored frame/background treatment.
- Generate and edit transcript overlays when a transcription provider exists.
- Save an edited copy while preserving the original.
- Export `.mp4` output in original, low, medium, or high quality.

## Save And Export Resources

- Original source video: owned by the host app and never overwritten.
- Saved edited copy: returned by `onSavedVideo`; used for saved-project preview.
- Exported video: returned by `onExportedVideoURL`; used for share/export flows.
- Project thumbnail: generated from the saved edited copy in the example app.

## Main Public Types

- `VideoEditorView`: present the editor.
- `VideoEditorSession`: open a local or async-resolved source.
- `VideoEditorConfiguration`: configure tools, export qualities, transcription,
  blocked actions, and duration limits.
- `VideoEditingConfiguration`: persist and restore the edit.
- `SavedVideo`: manual-save result.
- `VideoEditorSaveState`: saved snapshot result from the save path.
- `VideoQuality`: export quality.
- `ToolAvailability`: tool visibility and blocking.
- `ExportQualityAvailability`: export visibility and blocking.
- `VideoTranscriptionProvider`: custom transcription backend.
- `VideoCanvasEditorState` and `VideoCanvasMappingActor`: canvas state and mapping.

## Export Qualities

- `original`: preserve source resolution and frame rate when available.
- `low`: 854x480.
- `medium`: 1280x720.
- `high`: 1920x1080.

`original` must remain available even when premium qualities are blocked.

## Current Limits

- iOS-only.
- iPhone-focused UI.
- One additional recorded audio track.
- No multi-layer video timeline.
- No multiple external audio tracks.
- Preview and export are aligned by tests and conventions, not by one centralized
  engine.
- Freeform crop export is not a complete public contract.
