import Foundation
import Testing

@testable import VideoEditorKit

@Suite("AppleSpeechTranscriptionComponentTests")
struct AppleSpeechTranscriptionComponentTests {

    // MARK: - Public Methods

    @Test
    func transcribeVideoTransitionsFromLoadingToLoadedAndCleansTheExtractedAudio() async throws {
        let cleanupRecorder = CleanupRecorder()
        let localeProbe = AppleSpeechLocaleProbe()
        let extractedAudioURL = URL(fileURLWithPath: "/tmp/apple-speech-component-audio.m4a")
        let component = AppleSpeechTranscriptionComponent(
            dependencies: .init(
                extractAudio: { _ in extractedAudioURL },
                removeExtractedAudio: { cleanupRecorder.remove($0) },
                transcribeAudio: { audioURL, preferredLocale in
                    await localeProbe.record(
                        audioURL: audioURL,
                        preferredLocale: preferredLocale
                    )
                    await localeProbe.waitForResume()

                    return VideoTranscriptionResult(
                        segments: [
                            TranscriptionSegment(
                                id: UUID(),
                                startTime: 0,
                                endTime: 1,
                                text: "ola local"
                            )
                        ]
                    )
                }
            )
        )

        let transcriptionTask = Task {
            try await component.transcribeVideo(
                input: .init(
                    assetIdentifier: "asset-id",
                    source: .fileURL(URL(fileURLWithPath: "/tmp/source.mov")),
                    preferredLocale: "pt-BR"
                )
            )
        }

        await waitForState(of: component, equals: .loading)

        let capturedInput = try #require(await localeProbe.lastInput())
        #expect(capturedInput.audioURL == extractedAudioURL)
        #expect(capturedInput.preferredLocale == "pt-BR")

        await localeProbe.resume()

        let result = try await transcriptionTask.value

        #expect(result.segments.count == 1)
        #expect(result.segments[0].text == "ola local")
        #expect(await component.state == .loaded)
        #expect(cleanupRecorder.urls == [extractedAudioURL])
    }

    @Test
    func transcribeVideoTransitionsToFailedWhenTheLocalServiceFailsAndCleansTheExtractedAudio() async {
        let cleanupRecorder = CleanupRecorder()
        let extractedAudioURL = URL(fileURLWithPath: "/tmp/apple-speech-component-failure-audio.m4a")
        let component = AppleSpeechTranscriptionComponent(
            dependencies: .init(
                extractAudio: { _ in extractedAudioURL },
                removeExtractedAudio: { cleanupRecorder.remove($0) },
                transcribeAudio: { _, _ in
                    throw AppleSpeechTranscriptionService.ServiceError.unsupportedLocale("pt-BR")
                }
            )
        )

        do {
            _ = try await component.transcribeVideo(
                input: .init(
                    assetIdentifier: "asset-id",
                    source: .fileURL(URL(fileURLWithPath: "/tmp/source.mov")),
                    preferredLocale: "pt-BR"
                )
            )
            Issue.record("Expected the Apple speech component to fail for an unsupported locale.")
        } catch let error as TranscriptError {
            #expect(
                error
                    == .unavailable(
                        message: "The locale pt-BR is not supported for local speech transcription."
                    )
            )
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }

