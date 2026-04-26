# Export Save Handlers Implementation Plan

## Summary

This rollout separates the host integration into two independent callbacks:

- one callback dedicated to the exported video URL
- one callback dedicated to the rendered edited copy produced by manual save

The current goal is to keep both save and export explicit: save renders an edited copy for normal reuse, and export first saves pending edits before rendering the selected export resolution.

Latest behavior:

- the toolbar `Save` action is separate from the export/share action
- `Save` shows progress while rendering and blocks the editor surface, while `Cancel` remains available
- tapping `Cancel` during save cancels the in-flight save
- a successful toolbar or alert-driven save closes the editor after callbacks complete
- the example app stores the project thumbnail from the first frame of the persisted saved edited video

## Product Requirements

1. The editor must expose two handlers instead of one combined export callback.
2. Ordinary edit interactions must not persist automatically.
3. The editor must track unsaved changes internally and enable the save action only when the current snapshot differs from the saved baseline.
4. Manual save must return:
   - a rendered edited copy
   - the preserved original video URL
   - the latest `VideoEditingConfiguration`
   - a thumbnail derived from the saved edit when available
5. Export must call save first when there are pending edits, then render the selected export resolution.
6. Manual save must expose loading and cancellation so long native renders do not look frozen.
7. Manual save from the primary toolbar action must dismiss the editor after a successful save.

## Current State

- `VideoEditorView` tracks unsaved changes with `VideoEditorManualSaveCoordinator`.
- Manual save renders through `VideoEditorManualSaveRenderer` and emits `onSavedVideo`.
- `onSaveStateChanged` now accompanies manual save with the saved snapshot and thumbnail; it is not an autosave stream for every edit.
- The save button uses `VideoEditorManualSaveActionPresentation` to move between hidden, disabled, enabled, and loading states.
- `VideoEditorView` keeps a cancellable manual-save task so `Cancel` can stop an in-flight save while the editing surface is disabled.
- The example app persists the edited copy through `ProjectsRepository.saveEditedVideo(...)`.
- The example app keeps original, saved edited copy, and exported output as separate project files.
- `ProjectsRepository.saveEditedVideo(...)` generates the project thumbnail from the first frame of the persisted edited copy.

## Constraints

- The app is still an app-shell architecture, not a modular SDK with separate engines.
- Existing hosts that treated `onSaveStateChanged` as an autosave stream must move persistence to `onSavedVideo`.
- Crop and canvas geometry already live in `VideoEditingConfiguration`, and save/export thumbnail generation should continue consuming that saved snapshot.

## Target API Shape

Suggested host-facing callback contract:

```swift
VideoEditorView(
    session,
    configuration: configuration,
    callbacks: .init(
        onSaveStateChanged: { saveState in
            // Called after manual save publishes the saved snapshot.
        },
        onSavedVideo: { savedVideo in
            // Called after manual save renders the edited copy.
        },
        onDismissed: { latestConfiguration in
            // Optional lifecycle callback.
        },
        onExportedVideoURL: { exportedVideoURL in
            // Called only after explicit export succeeds.
        }
    )
)
```

Suggested save payload:

```swift
struct SaveState: Equatable, Sendable {
    let editingConfiguration: VideoEditingConfiguration
    let thumbnailData: Data?
}
```

Manual save also emits `SavedVideo`, which carries the edited-copy URL, original video URL, editing configuration, thumbnail data, and metadata. `thumbnailData` remains optional because frame generation can fail for invalid or unavailable media.

In the example app, project cover persistence does not trust transient callback thumbnail bytes. It regenerates thumbnail data from frame `0` of the saved edited-copy file after that file is copied into the project directory.

## Rollout

### Phase 1

Goal: split the callback contract and route the latest save payload through the host shell.

Deliverables:

- rename the host callbacks so export and save are independent
- make `VideoEditorView` publish `SaveState` instead of only raw `VideoEditingConfiguration`
- make `RootView` consume:
  - the latest saved payload
  - the exported video URL separately
