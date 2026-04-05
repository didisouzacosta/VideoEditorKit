# Local Whisper Transcription Kit Plan

## Status

- Implemented incrementally through Phase 6
- Ready for concrete Whisper runtime registration and host-side model selection

## Summary

The current editor already supports a host-injected transcription contract through `VideoTranscriptionProvider`, but it does not ship a concrete provider implementation.

The next step should be a separate reusable component, tentatively named `TranscriptionKit`, responsible for local offline transcription with Whisper. This component should stay independent from `VideoEditorKit`, accept media files as input, extract audio when the input is a video, download and cache a model on demand, run inference locally, and return a normalized result that can be adapted back into the editor's existing provider contract.

This document refines the initial plan into an implementation roadmap that matches the real codebase and keeps the editor decoupled from the Whisper engine.

At the current stage, the repository already includes:

- the isolated `TranscriptionKit` namespace and public API
- model caching and download infrastructure
- internal audio extraction and preparation for audio and video inputs
- a dedicated Objective-C++ bridge boundary prepared for future concrete `whisper.cpp` runtime registration
- end-to-end local orchestration from request to normalized transcription output
- a `VideoTranscriptionProvider` adapter that plugs the local component into the existing editor contract

## Current Repo Reality

- `VideoEditorKit` is still an app target, not a fully modular SDK package.
- The editor already consumes a generic provider contract in [VideoTranscriptionProvider.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorKit/Core/Models/Transcription/VideoTranscriptionProvider.swift).
- The editor already persists and renders normalized transcript data through [TranscriptModels.swift](/Users/adrianocosta/Documents/Projects/VideoEditorKit/VideoEditorKit/Core/Models/Transcription/TranscriptModels.swift).
- The editor should continue to depend only on a protocol-level provider and must not learn about Whisper, model downloads, or audio preprocessing details.

Because of that, the local Whisper implementation should be planned as a separate module with an adapter layer back into the editor's existing contract.

## Goals

- Provide a reusable local transcription module for iOS in Swift.
- Add the component without changing the current `VideoEditorKit` project structure.
- Keep the module fully decoupled from `VideoEditorKit`.
- Download Whisper models dynamically from a public URL.
- Cache the model locally and reuse it across transcriptions.
- Accept a local audio file URL or video file URL as input.
- Extract audio internally when the request input is a video.
- Normalize output into a stable public transcription model.
- Surface progress and typed failures for download, audio preparation, and inference.
- Make the resulting client easy to adapt into `VideoTranscriptionProvider`.
- Prepare the component to become a standalone library later with minimal or no API breakage.

## Non-Goals

- No SwiftUI UI inside `TranscriptionKit`.
- No dependency on editor screens, `EditorViewModel`, or transcript overlay models.
- No subtitle rendering.
- No translation pipeline in v1.
- No backend or remote inference in v1.
- No manual transcript editing in this module.
- No restructuring of the current `VideoEditorKit` app target as part of the first implementation.

## Hard Constraints

- The current repository structure must stay intact during the first implementation.
- The component must be introduced as an isolated capability, not as a refactor of the editor architecture.
- The component must adapt to the transcription protocols that already exist instead of changing them.
- The component must be designed as if it will later move into its own standalone library.

## Product Decisions

### Project-structure boundary

- The first implementation must not force a reorganization of folders, targets, or editor architecture in `VideoEditorKit`.
- We should introduce the new code as an isolated component inside the existing repository, with its own namespace and seams, so it can later be extracted into a Swift Package.
- `VideoEditorKit` should only gain the minimum integration surface needed to instantiate and adapt the component to `VideoTranscriptionProvider`.

### Input boundary

- The component should accept a generic media input, not only pre-extracted audio.
- V1 should support:
  - local audio files
  - local video files
- When the input is a video, the component itself should extract audio internally in the most reliable way available through `AVFoundation`.
- Host apps should not need to implement their own audio extraction just to use local Whisper transcription.

This makes the component more self-sufficient and more realistic as a future standalone library.

### Integration boundary with the editor

- `TranscriptionKit` returns its own normalized output model.
- `VideoEditorKit` keeps its current `VideoTranscriptionProvider`.
- A thin adapter translates `NormalizedTranscription` into `VideoTranscriptionResult`.
- The existing transcription contract in `VideoEditorKit` should be preserved as-is unless a compatibility gap is found that cannot be solved by the adapter.

### Model strategy

- Model download must be explicit in configuration, not hardcoded deep in the engine.
- v1 should support a single remote model per request.
- The descriptor must include enough metadata to validate cached files without needing editor-specific knowledge.
- The concrete remote model URL will be hardcoded by whoever integrates `TranscriptionKit`.
- That hardcoded model definition must live in a single obvious file so it is easy to find and replace later.
- Recommended location for the first implementation: a dedicated catalog file such as `TranscriptionKitHardcodedModels.swift`.

