# Resumable Editing Session Plan

> Superseded for V1 by [docs/video-editing-configuration-execution-plan.md](/Users/adrianocosta/Documents/Projects/VideoEditorKit/docs/video-editing-configuration-execution-plan.md). Keep this document only as historical context for the earlier session-based proposal.
>
> Historical path note: some file references below still reflect the intermediate migration layout. Read `Packages/VideoEditorKit/...` as `Sources/VideoEditorKit/...`, and host-app paths under `VideoEditor/...` as `Example/VideoEditor/...`.

## Summary

This plan adds a host-facing editing session contract so the editor can be reopened with both:

- the source video reference
- the full serializable editing state needed to resume work

The key design choice is to introduce a dedicated Codable session snapshot instead of making the runtime `Video` model itself directly serializable. That keeps `AVAsset`, thumbnails, SwiftUI colors, and other runtime-only concerns out of persistence.

## Current State

- `VideoEditorView` currently accepts only `_ sourceVideoURL: URL?`.
- `EditorViewModel` rebuilds runtime state from a video URL and does not accept a serialized edit snapshot.
- The runtime `Video` model already carries most editable state:
  - trim via `rangeDuration`
  - speed via `rate`
  - rotate via `rotation`
  - mirror via `isMirror`
  - color correction via `colorCorrection`
  - frame via `videoFrames`
  - recorded audio and video volume via `audio` and `volume`
  - crop/preset geometry via `freeformRect`
- Some of that state is not directly serializable today because the models contain runtime-only types such as:
  - `AVAsset`
  - `Color`
  - derived thumbnail images
- Free crop is not resumable today because its state lives inside `CropView` local `@State` and is not promoted into the editor model.
- The current imported source video is copied into `Caches`, which is not a durable long-term storage location for resumable sessions.

## Goals

1. Reopen the editor from a single session payload.
2. Let the host persist and later pass back all serializable editing changes.
3. Keep the runtime editor models optimized for playback and rendering.
4. Version the snapshot format so future migrations are safe.
5. Support staged rollout without rewriting the export pipeline first.

## Non-Goals

- Do not redesign the current editing UX in this change.
- Do not force the export pipeline to become snapshot-driven in phase 1.
- Do not promise parity for free crop until crop state is promoted into the model and wired into export.

## Proposed Public API

Introduce a new host-facing session type and use it as the primary editor input.

```swift
struct VideoEditorSession: Codable, Equatable, Sendable {
    var version: Int
    var source: VideoSourceReference
    var snapshot: VideoEditingSnapshot
}

struct VideoSourceReference: Codable, Equatable, Sendable {
    var kind: Kind
    var value: String

    enum Kind: String, Codable {
        case appSandboxRelativePath
        case securityScopedBookmarkBase64
        case absoluteFileURL
    }
}

struct VideoEditingSnapshot: Codable, Equatable, Sendable {
    var trim: TrimSnapshot
    var playback: PlaybackSnapshot
    var crop: CropSnapshot
    var corrections: CorrectionsSnapshot
    var frame: FrameSnapshot
    var audio: AudioSnapshot
    var ui: EditorUISnapshot
}
```

Suggested editor API shape:

```swift
init(
    session: VideoEditorSession,
    configuration: Configuration = .init(),
    onSessionChange: @escaping (VideoEditorSession) -> Void = { _ in },
    onExported: @escaping (ExportedVideo) -> Void = { _ in }
)
```

Compatibility bridge for staged rollout:

```swift
init(
    _ sourceVideoURL: URL? = nil,
    configuration: Configuration = .init(),
    onExported: @escaping (ExportedVideo) -> Void = { _ in }
)
```

The existing URL-only initializer can internally create a default session snapshot.

## Snapshot Shape

### `TrimSnapshot`

```swift
struct TrimSnapshot: Codable, Equatable, Sendable {
    var lowerBound: Double
    var upperBound: Double
}
```

Maps from `Video.rangeDuration`.

### `PlaybackSnapshot`

