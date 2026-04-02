//
//  VideoEditorSessionSourceResolver.swift
//  VideoEditorKit
//
//  Created by Codex on 02.04.2026.
//

import Foundation
import PhotosUI
import SwiftUI

struct VideoEditorSessionSourceResolver {

    enum ResolutionError: LocalizedError, Equatable {

        // MARK: - Public Properties

        case unsupportedSource
        case unableToLoadSelectedVideo
        case importFailed(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedSource:
                return "The selected source is not supported."
            case .unableToLoadSelectedVideo:
                return "The selected video could not be loaded."
            case .importFailed(let message):
                return message
            }
        }

    }

    // MARK: - Private Properties

    private let videoItemLoader: @Sendable (PhotosPickerItem) async throws -> VideoItem?

    // MARK: - Initializer

    init(
        videoItemLoader: @escaping @Sendable (PhotosPickerItem) async throws -> VideoItem? = {
            try await $0.loadTransferable(type: VideoItem.self)
        }
    ) {
        self.videoItemLoader = videoItemLoader
    }

    // MARK: - Public Methods

    func resolve(_ source: VideoEditorView.Session.Source?) async throws -> URL? {
        guard let source else { return nil }

        switch source {
        case .fileURL(let url):
            return url
        case .photosPickerItem(let item):
            return try await resolveImportedVideo {
                try await videoItemLoader(item)
            }
        }
    }

    func resolveImportedVideo(
        using loader: @escaping @Sendable () async throws -> VideoItem?
    ) async throws -> URL {
        do {
            guard let importedVideo = try await loader() else {
                throw ResolutionError.unableToLoadSelectedVideo
            }

            return importedVideo.url
        } catch let error as ResolutionError {
            throw error
        } catch {
            throw ResolutionError.importFailed(error.localizedDescription)
        }
    }

}