### Concurrency

- The main orchestration API should be actor-based.
- Model download and inference should be serialized per client unless we intentionally add concurrent model sessions later.

### Library-readiness

- Public API types must not leak editor-specific names or concepts.
- Infrastructure concerns must stay behind internal protocols.
- The component should not rely on app-global singletons.
- File-system roots, networking, and status reporting should be injectable.
- Objective-C++ bridge code must remain isolated so the public surface stays pure Swift.

## Proposed Module Boundary

The long-term target should be a dedicated Swift Package:

```text
TranscriptionKit/
├── Package.swift
├── Sources/
│   ├── TranscriptionKit/
│   │   ├── Public/
│   │   ├── Core/
│   │   ├── Infrastructure/
│   │   └── Bridge/
└── Tests/
    └── TranscriptionKitTests/
```

### Public

- Public request and result types
- Public protocol and client entry points
- Public status and error types

### Core

- Pure orchestration
- Validation
- Normalization
- State machine
- Use-case coordinators

### Infrastructure

- Model storage
- Downloading
- Audio preprocessing
- File-system access

### Bridge

- Objective-C++ bridge into `whisper.cpp`
- C / C++ interop only
- No business rules

## Public API Proposal

```swift
public struct TranscriptionRequest: Sendable, Hashable {
    public let media: TranscriptionMediaSource
    public let model: RemoteModelDescriptor
    public let language: String?
    public let task: TranscriptionTask
}
```

```swift
public enum TranscriptionMediaSource: Sendable, Hashable {
    case audioFile(URL)
    case videoFile(URL)
}
```

```swift
public struct RemoteModelDescriptor: Sendable, Hashable {
    public let id: String
    public let remoteURL: URL
    public let localFileName: String
    public let expectedSizeInBytes: Int64?
    public let sha256: String?
}
```

```swift
public enum TranscriptionTask: String, Sendable, Hashable {
    case transcribe
    case translate
}
```

```swift
public struct NormalizedTranscription: Sendable, Hashable {
    public let fullText: String
    public let language: String?
    public let duration: TimeInterval?
    public let segments: [NormalizedSegment]
}
```

```swift
public struct NormalizedSegment: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let words: [NormalizedWord]
}
```

```swift
public struct NormalizedWord: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
}
```

```swift
public enum TranscriptionStatus: Sendable, Equatable {
    case idle
    case downloading(progress: Double?)
    case preparingAudio
    case transcribing
    case completed
}
```

```swift
public enum TranscriptionError: Error, Sendable, Equatable {
    case invalidAudioFile
    case unsupportedAudioFormat
    case modelNotFound
    case modelIntegrityCheckFailed
    case modelDownloadFailed(message: String)
    case audioPreparationFailed(message: String)
    case transcriptionFailed(message: String)
    case cancelled
}
```

```swift
public protocol TranscriptionProviding: Sendable {
    func transcribe(_ request: TranscriptionRequest) async throws -> NormalizedTranscription
}
```

```swift
public actor TranscriptionClient: TranscriptionProviding {
    public func transcribe(_ request: TranscriptionRequest) async throws -> NormalizedTranscription
}
```

## Status Observation

The client should expose status changes without forcing a UI framework:

```swift
public protocol TranscriptionStatusReporting: Sendable {
    func report(_ status: TranscriptionStatus)
}
```

For v1, the simplest option is constructor injection of an optional reporter callback or reporter object. That keeps status delivery lightweight and testable.

## End-to-End Pipeline

1. Receive `TranscriptionRequest`.
2. Validate that the media source exists, is reachable, and is a local file URL.
3. If the source is a video, extract the audio track internally.
4. Resolve the local model path.
5. Validate cached model integrity.
6. Download model if missing or invalid.
7. Convert audio into the Whisper-compatible PCM format.
8. Invoke the Objective-C++ Whisper bridge.
9. Receive raw inference output.
10. Normalize into `NormalizedTranscription`.
11. Clean temporary files.
12. Return typed success or failure.

## Model Download and Storage

### Local storage

- Store cached models under `Application Support/TranscriptionKit/Models`.
- Store temporary prepared audio under `Application Support/TranscriptionKit/Temporary` or a system temp directory.
- Avoid storing models inside the host app's custom editor persistence directories.

### Validation strategy

V1 validation should support:

- file existence
- non-zero size
- optional exact size match when `expectedSizeInBytes` exists
- optional SHA-256 check when `sha256` exists

