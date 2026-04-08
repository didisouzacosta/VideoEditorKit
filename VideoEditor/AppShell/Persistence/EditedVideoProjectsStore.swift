//
//  EditedVideoProjectsStore.swift
//  VideoEditorKit
//
//  Created by Codex on 28.03.2026.
//

import AVFoundation
import Foundation
import SwiftData
import VideoEditorKit

@MainActor
struct EditedVideoProjectsStore {

    struct PersistedEditingState {

        // MARK: - Public Properties

        let project: EditedVideoProject
        let saveState: VideoEditorView.SaveState

    }

    private struct PreparedProjectSave {

        // MARK: - Public Properties

        let project: EditedVideoProject
        let now: Date
        let persistedOriginalURL: URL
        let persistedEditingConfiguration: VideoEditingConfiguration

    }

    // MARK: - Public Properties

    let modelContext: ModelContext

    enum StoreError: LocalizedError {
        case missingOriginalVideo

        var errorDescription: String? {
            switch self {
            case .missingOriginalVideo:
                "The original video could not be found for this project."
            }
        }
    }

    // MARK: - Private Properties

    private let fileManager = FileManager.default

    // MARK: - Public Methods

    func saveEditingState(
        projectID: UUID?,
        originalVideoURL: URL,
        saveState: VideoEditorView.SaveState
    ) async throws -> PersistedEditingState {
        let preparedSave = try prepareProjectSave(
            projectID: projectID,
            originalVideoURL: originalVideoURL,
            editingConfiguration: saveState.editingConfiguration
        )
        let sourceVideoMetadata = await loadVideoMetadata(from: preparedSave.persistedOriginalURL)

        applyCommonProjectFields(
            preparedSave,
            displayName: originalVideoURL.deletingPathExtension().lastPathComponent
        )

        if let thumbnailData = saveState.thumbnailData {
            preparedSave.project.thumbnailData = thumbnailData
        }

        if preparedSave.project.hasExportedVideo == false {
            applyVideoMetadata(
                sourceVideoMetadata,
                to: preparedSave.project
            )
        }

        try modelContext.save()

        return PersistedEditingState(
            project: preparedSave.project,
            saveState: .init(
                editingConfiguration: preparedSave.persistedEditingConfiguration,
                thumbnailData: preparedSave.project.thumbnailData
            )
        )
    }

    func saveExportedVideo(
        projectID: UUID?,
        originalVideoURL: URL,
        exportedVideo: ExportedVideo,
        editingConfiguration: VideoEditingConfiguration
    ) async throws -> EditedVideoProject {
        let preparedSave = try prepareProjectSave(
            projectID: projectID,
            originalVideoURL: originalVideoURL,
            editingConfiguration: editingConfiguration
        )
        let projectDirectoryURL = try ensureProjectDirectory(for: preparedSave.project.id)
        let persistedExportedURL = try persistExportedVideo(
            from: exportedVideo.url,
            to: projectDirectoryURL
        )
        let thumbnailData = await makeThumbnailData(
            fromExportedVideoAt: persistedExportedURL,
            editingConfiguration: preparedSave.persistedEditingConfiguration
        )

        applyCommonProjectFields(
            preparedSave,
            displayName: originalVideoURL.deletingPathExtension().lastPathComponent
        )

        preparedSave.project.exportedVideoFileName = persistedExportedURL.lastPathComponent
        preparedSave.project.thumbnailData = thumbnailData ?? preparedSave.project.thumbnailData
        applyVideoMetadata(
            exportedVideo,
            to: preparedSave.project
        )

        try modelContext.save()

        cleanupTransientMediaIfNeeded(originalVideoURL, protectedURL: preparedSave.persistedOriginalURL)
        cleanupTransientMediaIfNeeded(exportedVideo.url, protectedURL: persistedExportedURL)
        cleanupTransientAudioIfNeeded(
            originalConfiguration: editingConfiguration,
            persistedConfiguration: preparedSave.persistedEditingConfiguration
        )

        return preparedSave.project
    }

    func deleteProject(_ project: EditedVideoProject) throws {
        fileManager.removeIfExists(for: EditedVideoProject.directoryURL(for: project.id))
        modelContext.delete(project)
        try modelContext.save()
    }

    static func resolvedThumbnailTimestamp(
        for duration: Double,
        editingConfiguration: VideoEditingConfiguration
    ) -> Double {
        VideoEditingThumbnailTimestampResolver.exportedAssetTimestamp(
            for: editingConfiguration,
            exportedDuration: duration
        )
    }

    // MARK: - Private Methods

    private func prepareProjectSave(
        projectID: UUID?,
        originalVideoURL: URL,
        editingConfiguration: VideoEditingConfiguration
    ) throws -> PreparedProjectSave {
        guard fileManager.fileExists(atPath: originalVideoURL.path()) else {
            throw StoreError.missingOriginalVideo
        }

        let existingProject = try fetchProject(id: projectID)
        let now = Date()
        let resolvedProject =
            existingProject
            ?? EditedVideoProject(
                createdAt: now,
                updatedAt: now,
                displayName: originalVideoURL.deletingPathExtension().lastPathComponent,
                originalVideoFileName: "",
                exportedVideoFileName: "",
                editingConfigurationData: Data(),
                thumbnailData: nil,
                duration: 0,
                width: 0,
                height: 0,
                fileSize: 0
            )

        if existingProject == nil {
            modelContext.insert(resolvedProject)
        }

        let projectDirectoryURL = try ensureProjectDirectory(for: resolvedProject.id)
        let persistedOriginalURL = try persistOriginalVideo(
            from: originalVideoURL,
            to: projectDirectoryURL
        )
        let persistedEditingConfiguration = try persistRecordedAudioIfNeeded(
            editingConfiguration,
            in: projectDirectoryURL
        )

        return .init(
            project: resolvedProject,
            now: now,
            persistedOriginalURL: persistedOriginalURL,
            persistedEditingConfiguration: persistedEditingConfiguration
        )
    }

