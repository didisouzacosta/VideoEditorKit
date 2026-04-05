import Foundation
import Testing

@testable import VideoEditorKit

@Suite("LocalTranscriptionVideoProviderTests")
struct LocalTranscriptionVideoProviderTests {

    // MARK: - Public Methods

    @Test
    func providerMapsVideoInputIntoTranscriptionKitRequest() async throws {
        let remoteURL = try #require(
            URL(string: "https://example.com/base.bin")
        )
        let videoURL = URL(fileURLWithPath: "/tmp/source.mov")
        let client = RecordingTranscriptionClient(
            result: NormalizedTranscription(
                fullText: "ignored",
                segments: []
            )
        )
        let provider = LocalTranscriptionVideoProvider(
            modelDescriptor: RemoteModelDescriptor(
                id: "base",
                remoteURL: remoteURL,
                localFileName: "base.bin"
            ),
            client: client,
            defaultTask: .translate
        )

        _ = try await provider.transcribeVideo(
            input: VideoTranscriptionInput(
                assetIdentifier: "asset-1",
                source: .fileURL(videoURL),
                preferredLocale: " pt-BR "
            )
        )

        let request = await client.requests().first
        #expect(request?.media == .videoFile(videoURL))
        #expect(request?.model.id == "base")
        #expect(request?.language == "pt-BR")
        #expect(request?.task == .translate)
    }

    @Test
    func providerMapsNormalizedTranscriptionBackIntoEditorResult() async throws {
        let remoteURL = try #require(
            URL(string: "https://example.com/base.bin")
        )
        let segmentID = try #require(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        )
        let wordID = try #require(
            UUID(uuidString: "11111111-2222-3333-4444-555555555555")
        )
        let provider = LocalTranscriptionVideoProvider(
            modelDescriptor: RemoteModelDescriptor(
                id: "base",
                remoteURL: remoteURL,
                localFileName: "base.bin"
            ),
            client: RecordingTranscriptionClient(
                result: NormalizedTranscription(
                    fullText: "hello world",
                    language: "en",
                    duration: 2,
                    segments: [
                        NormalizedSegment(
                            id: segmentID,
                            startTime: 0,
                            endTime: 1,
                            text: "hello",
                            words: [
                                NormalizedWord(
                                    id: wordID,
                                    startTime: 0,
                                    endTime: 0.4,
                                    text: "hello"
                                )
                            ]
                        )
                    ]
                )
            )
        )

        let result = try await provider.transcribeVideo(
            input: VideoTranscriptionInput(
                assetIdentifier: "asset-1",
                source: .fileURL(URL(fileURLWithPath: "/tmp/source.mov")),
                preferredLocale: nil
            )
        )

        #expect(result.segments.count == 1)
        #expect(result.segments.first?.id.uuidString == "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        #expect(result.segments.first?.text == "hello")
        #expect(result.segments.first?.words.first?.id.uuidString == "11111111-2222-3333-4444-555555555555")
        #expect(result.segments.first?.words.first?.text == "hello")
    }

    @Test
    func providerPropagatesTranscriptionKitFailures() async throws {
        let remoteURL = try #require(
            URL(string: "https://example.com/base.bin")
        )
        let provider = LocalTranscriptionVideoProvider(
            modelDescriptor: RemoteModelDescriptor(
                id: "base",
                remoteURL: remoteURL,
                localFileName: "base.bin"
            ),
            client: RecordingTranscriptionClient(
                error: TranscriptionError.modelDownloadFailed(
                    message: "offline"
                )
            )
        )

        await #expect(throws: TranscriptionError.self) {
            try await provider.transcribeVideo(
                input: VideoTranscriptionInput(
                    assetIdentifier: "asset-1",
                    source: .fileURL(URL(fileURLWithPath: "/tmp/source.mov")),
                    preferredLocale: nil
                )
            )
        }
    }

}

private actor RecordingTranscriptionClient: TranscriptionProviding {

    // MARK: - Private Properties

    private let result: NormalizedTranscription?
    private let error: Error?
    private var recordedRequests: [TranscriptionRequest] = []

    // MARK: - Initializer

    init(result: NormalizedTranscription) {
        self.result = result
        self.error = nil
    }

    init(error: Error) {
        self.result = nil
        self.error = error
    }

    // MARK: - Public Methods

    func transcribe(_ request: TranscriptionRequest) async throws -> NormalizedTranscription {
        recordedRequests.append(request)

        if let error {
            throw error
        }

        return try #require(result)
    }

    func requests() -> [TranscriptionRequest] {
        recordedRequests
    }

}
