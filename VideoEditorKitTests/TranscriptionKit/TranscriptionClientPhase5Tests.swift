import Foundation
import Testing

@testable import VideoEditorKit

@Suite("TranscriptionClientPhase5Tests")
struct TranscriptionClientPhase5Tests {

    // MARK: - Public Methods

    @Test
    func clientExecutesTheFullPipelineAndReturnsANormalizedResult() async throws {
        let workingDirectory = try TranscriptionKitTestMediaFactory.makeWorkingDirectory()
        let extractedAudioURL = workingDirectory.appendingPathComponent("extracted.m4a")
        let preparedAudioURL = workingDirectory.appendingPathComponent("prepared.caf")
        let modelURL = workingDirectory.appendingPathComponent("model.bin")
        let remoteURL = try #require(
            URL(string: "https://example.com/base.bin")
        )
        let request = TranscriptionRequest(
            media: .videoFile(
                workingDirectory.appendingPathComponent("input.mov")
            ),
            model: RemoteModelDescriptor(
                id: "base",
                remoteURL: remoteURL,
                localFileName: "base.bin"
            ),
            language: "pt",
            task: .transcribe
        )
        let reporter = LockedStatusReporter()

        try Data([1, 2, 3]).write(to: extractedAudioURL)
        try Data([4, 5, 6]).write(to: preparedAudioURL)
        try Data([7, 8, 9]).write(to: modelURL)

        let client = TranscriptionClient(
            modelStore: StubModelStore(
                cachedState: .valid(modelURL),
                localModelURLValue: modelURL
            ),
            modelDownloader: StubModelDownloader(),
            mediaExtractor: StubMediaExtractor(
                result: ExtractedAudioSource(
                    audioURL: extractedAudioURL,
                    duration: 4.5,
                    wasExtractedFromVideo: true
                )
            ),
            audioPreparer: StubAudioPreparer(
                result: PreparedAudio(
                    fileURL: preparedAudioURL,
                    sampleRate: 16_000,
                    channelCount: 1,
                    duration: 4.5
                )
            ),
            whisperBridge: StubWhisperBridge(
                result: RawWhisperTranscriptionResult(
                    text: "  hello   world  ",
                    language: " pt-BR ",
                    segments: [
                        RawWhisperSegment(
                            startTime: 2,
                            endTime: 3,
                            text: "  second segment ",
                            words: [
                                RawWhisperWord(
                                    startTime: 2.6,
                                    endTime: 2.9,
                                    text: " segment "
                                ),
                                RawWhisperWord(
                                    startTime: 2.2,
                                    endTime: 2.4,
                                    text: " second "
                                ),
                            ]
                        ),
                        RawWhisperSegment(
                            startTime: -0.5,
                            endTime: 1,
                            text: "   ",
                            words: [
                                RawWhisperWord(
                                    startTime: 0.4,
                                    endTime: 0.8,
                                    text: "world"
                                ),
                                RawWhisperWord(
                                    startTime: 0,
                                    endTime: 0.2,
                                    text: "hello"
                                ),
                            ]
                        ),
                    ]
                )
            ),
            statusReporter: reporter
        )

        let result = try await client.transcribe(request)

        #expect(reporter.snapshot() == [.idle, .preparingAudio, .transcribing, .completed])
        #expect(result.fullText == "hello world")
        #expect(result.language == "pt-BR")
        #expect(result.duration == 4.5)
        #expect(result.segments.map(\.text) == ["hello world", "second segment"])
        #expect(result.segments.map(\.startTime) == [0, 2])
        #expect(result.segments.first?.words.map(\.text) == ["hello", "world"])
        #expect(result.segments.last?.words.map(\.text) == ["second", "segment"])
        #expect(!FileManager.default.fileExists(atPath: extractedAudioURL.path()))
        #expect(!FileManager.default.fileExists(atPath: preparedAudioURL.path()))
        #expect(FileManager.default.fileExists(atPath: modelURL.path()))
    }

    @Test
    func clientDownloadsTheModelReportsProgressAndRemovesTemporaryDownloads() async throws {
        let workingDirectory = try TranscriptionKitTestMediaFactory.makeWorkingDirectory()
        let inputAudioURL = workingDirectory.appendingPathComponent("input.m4a")
        let preparedAudioURL = workingDirectory.appendingPathComponent("prepared.caf")
        let installedModelURL = workingDirectory.appendingPathComponent("installed.bin")
        let temporaryDownloadURL = workingDirectory.appendingPathComponent("download.tmp")
        let remoteURL = try #require(
            URL(string: "https://example.com/base.bin")
        )
        let request = TranscriptionRequest(
            media: .audioFile(inputAudioURL),
            model: RemoteModelDescriptor(
                id: "base",
                remoteURL: remoteURL,
                localFileName: "base.bin"
            )
        )
        let reporter = LockedStatusReporter()
        let modelDownloader = StubModelDownloader(
            progressValues: [0.25, 1.0],
            downloadedData: Data([7, 8, 9])
        )

        try Data([1, 2, 3]).write(to: inputAudioURL)
        try Data([4, 5, 6]).write(to: preparedAudioURL)

        let client = TranscriptionClient(
            modelStore: StubModelStore(
                cachedState: .missing,
                localModelURLValue: installedModelURL,
                temporaryDownloadURLValue: temporaryDownloadURL,
                installedModelURLValue: installedModelURL
            ),
            modelDownloader: modelDownloader,
            mediaExtractor: StubMediaExtractor(
                result: ExtractedAudioSource(
                    audioURL: inputAudioURL,
                    duration: 2,
                    wasExtractedFromVideo: false
                )
            ),
            audioPreparer: StubAudioPreparer(
                result: PreparedAudio(
                    fileURL: preparedAudioURL,
                    sampleRate: 16_000,
                    channelCount: 1,
                    duration: 2
                )
            ),
            whisperBridge: StubWhisperBridge(
                result: RawWhisperTranscriptionResult(
                    text: "downloaded model",
                    language: nil,
                    segments: []
                )
            ),
            statusReporter: reporter
        )

        let result = try await client.transcribe(request)

        #expect(result.fullText == "downloaded model")
        #expect(
            reporter.snapshot() == [
                .idle,
                .downloading(progress: 0),
                .downloading(progress: 0.25),
                .downloading(progress: 1.0),
                .preparingAudio,
                .transcribing,
                .completed,
            ])
        #expect(modelDownloader.snapshot().count == 1)
        #expect(!FileManager.default.fileExists(atPath: temporaryDownloadURL.path()))
        #expect(!FileManager.default.fileExists(atPath: preparedAudioURL.path()))
        #expect(FileManager.default.fileExists(atPath: inputAudioURL.path()))
    }

}
