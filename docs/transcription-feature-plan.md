# Transcription Feature Plan

## Status

- Phase 1 completed
- Phase 2 completed
- Phase 3 completed
- Phase 4 completed
- Phase 5 completed
- Phase 6 completed

## Summary

The editor should support audio transcription as a host-integrated capability instead of owning a concrete transcription provider.

For the current app architecture, the safest path is:

- inject a provider contract through the editor configuration
- persist transcription inside `VideoEditingConfiguration`
- keep transcription content, style, and overlay layout separate
- preserve source timing and derive timeline timing for preview and export
- remap transcript timing automatically when trim or speed changes

This keeps the feature aligned with the existing app-first architecture while preparing it for a future, more modular editor.

## Current Code Reality

- The editor session already persists its full resumable state through `VideoEditingConfiguration` in [VideoEditingConfiguration.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorKit/Core/Models/Editing/VideoEditingConfiguration.swift).
- The editing session is autosaved through [VideoEditorView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorKit/Views/EditorView/VideoEditorView.swift), [RootView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorKit/Views/RootView/RootView.swift), and [EditedVideoProjectsStore.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorKit/AppShell/Persistence/EditedVideoProjectsStore.swift).
- The editor preview is composed in [PlayerHolderView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorKit/Views/EditorView/PlayerHolderView.swift) on top of `VideoCanvasPreviewView`.
- Export already runs through staged rendering in [VideoEditor.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorKit/Core/Models/Enums/VideoEditor.swift).
- `EditorViewModel` is the current orchestration point for editing state in [EditorViewModel.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorKit/Core/ViewModels/EditorViewModel.swift).

Because of that, transcription should start as a new persisted editing domain plus a new preview/export surface, not as a standalone subsystem outside the editor state flow.

## Product Decisions Confirmed

- The editor keeps a mapper between source time and playback/export time.
- The internal transcript model preserves source timing and projected timeline timing.
- Trim and speed changes remap transcript timing automatically instead of invalidating the transcript.

## Architecture Direction

### Provider layer

- `VideoTranscriptionProvider`
- `VideoTranscriptionInput`
- `VideoTranscriptionResult`
- provider output remains in source time

### Transcript domain layer

- `TranscriptDocument`
- `EditableTranscriptSegment`
- `EditableTranscriptWord`
- `TranscriptStyle`
- `TranscriptOverlayPosition`
- `TranscriptOverlaySize`
- `TranscriptTimeMapping`

### Mapping and remapping layer

- `EditorTranscriptMappingCoordinator`
- `EditorTranscriptRemappingCoordinator`
- `TranscriptTimeMapper`

### Presentation layer

- transcript tool sheet for segments and text editing
- overlay selection state in presentation-only state
- direct overlay controls for position and size in preview

### Export layer

- transcript burn-in stage integrated into the existing render pipeline
- export uses remapped timeline timing so preview and export stay aligned

## Phase Plan

## Phase 1

Status: completed.

Scope:

- document the feature roadmap
- add persistable transcript domain types
- extend `VideoEditingConfiguration` with a transcript payload
- bump the editing configuration schema version
- add migration and round-trip coverage in Swift Testing

Out of scope:

- no provider invocation yet
- no transcript tool UI yet
- no preview overlay yet
- no export burn-in yet

Completed outcome:

- the editor can now persist transcription-ready data inside the resumable editing configuration
- schema migration covers projects saved before the transcript payload existed
- the transcript model is ready for source-time and timeline-time remapping

## Phase 2

Status: completed.

Scope:

- add `TranscriptTimeMapper`
- add `EditorTranscriptMappingCoordinator`
- add `EditorTranscriptRemappingCoordinator`
- support source-time to timeline-time projection
- support automatic remapping when trim or speed changes
- cover the remapping rules with pure tests

Completed outcome:

- provider-shaped transcription output can now be mapped into the internal editable transcript document
- source timing is preserved while projected timeline timing is derived from trim and playback rate
- transcript timing is remapped automatically as the current editor session changes cut or speed
- pure Swift tests now cover source-time projection, provider-result mapping, remapping, and restored editor state

## Phase 3

Status: completed.

Scope:

- expose provider injection through `VideoEditorView.Configuration`
- add transcript state to `EditorViewModel`
- trigger async transcription from the current source video
- map provider output into the internal editable model
- support loading, success, and failure state

Completed outcome:

- the host app can now inject a transcription provider, available styles, and preferred locale through the editor configuration
- `EditorViewModel` now owns a runtime transcript state with loading, loaded, and failure handling
- the editor can transcribe the current source file asynchronously and map provider output into the persisted editable transcript document
- provider-not-configured, empty-result, invalid-source, and provider-failure paths are covered in Swift Testing

## Phase 4

Status: completed.

Scope:

- add the transcript tool to the toolbar and tool sheet flow
- show transcript segments in a list
- allow text editing per segment
- optionally support word-level text edits without changing timing
- support visual style assignment

Completed outcome:

- the transcript tool is now part of the editor toolbar and sheet flow
- the editor can show transcript segments, edit segment text, assign styles, and reset the transcript document
- text editing remains timing-safe because only `editedText` changes while time mappings stay intact

## Phase 5

Status: completed.

Scope:

- add transcript overlay preview on top of the player canvas
- support direct selection of the subtitle overlay
- add contextual controls for vertical position and simplified size
- add a pure layout resolver for width and font sizing
- ensure crop only limits visible area, without mutating transcript content

Completed outcome:

- the active transcript segment now renders as an overlay on top of the player canvas using timeline timing
- the preview supports direct overlay selection, a subtle dimmed background, a visible selection border, and contextual controls for position and size
- a pure layout resolver now calculates safe horizontal width, vertical placement, and adaptive font sizing for the overlay preview
- the overlay selection state stays transient in presentation state while position and size persist in the transcript document

## Phase 6

Status: completed.

Scope:

- add transcript burn-in to the export pipeline
- align active subtitle selection with timeline timing during export
- verify stage ordering against frame, crop, and canvas behavior
- add export-focused tests for the subtitle render plan

Completed outcome:

- the export pipeline now includes a dedicated transcript burn-in stage between color adjustments and canvas crop
- transcript rendering uses projected timeline timing, so preview selection timing and export timing stay aligned
- stage ordering is now explicit and testable through a pure render-stage plan
- export-focused tests cover transcript-stage activation and the expected stage order relative to adjusts and crop

## Testing Notes

The most important invariants for the feature are:

- provider output source timing is preserved
- textual edits never change timing
- trim and speed changes only remap projected timeline timing
- preview and export use the same projected timeline timing
- transcript persistence survives project reopen without losing style or overlay choices

For the first two phases, the minimum test suite should cover:

- `VideoEditingConfiguration` schema migration
- transcript codable round-trip
- source-time to timeline-time mapping
- remapping after trim changes
- remapping after playback-rate changes
- filtering or hiding segments that fall fully outside the trimmed range
