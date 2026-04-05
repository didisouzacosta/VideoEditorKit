# Local Whisper Transcription Kit Implementation Plan

## Status

- Phase 1 completed
- Phase 2 completed
- Phase 3 completed
- Phase 4 completed
- Phase 5 pending
- Phase 6 pending

## Implementation Goal

Implement an isolated `TranscriptionKit` component inside the current repository without changing the existing `VideoEditorKit` structure, while keeping the code ready for future extraction into its own library.

The component must:

- adapt to the existing editor transcription protocols instead of redefining them
- accept local audio or video input
- extract audio internally when needed
- keep model download definitions easy to find
- grow in phases without forcing architecture changes in the editor

## Constraints

- No reorganization of the current app target.
- No direct dependency from the component on editor UI or editor state types.
- The first implementation must be namespaced and isolated enough to be moved into a standalone package later.
- Hardcoded model URLs must live in one obvious catalog file.

## Phase 1: Foundation Skeleton

Status: completed.

Scope:

- create an isolated `VideoEditorKit/TranscriptionKit/` namespace inside the current repository
- define public request, media source, model descriptor, result, status, and error types
- define `TranscriptionProviding`
- define `TranscriptionClient`
- define internal seams for:
  - model storage
  - model downloading
  - media extraction
  - audio preparation
  - whisper bridging
- create a dedicated hardcoded model catalog file that implementers can edit later
- add Swift Testing coverage for the public contract shape and the hardcoded model catalog location

Delivered files:

- `VideoEditorKit/TranscriptionKit/Public/TranscriptionKitModels.swift`
- `VideoEditorKit/TranscriptionKit/Public/TranscriptionClient.swift`
- `VideoEditorKit/TranscriptionKit/Public/TranscriptionKitHardcodedModels.swift`
- `VideoEditorKit/TranscriptionKit/Core/TranscriptionKitDependencies.swift`
- `VideoEditorKitTests/TranscriptionKit/TranscriptionKitPhase1Tests.swift`

Acceptance:

- the isolated component compiles in the current app target
- the public API is editor-agnostic
- the model catalog is easy to locate and currently centralized in one file
- there is no dependency on `EditorViewModel`, `SwiftUI`, or transcript overlay types

## Phase 2: Model Store and Download

Status: completed.

Scope:

- implement local model path resolution
- implement model integrity validation
- implement download with progress reporting
- atomically install valid model files into the local cache

Expected files:

- `VideoEditorKit/TranscriptionKit/Infrastructure/TranscriptionModelStore.swift`
- `VideoEditorKit/TranscriptionKit/Infrastructure/URLSessionModelDownloader.swift`

Acceptance:

- valid local models are reused
- invalid models are rejected
- download progress can be observed

Delivered files:

- `VideoEditorKit/TranscriptionKit/Infrastructure/TranscriptionModelStore.swift`
- `VideoEditorKit/TranscriptionKit/Infrastructure/URLSessionModelDownloader.swift`
- `VideoEditorKitTests/TranscriptionKit/TranscriptionModelStoreTests.swift`
- `VideoEditorKitTests/TranscriptionKit/URLSessionModelDownloaderTests.swift`

Completed outcome:

- model cache resolution now uses a dedicated local directory under `Application Support/TranscriptionKit`
- cached models are validated by file size and optional SHA-256 metadata
- downloaded model files are installed atomically into the cache
- the default `TranscriptionClient` now guarantees model availability before later transcription stages
- the URL-session downloader reports observable progress and writes into a temporary destination

## Phase 3: Media Extraction and Audio Preparation

Status: completed.

Scope:

- implement media validation
- extract audio internally when the input is a video
- normalize audio into the PCM format expected by Whisper
- clean extracted and prepared temporary files

Expected files:

- `VideoEditorKit/TranscriptionKit/Infrastructure/AVFoundationMediaExtractor.swift`
- `VideoEditorKit/TranscriptionKit/Infrastructure/AVFoundationAudioPreparer.swift`

Acceptance:

- audio and video inputs converge into the same prepared-audio pipeline
- invalid media sources fail with typed errors

Delivered files:

