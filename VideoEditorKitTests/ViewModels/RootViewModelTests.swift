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
        #expect(viewModel.latestExportedEditingConfiguration == editingConfiguration)
        #expect(FileManager.default.fileExists(atPath: previousURL.path()) == false)
        #expect(currentAssetURL == newURL)
        #expect(viewModel.shouldShowVideoPicker == false)
        #expect(abs(viewModel.editedVideoAspectRatio - 0.5625) < 0.0001)
        #expect(viewModel.canReopenEditor)
        #expect(viewModel.hasUnrenderedChanges == false)
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
        #expect(viewModel.latestExportedEditingConfiguration == nil)
        #expect(FileManager.default.fileExists(atPath: url.path()) == false)
        #expect(viewModel.shouldShowVideoPicker)
        #expect(viewModel.canReopenEditor == false)
        #expect(viewModel.hasUnrenderedChanges == false)
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

        #expect(viewModel.editorDestination?.session.sourceVideoURL == sourceURL)
        #expect(viewModel.editorDestination?.session.editingConfiguration == editingConfiguration)
    }

    @Test
    func handleEditorDismissPersistsTheLatestEditingConfigurationWithoutClearingTheOutput() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedVideo = ExportedVideo(exportedURL, width: 1920, height: 1080, fileSize: 128)
        let exportedConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 2, upperBound: 8)
        )
        let dismissedConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 4, upperBound: 10),
            playback: .init(rate: 1.5, videoVolume: 0.9, currentTimelineTime: 6)
        )

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: exportedURL) }

        viewModel.startEditorSession(with: sourceURL)
        viewModel.handleExportedVideo(
            exportedVideo,
            editingConfiguration: exportedConfiguration
        )

        viewModel.handleEditorDismiss(editingConfiguration: dismissedConfiguration)

        #expect(viewModel.latestEditingConfiguration == dismissedConfiguration)
        #expect(viewModel.latestExportedEditingConfiguration == exportedConfiguration)
        #expect(viewModel.editedVideo == exportedVideo)
        #expect(viewModel.hasUnrenderedChanges)
    }

    @Test
    func handleEditorDismissWithNilKeepsTheExistingEditingConfiguration() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedVideo = ExportedVideo(exportedURL, width: 1920, height: 1080, fileSize: 128)
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 7)
        )

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: exportedURL) }

        viewModel.startEditorSession(with: sourceURL)
        viewModel.handleExportedVideo(
            exportedVideo,
            editingConfiguration: editingConfiguration
        )

        viewModel.handleEditorDismiss(editingConfiguration: nil)

        #expect(viewModel.latestEditingConfiguration == editingConfiguration)
        #expect(viewModel.latestExportedEditingConfiguration == editingConfiguration)
        #expect(viewModel.editedVideo == exportedVideo)
        #expect(viewModel.hasUnrenderedChanges == false)
    }

    @Test
    func handleEditingConfigurationChangedStoresTheLatestDraftWithoutTouchingTheOutput() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedVideo = ExportedVideo(exportedURL, width: 1920, height: 1080, fileSize: 128)
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 3, upperBound: 9),
            playback: .init(rate: 1.25, videoVolume: 0.85, currentTimelineTime: 5)
        )

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: exportedURL) }

        viewModel.startEditorSession(with: sourceURL)
        viewModel.handleExportedVideo(
            exportedVideo,
            editingConfiguration: .initial
        )

        viewModel.handleEditingConfigurationChanged(editingConfiguration)

        #expect(viewModel.latestEditingConfiguration == editingConfiguration)
        #expect(viewModel.latestExportedEditingConfiguration == .initial)
        #expect(viewModel.editedVideo == exportedVideo)
        #expect(viewModel.hasUnrenderedChanges)
    }

    @Test
    func handleExportedVideoRefreshesTheRenderedBaselineAfterDraftChanges() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let firstExportURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let refreshedExportURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let firstExport = ExportedVideo(firstExportURL, width: 1920, height: 1080, fileSize: 128)
        let refreshedExport = ExportedVideo(
            refreshedExportURL,
            width: 1920,
            height: 1080,
            fileSize: 256
        )
        let initialConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 7)
        )
        let updatedDraft = VideoEditingConfiguration(
            trim: .init(lowerBound: 3, upperBound: 9),
            playback: .init(rate: 1.4, videoVolume: 0.9, currentTimelineTime: 6)
        )

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: firstExportURL) }
        defer { FileManager.default.removeIfExists(for: refreshedExportURL) }

        viewModel.startEditorSession(with: sourceURL)
        viewModel.handleExportedVideo(
            firstExport,
            editingConfiguration: initialConfiguration
        )
        viewModel.handleEditingConfigurationChanged(updatedDraft)

        #expect(viewModel.hasUnrenderedChanges)

        viewModel.handleExportedVideo(
            refreshedExport,
            editingConfiguration: updatedDraft
        )

        #expect(viewModel.latestEditingConfiguration == updatedDraft)
        #expect(viewModel.latestExportedEditingConfiguration == updatedDraft)
        #expect(viewModel.editedVideo == refreshedExport)
        #expect(viewModel.hasUnrenderedChanges == false)
    }

    @Test
    func fullResumeFlowKeepsDraftReopenSeparateFromTheRenderedPreviewBaseline() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let firstExportURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let refreshedExportURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let firstExport = ExportedVideo(firstExportURL, width: 1920, height: 1080, fileSize: 128)
        let refreshedExport = ExportedVideo(
            refreshedExportURL,
            width: 1280,
            height: 720,
            fileSize: 256
        )
        let exportedConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 2, upperBound: 8),
            playback: .init(rate: 1.0, videoVolume: 1.0, currentTimelineTime: 4)
        )
        let resumedDraft = VideoEditingConfiguration(
            trim: .init(lowerBound: 4, upperBound: 10),
            playback: .init(rate: 1.35, videoVolume: 0.8, currentTimelineTime: 7),
            presentation: .init(selectedTool: .speed, cropTab: .rotate)
        )

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: firstExportURL) }
        defer { FileManager.default.removeIfExists(for: refreshedExportURL) }

        viewModel.startEditorSession(with: sourceURL)
        #expect(viewModel.editorDestination?.session == .init(sourceVideoURL: sourceURL))

        viewModel.handleExportedVideo(
            firstExport,
            editingConfiguration: exportedConfiguration
        )
        #expect(viewModel.hasUnrenderedChanges == false)

        viewModel.handleEditingConfigurationChanged(resumedDraft)
        #expect(viewModel.hasUnrenderedChanges)

        viewModel.reopenEditor()

        #expect(
            viewModel.editorDestination?.session
                == .init(
                    sourceVideoURL: sourceURL,
                    editingConfiguration: resumedDraft
                )
        )
        #expect(viewModel.editedVideo == firstExport)
        #expect(viewModel.latestExportedEditingConfiguration == exportedConfiguration)

        viewModel.handleExportedVideo(
            refreshedExport,
            editingConfiguration: resumedDraft
        )

        #expect(viewModel.editedVideo == refreshedExport)
        #expect(viewModel.latestEditingConfiguration == resumedDraft)
        #expect(viewModel.latestExportedEditingConfiguration == resumedDraft)
        #expect(viewModel.hasUnrenderedChanges == false)
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
