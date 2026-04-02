//
//  VideoEditorSessionBootstrapCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 02.04.2026.
//

import Foundation

struct VideoEditorSessionBootstrapCoordinator {

    enum BootstrapState: Equatable {

        // MARK: - Public Properties

        case idle
        case loading
        case loaded(URL)
        case failed(String)

    }

    // MARK: - Public Methods

    static func initialState(
        for source: VideoEditorView.Session.Source?
    ) -> BootstrapState {
        switch source {
        case .none:
            return .idle
        case .fileURL(let url):
            return .loaded(url)
        case .photosPickerItem:
            return .loading
        }
    }

    static func resolveState(
        for source: VideoEditorView.Session.Source?,
        using resolver: VideoEditorSessionSourceResolver
    ) async -> BootstrapState {
        switch source {
        case .none:
            return .idle
        case .fileURL(let url):
            return .loaded(url)
        case .photosPickerItem:
            do {
                guard let resolvedSourceURL = try await resolver.resolve(source) else {
                    return .failed(
                        VideoEditorSessionSourceResolver.ResolutionError
                            .unsupportedSource
                            .errorDescription
                            ?? "The selected source is not supported."
                    )
                }

                return .loaded(resolvedSourceURL)
            } catch {
                return .failed(error.localizedDescription)
            }
        }
    }

}