```swift
struct PlaybackSnapshot: Codable, Equatable, Sendable {
    var rate: Float
    var videoVolume: Float
    var currentTimelineTime: Double?
}
```

`currentTimelineTime` is optional but useful if the host wants resume-exactly-where-the-user-stopped behavior.

### `CropSnapshot`

```swift
struct CropSnapshot: Codable, Equatable, Sendable {
    var rotationDegrees: Double
    var isMirrored: Bool
    var freeCrop: NormalizedCropRect?
}

struct NormalizedCropRect: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}
```

`rotationDegrees` and `isMirrored` map from the current model immediately.

`freeCrop` is intentionally optional because the app does not model or export free crop yet. The rollout should still define the field now so the format does not need a breaking redesign when free crop becomes real state.

### `CorrectionsSnapshot`

```swift
struct CorrectionsSnapshot: Codable, Equatable, Sendable {
    var brightness: Double
    var contrast: Double
    var saturation: Double
}
```

Maps from `Video.colorCorrection`.

### `FrameSnapshot`

```swift
struct FrameSnapshot: Codable, Equatable, Sendable {
    var scaleValue: Double
    var frameColorHexRGBA: String?
}
```

Maps from `Video.videoFrames`. Use a stable color surrogate such as RGBA hex instead of serializing `Color`.

### `AudioSnapshot`

```swift
struct AudioSnapshot: Codable, Equatable, Sendable {
    var recordedAudio: AudioClipReference?
    var selectedTrack: SelectedTrack

    enum SelectedTrack: String, Codable {
        case video
        case recorded
    }
}

struct AudioClipReference: Codable, Equatable, Sendable {
    var source: VideoSourceReference
    var duration: Double
    var volume: Float
}
```

This covers:

- recorded audio file identity
- recorded audio duration
- recorded audio volume
- which track was selected in the UI when the editor was closed

### `EditorUISnapshot`

```swift
struct EditorUISnapshot: Codable, Equatable, Sendable {
    var selectedTool: String?
    var cropTab: String?
}
```

This is optional from a business perspective, but it helps the host reopen the editor in a more continuous state.

## Why A Dedicated DTO Layer

Do not make `Video` and `Audio` directly Codable as the first step.

Reasons:

- `Video` contains `AVAsset`, thumbnails, and geometry derived from layout.
- `Audio` exposes a computed `asset`.
- The runtime model should stay free to evolve for playback and rendering concerns.

Instead, add explicit mappers:

- `VideoEditingSnapshotMapper.makeRuntimeVideo(...)`
- `VideoEditingSnapshotMapper.makeSnapshot(from: Video, ...)`

That gives a clean seam for:

- normalization
- color conversion
- migration between snapshot versions
- testable round-trip serialization

## Asset Persistence Strategy

The source video URL cannot be treated as durable just because it is a `URL`.

Important current constraint:

- `VideoItem` imports videos into `Caches`
- `AudioRecorderManager` stores recorded audio in `Caches`

That means a resumable session needs an asset retention policy, not only a JSON snapshot.

Recommended policy:

1. Promote resumable assets into an app-managed folder before saving a session.
2. Persist only relative paths for app-owned files.
3. Use bookmark data only when the host intentionally owns an external file reference.
4. Treat temporary export outputs as non-resumable artifacts.

Suggested app-managed folders:

- `Application Support/EditorSources/`
- `Application Support/EditorAudio/`

Avoid using `Caches` for resumable sessions because the OS may purge it.

## Restoration Flow

1. Host resolves a `VideoEditorSession`.
2. `VideoEditorView` receives `session`.
3. The source reference resolves into a local readable URL.
4. `EditorViewModel` loads the source asset as it does today.
5. After the runtime `Video` is created, apply `snapshot` onto it through a mapper.
6. Sync dependent view models and managers:
   - `VideoPlayerManager`
7. Restore optional UI state such as selected tool, crop tab, and current playback position.

## Save Flow

The editor should emit updated sessions whenever meaningful state changes occur.

