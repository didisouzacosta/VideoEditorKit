# Export Save Handlers Implementation Plan

## Summary

This rollout separates the host integration into two independent callbacks:

- one callback dedicated to the exported video URL
- one callback dedicated to the latest editable state whenever the user changes the video

The long-term goal is to let the host save editing state continuously, while keeping export as an explicit user action.

## Product Requirements

1. The editor must expose two handlers instead of one combined export callback.
2. Any edit that changes the video state must trigger the save handler.
3. The save handler must return both:
   - the latest `VideoEditingConfiguration`
   - a thumbnail derived from the first frame visible at the current crop

## Current State

- `VideoEditorView` already publishes editing revisions through `editingConfigurationRevision`.
- `RootView` currently ignores those revisions and persists only on export.
- `EditedVideoProjectsStore` is still export-first and requires `ExportedVideo` to save.
- Project thumbnails are generated only from the exported file, always at timestamp `0`.

## Constraints

- The app is still an app-shell architecture, not a modular SDK with separate engines.
- The current persistence model assumes an exported file exists.
- Crop and canvas geometry already live in `VideoEditingConfiguration`, but thumbnail generation does not consume that state yet.

## Target API Shape

Suggested host-facing callback contract:

```swift
VideoEditorView(
    session,
    configuration: configuration,
    callbacks: .init(
        onSaveStateChanged: { saveState in
            // Called after each meaningful edit.
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

`thumbnailData` stays optional during the rollout so the API can be adopted before the thumbnail pipeline is fully wired.

## Rollout

### Phase 1

Goal: split the callback contract and route the latest save payload through the host shell.

Deliverables:

- rename the host callbacks so export and save are independent
- make `VideoEditorView` publish `SaveState` instead of only raw `VideoEditingConfiguration`
- make `RootView` consume:
  - the latest save payload continuously
  - the exported video URL separately
- keep export persistence working by resolving `ExportedVideo` from the exported URL and using the latest saved editing configuration

Notes:

- Phase 1 does not yet persist drafts on every edit
- Phase 1 does not yet generate the cropped thumbnail
- `thumbnailData` is expected to be `nil` until phase 3

### Phase 2

Goal: support persistence of editing state before the first export.

Deliverables:

- split `EditedVideoProjectsStore` into:
  - `saveEditingState(...)`
  - `saveExportedVideo(...)`
- allow a project record to exist without an exported file
- tighten `hasExportedVideo` and related project availability checks
- persist recorded audio together with the editing configuration during draft saves

Status:

- implemented
- `RootView` now persists edit state continuously
- `EditedVideoProjectsStore` now separates `saveEditingState(...)` and `saveExportedVideo(...)`
- draft projects can exist before export and remain editable from the home screen
- transient audio is copied into the project directory during draft saves without deleting the live editing copy

### Phase 3

Goal: generate the save thumbnail from the first visible frame of the current edit.

Deliverables:

- create a thumbnail generator that reads:
  - source video URL
  - trim lower bound
  - crop state
  - canvas state when relevant
- render the first visible frame at the current crop
- return `thumbnailData` through `onSaveStateChanged`
- store the same thumbnail in `EditedVideoProject`

Open question:

- confirm whether “first frame” means:
  - first frame of the original asset at time `0`
  - first frame of the active trimmed segment at `trim.lowerBound`

Recommended interpretation: use `trim.lowerBound`, because it matches the edited result more closely.

Status:

- implemented
- `VideoEditorView` now generates thumbnail data before publishing `onSaveStateChanged`
- thumbnail generation uses the first frame at `trim.lowerBound`
- thumbnail rendering respects crop-derived canvas geometry and current color adjustments
- saved draft state now receives non-`nil` thumbnail data when the frame can be rendered

### Phase 4

Goal: make continuous save robust under rapid editing interactions.

Deliverables:

- coalesce repeated save events during sliders and gestures
- cancel stale thumbnail work and keep only the latest request
- avoid redundant persistence when only transient presentation state changes
- add regression coverage for:
  - save callback emission
  - draft persistence without export
  - export update after draft save
  - thumbnail generation using crop

Status:

- implemented
- `VideoEditorView` now debounces save publication and skips callback emission when only transient UI state changes
- `RootView` now debounces disk persistence and keeps the latest pending save request
- `RootViewModel` now tracks pending and persisted save fingerprints to avoid redundant draft writes
- continuous-save dedupe ignores transient playback/tooling state while still preserving meaningful edit changes

## Current Status

Implemented in this cycle:

- callback split between save-state and export URL
- host shell now stores the latest editor save payload
- host shell now persists editing drafts before export
- export persistence now derives `ExportedVideo` from the exported URL and uses the latest saved configuration
- the store now supports separate draft-save and export-save flows
- draft projects can exist without an exported file and still be reopened from the home screen
- save callbacks now include thumbnail data rendered from the visible first frame of the edit

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

- run full simulator test execution once the environment is available, since this cycle validated `build` and `build-for-testing`
