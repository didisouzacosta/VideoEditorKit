import Foundation
import Testing

@testable import VideoEditorKit

@Suite("TranscriptionKitPhase1Tests")
struct TranscriptionKitPhase1Tests {

    // MARK: - Public Methods

    @Test
    func requestSupportsVideoMediaSourcesWithoutLeakingEditorTypes() {
        let mediaURL = URL(fileURLWithPath: "/tmp/source.mp4")
        let model = RemoteModelDescriptor(
            id: "base",
            remoteURL: URL(string: "https://example.com/base.bin")!,
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
        #expect(TranscriptionKitHardcodedModels.availableModels.isEmpty)
        #expect(TranscriptionKitHardcodedModels.preferredModel == nil)
    }

    @Test
    func clientCanBeConstructedWithThePhaseOneScaffolding() {
        let client = TranscriptionClient()

        #expect(String(describing: type(of: client)) == "TranscriptionClient")
    }

}
