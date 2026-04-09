# EditorView Package Extraction Plan

## Summary

This plan moves the remaining editor-owned SwiftUI surfaces out of the host app's `Views/EditorView` folder and into `Packages/VideoEditorKit`, while keeping the app shell responsible only for integration-specific behavior.

The migration should happen in three steps instead of one large move because the files under `VideoEditor/Views/EditorView` do not all have the same level of host coupling.

## Goal

Turn the package into the real owner of the editor view layer, with the app target keeping only:

- app-shell presentation
- persistence and reopen policy
- share and premium flows
- import adapters and shell-specific helpers

## Step 1 — Canvas Preview Surface

Move the most package-ready preview components first.

Scope:

- move `VideoCanvasEditorState` into the package
- move `VideoCanvasPreviewView` into the package
- move `VideoCanvasInteractionCancellationPolicy` into the package
- move `TranscriptOverlayPreview` into the package once its pure transcript layout/style helpers are package-owned
- move `TranscriptOverlayLayoutResolver` and `TranscriptTextStyleResolver` into the package
- move the matching policy/unit coverage into package tests
- keep host smoke coverage that renders the package view inside the app integration target

Why first:

- these types already depend mostly on package-owned canvas models
- they do not depend on `RootView`, persistence, paywall, or export policy
- they reduce `EditorView` folder size without forcing a full editor screen extraction yet

Exit criteria:

- the host app consumes `VideoCanvasEditorState` and `VideoCanvasPreviewView` from `VideoEditorKit`
- no duplicate app-local copies remain
- package tests and targeted host smoke tests still pass

Status:

- in progress
- started by moving `VideoCanvasEditorState`, `VideoCanvasPreviewView`, and `VideoCanvasInteractionCancellationPolicy` into `Packages/VideoEditorKit`
- continued by moving `TranscriptOverlayPreview`, `TranscriptOverlayLayoutResolver`, and `TranscriptTextStyleResolver` into `Packages/VideoEditorKit`

## Step 2 — Transcript and Export Presentation

Move the next layer of editor-owned views once the canvas preview primitives are package-owned.

Scope:

- evaluate and move `TranscriptOverlayPreview`
- move any transcript text/layout helpers that are purely editor-owned and can compile cleanly in the package
- evaluate and move `VideoExporterView` with the minimum package-owned export presentation dependencies

Constraints:

- transcript styling helpers may need package-safe platform handling if they keep `UIKit`-based text measurement
- export UI should move only when its view model and result types are cleanly package-owned for the active flow

Status:

- completed
- transcript preview rendering is package-owned from the end of step 1
- export metadata now uses the package-owned `ExportedVideo`
- export presentation is now package-owned through `VideoExporterView`, while the host keeps only the thin `HostedVideoExporterView` adapter over the local render view model

Exit criteria:

- transcript preview rendering is package-owned
- export selection/progress UI is package-owned or has a clearly documented blocker
- host app no longer owns editor presentation that does not add local behavior

## Step 3 — Main Editor Screen Cutover

Replace the current host implementation shell with a thin host wrapper over a package-owned editor view.

Scope:

- introduce the package-owned `public struct VideoEditorView: View`
- migrate the implementation currently in `HostedVideoEditorView`
- move package-owned subviews such as `PlayerHolderView` and related controls only after their runtime dependencies are either extracted or intentionally injected
- keep only explicit host-specific seams, such as local project lifecycle and any remaining runtime-specific wrapper logic

Exit criteria:

- `HostedVideoEditorView` becomes a minimal host adapter or can be deleted entirely
- the package owns the actual editor screen implementation
- `VideoEditor/Views/EditorView` is reduced to true host-only integration code, or disappears completely

Status:

- completed
- started by moving the editor bootstrap/navigation shell into the package-owned `VideoEditorView`
- the app shell now opens the package directly through `VideoEditorView`
- continued by moving the loaded editor composition shell into a package-owned `VideoEditorLoadedView`, with the host now injecting player, controls, tool tray, and runtime bootstrap behavior
- continued by moving the player stage/status/canvas shell into a package-owned `VideoEditorPlayerStageView`, with the host now only injecting player rendering, transcript overlay, reset affordance, and runtime callbacks
- continued by moving the playback timeline container shell into a package-owned `VideoEditorPlaybackTimelineContainerView`, with the host now injecting the styled play button and timeline-specific content
- continued by moving the timeline badge-and-track section shell into a package-owned `VideoEditorPlaybackTimelineTrackSectionView`, with the host still owning trim ranges, scrub gestures, and thumbnail loading rules
- continued by moving the full playback timeline shell into a package-owned `VideoEditorPlaybackTimelineView`, with `ThumbnailsSliderView` now only injecting play button, badge, track, and footer content
- continued by removing the redundant host `PlayerControl` wrapper and inlining its runtime binding/adaptation at the `HostedVideoEditorView` boundary
- continued by moving the player surface shell into a package-owned `VideoEditorPlayerSurfaceView`, leaving the host responsible only for the injected player runtime view and editor-owned overlays
- continued by moving the tools tray and tool sheet chrome into package-owned `VideoEditorToolsTrayView` and `VideoEditorToolSheetView`, while the host keeps tool-specific drafts, apply/reset logic, and concrete tool content
- continued by moving the pure tool sheet presentation policy into package-owned `VideoEditorToolSheetPresentationPolicy`, while the host now concentrates only on draft coordination and runtime side effects
- continued by extracting `EditorToolDraftCoordinator` in the host so `ToolsSectionView` no longer owns draft-loading, change-detection, and reset-mode rules inline
- continued by extracting `HostedVideoEditorToolActionCoordinator` and `HostedVideoEditorToolContentView` so `ToolsSectionView` now mostly just composes the package tray/sheet chrome with host-injected bindings and adapters
- continued by extracting `HostedVideoEditorRuntimeCoordinator` so `HostedVideoEditorView` no longer owns bootstrap wiring, save publication, dismissal fallback, and player load-state resolution inline
- continued by extracting `HostedVideoEditorTrimSectionView` so the host trim/timeline runtime wiring no longer sits inside `HostedVideoEditorView`
- continued by extracting `HostedVideoEditorPlayerStageCoordinator`, `HostedVideoEditorPlayerOverlayView`, and `HostedVideoEditorPlayerTrailingControlsView` so `PlayerHolderView` now mostly delegates stage derivation, transcript overlay identity, and reset chrome to explicit host adapters
- continued by extracting `HostedVideoEditorShellCoordinator`, `HostedVideoEditorLoadedContentView`, and `HostedVideoEditorExportSheetContentView` so `HostedVideoEditorView` now mostly owns host state only, while loaded-content composition, export-sheet composition, and shell callbacks are delegated
- continued by removing the app-local `ToolModel` duplication so the host now uses the package-owned `ToolEnum` and `ToolAvailability` types directly
- completed by moving the remaining editor implementation into `Packages/VideoEditorKit/Internal`, deleting the app-local `Views/EditorView` and `Views/ToolsView` surfaces, and removing the duplicate editor-owned models still left under `VideoEditor/Core`

Result:

- `VideoEditorView` is now the only editor entry point the app shell calls
- the app target keeps only `RootView`, `RootViewModel`, persistence, import flow, sharing, transcription bootstrapping, and generic UI/file helpers
- editor-owned views, managers, models, and tests now live under `Packages/VideoEditorKit`

## Non-Goals

- do not move `RootView` or app-shell flows into the package
- do not force a single mega-change that also redesigns player, export, and persistence architecture
- do not hide remaining host-only rules; keep them explicit while they still depend on app-local models
