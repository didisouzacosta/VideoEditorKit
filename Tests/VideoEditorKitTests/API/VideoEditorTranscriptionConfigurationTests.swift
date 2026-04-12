import Testing

@testable import VideoEditorKit

@Suite("VideoEditorTranscriptionConfigurationTests")
struct EditorTranscriptionConfigTests {

    // MARK: - Public Methods

    @MainActor
    @Test
    func appleSpeechKeepsThePreferredLocaleAndCreatesAStatefulProvider() {
        let configuration = VideoEditorView.Configuration.TranscriptionConfiguration.appleSpeech(
            preferredLocale: "pt-BR"
        )

        #expect(configuration.preferredLocale == "pt-BR")
        #expect(configuration.provider != nil)
        #expect((configuration.provider as? any VideoTranscriptionComponentProtocol) != nil)
        #expect(configuration.isConfigured)
    }

    @MainActor
    @Test
    func appleSpeechCreatesAProviderWithoutAPreferredLocale() {
        let configuration = VideoEditorView.Configuration.TranscriptionConfiguration.appleSpeech()

        #expect(configuration.preferredLocale == nil)
        #expect(configuration.provider != nil)
        #expect(configuration.isConfigured)
    }

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