        #expect(
            await component.state
                == .failed(
                    .unavailable(
                        message: "The locale pt-BR is not supported for local speech transcription."
                    )
                )
        )
        #expect(cleanupRecorder.urls == [extractedAudioURL])
    }

    @Test
    func cancelCurrentTranscriptionCancelsTheInFlightOperationAndCleansTheExtractedAudio() async {
        let cleanupRecorder = CleanupRecorder()
        let startProbe = StartProbe()
        let extractedAudioURL = URL(fileURLWithPath: "/tmp/apple-speech-component-cancel-audio.m4a")
        let component = AppleSpeechTranscriptionComponent(
            dependencies: .init(
                extractAudio: { _ in extractedAudioURL },
                removeExtractedAudio: { cleanupRecorder.remove($0) },
                transcribeAudio: { _, _ in
                    await startProbe.markStarted()
                    try await Task.sleep(for: .seconds(60))

                    return VideoTranscriptionResult(
                        segments: [
                            TranscriptionSegment(
                                id: UUID(),
                                startTime: 0,
                                endTime: 1,
                                text: "never finishes"
                            )
                        ]
                    )
                }
            )
        )

        let transcriptionTask = Task {
            try await component.transcribeVideo(
                input: .init(
                    assetIdentifier: "asset-id",
                    source: .fileURL(URL(fileURLWithPath: "/tmp/source.mov")),
                    preferredLocale: nil
                )
            )
        }

        await waitForState(of: component, equals: .loading)
        await startProbe.waitUntilStarted()
        await component.cancelCurrentTranscription()

        do {
            _ = try await transcriptionTask.value
            Issue.record("Expected the transcription task to be cancelled.")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }

        #expect(await component.state == .failed(.cancelled))
        #expect(cleanupRecorder.urls == [extractedAudioURL])
    }

    @Test
    func transcribeVideoFailsWithInvalidVideoSourceForRemoteURLs() async {
        guard let remoteVideoURL = URL(string: "https://example.com/video.mov") else {
            Issue.record("Expected the non-file video URL fixture to be valid.")
            return
        }

        let component = AppleSpeechTranscriptionComponent(
            dependencies: .init(
                extractAudio: { _ in
                    Issue.record("The extractor should not be called for an invalid source.")
                    return URL(fileURLWithPath: "/tmp/unreachable.m4a")
                },
                removeExtractedAudio: { _ in },
                transcribeAudio: { _, _ in
                    Issue.record("The Apple speech service should not be called for an invalid source.")
                    return VideoTranscriptionResult()
                }
            )
        )

        do {
            _ = try await component.transcribeVideo(
                input: .init(
                    assetIdentifier: "asset-id",
                    source: .fileURL(remoteVideoURL),
                    preferredLocale: nil
                )
            )
            Issue.record("Expected the component to reject a non-file video URL.")
        } catch let error as TranscriptError {
            #expect(error == .invalidVideoSource)
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }

        #expect(await component.state == .failed(.invalidVideoSource))
    }

    // MARK: - Private Methods

    private func waitForState(
        of component: AppleSpeechTranscriptionComponent,
        equals expectedState: TranscriptFeatureState
    ) async {
        for _ in 0..<50 {
            if await component.state == expectedState {
                return
            }

            try? await Task.sleep(for: .milliseconds(10))
        }

        Issue.record("Timed out waiting for component state \(expectedState).")
    }

}

private actor AppleSpeechLocaleProbe {

    struct Input: Sendable {
        let audioURL: URL
        let preferredLocale: String?
    }

    // MARK: - Private Properties

    private var inputs = [Input]()
    private var continuation: CheckedContinuation<Void, Never>?
    private var hasResumed = false

    // MARK: - Public Methods

    func record(audioURL: URL, preferredLocale: String?) {
        inputs.append(
            .init(
                audioURL: audioURL,
                preferredLocale: preferredLocale
            )
        )
    }

    func waitForResume() async {
        guard hasResumed == false else { return }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        guard hasResumed == false else { return }

        hasResumed = true
        continuation?.resume()
        continuation = nil
    }

    func lastInput() -> Input? {
        inputs.last
    }

}

private final class CleanupRecorder: @unchecked Sendable {

    // MARK: - Private Properties

    private let lock = NSLock()
    private var recordedURLs = [URL]()

    // MARK: - Public Properties

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return recordedURLs
    }

    // MARK: - Public Methods

    func remove(_ url: URL) {
        lock.lock()
        recordedURLs.append(url)
        lock.unlock()
    }

}

private actor StartProbe {

    // MARK: - Private Properties

    private var hasStarted = false

    // MARK: - Public Methods

    func markStarted() {
        hasStarted = true
    }

    func waitUntilStarted() async {
        while hasStarted == false {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

}
