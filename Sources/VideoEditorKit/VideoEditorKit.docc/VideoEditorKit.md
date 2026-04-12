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
- `VideoEditorSaveState`: continuous-save payload emitted by the editor
- `VideoEditingConfiguration`: serializable editing snapshot used to restore a session later
- `VideoEditorKitPackage`: lightweight package metadata namespace

## Tool And Export Availability

Use these types when your host app needs feature gating, premium locks, or custom ordering:

- `ToolEnum`
- `ToolAvailability`
- `VideoQuality`
- `ExportQualityAvailability`
- `ExportedVideo`

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
2. Persist `VideoEditingConfiguration` whenever save callbacks fire.
3. Configure visible tools and export qualities through `VideoEditorConfiguration`.
4. Present `VideoEditorView`.
5. Handle `onExportedVideoURL` in your own share, upload, or save flow.

For custom caption workflows:

1. Use `VideoEditorConfiguration.TranscriptionConfiguration.appleSpeech(preferredLocale:)` when you want the built-in Apple Speech integration.
2. Use `VideoEditorConfiguration.TranscriptionConfiguration.openAIWhisper(apiKey:preferredLocale:)` when you want the built-in OpenAI Whisper integration.
3. Implement `VideoTranscriptionProvider` and pass it through `VideoEditorConfiguration.TranscriptionConfiguration` when you already have a custom speech-to-text backend.
4. Persist the resulting `VideoEditingConfiguration.transcript` state with the rest of the editing snapshot.

Apple Speech does not require an API key. It uses the system Speech framework, so the host app is still responsible for its own Speech recognition usage description and for choosing an appropriate `preferredLocale` when the spoken language is known.

For custom crop or preview tooling:

1. Use `VideoCanvasEditorState` as the mutable canvas state source of truth.
2. Build render and preview geometry through `VideoCanvasMappingActor`.
3. Reuse `VideoCanvasPreviewView` or lower-level `VideoCanvas*` mapping types.

## Notes

- The package is currently iOS-only.
- The public surface is broader than the primary host integration API because the module also exposes reusable editor building blocks and geometry helpers.
- The real behavior of the package today is documented in the repository `README.md` and should be treated as the source of truth for current capabilities and limitations.
