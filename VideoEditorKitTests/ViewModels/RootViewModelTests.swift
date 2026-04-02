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
            viewModel.latestEditorSaveState
                == .init(editingConfiguration: editingConfiguration)
        )
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
    func handlePersistedEditingStateSaveUpdatesTheCurrentContextAndLatestSaveState() throws {
        let viewModel = RootViewModel()
        let persistedOriginalURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let projectID = UUID()
        let saveState = VideoEditorView.SaveState(
            editingConfiguration: .init(
                trim: .init(lowerBound: 1, upperBound: 4)
            ),
            thumbnailData: Data([0x0A, 0x0B])
        )

        defer { FileManager.default.removeIfExists(for: persistedOriginalURL) }

        viewModel.handlePersistedEditingStateSave(
            projectID: projectID,
            originalVideoURL: persistedOriginalURL,
            saveState: saveState
        )

        #expect(viewModel.currentProjectID == projectID)
        #expect(viewModel.currentSourceVideoURL == persistedOriginalURL)
        #expect(viewModel.latestEditorSaveState == saveState)
    }

    @Test
    func handleEditorSaveStateChangeStoresTheLatestPayloadFromTheEditor() {
        let viewModel = RootViewModel()
        let saveState = VideoEditorView.SaveState(
            editingConfiguration: .init(
                trim: .init(lowerBound: 1, upperBound: 4)
            ),
            thumbnailData: Data([0x01, 0x02, 0x03])
        )

        let shouldPersist = viewModel.handleEditorSaveStateChange(saveState)

        #expect(viewModel.latestEditorSaveState == saveState)
        #expect(shouldPersist)
    }

    @Test
    func handleEditorSaveStateChangeSkipsTransientOnlyChanges() {
        let viewModel = RootViewModel()
        let baseConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 4),
            playback: .init(
                rate: 1.25,
                videoVolume: 0.8,
                currentTimelineTime: 6
            ),
            audio: .init(
                recordedClip: .init(
                    url: URL(fileURLWithPath: "/tmp/test-audio.m4a"),
                    duration: 2,
                    volume: 0.6
                ),
                selectedTrack: .recorded
            ),
            presentation: .init(
                .adjusts,
                socialVideoDestination: .tikTok,
                showsSafeAreaGuides: true
            )
        )
        let transientOnlyChange = VideoEditingConfiguration(
            trim: baseConfiguration.trim,
            playback: .init(
                rate: 1.25,
                videoVolume: 0.8,
                currentTimelineTime: 12
            ),
            crop: baseConfiguration.crop,
            canvas: .init(
                snapshot: .init(
                    preset: .original,
                    freeCanvasSize: CGSize(width: 1080, height: 1080),
                    transform: .identity,
                    showsSafeAreaOverlay: false
                )
            ),
            adjusts: baseConfiguration.adjusts,
            frame: baseConfiguration.frame,
            audio: .init(
                recordedClip: baseConfiguration.audio.recordedClip,
                selectedTrack: .video
            ),
            presentation: .init(
                nil,
                socialVideoDestination: .tikTok,
                showsSafeAreaGuides: false
            )
        )

        let firstShouldPersist = viewModel.handleEditorSaveStateChange(
            .init(editingConfiguration: baseConfiguration)
        )
        let secondShouldPersist = viewModel.handleEditorSaveStateChange(
            .init(editingConfiguration: transientOnlyChange)
        )

        #expect(firstShouldPersist)
        #expect(secondShouldPersist == false)
        #expect(
            viewModel.latestEditorSaveState?.editingConfiguration == transientOnlyChange
        )
    }

    @Test
    func handlePersistedEditingStateSavePreventsReSavingTheSameFingerprint() throws {
        let viewModel = RootViewModel()
        let persistedOriginalURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let saveState = VideoEditorView.SaveState(
            editingConfiguration: .init(
                trim: .init(lowerBound: 1, upperBound: 4)
            )
        )

        defer { FileManager.default.removeIfExists(for: persistedOriginalURL) }

        #expect(viewModel.handleEditorSaveStateChange(saveState))

        viewModel.handlePersistedEditingStateSave(
            projectID: UUID(),
            originalVideoURL: persistedOriginalURL,
            saveState: saveState
        )

        #expect(viewModel.handleEditorSaveStateChange(saveState) == false)
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
    func exportedVideoShareIsPresentedWhileTheEditorRemainsActive() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let persistedOriginalURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let projectID = UUID()

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: persistedOriginalURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        viewModel.startEditorSession(with: sourceURL)
        viewModel.handlePersistedExportedVideo(
            projectID: projectID,
            originalVideoURL: persistedOriginalURL,
            exportedVideoURL: exportedVideoURL
        )

        #expect(viewModel.currentProjectID == projectID)
        #expect(viewModel.currentSourceVideoURL == persistedOriginalURL)
        #expect(viewModel.editorDestination != nil)
        #expect(viewModel.shareDestination == .init(videoURL: exportedVideoURL))
    }

    @Test
    func exportedVideoShareIsPresentedImmediatelyWhenTheShellIsVisible() throws {
        let viewModel = RootViewModel()
        let persistedOriginalURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let projectID = UUID()

        defer { FileManager.default.removeIfExists(for: persistedOriginalURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        viewModel.handlePersistedExportedVideo(
            projectID: projectID,
            originalVideoURL: persistedOriginalURL,
            exportedVideoURL: exportedVideoURL
        )

        #expect(viewModel.currentProjectID == projectID)
        #expect(viewModel.currentSourceVideoURL == persistedOriginalURL)
        #expect(viewModel.shareDestination == .init(videoURL: exportedVideoURL))
    }

    @Test
    func dismissShareDestinationClearsThePresentedShareSheet() throws {
        let viewModel = RootViewModel()
        let persistedOriginalURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: persistedOriginalURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        viewModel.handlePersistedExportedVideo(
            projectID: UUID(),
            originalVideoURL: persistedOriginalURL,
            exportedVideoURL: exportedVideoURL
        )
        #expect(viewModel.shareDestination == .init(videoURL: exportedVideoURL))

        viewModel.dismissShareDestination()

        #expect(viewModel.shareDestination == nil)
    }

    @Test
    func handleEditorDismissClearsAnyPresentedShareDestination() throws {
        let viewModel = RootViewModel()
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let persistedOriginalURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: persistedOriginalURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        viewModel.startEditorSession(with: sourceURL)
        viewModel.handlePersistedExportedVideo(
            projectID: UUID(),
            originalVideoURL: persistedOriginalURL,
            exportedVideoURL: exportedVideoURL
        )
        #expect(viewModel.shareDestination == .init(videoURL: exportedVideoURL))

        viewModel.handleEditorDismiss()

        #expect(viewModel.editorDestination == nil)
        #expect(viewModel.shareDestination == nil)
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
