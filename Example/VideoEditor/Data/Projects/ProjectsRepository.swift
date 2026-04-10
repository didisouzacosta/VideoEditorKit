import Foundation
import SwiftData
import VideoEditorKit

@MainActor
struct ProjectsRepository {

    struct PersistedEditingState {

        // MARK: - Public Properties

        let project: EditedVideoProject
        let saveState: VideoEditorView.SaveState

    }

    enum StoreError: LocalizedError {
        case missingOriginalVideo

        var errorDescription: String? {
            switch self {
            case .missingOriginalVideo:
                "The original video could not be found for this project."
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

    // MARK: - Public Properties

    let modelContext: ModelContext

    // MARK: - Private Properties

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
            applyVideoMetadata(sourceVideoMetadata, to: preparedSave.project)
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
        let projectDirectoryURL = try mediaStore.ensureProjectDirectory(for: preparedSave.project.id)
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
        let persistedEditingConfiguration = try mediaStore.persistRecordedAudioIfNeeded(
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
            (try? JSONEncoder().encode(preparedSave.persistedEditingConfiguration)) ?? Data()
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
