# VideoEditorKit

`VideoEditorKit` is the public documentation entry point for the `VideoEditorKit` Swift package.

Use this page as a map of the module's public surface.

## Main Integration API

These are the symbols most host apps start with:

- `VideoEditorView`: the main full-screen SwiftUI editor
- `VideoEditorSession`: host-provided source and resume state
- `VideoEditorSessionSource`: either a ready local file URL or an asynchronously resolved imported file
- `VideoEditorImportedFileSource`: async file resolver used by `VideoEditorSessionSource.importedFile`
- `VideoEditorCallbacks`: host callbacks for save, dismiss, source resolution, and export
- `VideoEditorConfiguration`: runtime tool, export, optional transcription, and duration configuration
- `VideoEditorSaveState`: saved editing snapshot emitted after manual save
- `SavedVideo`: rendered edited-copy payload emitted after manual save
- `VideoEditingConfiguration`: serializable editing snapshot used to restore a session later
- `VideoEditorKitPackage`: lightweight package metadata namespace

For saved-project integrations, pass the preserved original video as the session source, pass the stored `VideoEditingConfiguration` as the resume snapshot, and pass the saved edited copy as `preparedOriginalExportVideo` when it is available. That lets original-quality export reuse the already saved edited video when there are no pending changes.

## Tool And Export Availability

Use these types when your host app needs feature gating, premium locks, or custom ordering:

- `ToolEnum`
- `ToolAvailability`
- `VideoQuality`
- `ExportQualityAvailability`
- `ExportedVideo`

`VideoQuality.original` is the last export option and is always enabled after configuration normalization. It applies the current editing configuration while preserving the source video's native resolution and source frame rate when available. The fixed high, medium, and low qualities continue to render at `1920x1080`, `1280x720`, and `854x480`.

## Canvas, Crop, And Layout

These symbols support the crop and canvas system that powers preview and export mapping:

- `VideoCanvasPreset`
- `VideoCanvasTransform`
- `VideoCanvasSnapshot`
- `VideoCanvasEditorState`
- `VideoCanvasSourceDescriptor`
- `VideoCanvasResolvedPreset`
- `VideoCanvasRenderRequest`
- `VideoCanvasExportMapping`
- `VideoCanvasLayout`
- `VideoCanvasMappingActor`
- `VideoCanvasPreviewView`
- `VideoCanvasInteractionCancellationPolicy`
- `VideoCropFormatPreset`
- `VideoCropPreviewLayout`
- `PlaybackTimeMapping`
- `EditorCropEditingState`
- `EditorCropEditingCoordinator`
- `EditorToolSelectionCoordinator`
- `EditorToolbarLayoutMetrics`
- `EditorToolbarLayoutResolver`
- `ResolvedVideoEditingPresentationState`
- `VideoEditingPresentationStateResolver`

## Transcript And Captioning API

These types model transcript generation, editing, layout, and rendering:

- `VideoTranscriptionProvider`
- `VideoTranscriptionComponentProtocol`
- `VideoTranscriptionInput`
- `VideoTranscriptionSource`
- `VideoTranscriptionResult`
- `TranscriptionSegment`
- `TranscriptionWord`
- `TranscriptDocument`
- `EditableTranscriptSegment`
- `EditableTranscriptWord`
- `TranscriptTimeMapping`
- `TranscriptStyle`
- `RGBAColor`
- `TranscriptTextAlignment`
- `TranscriptFontWeight`
- `TranscriptOverlayPosition`
- `TranscriptOverlaySize`
- `TranscriptFeaturePersistenceState`
- `TranscriptFeatureState`
- `TranscriptError`
- `TranscriptTextStyleResolver`
- `TranscriptOverlayLayoutResolver`
- `TranscriptOverlayPreview`
- `TranscriptWordHighlightStyle`
- `TranscriptTimeMapper`
- `EditorTranscriptMappingCoordinator`
- `EditorTranscriptRemappingCoordinator`
- `TranscriptWordEditingCoordinator`

## Reusable SwiftUI Building Blocks

Advanced integrations can reuse smaller public views that the package already ships:

- `VideoEditorLoadedView`
- `VideoEditorPlayerStageState`
- `VideoEditorPlayerStageView`
- `VideoEditorPlayerSurfaceView`
- `VideoEditorPlaybackTimelineContainerView`
- `VideoEditorPlaybackTimelineView`
- `VideoEditorPlaybackTimelineTrackSectionView`
- `VideoExportPresentationState`
- `VideoExporterView`
- `VideoEditorToolsTrayView`
- `VideoEditorToolSheetView`
- `VideoEditorToolSheetPresentationPolicy`

## Session Bootstrapping

If your host app resolves videos asynchronously, these helpers are the public bridge:

- `VideoEditorSessionBootstrapCoordinator`

## Choosing The Right Starting Point

For most host apps:

1. Create a `VideoEditorSession` from a local file or imported-file resolver.
2. Persist `SavedVideo` when `onSavedVideo` fires, keeping the original source and saved edited copy separately.
3. Configure visible tools and export qualities through `VideoEditorConfiguration`.
4. Present `VideoEditorView`.
5. Handle `onExportedVideoURL` in your own share, upload, or save flow.

Manual save is explicit. The editor tracks unsaved changes internally, enables the localized `Save` action only when the current editing snapshot differs from the last saved baseline, and prompts before canceling with pending changes. While manual save renders the edited copy, the `Save` action shows progress and the editing surface is blocked. `Cancel` remains available during that render and cancels the in-flight save instead of presenting the unsaved-changes prompt.

When manual save succeeds from the toolbar or from the unsaved-changes alert, the editor updates its saved baseline and dismisses. Export saves pending edits first, then renders the selected export resolution and calls the export callback.

The `.original` export quality uses the same native source-quality render intent as manual save, but still follows the export callback path. Hosts can block premium low, medium, or high qualities, but `.original` remains available.

## AI-Assisted Integration Prompt

When asking an AI coding assistant to integrate this package, be explicit about persistence and source ownership:

```text
Integrate VideoEditorKit into this iOS app. Present VideoEditorView from a local file URL or VideoEditorSessionSource.importedFile. Persist SavedVideo from onSavedVideo as the manually saved edited copy, keep the original source video separately, store SavedVideo.editingConfiguration for resume, and pass the saved edited copy back as preparedOriginalExportVideo when reopening the project. Use onExportedVideoURL only for explicit export/share output. Do not overwrite the original source video and do not treat onSaveStateChanged as per-edit autosave.
```

For custom caption workflows:

1. Use `VideoEditorConfiguration.TranscriptionConfiguration.openAIWhisper(apiKey:preferredLocale:)` when you want the built-in OpenAI Whisper integration.
2. Implement `VideoTranscriptionProvider` and pass it through `VideoEditorConfiguration.TranscriptionConfiguration` when you already have a custom speech-to-text backend.
3. Persist the resulting `VideoEditingConfiguration.transcript` state with the rest of the editing snapshot.

For custom crop or preview tooling:

1. Use `VideoCanvasEditorState` as the mutable canvas state source of truth.
2. Build render and preview geometry through `VideoCanvasMappingActor`.
3. Reuse `VideoCanvasPreviewView` or lower-level `VideoCanvas*` mapping types.

## Notes

- The package is currently iOS-only.
- The public surface is broader than the primary host integration API because the module also exposes reusable editor building blocks and geometry helpers.
- The real behavior of the package today is documented in the repository `README.md` and should be treated as the source of truth for current capabilities and limitations.
