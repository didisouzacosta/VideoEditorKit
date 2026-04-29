import Foundation
import SwiftData
import VideoEditorKit

@MainActor
struct ProjectsRepository {

    struct PersistedEditingState {

        // MARK: - Public Properties

        let project: EditedVideoProject
        let editingConfiguration: VideoEditingConfiguration
        let thumbnailData: Data?

    }

    struct PersistedSavedVideo {

        // MARK: - Public Properties

        let project: EditedVideoProject
        let savedVideo: SavedVideo

    }

    enum StoreError: LocalizedError {
        case missingOriginalVideo

        var errorDescription: String? {
            switch self {
            case .missingOriginalVideo:
                ExampleStrings.missingStoredOriginalVideo
            }
        }
    }

    private struct PreparedProjectSave {

        // MARK: - Public Properties

        let project: EditedVideoProject
        let now: Date
        let persistedOriginalURL: URL
        let persistedEditingConfiguration: VideoEditingConfiguration

    }

    // MARK: - Private Properties

    private let modelContext: ModelContext
    private let mediaStore: ProjectMediaStore

    // MARK: - Initializer

    init(
        modelContext: ModelContext,
        mediaStore: ProjectMediaStore = .init()
    ) {
        self.modelContext = modelContext
        self.mediaStore = mediaStore
    }

    // MARK: - Public Methods

    func saveEditingState(
        projectID: UUID?,
        originalVideoURL: URL,
        editingConfiguration: VideoEditingConfiguration,
        thumbnailData: Data? = nil
    ) async throws -> PersistedEditingState {
        let preparedSave = try prepareProjectSave(
            projectID: projectID,
            originalVideoURL: originalVideoURL,
            editingConfiguration: editingConfiguration
        )
        let sourceVideoMetadata = await loadVideoMetadata(from: preparedSave.persistedOriginalURL)

        applyCommonProjectFields(
            preparedSave,
            displayName: originalVideoURL.deletingPathExtension().lastPathComponent
        )

        if let thumbnailData {
            preparedSave.project.thumbnailData = thumbnailData
        }

        if preparedSave.project.hasExportedVideo == false {
            applyVideoMetadata(sourceVideoMetadata, to: preparedSave.project)
        }

        try modelContext.save()

        return PersistedEditingState(
            project: preparedSave.project,
            editingConfiguration: preparedSave.persistedEditingConfiguration,
            thumbnailData: preparedSave.project.thumbnailData
        )
    }

