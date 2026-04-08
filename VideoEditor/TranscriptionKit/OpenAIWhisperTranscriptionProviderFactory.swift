//
//  OpenAIWhisperTranscriptionProviderFactory.swift
//  VideoEditorKit
//
//  Created by Codex on 08.04.2026.
//

import Foundation
import VideoEditorKit

struct OpenAIWhisperTranscriptionProviderFactory {

    struct Dependencies: Sendable {

        // MARK: - Public Properties

        let resolveAPIKey: @Sendable () -> String?
        let makeProvider: @Sendable (String) -> any VideoTranscriptionProvider

        // MARK: - Initializer

        init(
            resolveAPIKey: @escaping @Sendable () -> String?,
            makeProvider: @escaping @Sendable (String) -> any VideoTranscriptionProvider
        ) {
            self.resolveAPIKey = resolveAPIKey
            self.makeProvider = makeProvider
        }

        init() {
            self.init(
                resolveAPIKey: { nil },
                makeProvider: { OpenAIWhisperTranscriptionComponent($0) }
            )
        }

    }

    // MARK: - Private Properties

    private let dependencies: Dependencies

    // MARK: - Initializer

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    // MARK: - Public Methods

    func makeProvider() -> (any VideoTranscriptionProvider)? {
        guard let apiKey = resolvedAPIKey() else { return nil }
        return dependencies.makeProvider(apiKey)
    }

    // MARK: - Private Methods

    private func resolvedAPIKey() -> String? {
        let trimmedAPIKey = dependencies.resolveAPIKey()?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let trimmedAPIKey else { return nil }
        guard trimmedAPIKey.isEmpty == false else { return nil }
        return trimmedAPIKey
    }

}
