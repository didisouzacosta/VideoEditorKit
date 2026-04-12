import Foundation
import Testing

@testable import VideoEditorKit

@Suite("AppleSpeechTranscriptionComponentTests")
struct AppleSpeechTranscriptionComponentTests {

    // MARK: - Public Methods

    @Test
    func transcribeVideoTransitionsFromLoadingToLoadedAndCleansTheExtractedAudio() async throws {
        let cleanupRecorder = AppleSpeechCleanupRecorder()
        let transcribeProbe = AppleSpeechTranscribeProbe()
        let extractedAudioURL = URL(fileURLWithPath: "/tmp/apple-speech-component-audio.m4a")
        let component = AppleSpeechTranscriptionComponent(
            .init(
                extractAudio: { _ in extractedAudioURL },
                removeExtractedAudio: { cleanupRecorder.remove($0) },
                resolveAvailability: { _ in
                    .success(.init(Locale(identifier: "pt_BR")))
                },
                transcribeAudio: { audioURL, locale in
                    await transcribeProbe.record(audioURL: audioURL, locale: locale)
                    await transcribeProbe.waitForResume()
                    return VideoTranscriptionResult(
                        segments: [
                            TranscriptionSegment(
                                id: UUID(),
                                startTime: 0,
                                endTime: 2,
                                text: "ola mundo",
                                words: [
                                    TranscriptionWord(
                                        id: UUID(),
                                        startTime: 0,
                                        endTime: 0.8,
                                        text: "ola"
                                    ),
                                    TranscriptionWord(
                                        id: UUID(),
                                        startTime: 1,
                                        endTime: 2,
                                        text: "mundo"
                                    ),
                                ]
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

        let capturedRequest = try #require(await transcribeProbe.lastRequest())
        #expect(capturedRequest.audioURL == extractedAudioURL)
        #expect(capturedRequest.locale.identifier == "pt_BR")

        await transcribeProbe.resume()

        let result = try await transcriptionTask.value

        #expect(result.segments.count == 1)
        #expect(result.segments[0].text == "ola mundo")
        #expect(result.segments[0].words.map(\.text) == ["ola", "mundo"])
        #expect(await component.state == .loaded)
        #expect(cleanupRecorder.urls == [extractedAudioURL])
    }

    @Test
    func transcribeVideoTransitionsToFailedWhenRecognitionFailsAndCleansTheExtractedAudio() async {
        let cleanupRecorder = AppleSpeechCleanupRecorder()
        let extractedAudioURL = URL(fileURLWithPath: "/tmp/apple-speech-component-failure-audio.m4a")
        let component = AppleSpeechTranscriptionComponent(
            .init(
                extractAudio: { _ in extractedAudioURL },
                removeExtractedAudio: { cleanupRecorder.remove($0) },
                resolveAvailability: { _ in
                    .success(.init(Locale(identifier: "en_US")))
                },
                transcribeAudio: { _, _ in
                    throw TranscriptError.providerFailure(message: "Speech recognition failed.")
                }
            )
        )

        do {
            _ = try await component.transcribeVideo(
                input: .init(
                    assetIdentifier: "asset-id",
                    source: .fileURL(URL(fileURLWithPath: "/tmp/source.mov")),
                    preferredLocale: "en-US"
                )
            )
            Issue.record("Expected the component to fail when recognition fails.")
        } catch let error as TranscriptError {
            #expect(error == .providerFailure(message: "Speech recognition failed."))
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }

        #expect(await component.state == .failed(.providerFailure(message: "Speech recognition failed.")))
        #expect(cleanupRecorder.urls == [extractedAudioURL])
    }

    @Test
    func transcribeVideoFailsWithUnavailableLocaleBeforeExtractingAudio() async {
        let component = AppleSpeechTranscriptionComponent(
            .init(
                extractAudio: { _ in
                    Issue.record("The extractor should not be called when availability fails.")
                    return URL(fileURLWithPath: "/tmp/unreachable.m4a")
                },
                removeExtractedAudio: { _ in },
                resolveAvailability: { _ in
                    .failure(.unavailable(message: "Apple Speech transcription is not available for pt-BR."))
                },
                transcribeAudio: { _, _ in
                    Issue.record("The transcriber should not be called when availability fails.")
                    return VideoTranscriptionResult()
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
            Issue.record("Expected the component to fail when Apple Speech is unavailable.")
        } catch let error as TranscriptError {
            #expect(
                error
                    == .unavailable(
                        message: "Apple Speech transcription is not available for pt-BR."
                    )
            )
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }

        #expect(
            await component.state
                == .failed(
                    .unavailable(message: "Apple Speech transcription is not available for pt-BR.")
                )
        )
    }

    @Test
    func cancelCurrentTranscriptionCancelsTheInFlightOperationAndCleansTheExtractedAudio() async {
        let cleanupRecorder = AppleSpeechCleanupRecorder()
        let startProbe = AppleSpeechStartProbe()
        let extractedAudioURL = URL(fileURLWithPath: "/tmp/apple-speech-component-cancel-audio.m4a")
        let component = AppleSpeechTranscriptionComponent(
            .init(
                extractAudio: { _ in extractedAudioURL },
                removeExtractedAudio: { cleanupRecorder.remove($0) },
                resolveAvailability: { _ in
                    .success(.init(Locale(identifier: "en_US")))
                },
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
            .init(
                extractAudio: { _ in
                    Issue.record("The extractor should not be called for an invalid source.")
                    return URL(fileURLWithPath: "/tmp/unreachable.m4a")
                },
                removeExtractedAudio: { _ in },
                resolveAvailability: { _ in
                    .success(.init(Locale(identifier: "en_US")))
                },
                transcribeAudio: { _, _ in
                    Issue.record("The transcriber should not be called for an invalid source.")
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

    @Test
    func availabilityErrorDelegatesToTheAvailabilityResolver() async {
        let component = AppleSpeechTranscriptionComponent(
            .init(
                extractAudio: { _ in URL(fileURLWithPath: "/tmp/unreachable.m4a") },
                removeExtractedAudio: { _ in },
                resolveAvailability: { preferredLocale in
                    .failure(.unavailable(message: "Unsupported locale: \(preferredLocale ?? "none")."))
                },
                transcribeAudio: { _, _ in VideoTranscriptionResult() }
            )
        )

        let error = await component.availabilityError(preferredLocale: "pt-BR")

        #expect(error == .unavailable(message: "Unsupported locale: pt-BR."))
        #expect(await component.state == .idle)
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

private final class AppleSpeechCleanupRecorder: @unchecked Sendable {

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

private actor AppleSpeechTranscribeProbe {

    struct Request: Equatable, Sendable {

        // MARK: - Public Properties

        let audioURL: URL
        let locale: Locale

    }

    // MARK: - Private Properties

    private var requests = [Request]()
    private var continuation: CheckedContinuation<Void, Never>?
    private var hasResumed = false

    // MARK: - Public Methods

    func record(audioURL: URL, locale: Locale) {
        requests.append(
            Request(
                audioURL: audioURL,
                locale: locale
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
        hasResumed = true
        continuation?.resume()
        continuation = nil
    }

    func lastRequest() -> Request? {
        requests.last
    }

}

private actor AppleSpeechStartProbe {

    // MARK: - Private Properties

    private var hasStarted = false
    private var continuation: CheckedContinuation<Void, Never>?

    // MARK: - Public Methods

    func markStarted() {
        hasStarted = true
        continuation?.resume()
        continuation = nil
    }

    func waitUntilStarted() async {
        guard hasStarted == false else { return }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

}
