//
//  VideoEditorSessionSourceResolver.swift
//  VideoEditor
//
//  Created by Codex on 02.04.2026.
//

import Foundation
import PhotosUI
import SwiftUI
import VideoEditorKit

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

    func makeSource(
        from item: PhotosPickerItem
    ) -> VideoEditorSessionSource {
        .importedFile(
            .init(
                taskIdentifier: taskIdentifier(for: item)
            ) {
                try await resolveImportedVideo {
                    try await videoItemLoader(item)
                }
            }
        )
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

    // MARK: - Private Methods

    private func taskIdentifier(
        for item: PhotosPickerItem
    ) -> String {
        let itemIdentifier = item.itemIdentifier ?? "unknown"
        let supportedContentTypes = String(describing: item.supportedContentTypes)

        return "picker:\(itemIdentifier)-\(supportedContentTypes)"
    }

}