    private func applyCommonProjectFields(
        _ preparedSave: PreparedProjectSave,
        displayName: String
    ) {
        preparedSave.project.updatedAt = preparedSave.now
        preparedSave.project.displayName = displayName
        preparedSave.project.originalVideoFileName = preparedSave.persistedOriginalURL.lastPathComponent
        preparedSave.project.editingConfigurationData =
            (try? JSONEncoder().encode(
                preparedSave.persistedEditingConfiguration
            )) ?? Data()
    }

    private func applyVideoMetadata(
        _ video: ExportedVideo,
        to project: EditedVideoProject
    ) {
        project.duration = video.duration
        project.width = video.width
        project.height = video.height
        project.fileSize = video.fileSize
    }

    private func loadVideoMetadata(
        from url: URL
    ) async -> ExportedVideo {
        await ExportedVideo.load(from: url)
    }

    private func fetchProject(id: UUID?) throws -> EditedVideoProject? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<EditedVideoProject>()
        return try modelContext.fetch(descriptor).first(where: { $0.id == id })
    }

    private func ensureProjectDirectory(for id: UUID) throws -> URL {
        let projectsDirectoryURL = EditedVideoProject.projectsDirectoryURL()
        let projectDirectoryURL = EditedVideoProject.directoryURL(for: id)

        try fileManager.createDirectory(
            at: projectsDirectoryURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: projectDirectoryURL,
            withIntermediateDirectories: true
        )

        return projectDirectoryURL
    }

    private func persistOriginalVideo(
        from sourceURL: URL,
        to projectDirectoryURL: URL
    ) throws -> URL {
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
        let destinationURL = projectDirectoryURL.appending(path: "original.\(fileExtension)")
        return try persistFile(from: sourceURL, to: destinationURL)
    }

    private func persistExportedVideo(
        from sourceURL: URL,
        to projectDirectoryURL: URL
    ) throws -> URL {
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension
        let destinationURL = projectDirectoryURL.appending(path: "exported.\(fileExtension)")
        return try persistFile(from: sourceURL, to: destinationURL)
    }

    private func persistRecordedAudioIfNeeded(
        _ editingConfiguration: VideoEditingConfiguration,
        in projectDirectoryURL: URL
    ) throws -> VideoEditingConfiguration {
        var persistedEditingConfiguration = editingConfiguration

        guard var recordedClip = editingConfiguration.audio.recordedClip else {
            removePersistedRecordedAudioIfNeeded(in: projectDirectoryURL)
            return persistedEditingConfiguration
        }

        let fileExtension = recordedClip.url.pathExtension.isEmpty ? "m4a" : recordedClip.url.pathExtension
        let destinationURL = projectDirectoryURL.appending(path: "recorded-audio.\(fileExtension)")

        if recordedClip.url.standardizedFileURL != destinationURL.standardizedFileURL {
            removePersistedRecordedAudioIfNeeded(in: projectDirectoryURL)
            recordedClip.url = try persistFile(from: recordedClip.url, to: destinationURL)
        }

        persistedEditingConfiguration.audio.recordedClip = recordedClip
        return persistedEditingConfiguration
    }

    private func removePersistedRecordedAudioIfNeeded(in projectDirectoryURL: URL) {
        guard
            let projectFiles = try? fileManager.contentsOfDirectory(
                at: projectDirectoryURL,
                includingPropertiesForKeys: nil
            )
        else {
            return
        }

        for fileURL in projectFiles where fileURL.lastPathComponent.hasPrefix("recorded-audio.") {
            fileManager.removeIfExists(for: fileURL)
        }
    }

    private func persistFile(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws -> URL {
        if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return destinationURL
        }

        fileManager.removeIfExists(for: destinationURL)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func makeThumbnailData(
        fromExportedVideoAt url: URL,
        editingConfiguration: VideoEditingConfiguration
    ) async -> Data? {
        let asset = AVURLAsset(url: url)
        let duration = (try? await asset.load(.duration).seconds) ?? .zero
        let timestamp = Self.resolvedThumbnailTimestamp(
            for: duration,
            editingConfiguration: editingConfiguration
        )
        let image = await asset.generateImage(
            at: timestamp,
            maximumSize: CGSize(width: 720, height: 720),
            requiresExactFrame: true
        )

        return image?.jpegData(compressionQuality: 0.85)
    }

    private func cleanupTransientMediaIfNeeded(
        _ originalURL: URL,
        protectedURL: URL
    ) {
        guard originalURL.standardizedFileURL != protectedURL.standardizedFileURL else { return }
        guard isTransientMediaURL(originalURL) else { return }
        fileManager.removeIfExists(for: originalURL)
    }

    private func cleanupTransientAudioIfNeeded(
        originalConfiguration: VideoEditingConfiguration,
        persistedConfiguration: VideoEditingConfiguration
    ) {
        guard
            let originalURL = originalConfiguration.audio.recordedClip?.url,
            let persistedURL = persistedConfiguration.audio.recordedClip?.url
        else {
            return
        }

        cleanupTransientMediaIfNeeded(originalURL, protectedURL: persistedURL)
    }

    private func isTransientMediaURL(_ url: URL) -> Bool {
        let standardizedPath = url.standardizedFileURL.path()
        return standardizedPath.hasPrefix(URL.cachesDirectory.path())
            || standardizedPath.hasPrefix(URL.temporaryDirectory.path())
    }

}
