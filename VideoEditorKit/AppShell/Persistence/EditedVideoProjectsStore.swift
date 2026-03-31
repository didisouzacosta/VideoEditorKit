//
//  EditedVideoProjectsStore.swift
//  VideoEditorKit
//
//  Created by Codex on 28.03.2026.
//

import AVFoundation
import Foundation
import SwiftData
import UIKit

@MainActor
struct EditedVideoProjectsStore {

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

    func saveProject(
        projectID: UUID?,
        originalVideoURL: URL,
        exportedVideo: ExportedVideo,
        editingConfiguration: VideoEditingConfiguration
    ) async throws -> EditedVideoProject {
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
        let persistedExportedURL = try persistExportedVideo(
            from: exportedVideo.url,
            to: projectDirectoryURL
        )
        let persistedEditingConfiguration = try persistRecordedAudioIfNeeded(
            editingConfiguration,
            in: projectDirectoryURL
        )
        let thumbnailData = await makeThumbnailData(
            fromExportedVideoAt: persistedExportedURL
        )

        resolvedProject.updatedAt = now
        resolvedProject.displayName = originalVideoURL.deletingPathExtension().lastPathComponent
        resolvedProject.originalVideoFileName = persistedOriginalURL.lastPathComponent
        resolvedProject.exportedVideoFileName = persistedExportedURL.lastPathComponent
        resolvedProject.editingConfigurationData = try JSONEncoder().encode(
            persistedEditingConfiguration
        )
        resolvedProject.thumbnailData = thumbnailData
        resolvedProject.duration = exportedVideo.duration
        resolvedProject.width = exportedVideo.width
        resolvedProject.height = exportedVideo.height
        resolvedProject.fileSize = exportedVideo.fileSize

        try modelContext.save()

        cleanupTransientMediaIfNeeded(originalVideoURL, protectedURL: persistedOriginalURL)
        cleanupTransientMediaIfNeeded(exportedVideo.url, protectedURL: persistedExportedURL)
        cleanupTransientAudioIfNeeded(
            originalConfiguration: editingConfiguration,
            persistedConfiguration: persistedEditingConfiguration
        )

        return resolvedProject
    }

    func deleteProject(_ project: EditedVideoProject) throws {
        fileManager.removeIfExists(for: EditedVideoProject.directoryURL(for: project.id))
        modelContext.delete(project)
        try modelContext.save()
    }

    // MARK: - Private Methods

    private func fetchProject(id: UUID?) throws -> EditedVideoProject? {
        guard let id else { return nil }

        let descriptor = FetchDescriptor<EditedVideoProject>(
            predicate: #Predicate<EditedVideoProject> { project in
                project.id == id
            }
        )

        return try modelContext.fetch(descriptor).first
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
        removePersistedRecordedAudioIfNeeded(in: projectDirectoryURL)

        guard var recordedClip = editingConfiguration.audio.recordedClip else {
            return persistedEditingConfiguration
        }

        let fileExtension = recordedClip.url.pathExtension.isEmpty ? "m4a" : recordedClip.url.pathExtension
        let destinationURL = projectDirectoryURL.appending(path: "recorded-audio.\(fileExtension)")

        recordedClip.url = try persistFile(from: recordedClip.url, to: destinationURL)
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
        fromExportedVideoAt url: URL
    ) async -> Data? {
        let asset = AVURLAsset(url: url)
        let duration = (try? await asset.load(.duration).seconds) ?? .zero
        let timestamp = Self.resolvedThumbnailTimestamp(for: duration)
        let image = await asset.generateImage(
            at: timestamp,
            maximumSize: CGSize(width: 720, height: 720)
        )

        return image?.jpegData(compressionQuality: 0.85)
    }

    static func resolvedThumbnailTimestamp(
        for duration: Double
    ) -> Double {
        guard duration.isFinite, duration >= 0 else { return 0 }
        return 0
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
