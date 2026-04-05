import Foundation
import Testing

@testable import VideoEditorKit

@Suite("WhisperBridgeTests")
struct WhisperBridgeTests {

    // MARK: - Public Methods

    @Test
    func bridgeMapsRunnerPayloadIntoRawWhisperTypes() async throws {
        let bridge = WhisperBridge(
            runner: StubWhisperBridgeRunner(
                result: WhisperBridgeResultPayload(
                    text: "full text",
                    language: "pt",
                    segments: [
                        WhisperBridgeSegmentPayload(
                            startTime: 0,
                            endTime: 1.2,
                            text: "segment text",
                            words: [
                                WhisperBridgeWordPayload(
                                    startTime: 0,
                                    endTime: 0.5,
                                    text: "hello"
                                )
                            ]
                        )
                    ]
                )
            )
        )

        let result = try await bridge.transcribe(
            preparedAudio: PreparedAudio(
                fileURL: URL(fileURLWithPath: "/tmp/prepared.caf"),
                sampleRate: 16_000,
                channelCount: 1,
                duration: 1.2
            ),
            modelURL: URL(fileURLWithPath: "/tmp/model.bin"),
            language: "pt",
            task: .transcribe
        )

        #expect(result.text == "full text")
        #expect(result.language == "pt")
        #expect(result.segments.count == 1)
        #expect(result.segments.first?.text == "segment text")
        #expect(result.segments.first?.words.first?.text == "hello")
    }

    @Test
    func objectiveCRunnerReturnsATypedErrorWhenNoRuntimeIsRegistered() async {
        let runner = WhisperObjectiveCRunner()

        await #expect(throws: TranscriptionError.self) {
            try await runner.run(
                WhisperBridgeRequestPayload(
                    preparedAudio: PreparedAudio(
                        fileURL: URL(fileURLWithPath: "/tmp/prepared.caf"),
                        sampleRate: 16_000,
                        channelCount: 1,
                        duration: 1
                    ),
                    modelURL: URL(fileURLWithPath: "/tmp/model.bin"),
                    language: nil,
                    task: .transcribe
                )
            )
        }
    }

}

private struct StubWhisperBridgeRunner: WhisperBridgeRunning {

    // MARK: - Public Properties

    let result: WhisperBridgeResultPayload

    // MARK: - Public Methods

    func run(_ request: WhisperBridgeRequestPayload) async throws -> WhisperBridgeResultPayload {
        result
    }

}
