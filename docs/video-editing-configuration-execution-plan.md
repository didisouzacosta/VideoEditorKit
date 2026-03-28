# Video Editing Configuration Execution Plan

## Status

- Phase 1 completed
- Phase 2 completed
- Phase 3 completed
- Host example resume flow started
- Phase 4 completed
- Phase 5 completed
- Phase 6 completed
- Phase 7 completed
- Phase 8 completed
- Phase 9 completed
- Phase 10 completed

## Summary

The resumable editing contract should stay simple:

- host input: `sourceVideoURL + VideoEditingConfiguration`
- editor output on export: `ExportedVideo + VideoEditingConfiguration`

The editor should not own persistence of the original asset. The integrator is responsible for reopening the editor later with:

- the same original video reference
- the latest saved `VideoEditingConfiguration`

That keeps the editor focused on three jobs only:

1. load a source video
2. apply a serializable editing configuration
3. return the updated configuration only together with `onExported`

## Why This Boundary

- It avoids a heavier `session` abstraction for V1.
- It avoids coupling editor persistence to host persistence strategy.
- It keeps the exported file separate from the source-of-truth editing state.
- It allows the host to save configuration wherever it wants: Core Data, database, file, cloud, or memory.

## Source Of Truth

For resume flows, the source of truth must be:

- original video
- latest `VideoEditingConfiguration`

The exported file is an output artifact, not the source of truth for reopening the editor.

## Configuration Scope

`VideoEditingConfiguration` should cover every editing choice that is currently serializable or can be made serializable without redesigning the editor architecture:

- trim
- speed
- rotation
- mirror
- filter
- color corrections
- frame
- additional audio reference and volumes
- text overlays
- lightweight presentation state useful for resume continuity

Free crop should be represented as optional future-facing state, but full restore/export parity should stay out of scope until crop leaves local `View` state.

## Phase Plan

### Phase 1

Create the serializable configuration contract and the first mapping layer.

Scope:

- Add `VideoEditingConfiguration` as a Codable model.
- Add nested serializable value types for trim, playback, crop, filter, frame, audio, text, and presentation.
- Add a mapper from runtime editor state to configuration.
- Add a mapper from configuration back to runtime `Video`.
- Add tests for encode/decode and mapping round-trips.

Out of scope:

- No changes to `VideoEditorView` public initializer yet.
- No free crop runtime integration yet.

### Phase 2

Wire the configuration into the editor boundary.

Scope:

- Add `VideoEditorView` input that accepts `sourceVideoURL + VideoEditingConfiguration`.
- Restore runtime state from the provided configuration after video load.
- Keep the current URL-only entry point as a compatibility convenience.

### Phase 3

Return updated configuration through `onExported`.

Scope:

- Ensure export returns the latest `VideoEditingConfiguration`.
- Keep configuration extraction centralized so the returned snapshot always reflects the current editor state.

Out of scope:

- No continuous change callback.
- No configuration return on editor close or dismissal.

### Host Example Follow-Up

Use the stored `VideoEditingConfiguration` in the example host integration.

Scope:

- Keep the original imported video as the host source of truth.
- Store the latest exported `VideoEditingConfiguration` in `RootViewModel`.
- Reopen `VideoEditorView` with `sourceVideoURL + editingConfiguration`.
- Demonstrate the round-trip in the sample `RootView`.

### Phase 4

Promote free crop into real editor state.

Scope:

- Move crop state out of `CropView` local `@State`.
- Persist crop geometry inside `VideoEditingConfiguration`.
- Restore crop preview from configuration.

Implementation note:

- Store free crop geometry normalized to the current preview size so restore can survive different container sizes more gracefully.

### Phase 5

Align preview and export with the same crop state.

Scope:

- Make export consume the same crop configuration.
- Add tests for crop restore and export parity.

### Phase 6

Normalize text overlay positions at the configuration boundary.

Scope:

- Serialize text offsets relative to the current preview geometry instead of raw screen points.
- Restore normalized text offsets back into runtime coordinates during reopen.
- Keep backward compatibility with older raw-offset configurations.
- Rescale runtime text positions when the preview layout changes after restore.

### Phase 7

Version the configuration contract explicitly.

Scope:

- Add a `version` field to `VideoEditingConfiguration`.
- Encode snapshots with the current schema version.
- Decode older snapshots that do not include `version`.
- Keep the migration boundary centralized in the configuration model so future schema changes have one entry point.

### Phase 8

Make schema evolution explicit in code.

Scope:

- Represent known snapshot versions as a dedicated schema enum.
- Keep `version` as the serialized wire field for compatibility.
- Route decode through a single migration entry point.
- Preserve unknown future versions without forcing local reinterpretation.

### Phase 9

Make unknown future snapshots round-trip safely.

Scope:

- Preserve the original opaque payload when decoding an unknown schema version.
- Re-encode unknown future snapshots without downgrading `version` to the local schema.
- Avoid dropping unknown fields while still keeping known-version migrations on the typed path.

### Phase 10

Return the latest editing configuration when the editor closes without export.

Scope:

- Add a host callback for explicit editor dismissal.
- Send the freshest `VideoEditingConfiguration` available at close time.
- Keep the export callback as the source of truth for rendered output, while letting the host preserve resume state after a cancel/close flow.

## Phase 1 Deliverables

This phase should produce:

- one stable Codable configuration model
- one runtime mapper
- one test suite protecting the contract

That gives the project a safe foundation before any public API expansion.

## Mapping Rules For Phase 1

- `Video.rangeDuration` -> trim
- `Video.rate` and `Video.volume` -> playback
- `Video.rotation` and `Video.isMirror` -> crop transform state
- `Video.filterName` and `Video.colorCorrection` -> filter state
- `Video.videoFrames` -> frame state
- `Video.audio` plus selected track -> audio state
- `Video.textBoxes` -> text overlay state
- selected tool and crop tab -> presentation state

## Serialization Notes

- Colors should be stored as serializable tokens, preferably palette identifiers with RGBA fallback.
- Text offsets should be serialized relative to `video.geometrySize`.
- Older configurations with raw point offsets should remain restorable as a compatibility fallback.
- Snapshots should always encode an explicit schema version.
- Known schema versions should be represented in code instead of spread as raw integers.
- Unknown future snapshots should round-trip opaquely until the local app explicitly understands them.
- The original source video URL stays outside `VideoEditingConfiguration`.
- Recorded audio reference may be serialized inside the configuration, because it is part of the edit state.

## Risks

- Reopening with a different source video than the one used to produce the configuration will lead to invalid restores.
- Very large off-screen text offsets can still fall back to legacy raw interpretation if they exceed the normalized heuristic range.
- Future schema migrations still need dedicated transform rules once the payload shape actually changes, even though the entry point is now centralized.
- Unknown future snapshots can be preserved safely, but they still cannot participate in new typed behavior until the app adds a matching schema migration.
- Free crop remains incomplete until phases 4 and 5.

## Acceptance Criteria

- A host can persist one Codable `VideoEditingConfiguration`.
- The project can reconstruct the current editable runtime state from that configuration.
- The current editable runtime state can be converted back into the same configuration shape.
- Tests protect the initial contract before editor API wiring begins.
