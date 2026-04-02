# VideoEditor PhotosPicker Session Plan

## Summary

This plan moves `PhotosPickerItem` loading responsibility from the app shell into `VideoEditorView`, while keeping the editor reusable for future SDK extraction.

The key design choice is to make the editor accept a host-facing source abstraction instead of only a resolved file URL. That lets the host open the editor immediately with:

- a local file URL for resumable sessions
- a `PhotosPickerItem` for newly imported media

The editor then becomes responsible for:

- resolving the source into a local file URL
- showing loading UI while import is in progress
- showing a recoverable error state on failure
- only bootstrapping the editing interface once media is ready

## Current State

- `RootView` opens the editor immediately with `Session.Source.photosPickerItem`.
- `VideoEditorView` resolves the source into a local file URL after presentation.
- `VideoEditorView` owns bootstrap UI for `loading`, `error`, and `loaded` states.
- `RootViewModel` stores the resolved original video URL only after the editor reports it through `onSourceVideoResolved`.
- URL-based reopen remains supported through `Session.Source.fileURL` and compatibility initializers.

## Goals

1. Let the host present the editor immediately with either a file URL or a `PhotosPickerItem`.
2. Make the editor responsible for import bootstrap UI (`loading`, `error`, `success`).
3. Preserve the current URL-based reopen flow for saved projects.
4. Keep the API suitable for future SDK extraction.
5. Roll out incrementally without breaking persistence and export.

## Non-Goals

- Do not migrate persistence or export ownership into the editor in this change.
- Do not force the host to stop using file URLs for saved-project reopen.
- Do not move share sheet or paywall alert concerns into the editor.

## Proposed Public API Direction

Extend `VideoEditorView.Session` with a source abstraction:

```swift
extension VideoEditorView {
    struct Session {
        var source: Source?
        var editingConfiguration: VideoEditingConfiguration?

        enum Source {
            case fileURL(URL)
            case photosPickerItem(PhotosPickerItem)
        }
    }
}
```

Compatibility bridge remains available:

```swift
init(
    sourceVideoURL: URL? = nil,
    editingConfiguration: VideoEditingConfiguration? = nil
)
```

This compatibility initializer internally maps to `.fileURL`.

## Rollout Phases

### Phase 1 — Session Contract Foundation

- Add `VideoEditorView.Session.Source`.
- Keep URL-based call sites working through compatibility initializers and computed properties.
- Add tests covering:
  - file URL source construction
  - compatibility mapping from `sourceVideoURL`
  - session equality for URL-backed sessions

Status:
- Completed.

### Phase 2 — Editor-Owned Source Resolution

- Introduce a dedicated editor-side source resolver near `VideoEditorView`.
- Move `loadTransferable(type: VideoItem.self)` behavior out of `RootView`.
- Defer source resolution callbacks until the editor itself owns bootstrap and starts resolving the source after presentation.

Suggested file:
- `VideoEditorKit/Views/EditorView/VideoEditorSessionSourceResolver.swift`

Status:
- Completed.

### Phase 3 — Bootstrap UI Inside The Editor

- Add explicit editor bootstrap state:
  - `idle`
  - `loading`
  - `loaded(URL)`
  - `failed(String)`
- Render loading and error UI inside `VideoEditorView`.
- Only call `editorViewModel.setSourceVideoIfNeeded(...)` after bootstrap succeeds.

Status:
- Completed.

### Phase 4 — Host Migration

- Update `RootViewModel.startEditorSession(...)` to accept `Session.Source`.
- Remove `RootView.loadSelectedItem(_:)`.
- Remove `itemLoadTask` and import loading state from the app shell.
- Open the editor immediately from `RootView` with `.photosPickerItem(selectedItem)`.

Status:
- Completed.

### Phase 5 — Cleanup

- Remove `RootViewModel.isLoading` if import loading is fully editor-owned.
- Keep shell-owned errors focused on persistence/export only.
- Revisit naming and public API polish for SDK extraction.

Status:
- Completed.

## Testing Strategy

### Phase 1

- Extend unit tests around `VideoEditorView.Session` construction and equality.
- Keep `RootViewModelTests` passing to validate compatibility with current URL flow.

### Phase 2 / 3

- Add dedicated tests for source resolution behavior.
- Add editor bootstrap tests covering loading, success, and failure states.

### Phase 4

- Add or update `RootViewModelTests` for source-based session opening.
- Add smoke coverage for host presentation while the editor is bootstrapping.

## Risks

- `PhotosPickerItem` is less stable as a persisted contract than a file URL, so it should remain a transient session input only.
- The host still needs the resolved source URL for persistence/export, so source resolution must notify the host once complete.
- Session equality must stay predictable even after introducing a non-URL source case.

## Recommended Implementation Order

1. Phase 1 contract changes
2. Phase 1 tests
3. Phase 2 source resolver
4. Phase 3 bootstrap UI
5. Phase 4 host migration
6. Phase 5 cleanup
