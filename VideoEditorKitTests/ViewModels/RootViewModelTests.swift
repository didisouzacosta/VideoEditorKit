import CoreGraphics
import Foundation
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("RootViewModelTests")
struct RootViewModelTests {

    // MARK: - Public Methods

    @Test
    func handleViewDisappearStopsTheLoadingState() {
        let viewModel = RootViewModel()
        viewModel.isLoading = true

        viewModel.handleViewDisappear()

        #expect(viewModel.isLoading == false)
    }

    @Test
    func startEditorSessionPublishesTheSessionForTheEditor() throws {
        let viewModel = RootViewModel()
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 2, upperBound: 8),
            playback: .init(rate: 1.4, videoVolume: 0.7, currentTimelineTime: 5)
        )
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let projectID = UUID()

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        viewModel.startEditorSession(
            with: sourceURL,
            projectID: projectID,
            editingConfiguration: editingConfiguration
        )

        #expect(viewModel.currentProjectID == projectID)
        #expect(viewModel.currentSourceVideoURL == sourceURL)
        #expect(
            viewModel.editorDestination?.session
                == .init(
                    sourceVideoURL: sourceURL,
                    editingConfiguration: editingConfiguration
                )
        )
    }

    @Test
    func handlePersistedProjectSaveReplacesTheCurrentEditingContext() throws {
        let viewModel = RootViewModel()
        let temporarySourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let persistedOriginalURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let projectID = UUID()

        defer { FileManager.default.removeIfExists(for: temporarySourceURL) }
        defer { FileManager.default.removeIfExists(for: persistedOriginalURL) }

        viewModel.startEditorSession(with: temporarySourceURL)
        viewModel.handlePersistedProjectSave(
            projectID: projectID,
            originalVideoURL: persistedOriginalURL
        )

        #expect(viewModel.currentProjectID == projectID)
        #expect(viewModel.currentSourceVideoURL == persistedOriginalURL)
    }

    @Test
    func handleEditorDismissClearsThePickerSelectionWithoutDroppingTheCurrentSession() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let projectID = UUID()

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        viewModel.isLoading = true
        viewModel.startEditorSession(with: sourceURL, projectID: projectID)
        viewModel.handleEditorDismiss()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.currentProjectID == projectID)
        #expect(viewModel.currentSourceVideoURL == sourceURL)
    }

    @Test
    func exportedVideoLoadCollectsMetadataNeededByTheHostPreview() async throws {
        let url = try await TestFixtures.createTemporaryVideo(size: CGSize(width: 48, height: 24))

        defer { FileManager.default.removeIfExists(for: url) }

        let exportedVideo = await ExportedVideo.load(from: url)

        #expect(exportedVideo.url == url)
        #expect(abs(exportedVideo.width - 48) < 0.0001)
        #expect(abs(exportedVideo.height - 24) < 0.0001)
        #expect(abs(exportedVideo.aspectRatio - 2) < 0.0001)
        #expect(abs(exportedVideo.duration - 1) < 0.05)
        #expect(exportedVideo.fileSize > 0)
    }

}
