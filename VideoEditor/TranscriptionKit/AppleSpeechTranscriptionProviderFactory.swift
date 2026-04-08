//
//  AppleSpeechTranscriptionProviderFactory.swift
//  VideoEditorKit
//
//  Created by Codex on 08.04.2026.
//

import VideoEditorKit

struct AppleSpeechTranscriptionProviderFactory {

    struct Dependencies: Sendable {

        // MARK: - Public Properties

        let makeProvider: @Sendable () -> any VideoTranscriptionProvider

        // MARK: - Initializer

        init(
            makeProvider: @escaping @Sendable () -> any VideoTranscriptionProvider
        ) {
            self.makeProvider = makeProvider
        }

        init() {
            self.init(
                makeProvider: {
                    AppleSpeechTranscriptionComponent()
                }
            )
        }

    }

    // MARK: - Private Properties

    private let dependencies: Dependencies

    // MARK: - Initializer

    init(
        dependencies: Dependencies = .init()
    ) {
        self.dependencies = dependencies
    }

    // MARK: - Public Methods

    func makeProvider() -> any VideoTranscriptionProvider {
        return dependencies.makeProvider()
    }

}
