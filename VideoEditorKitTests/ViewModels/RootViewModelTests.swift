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

        defer { FileManager.default.removeIfExists(for: previousURL) }
        defer { FileManager.default.removeIfExists(for: newURL) }

        viewModel.editedVideoURL = previousURL

        viewModel.handleExportedVideo(newURL)

        let currentAssetURL = (viewModel.resultPlayer.currentItem?.asset as? AVURLAsset)?.url

        #expect(viewModel.editedVideoURL == newURL)
        #expect(FileManager.default.fileExists(atPath: previousURL.path()) == false)
        #expect(currentAssetURL == newURL)
    }

}