Recommended rule:

- if `sha256` exists, it becomes the strongest integrity check
- if only `expectedSizeInBytes` exists, size matching is the fallback
- if neither exists, validate only existence plus non-zero size and expose that this is a weaker guarantee in docs

### Download strategy

- download only when no valid local model is available
- do not overwrite a valid cached file
- download into a temporary file first
- move atomically into the final model path after validation

### Networking abstraction

Do not let the orchestrator own `URLSession` directly. Use an injected downloader abstraction:

```swift
protocol ModelDownloading: Sendable {
    func downloadModel(
        from remoteURL: URL,
        to temporaryURL: URL,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws
}
```

This makes download behavior testable and keeps the actor orchestration small.

## Media Preparation

The component should own media preparation end-to-end before inference.

### Media validation

- validate local audio file URLs
- validate local video file URLs
- reject unsupported or remote URLs
- fail early when a video does not contain an extractable audio track

### Video audio extraction

When the input is a video, the component should extract audio internally through `AVFoundation`.

Goals:

- isolate video-specific handling inside the component
- produce a stable intermediate audio file for the rest of the pipeline
- avoid making host apps repeat extraction code

Suggested boundary:

```swift
protocol MediaExtracting: Sendable {
    func extractAudioIfNeeded(
        from source: TranscriptionMediaSource
    ) async throws -> ExtractedAudioSource
}
```

```swift
struct ExtractedAudioSource: Sendable, Hashable {
    let audioURL: URL
    let duration: TimeInterval?
    let wasExtractedFromVideo: Bool
}
```

Implementation guidance:

- prefer `AVAssetExportSession` or a reader/writer pipeline depending on the formats we need to support best
- extract into a temporary local audio file owned by the component
- remove temporary extracted audio when the request completes

## Audio Preparation

Whisper performs best with normalized PCM input. The preprocessing layer should:

- accept a local audio file URL
- load the asset via `AVFoundation`
- transcode or render to:
  - mono
  - 16-bit PCM or Float32 PCM depending on bridge expectation
  - sample rate compatible with the selected Whisper integration, ideally 16 kHz

### Proposed boundary

```swift
protocol AudioPreparing: Sendable {
    func prepareAudio(at audioURL: URL) async throws -> PreparedAudio
}
```

```swift
struct PreparedAudio: Sendable, Hashable {
    let fileURL: URL
    let sampleRate: Double
    let channelCount: Int
    let duration: TimeInterval?
}
```

### Cleanup rules

- prepared temporary audio should be removed after success
- prepared temporary audio should also be removed on failure paths when possible
- extracted temporary audio from video should follow the same cleanup policy

## Whisper Bridge

The bridge layer should stay thin and implementation-focused.

### Responsibilities

- own Objective-C++ interop
- load the model file
- run inference
- transform raw engine output into an internal raw-result DTO

### Non-responsibilities

- model downloading
- file-system policy
- audio validation
- normalization rules
- app-specific error messages

### Raw bridge output

```swift
struct RawWhisperTranscriptionResult: Sendable {
    let text: String
    let language: String?
    let segments: [RawWhisperSegment]
}
```

```swift
struct RawWhisperSegment: Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let words: [RawWhisperWord]
}
```

```swift
struct RawWhisperWord: Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}
```

## Normalization

Normalization should be deterministic and pure.

Rules:

- always trim obvious whitespace artifacts
- preserve segment timing from the engine
- compute `fullText` from normalized segments when necessary
- include word timings when available
- tolerate engines that do not return words by producing `words = []`

The normalization layer should never know about editor overlays, styles, or timeline remapping.

## Integration with VideoEditorKit

The editor should continue using its current provider contract:

```swift
protocol VideoTranscriptionProvider: Sendable {
    func transcribeVideo(input: VideoTranscriptionInput) async throws -> VideoTranscriptionResult
}
```

Recommended integration path:

1. Host app resolves the current source video.
2. Adapter builds a `TranscriptionRequest` with `.videoFile(...)` or `.audioFile(...)`.
3. Adapter calls `TranscriptionClient`.
4. `TranscriptionKit` validates media, extracts audio if needed, prepares PCM, guarantees the model, and runs Whisper.
5. Adapter maps `NormalizedTranscription` into `VideoTranscriptionResult`.
6. Editor consumes the result without knowing anything about Whisper.

This preserves the editor's open-provider architecture while allowing us to ship a concrete local provider separately.

## Suggested Adapter Layer

Inside the host app or in a small integration target, add:

