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
        let previousURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let newURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let previousVideo = ExportedVideo(previousURL, width: 1920, height: 1080, fileSize: 128)
        let newVideo = ExportedVideo(newURL, width: 1080, height: 1920, fileSize: 256)

        defer { FileManager.default.removeIfExists(for: previousURL) }
        defer { FileManager.default.removeIfExists(for: newURL) }

        viewModel.editedVideo = previousVideo

        viewModel.handleExportedVideo(newVideo)

        let currentAssetURL = (viewModel.resultPlayer.currentItem?.asset as? AVURLAsset)?.url

        #expect(viewModel.editedVideo == newVideo)
        #expect(FileManager.default.fileExists(atPath: previousURL.path()) == false)
        #expect(currentAssetURL == newURL)
        #expect(viewModel.shouldShowVideoPicker == false)
        #expect(abs(viewModel.editedVideoAspectRatio - 0.5625) < 0.0001)
    }

    @Test
    func clearEditedVideoDeletesTheCurrentOutputAndRestoresThePicker() throws {
        let viewModel = RootViewModel()
        let url = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedVideo = ExportedVideo(url, width: 1920, height: 1080, fileSize: 128)

        defer { FileManager.default.removeIfExists(for: url) }

        viewModel.handleExportedVideo(exportedVideo)
        viewModel.clearEditedVideo()

        #expect(viewModel.editedVideo == nil)
        #expect(viewModel.resultPlayer.currentItem == nil)
        #expect(FileManager.default.fileExists(atPath: url.path()) == false)
        #expect(viewModel.shouldShowVideoPicker)
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
