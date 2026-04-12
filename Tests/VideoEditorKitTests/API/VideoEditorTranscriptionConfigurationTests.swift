import Testing

@testable import VideoEditorKit

@Suite("VideoEditorTranscriptionConfigurationTests")
struct EditorTranscriptionConfigTests {

    // MARK: - Public Methods

    @MainActor
    @Test
    func openAIWhisperReturnsAnUnconfiguredStateWhenTheAPIKeyIsBlank() {
        let configuration = VideoEditorView.Configuration.TranscriptionConfiguration.openAIWhisper(
            apiKey: "   "
        )

        #expect(configuration.provider == nil)
        #expect(configuration.isConfigured == false)
    }

    @MainActor
    @Test
    func openAIWhisperKeepsThePreferredLocaleAndCreatesAProvider() {
        let configuration = VideoEditorView.Configuration.TranscriptionConfiguration.openAIWhisper(
            apiKey: "test-api-key",
            preferredLocale: "en-US"
        )

        #expect(configuration.preferredLocale == "en-US")
        #expect(configuration.provider != nil)
        #expect(configuration.isConfigured)
    }

}