```swift
struct WhisperVideoTranscriptionProvider: VideoTranscriptionProvider {
    let client: TranscriptionProviding
    let model: RemoteModelDescriptor

    func transcribeVideo(input: VideoTranscriptionInput) async throws -> VideoTranscriptionResult
}
```

This adapter should stay thin because the video-specific extraction work belongs inside `TranscriptionKit`, not in `VideoEditorKit`.

## Failure Model

The component should explicitly distinguish between:

- bad input
- model cache or integrity failure
- network download failure
- audio preparation failure
- bridge or inference failure
- cancellation

This matters because host apps may want to retry downloads but not retry malformed local files.

## Testing Strategy

### Pure unit tests

- request validation
- model path resolution
- integrity validation
- normalization from raw Whisper output
- typed error mapping

### Infrastructure tests

- cached model reuse
- temporary download then atomic move
- cleanup of temporary audio
- progress reporting during download

### Bridge contract tests

- mock bridge invocation shape
- verify raw result mapping
- failure propagation from the bridge

### Integration tests

- host adapter from video URL to normalized result
- adapter mapping into `VideoTranscriptionResult`
- video-input path covering internal audio extraction

### What not to depend on in most tests

- real network
- real large Whisper models
- real device microphone

Prefer seams and fixtures everywhere except a small optional manual smoke path.

## Implementation Phases

## Phase 1: Package and Public API

Scope:

- create an isolated `TranscriptionKit` namespace inside the current repository without changing the existing app structure
- define public request, result, status, and error types
- define client protocol
- define internal abstractions for downloader, media extractor, audio preparer, model store, and bridge

Acceptance:

- isolated component builds inside the current repository
- public API compiles cleanly
- no dependency on `VideoEditorKit`
- extraction into a future standalone package remains straightforward

## Phase 2: Model Store and Download

Scope:

- implement model path resolution
- implement cache validation
- implement download with progress
- implement atomic install into local cache

Acceptance:

- valid cached model is reused
- invalid cache triggers re-download
- download progress is observable

## Phase 3: Audio Preparation

Scope:

- implement media-source validation
- implement internal extraction from video to audio
- implement `AVFoundation` audio preparation pipeline
- convert arbitrary local audio input into Whisper-compatible PCM
- clean temporary extracted and prepared files

Acceptance:

- video input and audio input both reach the same prepared-audio stage
- supported audio inputs become valid prepared audio
- unsupported or invalid files fail with typed errors

## Phase 4: Whisper Bridge

Scope:

- integrate `whisper.cpp`
- add Objective-C++ bridge
- define raw result DTOs
- map bridge failures into typed errors

Acceptance:

- the bridge can load a model and run inference over prepared audio
- no business rules leak into `.mm`

## Phase 5: Orchestration and Normalization

Scope:

- implement `TranscriptionClient`
- connect validation, model guarantee, audio preparation, bridge call, and normalization
- expose status reporting throughout the pipeline

Acceptance:

- one public API call runs the full local transcription flow
- result is normalized and stable

## Phase 6: VideoEditorKit Adapter

Scope:

- add a host-side adapter from `VideoTranscriptionInput` to `TranscriptionKit`
- map normalized output into `VideoTranscriptionResult`
- validate integration against the current editor transcription flow

Acceptance:

- editor can use the local Whisper implementation through the existing provider protocol
- editor remains decoupled from `TranscriptionKit` internals
- no structural changes are required in the current editor codebase to consume the component

## Open Decisions

- whether the first shipped model should be bundled by default or only downloaded remotely
- whether SHA-256 verification is mandatory or optional in v1
- whether status reporting should be callback-based, `AsyncStream`-based, or both
- whether we want one reusable actor instance per model or a fresh client per request
- whether the bridge should emit word-level timestamps in v1 or segment-level only
- which extraction path is most reliable for video-to-audio conversion across the input formats we care about

## Recommended First Slice

The safest first implementation slice is:

1. create the package and public API
2. implement model caching and download
3. implement media validation plus internal video-audio extraction
4. stub the bridge with a fake engine
5. prove the full orchestration path with tests
6. only then integrate real `whisper.cpp`

That gives us confidence in the architecture before taking on the riskiest part, which is the C++ bridge and audio conversion pipeline.

## Acceptance Criteria

- the component is reusable and independent from `VideoEditorKit`
- a host can call one async API with a local audio file URL or video file URL
- video input is handled internally by extracting audio without host-side extraction logic
- the client downloads and caches the model automatically
- repeated calls reuse a valid cached model
- the transcription result is normalized into stable public types
- failures are typed and actionable
- the module is covered by isolated tests
- `VideoEditorKit` can integrate it through an adapter without learning about Whisper internals
- the first implementation does not require reorganizing the current project structure
