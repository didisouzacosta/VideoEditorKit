//
//  AppShellTranscriptionConfiguration.swift
//  VideoEditor
//
//  Created by Codex on 08.04.2026.
//

import Foundation
import VideoEditorKit

enum AppShellTranscriptionConfiguration {

    private enum Keys {
        static let openAIAPIKey = "OPENAI_API_KEY"
    }

    static func makeDefaultTranscriptionConfiguration(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> VideoEditorView.Configuration.TranscriptionConfiguration {
        guard let apiKey = optionalOpenAIAPIKey(infoDictionary: infoDictionary) else {
            return .init()
        }

        return openAIWhisper(apiKey: apiKey)
    }

    static func appleSpeech(
        preferredLocale: String? = nil,
        dependencies: AppleSpeechTranscriptionProviderFactory.Dependencies = .init()
    ) -> VideoEditorView.Configuration.TranscriptionConfiguration {
        let provider = AppleSpeechTranscriptionProviderFactory(
            dependencies: dependencies
        )
        .makeProvider()
        let resolvedPreferredLocale =
            preferredLocale
            ?? Locale.autoupdatingCurrent.identifier.replacingOccurrences(
                of: "_",
                with: "-"
            )

        return .init(
            provider: provider,
            preferredLocale: resolvedPreferredLocale
        )
    }

    static func openAIWhisper(
        apiKey: String,
        preferredLocale: String? = nil,
        dependencies: OpenAIWhisperTranscriptionProviderFactory.Dependencies = .init()
    ) -> VideoEditorView.Configuration.TranscriptionConfiguration {
        let provider = OpenAIWhisperTranscriptionProviderFactory(
            dependencies: .init(
                resolveAPIKey: { apiKey },
                makeProvider: dependencies.makeProvider
            )
        )
        .makeProvider()

        return .init(
            provider: provider,
            preferredLocale: preferredLocale
        )
    }

    static func resolvedOpenAIAPIKey(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> String {
        optionalOpenAIAPIKey(infoDictionary: infoDictionary) ?? ""
    }

    private static func optionalOpenAIAPIKey(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> String? {
        let apiKey = (infoDictionary?[Keys.openAIAPIKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let apiKey, apiKey.isEmpty == false else { return nil }
        return apiKey
    }

}
