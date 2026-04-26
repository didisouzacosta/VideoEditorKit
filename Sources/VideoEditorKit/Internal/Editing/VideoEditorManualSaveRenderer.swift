//
//  VideoEditorManualSaveRenderer.swift
//  VideoEditorKit
//
//  Created by Codex on 26.04.2026.
//

import Foundation

struct VideoEditorManualSaveRenderer {

    struct Dependencies {

        // MARK: - Public Properties

        static let live = Self(
            renderEditedVideo: { video, editingConfiguration, onProgress in
                try await VideoEditor.startRender(
                    video: video,
                    editingConfiguration: editingConfiguration,
                    renderIntent: .saveNative(sourceFrameRate: nil),
                    onProgress: onProgress
                )
            },
            loadSavedMetadata: { url in
                await ExportedVideo.load(from: url)
            },
            makeThumbnailData: { sourceVideoURL, editingConfiguration in
                await VideoEditingThumbnailRenderer.makeThumbnailData(
                    sourceVideoURL: sourceVideoURL,
                    editingConfiguration: editingConfiguration
                )
            }
        )

        let renderEditedVideo:
            @Sendable (Video, VideoEditingConfiguration, VideoEditor.ProgressHandler?) async throws -> URL
        let loadSavedMetadata: @Sendable (URL) async -> ExportedVideo
        let makeThumbnailData: @Sendable (URL, VideoEditingConfiguration) async -> Data?

    }

    // MARK: - Private Properties

    private let dependencies: Dependencies

    // MARK: - Initializer

    init(_ dependencies: Dependencies = .live) {
        self.dependencies = dependencies
    }

    // MARK: - Public Methods

    func save(
        video: Video,
        editingConfiguration: VideoEditingConfiguration,
        originalVideoURL: URL,
        onProgress: VideoEditor.ProgressHandler? = nil
    ) async throws -> SavedVideo {
        let savedVideoURL = try await dependencies.renderEditedVideo(
            video,
            editingConfiguration,
            onProgress
        )
        let metadata = await dependencies.loadSavedMetadata(savedVideoURL)
        let thumbnailData = await dependencies.makeThumbnailData(
            originalVideoURL,
            editingConfiguration
        )

        return SavedVideo(
            savedVideoURL,
            originalVideoURL: originalVideoURL,
            editingConfiguration: editingConfiguration,
            thumbnailData: thumbnailData,
            metadata: metadata
        )
    }

}
