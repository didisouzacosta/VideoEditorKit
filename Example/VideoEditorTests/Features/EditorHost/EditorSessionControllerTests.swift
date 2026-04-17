import CoreGraphics
import Foundation
import Testing
import VideoEditorKit

@testable import VideoEditor

@MainActor
@Suite("EditorSessionControllerTests")
struct EditorSessionControllerTests {

    // MARK: - Public Methods

    @Test
    func importedDraftStartsWithoutAResolvedSourceVideoURL() {
        let importedSource = VideoEditorSessionSource.importedFile(
            .init(taskIdentifier: "editor-session-controller-test") {
                URL(fileURLWithPath: "/tmp/editor-session-controller.mp4")
            }
        )
        let controller = EditorSessionController(
            .imported(importedSource)
        )

        #expect(controller.currentSourceVideoURL == nil)
        #expect(controller.session == .init(source: importedSource))
    }

    @Test
    func projectDraftSeedsTheCurrentEditingContext() throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 2, upperBound: 8),
            playback: .init(rate: 1.4, videoVolume: 0.7, currentTimelineTime: 5)
        )
        var expectedEditingConfiguration = editingConfiguration
        expectedEditingConfiguration.playback.currentTimelineTime = nil
        let project = makeProject(
            originalVideoFileName: sourceURL.lastPathComponent,
            editingConfiguration: editingConfiguration
        )
        let controller = EditorSessionController(.project(project))

        #expect(controller.currentProjectID == project.id)
        #expect(controller.currentSourceVideoURL == project.originalVideoURL)
        #expect(
            controller.latestSaveState
                == .init(editingConfiguration: expectedEditingConfiguration)
        )
        #expect(
            controller.session
                == .init(
                    sourceVideoURL: project.originalVideoURL,
                    editingConfiguration: expectedEditingConfiguration
                )
        )
    }

    @Test
    func registerSaveStateChangeStoresTheLatestPayloadAndRequestsPersistence() {
        let controller = EditorSessionController(
            .imported(.fileURL(URL(fileURLWithPath: "/tmp/controller.mp4")))
        )
        let saveState = VideoEditorView.SaveState(
            editingConfiguration: .init(
                trim: .init(lowerBound: 1, upperBound: 4)
            ),
            thumbnailData: Data([0x01, 0x02, 0x03])
        )

        let shouldPersist = controller.registerSaveStateChange(saveState)

        #expect(controller.latestSaveState == saveState)
        #expect(shouldPersist)
    }

    @Test
    func registerSaveStateChangeSkipsTransientOnlyChanges() {
        let controller = EditorSessionController(
            .imported(.fileURL(URL(fileURLWithPath: "/tmp/controller.mp4")))
        )
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

        let firstShouldPersist = controller.registerSaveStateChange(
            .init(editingConfiguration: baseConfiguration)
        )
        let secondShouldPersist = controller.registerSaveStateChange(
            .init(editingConfiguration: transientOnlyChange)
        )

        #expect(firstShouldPersist)
        #expect(secondShouldPersist == false)
        #expect(controller.latestSaveState?.editingConfiguration == transientOnlyChange)
    }

    @Test
    func handlePersistedEditingStateSaveUpdatesTheCurrentContext() throws {
        let persistedOriginalURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let project = makeProject(
            originalVideoFileName: persistedOriginalURL.lastPathComponent
        )
        let saveState = VideoEditorView.SaveState(
            editingConfiguration: .init(
                trim: .init(lowerBound: 1, upperBound: 4)
            ),
            thumbnailData: Data([0x0A, 0x0B])
        )
        let controller = EditorSessionController(
            .imported(.fileURL(URL(fileURLWithPath: "/tmp/controller.mp4")))
        )

        controller.handlePersistedEditingStateSave(
            .init(project: project, saveState: saveState)
        )

        #expect(controller.currentProjectID == project.id)
        #expect(controller.currentSourceVideoURL == project.originalVideoURL)
        #expect(controller.latestSaveState == saveState)
        #expect(controller.registerSaveStateChange(saveState) == false)
    }

    @Test
    func handlePersistedExportUpdatesTheCurrentContextAndPresentsShare() throws {
        let originalURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let exportedURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let project = makeProject(
            originalVideoFileName: originalURL.lastPathComponent,
            exportedVideoFileName: exportedURL.lastPathComponent
        )
        let controller = EditorSessionController(
            .imported(.fileURL(URL(fileURLWithPath: "/tmp/controller.mp4")))
        )

        controller.handlePersistedExport(project: project)

        #expect(controller.currentProjectID == project.id)
        #expect(controller.currentSourceVideoURL == project.originalVideoURL)
        #expect(controller.shareDestination == .init(videoURL: project.exportedVideoURL))

        controller.dismissShareDestination()
        #expect(controller.shareDestination == nil)

        controller.handlePersistedExport(project: project)
        controller.dismissShareDestination()
        #expect(controller.shareDestination == nil)
    }

    // MARK: - Private Methods

    private func makeProject(
        originalVideoFileName: String = "original.mp4",
        exportedVideoFileName: String = "",
        editingConfiguration: VideoEditingConfiguration? = nil
    ) -> EditedVideoProject {
        let configurationData =
            (try? JSONEncoder().encode(editingConfiguration ?? .initial)) ?? Data()

        return EditedVideoProject(
            createdAt: .now,
            updatedAt: .now,
            displayName: "Project",
            originalVideoFileName: originalVideoFileName,
            exportedVideoFileName: exportedVideoFileName,
            editingConfigurationData: configurationData,
            thumbnailData: nil,
            duration: 0,
            width: 0,
            height: 0,
            fileSize: 0
        )
    }

}
