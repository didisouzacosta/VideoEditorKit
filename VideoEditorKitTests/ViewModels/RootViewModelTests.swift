import AVFoundation
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("RootViewModelTests")
struct RootViewModelTests {

    // MARK: - Public Methods

    @Test
    func loadSelectedItemWithNilStopsTheLoadingState() {
        let viewModel = RootViewModel()
        viewModel.isLoading = true

        viewModel.loadSelectedItem(nil)

        #expect(viewModel.isLoading == false)
    }

    @Test
    func handleExportedVideoReplacesThePlayerItemAndDeletesThePreviousOutput() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let previousURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let newURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let previousVideo = ExportedVideo(previousURL, width: 1920, height: 1080, fileSize: 128)
        let newVideo = ExportedVideo(newURL, width: 1080, height: 1920, fileSize: 256)
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 2, upperBound: 8)
        )

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: previousURL) }
        defer { FileManager.default.removeIfExists(for: newURL) }

        viewModel.startEditorSession(with: sourceURL)
        viewModel.editedVideo = previousVideo

        viewModel.handleExportedVideo(
            newVideo,
            editingConfiguration: editingConfiguration
        )

        let currentAssetURL = (viewModel.resultPlayer.currentItem?.asset as? AVURLAsset)?.url

        #expect(viewModel.editedVideo == newVideo)
        #expect(viewModel.latestEditingConfiguration == editingConfiguration)
        #expect(FileManager.default.fileExists(atPath: previousURL.path()) == false)
        #expect(currentAssetURL == newURL)
        #expect(viewModel.shouldShowVideoPicker == false)
        #expect(abs(viewModel.editedVideoAspectRatio - 0.5625) < 0.0001)
        #expect(viewModel.canReopenEditor)
    }

    @Test
    func clearEditedVideoDeletesTheCurrentOutputAndRestoresThePicker() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let url = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedVideo = ExportedVideo(url, width: 1920, height: 1080, fileSize: 128)

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: url) }

        viewModel.startEditorSession(with: sourceURL)
        viewModel.handleExportedVideo(
            exportedVideo,
            editingConfiguration: .initial
        )
        viewModel.clearEditedVideo()

        #expect(viewModel.editedVideo == nil)
        #expect(viewModel.resultPlayer.currentItem == nil)
        #expect(viewModel.latestEditingConfiguration == nil)
        #expect(FileManager.default.fileExists(atPath: url.path()) == false)
        #expect(viewModel.shouldShowVideoPicker)
        #expect(viewModel.canReopenEditor == false)
    }

    @Test
    func reopenEditorUsesTheOriginalSourceAndLatestEditingConfiguration() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedVideo = ExportedVideo(exportedURL, width: 1920, height: 1080, fileSize: 128)
        let editingConfiguration = VideoEditingConfiguration(
            playback: .init(rate: 1.5, videoVolume: 0.8, currentTimelineTime: 7),
            presentation: .init(selectedTool: .speed, cropTab: .rotate)
        )

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: exportedURL) }

        viewModel.startEditorSession(with: sourceURL)
        viewModel.handleExportedVideo(
            exportedVideo,
            editingConfiguration: editingConfiguration
        )
        viewModel.editorDestination = nil

        viewModel.reopenEditor()

        #expect(viewModel.editorDestination?.url == sourceURL)
        #expect(viewModel.editorDestination?.editingConfiguration == editingConfiguration)
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
        #expect(exportedVideo.fileSize > 0)
    }

}
