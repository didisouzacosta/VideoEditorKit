import SwiftData
import Testing
import UIKit

@testable import VideoEditorKit

@MainActor
@Suite("EditedVideoProjectsStoreTests")
struct EditedVideoProjectsStoreTests {

    // MARK: - Public Methods

    @Test
    func saveProjectPersistsOriginalAndExportedVideosPlusEditingConfiguration() async throws {
        let container = try makeContainer()
        let store = EditedVideoProjectsStore(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let exportedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemGreen)
        let exportedVideo = await ExportedVideo.load(from: exportedVideoURL)
        let audioURL = try TestFixtures.createTemporaryAudio()
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 4),
            audio: .init(
                recordedClip: .init(
                    url: audioURL,
                    duration: 0.5,
                    volume: 0.7
                ),
                selectedTrack: .recorded
            ),
            presentation: .init(.audio)
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }
        defer { FileManager.default.removeIfExists(for: audioURL) }

        let project = try await store.saveProject(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            exportedVideo: exportedVideo,
            editingConfiguration: editingConfiguration
        )

        #expect(project.hasOriginalVideo)
        #expect(project.hasExportedVideo)
        #expect(project.thumbnailData != nil)
        #expect(project.duration > 0)
        #expect(project.originalVideoURL.lastPathComponent.hasPrefix("original."))
        #expect(project.exportedVideoURL.lastPathComponent.hasPrefix("exported."))
        #expect(project.editingConfiguration?.trim == editingConfiguration.trim)
        #expect(project.editingConfiguration?.audio.selectedTrack == .recorded)
        #expect(
            project.editingConfiguration?.audio.recordedClip?.url.lastPathComponent.hasPrefix(
                "recorded-audio."
            ) == true
        )
    }

    @Test
    func saveProjectUpdatesTheExistingRecordInsteadOfCreatingANewOne() async throws {
        let container = try makeContainer()
        let store = EditedVideoProjectsStore(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let firstExportURL = try await TestFixtures.createTemporaryVideo(color: .systemGreen)
        let secondExportURL = try await TestFixtures.createTemporaryVideo(color: .systemOrange)
        let firstExportedVideo = await ExportedVideo.load(from: firstExportURL)
        let secondExportedVideo = await ExportedVideo.load(from: secondExportURL)

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: firstExportURL) }
        defer { FileManager.default.removeIfExists(for: secondExportURL) }

        let firstProject = try await store.saveProject(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            exportedVideo: firstExportedVideo,
            editingConfiguration: .initial
        )
        let updatedTrim = VideoEditingConfiguration(
            trim: .init(lowerBound: 2, upperBound: 6)
        )

        let updatedProject = try await store.saveProject(
            projectID: firstProject.id,
            originalVideoURL: firstProject.originalVideoURL,
            exportedVideo: secondExportedVideo,
            editingConfiguration: updatedTrim
        )
        let projects = try container.mainContext.fetch(FetchDescriptor<EditedVideoProject>())

        #expect(updatedProject.id == firstProject.id)
        #expect(projects.count == 1)
        #expect(updatedProject.editingConfiguration?.trim == updatedTrim.trim)
        #expect(updatedProject.fileSize == secondExportedVideo.fileSize)
    }

    @Test
    func deleteProjectRemovesTheStoredFilesAndTheSwiftDataRecord() async throws {
        let container = try makeContainer()
        let store = EditedVideoProjectsStore(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let exportedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemGreen)
        let exportedVideo = await ExportedVideo.load(from: exportedVideoURL)

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        let project = try await store.saveProject(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            exportedVideo: exportedVideo,
            editingConfiguration: .initial
        )
        let directoryURL = EditedVideoProject.directoryURL(for: project.id)

        try store.deleteProject(project)

        let remainingProjects = try container.mainContext.fetch(FetchDescriptor<EditedVideoProject>())

        #expect(remainingProjects.isEmpty)
        #expect(FileManager.default.fileExists(atPath: directoryURL.path()) == false)
    }

    // MARK: - Private Methods

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: EditedVideoProject.self,
            configurations: configuration
        )
    }

}