Recommended trigger points:

- trim changed
- rate changed
- rotation or mirror changed
- corrections changed
- frame changed
- audio recorded, removed, or volume changed
- crop/preset changed
- editor dismissal
- app backgrounding while the editor is open

To avoid noisy writes, debounce host callbacks for high-frequency changes such as trim dragging or slider updates.

## Phases

### Phase 1

Introduce the serializable DTOs, versioning, color conversion, and mapper layer.

Scope:

- Add `VideoEditorSession`, `VideoEditingSnapshot`, and nested DTOs.
- Add a source reference abstraction for durable asset identity.
- Add snapshot mappers to and from the runtime editor state.
- Keep the current URL-only editor flow working.

Out of scope:

- No crop freeform restoration yet.
- No host callback wiring yet.

### Phase 2

Add resumable session input and session update output to the editor boundary.

Scope:

- Add `VideoEditorView.init(session:configuration:onSessionChange:onExported:)`.
- Build a default snapshot when the legacy initializer is used.
- Emit debounced session updates from `EditorViewModel`.

Out of scope:

- No Core Data migration required unless the app demo decides to persist sessions there.

### Phase 3

Move resumable media into durable storage.

Scope:

- Replace current resumable asset writes from `Caches` to an app-managed durable folder.
- Add source and recorded-audio copy/move rules.
- Add cleanup rules for deleted or replaced sessions.

Out of scope:

- No cloud sync yet.

### Phase 4

Promote free crop into real editor state.

Scope:

- Replace `CropView` local-only crop state with model-backed state.
- Store crop as normalized geometry in the snapshot.
- Restore crop preview from the snapshot.

Out of scope:

- Do not claim export parity until export consumes the same crop snapshot.

### Phase 5

Make preview, export, and persistence consume the same crop and session model.

Scope:

- Feed free crop into export.
- Add tests that compare restored preview state with exported transform inputs.
- Document the new parity guarantees.

## Files Expected To Change

- `Example/VideoEditor/Views/EditorView/HostedVideoEditorView.swift`
- `Example/VideoEditor/Core/ViewModels/EditorViewModel.swift`
- `Example/VideoEditor/Core/Models/Video.swift`
- `Example/VideoEditor/Core/Models/AudioModel.swift`
- `Example/VideoEditor/Views/ToolsView/Presets/CropView.swift`
- `Example/VideoEditor/Views/RootView/RootView.swift`
- new files under `Example/VideoEditor/Core/Models/Session/`
- new tests under `Example/VideoEditorTests/Models/` and `Example/VideoEditorTests/ViewModels/`

## Test Plan

Add characterization and round-trip tests before wiring the full feature:

1. Snapshot encode/decode round-trip preserves values.
2. Runtime video to snapshot mapping preserves editable state.
3. Snapshot to runtime video restoration restores trim, speed, rotation, mirror, crop, corrections, frame, and audio metadata.
4. Color conversion is stable for supported editor colors.
5. Normalized crop geometry restores predictably across at least two container sizes.
6. Legacy URL-only initializer still opens the editor with a default snapshot.
7. Session update callbacks are debounced and emit the latest state.

Add crop-specific tests only when crop leaves local `View` state and becomes model-backed.

## Risks

- Persisting absolute file URLs alone will produce brittle sessions if the underlying file is temporary or moved.
- Serializing raw view-space offsets without normalization will make text restoration drift across devices.
- If session updates are emitted from multiple places without centralization, the host may persist stale snapshots.
- Free crop will remain partial until the same data model drives preview, persistence, and export.

## Acceptance Criteria

- The host can reopen the editor from one `VideoEditorSession`.
- The session format is Codable, versioned, and test-covered.
- Trim, speed, rotate, mirror, filter, corrections, frame, text, audio, and UI restoration state can be serialized and restored.
- The editor no longer depends on `Caches` as the durable source of resumable media.
- Free crop is explicitly represented as optional state now and fully supported only after phases 4 and 5.
