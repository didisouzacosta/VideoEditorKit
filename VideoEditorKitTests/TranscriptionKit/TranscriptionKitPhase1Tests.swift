import Foundation
import Testing

@testable import VideoEditorKit

@Suite("TranscriptionKitPhase1Tests")
struct TranscriptionKitPhase1Tests {

    // MARK: - Public Methods

    @Test
    func requestSupportsVideoMediaSourcesWithoutLeakingEditorTypes() {
        let mediaURL = URL(fileURLWithPath: "/tmp/source.mp4")
        let remoteURL = URL(filePath: "/tmp/base.bin")
        let model = RemoteModelDescriptor(
            id: "base",
            remoteURL: remoteURL,
            localFileName: "base.bin"
        )

        let request = TranscriptionRequest(
            media: .videoFile(mediaURL),
            model: model,
            language: "pt",
            task: .transcribe
        )

        #expect(request.media == .videoFile(mediaURL))
        #expect(request.media.fileURL == mediaURL)
        #expect(request.model == model)
        #expect(request.language == "pt")
        #expect(request.task == .transcribe)
    }

    @Test
    func hardcodedModelCatalogStartsCentralizedInOneEasyToFindSurface() {
        let preferredModel = TranscriptionKitHardcodedModels.preferredModel

        #expect(TranscriptionKitHardcodedModels.availableModels.count == 1)
        #expect(preferredModel?.id == "ggml-base")
        #expect(
            preferredModel?.remoteURL.absoluteString
                == "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
        )
        #expect(preferredModel?.localFileName == "ggml-base.bin")
    }

    @Test
    func clientCanBeConstructedWithThePhaseOneScaffolding() {
        let client = TranscriptionClient()

        #expect(String(describing: type(of: client)) == "TranscriptionClient")
    }

}
