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
        VideoEditorView.Configuration.TranscriptionConfiguration.openAIWhisper(
            apiKey: resolvedOpenAIAPIKey(infoDictionary: infoDictionary)
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