    func saveEditedVideo(
        projectID: UUID?,
        savedVideo: SavedVideo
    ) async throws -> PersistedSavedVideo {
        let preparedSave = try prepareProjectSave(
            projectID: projectID,
            originalVideoURL: savedVideo.originalVideoURL,
            editingConfiguration: savedVideo.editingConfiguration
        )
        let projectDirectoryURL = try mediaStore.ensureProjectDirectory(for: preparedSave.project.id)
        let previousEditedURL =
            preparedSave.project.hasSavedEditedVideo
            ? preparedSave.project.savedEditedVideoURL
            : nil
        let persistedEditedURL = try mediaStore.persistEditedVideo(
            from: savedVideo.url,
            to: projectDirectoryURL
        )
        let persistedMetadata = ExportedVideo(
            persistedEditedURL,
            width: savedVideo.metadata.width,
            height: savedVideo.metadata.height,
            duration: savedVideo.metadata.duration,
            fileSize: savedVideo.metadata.fileSize
        )
        let thumbnailData: Data?

        if let savedThumbnailData = savedVideo.thumbnailData {
            thumbnailData = savedThumbnailData
        } else {
            thumbnailData = await ProjectMediaStore.makeFirstFrameThumbnailData(
                fromVideoAt: persistedEditedURL
            )
        }

        applyCommonProjectFields(
            preparedSave,
            displayName: savedVideo.originalVideoURL.deletingPathExtension().lastPathComponent
        )

        preparedSave.project.savedEditedVideoFileName = persistedEditedURL.lastPathComponent
        preparedSave.project.thumbnailData = thumbnailData ?? preparedSave.project.thumbnailData
        applyVideoMetadata(persistedMetadata, to: preparedSave.project)

        try modelContext.save()

        mediaStore.deleteStoredMediaIfNeeded(previousEditedURL)
        mediaStore.cleanupTransientMediaIfNeeded(
            savedVideo.originalVideoURL,
            protectedURL: preparedSave.persistedOriginalURL
        )
        mediaStore.cleanupTransientMediaIfNeeded(
            savedVideo.url,
            protectedURL: persistedEditedURL
        )
        mediaStore.cleanupTransientAudioIfNeeded(
            originalConfiguration: savedVideo.editingConfiguration,
            persistedConfiguration: preparedSave.persistedEditingConfiguration
        )

        return PersistedSavedVideo(
            project: preparedSave.project,
            savedVideo: .init(
                persistedEditedURL,
                originalVideoURL: preparedSave.persistedOriginalURL,
                editingConfiguration: preparedSave.persistedEditingConfiguration,
                thumbnailData: preparedSave.project.thumbnailData,
                metadata: persistedMetadata
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
        let projectDirectoryURL = try mediaStore.ensureProjectDirectory(for: preparedSave.project.id)
        let previousExportedURL =
            preparedSave.project.hasExportedVideo
            ? preparedSave.project.exportedVideoURL
            : nil
        let persistedExportedURL = try mediaStore.persistExportedVideo(
            from: exportedVideo.url,
            to: projectDirectoryURL
        )
        let thumbnailData = await ProjectMediaStore.makeThumbnailData(
            fromExportedVideoAt: persistedExportedURL,
            editingConfiguration: preparedSave.persistedEditingConfiguration
        )

        applyCommonProjectFields(
            preparedSave,
            displayName: originalVideoURL.deletingPathExtension().lastPathComponent
        )

        preparedSave.project.exportedVideoFileName = persistedExportedURL.lastPathComponent
        preparedSave.project.thumbnailData = thumbnailData ?? preparedSave.project.thumbnailData
        applyVideoMetadata(exportedVideo, to: preparedSave.project)

        try modelContext.save()

        mediaStore.deleteStoredMediaIfNeeded(previousExportedURL)
        mediaStore.cleanupTransientMediaIfNeeded(
            originalVideoURL,
            protectedURL: preparedSave.persistedOriginalURL
        )
        mediaStore.cleanupTransientMediaIfNeeded(
            exportedVideo.url,
            protectedURL: persistedExportedURL
        )
        mediaStore.cleanupTransientAudioIfNeeded(
            originalConfiguration: editingConfiguration,
            persistedConfiguration: preparedSave.persistedEditingConfiguration
        )

        return preparedSave.project
    }

    func deleteProject(_ project: EditedVideoProject) throws {
        mediaStore.deleteProjectDirectory(for: project.id)
        modelContext.delete(project)
        try modelContext.save()
    }

    static func resolvedThumbnailTimestamp(
        for duration: Double,
        editingConfiguration: VideoEditingConfiguration
    ) -> Double {
        ProjectMediaStore.resolvedThumbnailTimestamp(
            for: duration,
            editingConfiguration: editingConfiguration
        )
    }

    // MARK: - Private Methods

    private func prepareProjectSave(
        projectID: UUID?,
        originalVideoURL: URL,
        editingConfiguration: VideoEditingConfiguration
    ) throws -> PreparedProjectSave {
        guard FileManager.default.fileExists(atPath: originalVideoURL.path()) else {
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
                savedEditedVideoFileName: "",
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

        let projectDirectoryURL = try mediaStore.ensureProjectDirectory(for: resolvedProject.id)
        let persistedOriginalURL = try mediaStore.persistOriginalVideo(
            from: originalVideoURL,
            to: projectDirectoryURL
        )
        let sanitizedEditingConfiguration = sanitizedEditingConfiguration(
            editingConfiguration
        )
        let persistedEditingConfiguration = try mediaStore.persistRecordedAudioIfNeeded(
            sanitizedEditingConfiguration,
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
            (try? JSONEncoder().encode(preparedSave.persistedEditingConfiguration)) ?? Data()
    }

    private func sanitizedEditingConfiguration(
        _ editingConfiguration: VideoEditingConfiguration
    ) -> VideoEditingConfiguration {
        var sanitizedEditingConfiguration = editingConfiguration
        sanitizedEditingConfiguration.playback.currentTimelineTime = nil
        return sanitizedEditingConfiguration
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

}