- keep export persistence working by resolving `ExportedVideo` from the exported URL and using the latest saved editing configuration

Notes:

- Phase 1 originally introduced save-state publication before the later manual-save refactor
- Phase 1 does not yet generate the cropped thumbnail
- `thumbnailData` is expected to be `nil` until phase 3

### Phase 2

Goal: support persistence of editing state before the first export.

Deliverables:

- split project persistence into:
  - `saveEditedVideo(...)`
  - `saveExportedVideo(...)`
- allow a project record to exist without an exported file
- tighten `hasExportedVideo` and related project availability checks
- persist recorded audio together with the editing configuration during manual saves

Status:

- implemented
- the example host now persists edit state only after `onSavedVideo`
- `ProjectsRepository` now separates `saveEditedVideo(...)` and `saveExportedVideo(...)`
- projects can exist before export with original media plus a saved edited copy
- transient audio is copied into the project directory during manual saves without deleting the live editing copy

### Phase 3

Goal: generate the save thumbnail from the first visible frame of the current edit.

Deliverables:

- create a thumbnail generator that reads:
  - source video URL
  - trim lower bound
  - crop state
  - canvas state when relevant
- render the first visible frame at the current crop
- return `thumbnailData` through manual save callbacks
- store the project cover thumbnail in `EditedVideoProject`

Resolved thumbnail policy:

- package callback thumbnails are generated from the saved edit snapshot and use the first visible frame of the edit
- example-app project cover thumbnails are generated from frame `0` of the persisted saved edited copy, because that file is already the ready-to-use edited artifact

Status:

- implemented
- `VideoEditorView` now generates thumbnail data before publishing manual save callbacks
- thumbnail generation uses the first frame at `trim.lowerBound`
- thumbnail rendering respects crop-derived canvas geometry and current color adjustments
- saved edit state now receives non-`nil` thumbnail data when the frame can be rendered
- the example app now persists the project thumbnail from the first frame of the saved edited video copy

### Phase 4

Goal: keep save-state publication robust under rapid editing interactions.

Deliverables:

- coalesce repeated save events during sliders and gestures
- cancel stale thumbnail work and keep only the latest request
- avoid redundant persistence when only transient presentation state changes
- add regression coverage for:
  - save callback emission
  - saved-edit persistence without export
  - export update after manual save
  - thumbnail generation using crop

Status:

- implemented
- superseded by manual save
- the editor now tracks unsaved changes internally instead of publishing continuous save callbacks after edit actions
- transient playback/tooling state is still ignored by the save fingerprint used for manual save availability

## Current Status

Implemented in this cycle:

- callback split between save-state and export URL
- manual save now emits `SavedVideo` through `onSavedVideo`
- host shell persists only after manual save
- export saves pending edits before rendering the selected quality
- export persistence derives `ExportedVideo` from the exported URL and uses the latest saved configuration
- the store now supports separate edited-copy save and export-save flows
- projects can exist with original media and a saved edited copy before export
- save callbacks now include thumbnail data rendered from the visible first frame of the edit
- project persistence regenerates its cover thumbnail from the first frame of the saved edited copy
- manual save shows progress, blocks editing interactions, supports cancel through the toolbar cancel action, and dismisses the editor on success

### Phase 5

Goal: cover save callback emission timing with focused regression tests.

Deliverables:

- extract `VideoEditorView` save emission orchestration into a dedicated coordinator
- add regression coverage for:
  - latest-wins behavior during rapid edits
  - transient-only changes not producing a second callback
  - reset/cancel semantics when the editor disappears

Status:

- implemented
- `VideoEditorView` now delegates debounced save emission to `VideoEditorSaveEmissionCoordinator`
- the coordinator is covered by dedicated tests for latest-wins, transient-state dedupe, and reset behavior

## Remaining Work

- keep integration documentation aligned with the explicit manual save process as future save/export behavior changes
