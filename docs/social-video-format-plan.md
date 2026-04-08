# Social Video Format Plan

## Status

- Planning documented
- Phase 1 completed
- Phase 2 completed
- Phase 3 completed
- Phase 4 completed
- Phase 5 completed

## Summary

The editor should support destination-oriented framing for short-form social platforms without introducing a separate rendering pipeline per platform.

For V1, the product decision is:

- keep a single crop model based on `VideoEditingConfiguration.Crop.freeformRect`
- expose a `9:16` format preset in the editor
- let the user reposition the video inside that fixed canvas during editing
- reuse the existing crop export stage instead of adding a new export-only transform

This keeps the first rollout small, useful, and aligned with the current architecture.

## Platform Baseline

Checked on 30 March 2026.

- Instagram Reels:
  - official accessible guidance points to fullscreen vertical delivery
  - product baseline for the editor should be `9:16`
- TikTok:
  - official ads specs recommend `9:16` vertical and accept `1:1` and `16:9`
  - official minimum for vertical is `540 x 960`
- YouTube Shorts:
  - official upload guidance accepts square or vertical
  - product baseline for the editor should be `9:16`

Recommended canvas for the app:

- `1080 x 1920` for vertical social export targets

Note:

- `1080 x 1920` is the app baseline we should optimize around for V1.
- Not every official help page exposes exact pixel guidance in the same place, so this should be treated as a product/export target derived from `9:16`, not as a hard platform contract for every surface.

## Why A Shared 9:16 Preset

Instagram Reels, TikTok, and YouTube Shorts all converge on the same practical editing canvas for mobile-first short video:

- portrait full screen
- `9:16`

That means the editor does not need three different crop engines.

For the current app, the better split is:

- crop preset:
  - shared `9:16`
- platform-specific guidance:
  - safe-area overlays and destination labeling

The safe-area layer can come later without invalidating the crop model.

## Current Code Reality

- The editor now exposes preset-first crop controls in [CropView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/ToolsView/Presets/CropView.swift).
- The preview already uses `CropView` driven by `cropFreeformRect` in [PlayerHolderView.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Views/EditorView/PlayerHolderView.swift).
- Crop state is already serializable via `VideoEditingConfiguration.Crop.freeformRect` in [VideoEditingConfiguration.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Editing/VideoEditingConfiguration.swift).
- Export already consumes `freeformRect` in the crop stage in [VideoEditor.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditor/Core/Models/Enums/VideoEditor.swift).

Because of that, the first implementation can be built on top of the current model instead of introducing new persistence immediately.

## UX Direction

### Format tab

The crop tool should expose:

- `Original`
- `9:16`

The `9:16` card should communicate its intended targets:

- Instagram Reels
- TikTok
- YouTube Shorts

### Preview behavior

- Selecting `Original` clears `freeformRect`.
- Selecting `9:16` creates the largest centered `9:16` crop that fits inside the current video.
- While `9:16` is active, the preview shows the crop frame with a preset badge and a black outside overlay.
- The user can drag to reposition, pinch to resize, and double tap to return to the full preset frame.

### Safe areas in Phase 4

Safe-area overlays now sit on top of the shared `9:16` preset as preview-only platform guidance.

The current product behavior is:

- the active destination can show platform-specific safe-area guides
- the guides help protect content from platform chrome and action rails
- the guides are intentionally excluded from exported media

## Phase Plan

### Phase 1

Add the first destination-ready vertical format preset.

Scope:

- document the social-format plan
- add a pure crop preset model for `Original` and `9:16`
- add tests for preset geometry
- implement the `format` tab UI
- apply the preset by writing `cropFreeformRect`
- allow repositioning through the existing crop drag behavior
- hide the crop overlay when the selected crop tab is not `format`

Out of scope:

- no new schema fields for destination/platform
- no safe-area overlays
- no export resolution changes
- no extra presets such as `1:1`, `4:5`, or `16:9`

### Phase 2

Persist destination intent separately from geometry.

Scope:

- add explicit destination metadata such as `instagramReels`, `tiktok`, and `youtubeShorts`
- keep it separate from the raw crop rect so the UI can reopen with the same destination selected even when the crop is full-frame
- rename the crop tool surface to `Presets`
- simplify the sheet to preset-first actions only
- show the active preset badge in the preview
- add black crop-outside overlay plus pinch and double-tap interactions for preset framing

### Phase 3

Support export-friendly vertical output sizing.

Scope:

- add portrait-aware output sizes to `VideoQuality`
- make the export pipeline choose vertical render sizes when the active format target is portrait
- keep the base render stage source-compatible for non-full-frame crops, then scale the final crop stage to the portrait target size

### Phase 4

Add platform-specific overlays.

Scope:

- show optional safe-area guides for Instagram Reels, TikTok, and YouTube Shorts
- keep guides out of the exported media
- persist whether the user left the guide visibility on or off

### Phase 5

Expand the preset library.

Scope:

- add `1:1`
- add `4:5`
- add `16:9`
- keep tests around crop geometry and format restore behavior

Completed outcome:

- the preset picker now exposes `Original`, `9:16`, `1:1`, `4:5`, and `16:9`
- non-social presets clear social destination intent and safe-area guides
- preset restore continues to infer the active format from persisted crop geometry

## Testing Notes

Every new preset should be backed by pure geometry tests before expanding the UI surface.

For the first phase, the most important assertions are:

- `Original` clears the crop rect
- `9:16` creates the expected centered crop for landscape video
- `9:16` still matches full-frame on already-vertical video
- selecting the preset updates editor state and tool activation correctly
