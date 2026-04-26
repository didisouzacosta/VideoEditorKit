# Manual Save and Export Refactor Plan

## Context

Before this refactor, the editor emitted continuous save snapshots while the user edited, and export was the first flow that produced a rendered video file for sharing or persistence. The new flow moves save/export into explicit user actions:

- save becomes manual and visible in the editor toolbar
- unsaved changes are tracked by an internal diff
- cancel with pending changes requires confirmation
- save renders an edited copy while preserving the original video, source resolution, and source FPS
- save is a long-running operation with explicit loading, editing-surface blocking, and cancel support
- successful save from the toolbar or unsaved-changes alert dismisses the editor
- export first saves the current edit, then renders the selected export resolution

This plan follows the current package-first architecture: `VideoEditorKit` owns the editor runtime and callbacks, while the example app owns project persistence and sharing.

## Goals

1. Add a primary manual save button to the editor toolbar, separated from the export toolbar item, positioned to the right of export, and labeled with localized "Save" text.
2. Stop saving after every edit action.
3. Track pending changes inside the editor and enable save only when the current editing configuration differs from the last saved baseline.
4. Warn the user when canceling with unsaved changes.
5. Preserve the original source video exactly as it is today.
6. Render a saved edited copy that applies the current edit configuration without changing resolution or FPS.
7. Make export call save first, then perform the requested resolution transform, then call the export callback.
8. Update host/example persistence so manual save and export are distinct lifecycle events.
9. Update documentation to describe the new process.

## Non-Goals

- Do not turn the current monolithic editor into pure layout/player/export engines as part of this refactor.
- Do not add freeform crop export support beyond what the current renderer already supports.
- Do not introduce background-resumable export jobs.
- Do not remove the original video from project storage.
- Do not change the available export qualities (`low`, `medium`, `high`) in this refactor.

## Proposed Public API Changes

Introduce a manual save payload for the host:

```swift
public struct SavedVideo: Sendable {
    public let url: URL
    public let originalVideoURL: URL
    public let editingConfiguration: VideoEditingConfiguration
    public let thumbnailData: Data?
    public let metadata: ExportedVideo
}
```

Add a callback to `VideoEditorCallbacks`:

```swift
public let onSavedVideo: (SavedVideo) -> Void
```

The existing export callback remains distinct:

```swift
public let onExportedVideoURL: (URL) -> Void
```

`onSaveStateChanged` should no longer be called after every edit. It remains available as save-state publication after explicit manual save, while `onSavedVideo` is the primary persistence callback for the rendered edited copy.

## Editor State Changes

Add a manual save coordinator inside `VideoEditorKit`, for example `VideoEditorManualSaveCoordinator`, responsible for:

- storing the saved baseline editing configuration
- comparing the baseline with the current configuration fingerprint
- exposing `hasUnsavedChanges`
- clearing pending state after a successful save
- resetting the baseline when loading or replacing the source video

The diff should use `VideoEditingConfiguration.continuousSaveFingerprint` so transient playback/tooling state does not incorrectly enable save.

## Toolbar Changes

Update `VideoEditorView` toolbar actions:

- keep the export action as an icon-only share-style button
- add a primary localized `Save` text button to the right of export
- render export and save as separate toolbar items, not as one grouped `HStack`
- disable save while there are no unsaved changes
- show progress in the save button while the native save render is running
- disable relevant actions while save/export work is in progress
- block the editor content while save is in progress, but leave `Cancel` active
- keep effectful work outside `body` in small private methods

Use a native SF Symbol share-style icon for export, such as `square.and.arrow.up`. The save action should be text-forward and localized in every supported package language.

## Cancel Confirmation Flow

When the user taps cancel:

1. If there are no unsaved changes, dismiss normally.
2. If a manual save is in progress, cancel that save and remain in the editor.
3. If there are unsaved changes, show a confirmation alert.
4. Alert actions:
   - Save: run the manual save flow; on success, dismiss.
   - Discard: dismiss without saving.
   - Cancel: stay in the editor.

Model alert presentation with one explicit state value rather than unrelated booleans.

## Save Rendering Flow

Manual save should:

1. Resolve the current `Video`.
2. Resolve the current `VideoEditingConfiguration`.
3. Render a copy of the original video with the current edits applied.
4. Preserve source resolution.
5. Preserve source FPS when the asset exposes reliable frame timing.
6. Generate thumbnail data for the saved edit.
7. Update the internal saved baseline.
8. Call `onSavedVideo`.
9. Dismiss the editor when the save was started from the toolbar or from the unsaved-changes alert.

