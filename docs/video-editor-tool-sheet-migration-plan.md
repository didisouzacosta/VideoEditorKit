# VideoEditorView Tool Sheet Migration Plan

## Summary

This plan replaces the custom inline tool modal with a native SwiftUI `.sheet`, while keeping `EditorViewModel.selectedTools` as the source of truth for tool presentation. It also introduces a configuration API for `VideoEditorView` so the initial fullscreen state can be injected by the host.

## Current State

- `VideoEditorView` owns `@State private var isFullScreen = false` and passes it down to the player and controls.
- `ToolsSectionView` renders the tools grid and overlays an inline custom bottom-sheet-like container when `editorVM.selectedTools` is not `nil`.
- `EditorViewModel.selectedTools` already models which tool is active, so it is the correct driver for a future `.sheet(item:)`.
- `SheetView` is not part of the tool flow today. It is currently used by `VideoExporterBottomSheetView`, so it cannot be removed in the first pass.

## Goals

1. Replace the custom tool modal with a native `.sheet`.
2. Control the sheet height with native APIs such as `presentationDetents`.
3. Add `VideoEditorView.Configuration`.
4. Start with `Configuration.isFullScreen: Bool = false`.
5. Use `configuration.isFullScreen` as the initial value of the internal fullscreen state.

## Non-Goals

- Do not migrate the export sheet in this change unless a dependency is discovered during implementation.
- Do not redesign the editing tools UI beyond what is required for the native sheet transition.
- Do not change the current source of truth for active tools.

## Phases

### Phase 1

Introduce the configuration API for `VideoEditorView` and seed the internal `@State` fullscreen value from `Configuration.isFullScreen`.

Scope:

- Add `VideoEditorView.Configuration`.
- Extend the `VideoEditorView` initializer with a `configuration` parameter that defaults to `.init()`.
- Initialize `_isFullScreen` from `configuration.isFullScreen`.
- Preserve the current call sites and behavior when configuration is omitted.

Out of scope:

- No `.sheet` migration yet.
- No tool presentation changes yet.

### Phase 2

Replace the inline tool presentation in `ToolsSectionView` with a native `.sheet` driven by `selectedTools`.

Scope:

- Keep the tool grid as the launcher.
- Convert `selectedTools` into a valid `.sheet(item:)` driver.
- Extract the tool content builder from the current inline `bottomSheet(...)` implementation.
- Preserve close, reset, remove-audio, and text-sync behaviors when the sheet is dismissed.

### Phase 3

Tune detents, interaction behavior, and cleanup old presentation code.

Scope:

- Define native sheet height groups per tool.
- Verify horizontal scrolling tools inside the sheet.
- Remove obsolete inline modal code.
- Reassess whether any shared sheet styling helpers remain necessary.

### Phase 4

Cleanup legacy tool-modal naming and align the codebase with the native-sheet model.

Scope:

- Rename tool content views that still carry `Sheet` naming even though they are no longer responsible for presenting a sheet.
- Update references and previews to match the new naming.
- Refresh this migration document so the current repository state matches the implemented rollout.

### Phase 5

Migrate the export flow to the native sheet stack and retire the remaining custom sheet container.

Scope:

- Present the export flow with SwiftUI `.sheet` from `VideoEditorView`.
- Convert `VideoExporterBottomSheetView` into native sheet content instead of a wrapper around `SheetView`.
- Delete `SheetView` once it no longer has active usages.

## Implementation Notes

### `VideoEditorView` configuration

- Preferred API shape:
  - `VideoEditorView.Configuration`
  - `init(_ sourceVideoURL: URL? = nil, configuration: Configuration = .init(), onExported: @escaping (URL) -> Void = { _ in })`
- The configuration should seed internal state only.
- Later updates to the configuration should not mutate the already-initialized `@State` unless the API is intentionally redesigned around bindings or observable configuration.

### Tool sheet migration

- Attach the native `.sheet` close to `ToolsSectionView`, because that file already owns the tool launcher and the tool-specific content builder.
- Keep `selectedTools` in `EditorViewModel` as the only active-tool state.
- Make system dismissal and explicit close actions follow the same closing path so text persistence and side effects stay aligned.

### Height strategy

- Keep the detent logic in the view layer, not in `ToolEnum`, to avoid introducing SwiftUI presentation knowledge into the model layer.
- Start with grouped detents by tool complexity and tune after manual validation.

## Files Expected To Change

- `VideoEditor/Views/EditorView/VideoEditorView.swift`
- `VideoEditor/Views/ToolsView/ToolsSectionView.swift`
- `VideoEditor/Core/ViewModels/EditorViewModel.swift`
- `VideoEditor/Core/Models/ToolModel.swift`
- `VideoEditor/Views/RootView/RootView.swift`
- `VideoEditor/Views/EditorView/PlayerHolderView.swift`

## Risks

- Native sheet dismissal can bypass current inline-close assumptions if dismiss handling is not centralized.
- Tool-specific interactions may feel different inside a draggable native sheet, especially for horizontally interactive controls.
- `isFullScreen` is used in sizing logic during `onAppear`, so initial state seeding must happen before the first render cycle that loads the source video.

## Acceptance Criteria

- `VideoEditorView` accepts a configuration object without breaking existing call sites.
- Omitting configuration preserves the current initial fullscreen behavior.
- Passing `configuration: .init(isFullScreen: true)` starts the editor in fullscreen.
- The tool migration remains clearly staged so phase 2 can swap the inline modal for a native sheet without revisiting the API groundwork.
