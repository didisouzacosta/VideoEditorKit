# Video Duration Limit Plan

## Summary

This plan introduces an optional host-defined duration limit for the editor session.

When the host passes a limit such as `300`, `120`, or `45`, the editor must treat that value as the maximum allowed duration for the selected trim window.

When the host does not pass a limit, the current behavior remains unchanged.

The rule applies to temporal trim only:

- a limit of `60` allows `0...60`
- a limit of `60` allows `30...90`
- a limit of `60` does not allow any selected window longer than `60`

This plan does not change visual crop behavior. In the current codebase, "crop" and timeline "cut" are different concerns. The limit described here constrains the timeline trim window.

## Goals

1. Allow the host app to configure an optional maximum video duration through `VideoEditorView.Configuration`.
2. Apply the limit consistently during initial load, resumable-session restore, save snapshots, and export snapshots.
3. Keep the implementation incremental and aligned with the current app-shaped architecture.
4. Add tests before changing the higher-risk timeline interaction layer.

## Non-Goals

- Do not redesign `Video` into a new engine-oriented model.
- Do not persist the host duration limit inside `VideoEditingConfiguration`.
- Do not change visual freeform crop or canvas geometry as part of this work.
- Do not introduce concurrent export guards or unrelated editor architecture changes.

## Proposed Public API

Extend `VideoEditorConfiguration` with a new optional property:

```swift
public init(
    tools: [ToolAvailability] = ToolAvailability.enabled(ToolEnum.all),
    exportQualities: [ExportQualityAvailability] = ExportQualityAvailability.allEnabled,
    transcription: TranscriptionConfiguration = .init(),
    maximumVideoDuration: TimeInterval? = nil,
    onBlockedToolTap: ((ToolEnum) -> Void)? = nil,
    onBlockedExportQualityTap: ((VideoQuality) -> Void)? = nil
)
```

Behavior:

- `nil` means no limit
- non-finite or non-positive values are normalized to `nil`
- a positive value represents the maximum allowed trim-window duration in seconds

## Current State

Today the timeline uses the full `video.originalDuration` as the trim bound, and the initial range is restored directly from the loaded `VideoEditingConfiguration` or from the raw asset duration.

Key current touchpoints:

- `VideoEditorConfiguration` is the host entry point
- `HostedVideoEditorRuntimeCoordinator` applies editor configuration into runtime state
- `EditorViewModel` loads the `Video` and applies pending editing configuration
- `EditorInitialLoadCoordinator` restores trim state into the loaded `Video`
- `ThumbnailsSliderView` currently enforces only `minimumDistance`, not `maximumDistance`

## Rollout Phases

### Phase 1 — Contract And Clamp Foundation

Status: completed.

Scope:

- add the optional duration limit to `VideoEditorConfiguration`
- normalize invalid host inputs
- introduce a pure internal coordinator to clamp trim windows against the limit
- apply the clamp during initial video load and resumable-session restore
- add unit tests for the public contract and pure trim-limit rules

Expected outcome:

- new sessions open already limited when needed
- restored sessions never exceed the configured limit
- save and export snapshots inherit the already-clamped trim state

### Phase 2 — Timeline Interaction Enforcement

Status: completed.

Scope:

- update the trim interaction layer so the user cannot drag the selected window beyond the configured maximum duration
- extend the slider stack to support `maximumDistance`, not only `minimumDistance`
- clamp active playback and scrub state when a limit change shrinks the selected range

Expected outcome:

- the UI itself prevents creating invalid trim ranges
- playback indicators remain coherent while editing the limited range

### Phase 3 — Host UX And Validation

Status: completed.

Scope:

- wire the example app with one or more sample limits
- review copy or affordances if the host wants to explain the limitation
- validate the package and example app on iOS Simulator

Expected outcome:

- end-to-end confidence in both package and host integration flows

## Technical Design Notes

### Why the limit belongs in `VideoEditorConfiguration`

The limit is a host policy, not part of persisted editing state. A project may be reopened under a different host plan or entitlement, so the current session policy should come from the runtime configuration rather than from `VideoEditingConfiguration`.

### Why the clamp should be centralized

The current code already computes trim state in multiple places. A dedicated pure coordinator reduces the risk of slightly different rules between:

- initial load
- resumable restore
- timeline interaction
- save and export snapshot generation

### Expected clamp semantics

For a source duration `D` and limit `L`:

- the selected range is always clamped inside `0...D`
- if the selected range duration is `<= L`, it is preserved
- if the selected range duration is `> L`, keep the lower bound and shrink the upper bound to `lowerBound + L`
- when there is no prior trim selection, default to `0...min(D, L)`

## Testing Strategy

### Phase 1

- `VideoEditorPublicTypesTests`
  - configuration stores valid positive limits
  - invalid limits normalize to `nil`
- dedicated coordinator tests
  - no-limit behavior preserves current trim semantics
  - initial default range becomes `0...limit`
  - persisted ranges above the limit are shrunk correctly
- `EditorInitialLoadCoordinatorTests`
  - applying pending configuration respects the limit
- `EditorViewModelTests`
  - source bootstrap applies the configured duration limit to the loaded video

### Phase 2

- slider interaction tests for maximum-distance enforcement
- playback time clamping tests when the selected range shrinks

### Phase 3

- package and example app validation on iOS Simulator using `scripts/test-ios.sh`

## Risks

- the current timeline stack was built around full-duration bounds, so interaction enforcement is the riskiest part
- a runtime limit change after the editor is already open can invalidate the current trim selection and playback time
- transcript time mapping depends on trim and playback rate, so any trim clamp must continue remapping transcript timeline values correctly

## Recommended Implementation Order

1. Phase 1 contract updates
2. Phase 1 pure clamp coordinator
3. Phase 1 view model and bootstrap integration
4. Phase 1 tests
5. Phase 2 slider enforcement
6. Phase 2 playback clamp cleanup
7. Phase 3 host wiring and simulator validation
