import SwiftData
import SwiftUI
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("EditedVideoProjectsStoreTests")
struct EditedVideoProjectsStoreTests {

    // MARK: - Public Methods

    @Test
    func saveEditingStatePersistsOriginalVideoAndEditingConfigurationBeforeExport() async throws {
        let container = try makeContainer()
        let store = EditedVideoProjectsStore(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let audioURL = try TestFixtures.createTemporaryAudio()
        let saveState = VideoEditorView.SaveState(
            editingConfiguration: VideoEditingConfiguration(
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
            ),
            thumbnailData: Data([0x01, 0x02, 0x03])
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: audioURL) }

        let persistedState = try await store.saveEditingState(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            saveState: saveState
        )
        let project = persistedState.project

        #expect(project.hasOriginalVideo)
        #expect(project.hasExportedVideo == false)
        #expect(project.originalVideoURL.lastPathComponent.hasPrefix("original."))
        #expect(project.thumbnailData == saveState.thumbnailData)
        #expect(project.duration > 0)
        #expect(project.fileSize > 0)
        #expect(project.editingConfiguration?.trim == saveState.editingConfiguration.trim)
        #expect(project.editingConfiguration?.audio.selectedTrack == .recorded)
        #expect(
            project.editingConfiguration?.audio.recordedClip?.url.lastPathComponent.hasPrefix(
                "recorded-audio."
            ) == true
        )
        #expect(
            persistedState.saveState.editingConfiguration.audio.recordedClip?.url.lastPathComponent.hasPrefix(
                "recorded-audio."
            ) == true
        )
    }

    @Test
    func saveEditingStateUpdatesTheExistingDraftInsteadOfCreatingANewOne() async throws {
        let container = try makeContainer()
        let store = EditedVideoProjectsStore(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let firstSaveState = VideoEditorView.SaveState(
            editingConfiguration: .init(
                trim: .init(lowerBound: 0, upperBound: 4)
            ),
            thumbnailData: Data([0x01])
        )
        let secondSaveState = VideoEditorView.SaveState(
            editingConfiguration: .init(
                trim: .init(lowerBound: 2, upperBound: 6)
            )
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }

        let firstPersistedState = try await store.saveEditingState(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            saveState: firstSaveState
        )
        let updatedPersistedState = try await store.saveEditingState(
            projectID: firstPersistedState.project.id,
            originalVideoURL: firstPersistedState.project.originalVideoURL,
            saveState: secondSaveState
        )
        let projects = try container.mainContext.fetch(FetchDescriptor<EditedVideoProject>())

        #expect(updatedPersistedState.project.id == firstPersistedState.project.id)
        #expect(projects.count == 1)
        #expect(updatedPersistedState.project.editingConfiguration?.trim == secondSaveState.editingConfiguration.trim)
        #expect(updatedPersistedState.project.thumbnailData == firstSaveState.thumbnailData)
    }

    @Test
    func saveEditingStateKeepsPersistedRecordedAudioWhenSavingTheSameDraftAgain() async throws {
        let container = try makeContainer()
        let store = EditedVideoProjectsStore(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let audioURL = try TestFixtures.createTemporaryAudio()
        let initialSaveState = VideoEditorView.SaveState(
            editingConfiguration: .init(
                audio: .init(
                    recordedClip: .init(
                        url: audioURL,
                        duration: 0.5,
                        volume: 0.7
                    ),
                    selectedTrack: .recorded
                )
            )
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: audioURL) }

        let firstPersistedState = try await store.saveEditingState(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            saveState: initialSaveState
        )
        let secondPersistedState = try await store.saveEditingState(
            projectID: firstPersistedState.project.id,
            originalVideoURL: firstPersistedState.project.originalVideoURL,
            saveState: firstPersistedState.saveState
        )

        let persistedAudioURL = try #require(secondPersistedState.project.editingConfiguration?.audio.recordedClip?.url)

        #expect(FileManager.default.fileExists(atPath: persistedAudioURL.path()))
    }

    @Test
    func saveExportedVideoPromotesTheExistingDraftWithoutCreatingANewRecord() async throws {
        let container = try makeContainer()
        let store = EditedVideoProjectsStore(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let exportedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemGreen)
        let exportedVideo = await ExportedVideo.load(from: exportedVideoURL)
        let initialSaveState = VideoEditorView.SaveState(
            editingConfiguration: .init(
                trim: .init(lowerBound: 1, upperBound: 3)
            ),
            thumbnailData: Data([0x05, 0x06])
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        let draftState = try await store.saveEditingState(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            saveState: initialSaveState
        )
        let exportedProject = try await store.saveExportedVideo(
            projectID: draftState.project.id,
            originalVideoURL: draftState.project.originalVideoURL,
            exportedVideo: exportedVideo,
            editingConfiguration: draftState.saveState.editingConfiguration
        )
        let projects = try container.mainContext.fetch(FetchDescriptor<EditedVideoProject>())

        #expect(exportedProject.id == draftState.project.id)
        #expect(projects.count == 1)
        #expect(exportedProject.hasExportedVideo)
        #expect(exportedProject.exportedVideoURL.lastPathComponent.hasPrefix("exported."))
        #expect(exportedProject.thumbnailData != nil)
        #expect(exportedProject.duration == exportedVideo.duration)
        #expect(exportedProject.fileSize == exportedVideo.fileSize)
    }

    @Test
    func saveExportedVideoUsesTheCurrentTimelineFrameForThePersistedThumbnail() async throws {
        let container = try makeContainer()
        let store = EditedVideoProjectsStore(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let exportedVideoURL = try await TestFixtures.createTemporaryVideo(
            size: CGSize(width: 80, height: 40),
            frameCount: 30,
            framesPerSecond: 30,
            drawFrame: { context, size, frameIndex in
                let color = frameIndex < 6 ? UIColor.systemRed : UIColor.systemBlue
                context.setFillColor(color.cgColor)
                context.fill(CGRect(origin: .zero, size: size))
            }
        )
        let exportedVideo = await ExportedVideo.load(from: exportedVideoURL)
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 2),
            playback: .init(
                rate: 1,
                videoVolume: 1,
                currentTimelineTime: 1.6
            )
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        let exportedProject = try await store.saveExportedVideo(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            exportedVideo: exportedVideo,
            editingConfiguration: editingConfiguration
        )
        let thumbnailImage = try #require(
            exportedProject.thumbnailData.flatMap(UIImage.init(data:))
        )
        let sampledColor = try #require(
            thumbnailImage.persistedProjectSampledColor(
                at: CGPoint(
                    x: thumbnailImage.size.width / 2,
                    y: thumbnailImage.size.height / 2
                )
            )
        )

        #expect(sampledColor.blueComponent > 0.55)
        #expect(sampledColor.redComponent < 0.45)
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

        let draftState = try await store.saveEditingState(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            saveState: .init(editingConfiguration: .initial)
        )
        let project = try await store.saveExportedVideo(
            projectID: draftState.project.id,
            originalVideoURL: draftState.project.originalVideoURL,
            exportedVideo: exportedVideo,
            editingConfiguration: .initial
        )
        let directoryURL = EditedVideoProject.directoryURL(for: project.id)

        try store.deleteProject(project)

        let remainingProjects = try container.mainContext.fetch(FetchDescriptor<EditedVideoProject>())

        #expect(remainingProjects.isEmpty)
        #expect(FileManager.default.fileExists(atPath: directoryURL.path()) == false)
    }

    @Test
    func thumbnailTimestampUsesTheCurrentTimelineFrameRelativeToTheExportedClip() {
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 10, upperBound: 20),
            playback: .init(
                rate: 2,
                videoVolume: 1,
                currentTimelineTime: 6
            )
        )

        #expect(
            abs(
                EditedVideoProjectsStore.resolvedThumbnailTimestamp(
                    for: 10,
                    editingConfiguration: editingConfiguration
                ) - 1
            ) < 0.0001
        )
    }

    @Test
    func thumbnailTimestampFallsBackToTheStartOfTheExportedClipWhenNoCurrentTimeIsAvailable() {
        #expect(
            EditedVideoProjectsStore.resolvedThumbnailTimestamp(
                for: 0,
                editingConfiguration: .initial
            ) == 0
        )
        #expect(
            EditedVideoProjectsStore.resolvedThumbnailTimestamp(
                for: 3.5,
                editingConfiguration: .initial
            ) == 0
        )
        #expect(
            EditedVideoProjectsStore.resolvedThumbnailTimestamp(
                for: 120,
                editingConfiguration: .initial
            ) == 0
        )
    }

    @Test
    func hasExportedVideoIsFalseWhenTheProjectHasNoExportedFileName() {
        let project = EditedVideoProject(
            createdAt: .now,
            updatedAt: .now,
            displayName: "Draft",
            originalVideoFileName: "original.mp4",
            exportedVideoFileName: "",
            editingConfigurationData: Data(),
            thumbnailData: nil,
            duration: 0,
            width: 0,
            height: 0,
            fileSize: 0
        )

        #expect(project.hasExportedVideo == false)
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

private struct PersistedProjectSampledColor {

    // MARK: - Public Properties

    let redComponent: CGFloat
    let greenComponent: CGFloat
    let blueComponent: CGFloat
    let alphaComponent: CGFloat

}

extension UIImage {

    // MARK: - Private Methods

    fileprivate func persistedProjectSampledColor(
        at point: CGPoint
    ) -> PersistedProjectSampledColor? {
        guard let cgImage else { return nil }

        let clampedPoint = CGPoint(
            x: min(max(point.x, 0), max(size.width - 1, 0)),
            y: min(max(point.y, 0), max(size.height - 1, 0))
        )
        let pixel = UnsafeMutablePointer<UInt8>.allocate(capacity: 4)
        defer { pixel.deallocate() }

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.translateBy(x: -clampedPoint.x, y: clampedPoint.y - size.height + 1)
        context.draw(
            cgImage,
            in: CGRect(
                origin: .zero,
                size: size
            )
        )

        let red = CGFloat(pixel[0]) / 255
        let green = CGFloat(pixel[1]) / 255
        let blue = CGFloat(pixel[2]) / 255
        let alpha = CGFloat(pixel[3]) / 255

        return PersistedProjectSampledColor(
            redComponent: red,
            greenComponent: green,
            blueComponent: blue,
            alphaComponent: alpha
        )
    }

}