- `VideoEditorKit/TranscriptionKit/Infrastructure/AVFoundationMediaExtractor.swift`
- `VideoEditorKit/TranscriptionKit/Infrastructure/AVFoundationAudioPreparer.swift`
- `VideoEditorKitTests/TranscriptionKit/AVFoundationMediaExtractorTests.swift`
- `VideoEditorKitTests/TranscriptionKit/AVFoundationAudioPreparerTests.swift`
- `VideoEditorKitTests/TranscriptionKit/TranscriptionClientPhase3Tests.swift`
- `VideoEditorKitTests/TranscriptionKit/TranscriptionKitTestMediaFactory.swift`

Completed outcome:

- local `audioFile` and `videoFile` inputs now converge through the same extraction and preparation pipeline
- `videoFile` sources extract audio internally with `AVFoundation`, without leaking editor-specific types
- prepared audio is normalized into a local PCM `.caf` file for the future Whisper bridge stage
- temporary extracted and prepared files are already cleaned up by `TranscriptionClient` on failure paths before the bridge exists
- the default `TranscriptionClient` now points to the real media extractor and audio preparer instead of phase-one placeholders

## Phase 4: Whisper Bridge

Status: completed.

Scope:

- add Objective-C++ bridge files
- define raw result DTOs
- isolate all bridge-specific logic from orchestration and normalization
- prepare a narrow runtime registration boundary for the future concrete `whisper.cpp` integration

Expected files:

- `VideoEditorKit/TranscriptionKit/Bridge/WhisperBridge.swift`
- `VideoEditorKit/TranscriptionKit/Bridge/WhisperBridge.mm`
- `VideoEditorKit/TranscriptionKit/Bridge/WhisperBridge.hpp`

Acceptance:

- bridge boundary compiles inside the current app target
- Swift orchestration stays independent from Objective-C++ and C++ details
- no product or editor rules live in bridge code

Delivered files:

- `VideoEditorKit/VideoEditorKit-Bridging-Header.h`
- `VideoEditorKit/TranscriptionKit/Bridge/WhisperBridge.h`
- `VideoEditorKit/TranscriptionKit/Bridge/WhisperBridge.hpp`
- `VideoEditorKit/TranscriptionKit/Bridge/WhisperBridge.mm`
- `VideoEditorKit/TranscriptionKit/Bridge/WhisperBridge.swift`
- `VideoEditorKitTests/TranscriptionKit/WhisperBridgeTests.swift`

Completed outcome:

- the app target now includes a dedicated Objective-C++ bridge boundary for future `whisper.cpp` wiring
- `TranscriptionClient` now defaults to the real `WhisperBridge` instead of the earlier placeholder bridge seam
- bridge-specific DTOs and error mapping stay isolated from orchestration, download, extraction, and normalization layers
- the C++ side exposes a runtime-registration seam so the future concrete `whisper.cpp` runtime can be plugged in without reshaping the Swift API
- when no runtime is registered yet, the bridge fails with a typed transcription error instead of crashing or leaking C++ details

Implementation note:

- This phase intentionally stops at a bridge-ready boundary because the repository still does not vendor or link a concrete `whisper.cpp` runtime.
- The next runtime step should plug a real implementation into `RegisterWhisperRuntime(...)` without changing the public Swift API.

## Phase 5: Full Orchestration

Scope:

- connect validation, model guarantee, extraction, audio preparation, bridge, cleanup, and normalization
- emit status transitions through the client
- add focused tests for success and failure paths

Expected files:

- extend `TranscriptionClient`
- add normalizers and coordinators as needed inside `Core/`

Acceptance:

- one async call executes the local transcription flow end to end
- output is normalized and stable

## Phase 6: Adapter to VideoEditorKit

Scope:

- create a thin adapter from `VideoTranscriptionInput` to `TranscriptionRequest`
- map normalized output back into `VideoTranscriptionResult`
- keep `VideoEditorKit` dependent only on its current provider contract

Expected files:

- adapter file near the current transcription integration boundary

Acceptance:

- editor can use local Whisper transcription through the existing provider protocol
- no structural change is required in the current editor architecture

## Notes

- The hardcoded model URL should be edited only in `TranscriptionKitHardcodedModels.swift`.
- Phase 1 intentionally delivers scaffolding and contract boundaries first; it does not yet deliver real model download, extraction, or inference.