The original video remains stored separately and unchanged.

In the example app, the persisted project thumbnail is generated from the first frame of the saved edited video copy so the saved project cover reflects the ready-to-use edited artifact.

## Export Rendering Flow

Export should:

1. Run manual save first when the current edit has unsaved changes.
2. Use the saved snapshot as the source of truth for the export request.
3. Render the selected export quality (`low`, `medium`, or `high`).
4. Call `onExportedVideoURL`.

This keeps save and export consistent while preserving export as a separate resolution-changing operation.

## Render Pipeline Changes

Introduce an explicit render intent/profile:

```swift
enum VideoRenderIntent {
    case saveNative
    case export(VideoQuality)
}
```

or an equivalent `VideoRenderProfile` value that includes:

- render size
- frame duration or nominal FPS
- whether source dimensions should be preserved
- selected export quality when relevant

`saveNative` should reuse the same edit stages as export, but resolve the final canvas from the source asset instead of `VideoQuality`.

## Example App Persistence Changes

Update `EditorHostScreen`, `EditorSessionController`, `ProjectsRepository`, and `ProjectMediaStore` so:

- autosave debounce is removed
- the host persists only after the manual save callback
- projects can store the original video and the saved edited copy separately
- exported video remains separate from the saved edited copy
- share presentation continues to use the appropriate generated file URL

Likely repository additions:

```swift
func saveEditedVideo(...)
func saveExportedVideo(...)
```

## Documentation Updates

Update documentation in the same implementation cycle:

- `AGENTS.md`
- `CLAUDE.md`
- `README.md`
- `Sources/VideoEditorKit/VideoEditorKit.docc/VideoEditorKit.md`
- `Docs/export-save-handlers-implementation-plan.md`
- `Docs/export-background-lifecycle-plan.md`
- any other document that still presents continuous autosave as the primary save flow

Documentation must state that:

- edits are no longer saved automatically
- the editor tracks unsaved changes internally
- cancel with pending changes prompts the user
- cancel during an in-flight save cancels that save instead of showing the unsaved-changes prompt
- save shows loading, blocks editing interactions, and closes the editor on success
- save renders an edited copy while preserving source resolution and FPS
- the original video is always preserved
- the example app uses the first frame of the saved edited copy as the project thumbnail
- export performs save first, then renders the selected export resolution
- save and export are distinct host callbacks
- integration examples should use the manual save callback instead of autosave

## Test Plan

Add characterization tests before changing behavior:

- current autosave scheduling publishes save state from the loaded video URL
- current autosave shape maps into the public save payload
- current export publishes the exported URL after render
- current export uses the selected quality
- current export uses the current editing configuration snapshot

Add behavior tests during the refactor:

- diff starts clean after initial load
- editing a tool enables save
- save success clears unsaved changes
- save success dismisses the editor
- save is disabled when there are no unsaved changes
- save shows a loading state and blocks editor content while rendering
- cancel without changes dismisses immediately
- cancel during save cancels the current save task
- cancel with changes presents confirmation
- discard closes without save callback
- save from alert calls the save callback and dismisses
- export calls save before export when changes are pending
- native save preserves source resolution
- native save preserves source FPS when available
- no host save callback fires during ordinary edit interactions

Official validation should use the iOS Simulator:

```sh
Scripts/test-ios.sh
```

When package-only validation is needed, use the shared `VideoEditorKit-Package` scheme in `Example/VideoEditor.xcworkspace`.

## Implementation Phases

1. Add characterization tests for the current autosave and export behavior.
2. Add the manual save public payload and callback.
3. Add the internal diff/manual save coordinator.
4. Add toolbar save UI and cancel confirmation state.
5. Disable autosave and route save through the explicit button/action.
6. Add native save render intent/profile.
7. Make export depend on save.
8. Update example app persistence and sharing.
9. Update documentation.
10. Run formatting and iOS Simulator validation.

## Current Implementation Status

- Phases 1 through 8 are implemented.
- Phase 9 updated integration and repository documentation to describe explicit manual save, unsaved-change tracking, cancel confirmation, the `SavedVideo` callback, and export's save-first behavior.
- Phase 10 completed the focused validation pass for the manual-save runtime behavior.
- Follow-up refinements are implemented and documented: export/save toolbar separation, loading and cancelable manual save, successful-save dismissal, and first-frame persisted thumbnails in the example app.
