import SwiftData
import SwiftUI
import Testing
import VideoEditorKit

@testable import VideoEditor

@MainActor
@Suite("ProjectsRepositoryTests")
struct ProjectsRepositoryTests {

    // MARK: - Public Methods

    @Test
    func saveEditedVideoPersistsOriginalVideoAndEditedCopyBeforeExport() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let editedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemPurple)
        let editedVideoMetadata = await ExportedVideo.load(from: editedVideoURL)
        let thumbnailData = try #require(
            TestFixtures.makeSolidImage(color: .systemPurple).jpegData(compressionQuality: 0.85)
        )
        let savedVideo = SavedVideo(
            editedVideoURL,
            originalVideoURL: originalVideoURL,
            editingConfiguration: .init(
                trim: .init(lowerBound: 1, upperBound: 4),
                playback: .init(
                    rate: 1,
                    videoVolume: 1,
                    currentTimelineTime: 2
                )
            ),
            thumbnailData: thumbnailData,
            metadata: editedVideoMetadata
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: editedVideoURL) }

        let persistedSave = try await store.saveEditedVideo(
            projectID: nil,
            savedVideo: savedVideo
        )
        let project = persistedSave.project

        #expect(project.hasOriginalVideo)
        #expect(project.hasSavedEditedVideo)
        #expect(project.hasExportedVideo == false)
        #expect(project.savedPlaybackVideoURL == project.savedEditedVideoURL)
        #expect(project.canPreviewSavedVideo)
        #expect(project.canShareSavedVideo)
        #expect(project.originalVideoURL.lastPathComponent.hasPrefix("original."))
        #expect(project.savedEditedVideoURL.lastPathComponent.hasPrefix("edited."))
        #expect(project.savedEditedVideoURL != project.exportedVideoURL)
        #expect(project.thumbnailData == savedVideo.thumbnailData)
        #expect(project.thumbnailData.flatMap(UIImage.init(data:)) != nil)
        #expect(project.duration == editedVideoMetadata.duration)
        #expect(project.fileSize == editedVideoMetadata.fileSize)
        #expect(project.editingConfiguration?.trim == savedVideo.editingConfiguration.trim)
        #expect(project.editingConfiguration?.playback.currentTimelineTime == nil)
        #expect(persistedSave.savedVideo.url == project.savedEditedVideoURL)
        #expect(persistedSave.savedVideo.originalVideoURL == project.originalVideoURL)
        #expect(persistedSave.savedVideo.editingConfiguration.playback.currentTimelineTime == nil)
    }

    @Test
    func saveEditedVideoMovesTransientEditedOutputIntoProjectStorage() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let editedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemPurple)
        let originalEditedFileNumber = try systemFileNumber(for: editedVideoURL)
        let savedVideo = SavedVideo(
            editedVideoURL,
            originalVideoURL: originalVideoURL,
            editingConfiguration: .initial,
            metadata: await ExportedVideo.load(from: editedVideoURL)
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: editedVideoURL) }

        let persistedSave = try await store.saveEditedVideo(
            projectID: nil,
            savedVideo: savedVideo
        )
        let persistedEditedFileNumber = try systemFileNumber(
            for: persistedSave.project.savedEditedVideoURL
        )

        #expect(persistedEditedFileNumber == originalEditedFileNumber)
    }

    @Test
    func saveEditedVideoRefreshesTheSavedPlaybackURLWhenUpdatingAnExistingProject() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let firstEditedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemPurple)
        let secondEditedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemGreen)

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: firstEditedVideoURL) }
        defer { FileManager.default.removeIfExists(for: secondEditedVideoURL) }

        let firstSave = try await store.saveEditedVideo(
            projectID: nil,
            savedVideo: SavedVideo(
                firstEditedVideoURL,
                originalVideoURL: originalVideoURL,
                editingConfiguration: .initial,
                metadata: await ExportedVideo.load(from: firstEditedVideoURL)
            )
        )
        let firstPlaybackURL = try #require(firstSave.project.savedPlaybackVideoURL)

        let secondSave = try await store.saveEditedVideo(
            projectID: firstSave.project.id,
            savedVideo: SavedVideo(
                secondEditedVideoURL,
                originalVideoURL: firstSave.project.originalVideoURL,
                editingConfiguration: .init(playback: .init(rate: 2)),
                metadata: await ExportedVideo.load(from: secondEditedVideoURL)
            )
        )
        let secondPlaybackURL = try #require(secondSave.project.savedPlaybackVideoURL)

        #expect(secondPlaybackURL != firstPlaybackURL)
        #expect(FileManager.default.fileExists(atPath: secondPlaybackURL.path()))
        #expect(FileManager.default.fileExists(atPath: firstPlaybackURL.path()) == false)
    }

    @Test
    func saveEditedVideoUsesTheFirstEditedVideoFrameForThePersistedThumbnail() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let editedVideoURL = try await TestFixtures.createTemporaryVideo(
            size: CGSize(width: 80, height: 40),
            frameCount: 30,
            framesPerSecond: 30,
            drawFrame: { context, size, frameIndex in
                let color = frameIndex == 0 ? UIColor.systemRed : UIColor.systemBlue
                context.setFillColor(color.cgColor)
                context.fill(CGRect(origin: .zero, size: size))
            }
        )
        let savedVideo = SavedVideo(
            editedVideoURL,
            originalVideoURL: originalVideoURL,
            editingConfiguration: .init(
                playback: .init(
                    rate: 1,
                    videoVolume: 1,
                    currentTimelineTime: 0.8
                )
            ),
            metadata: await ExportedVideo.load(from: editedVideoURL)
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: editedVideoURL) }

        let persistedSave = try await store.saveEditedVideo(
            projectID: nil,
            savedVideo: savedVideo
        )
        let thumbnailImage = try #require(
            persistedSave.project.thumbnailData.flatMap(UIImage.init(data:))
        )
        let sampledColor = try #require(
            thumbnailImage.persistedProjectSampledColor(
                at: CGPoint(
                    x: thumbnailImage.size.width / 2,
                    y: thumbnailImage.size.height / 2
                )
            )
        )

        #expect(sampledColor.redComponent > 0.55)
        #expect(sampledColor.blueComponent < 0.45)
    }

    @Test
    func saveExportedVideoKeepsTheSavedEditedCopySeparateFromShareOutput() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let editedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemPurple)
        let exportedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemGreen)
        let savedVideo = SavedVideo(
            editedVideoURL,
            originalVideoURL: originalVideoURL,
            editingConfiguration: .init(
                trim: .init(lowerBound: 1, upperBound: 3)
            ),
            metadata: await ExportedVideo.load(from: editedVideoURL)
        )
        let exportedVideo = await ExportedVideo.load(from: exportedVideoURL)

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: editedVideoURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        let persistedSave = try await store.saveEditedVideo(
            projectID: nil,
            savedVideo: savedVideo
        )
        let exportedProject = try await store.saveExportedVideo(
            projectID: persistedSave.project.id,
            originalVideoURL: persistedSave.project.originalVideoURL,
            exportedVideo: exportedVideo,
            editingConfiguration: persistedSave.savedVideo.editingConfiguration
        )

        #expect(exportedProject.hasSavedEditedVideo)
        #expect(exportedProject.hasExportedVideo)
        #expect(exportedProject.savedPlaybackVideoURL == exportedProject.savedEditedVideoURL)
        #expect(exportedProject.canPreviewSavedVideo)
        #expect(exportedProject.canShareSavedVideo)
        #expect(exportedProject.savedEditedVideoURL.lastPathComponent.hasPrefix("edited."))
        #expect(exportedProject.exportedVideoURL.lastPathComponent.hasPrefix("exported."))
        #expect(exportedProject.savedEditedVideoURL != exportedProject.exportedVideoURL)
    }

    @Test
    func saveEditingStatePersistsOriginalVideoAndEditingConfigurationBeforeExport() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
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
        let thumbnailData = Data([0x01, 0x02, 0x03])

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: audioURL) }

        let persistedState = try await store.saveEditingState(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            editingConfiguration: editingConfiguration,
            thumbnailData: thumbnailData
        )
        let project = persistedState.project

        #expect(project.hasOriginalVideo)
        #expect(project.hasExportedVideo == false)
        #expect(project.originalVideoURL.lastPathComponent.hasPrefix("original."))
        #expect(project.thumbnailData == thumbnailData)
        #expect(project.duration > 0)
        #expect(project.fileSize > 0)
        #expect(project.editingConfiguration?.trim == editingConfiguration.trim)
        #expect(project.editingConfiguration?.playback.currentTimelineTime == nil)
        #expect(project.editingConfiguration?.audio.selectedTrack == .recorded)
        #expect(
            project.editingConfiguration?.audio.recordedClip?.url.lastPathComponent.hasPrefix(
                "recorded-audio."
            ) == true
        )
        #expect(persistedState.editingConfiguration.playback.currentTimelineTime == nil)
        #expect(
            persistedState.editingConfiguration.audio.recordedClip?.url.lastPathComponent.hasPrefix(
                "recorded-audio."
            ) == true
        )
    }

    @Test
    func saveEditingStateUpdatesTheExistingDraftInsteadOfCreatingANewOne() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let firstEditingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 0, upperBound: 4)
        )
        let firstThumbnailData = Data([0x01])
        let secondEditingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 2, upperBound: 6)
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }

        let firstPersistedState = try await store.saveEditingState(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            editingConfiguration: firstEditingConfiguration,
            thumbnailData: firstThumbnailData
        )
        let updatedPersistedState = try await store.saveEditingState(
            projectID: firstPersistedState.project.id,
            originalVideoURL: firstPersistedState.project.originalVideoURL,
            editingConfiguration: secondEditingConfiguration
        )
        let projects = try container.mainContext.fetch(FetchDescriptor<EditedVideoProject>())

        #expect(updatedPersistedState.project.id == firstPersistedState.project.id)
        #expect(projects.count == 1)
        #expect(updatedPersistedState.project.editingConfiguration?.trim == secondEditingConfiguration.trim)
        #expect(updatedPersistedState.project.thumbnailData == firstThumbnailData)
    }

    @Test
    func saveEditingStateKeepsPersistedRecordedAudioWhenSavingTheSameDraftAgain() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let audioURL = try TestFixtures.createTemporaryAudio()
        let initialEditingConfiguration = VideoEditingConfiguration(
            audio: .init(
                recordedClip: .init(
                    url: audioURL,
                    duration: 0.5,
                    volume: 0.7
                ),
                selectedTrack: .recorded
            )
        )

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: audioURL) }

        let firstPersistedState = try await store.saveEditingState(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            editingConfiguration: initialEditingConfiguration
        )
        let secondPersistedState = try await store.saveEditingState(
            projectID: firstPersistedState.project.id,
            originalVideoURL: firstPersistedState.project.originalVideoURL,
            editingConfiguration: firstPersistedState.editingConfiguration,
            thumbnailData: firstPersistedState.thumbnailData
        )

        let persistedAudioURL = try #require(secondPersistedState.project.editingConfiguration?.audio.recordedClip?.url)

        #expect(FileManager.default.fileExists(atPath: persistedAudioURL.path()))
    }

    @Test
    func saveExportedVideoPromotesTheExistingDraftWithoutCreatingANewRecord() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let exportedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemGreen)
        let exportedVideo = await ExportedVideo.load(from: exportedVideoURL)
        let initialEditingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 3)
        )
        let initialThumbnailData = Data([0x05, 0x06])

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        let draftState = try await store.saveEditingState(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            editingConfiguration: initialEditingConfiguration,
            thumbnailData: initialThumbnailData
        )
        let exportedProject = try await store.saveExportedVideo(
            projectID: draftState.project.id,
            originalVideoURL: draftState.project.originalVideoURL,
            exportedVideo: exportedVideo,
            editingConfiguration: draftState.editingConfiguration
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
    func saveExportedVideoUsesTheExportStartFrameForThePersistedThumbnail() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
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

        #expect(sampledColor.redComponent > 0.55)
        #expect(sampledColor.blueComponent < 0.45)
    }

    @Test
    func deleteProjectRemovesTheStoredFilesAndTheSwiftDataRecord() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let exportedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemGreen)
        let exportedVideo = await ExportedVideo.load(from: exportedVideoURL)

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        let draftState = try await store.saveEditingState(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            editingConfiguration: .initial
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
    func thumbnailTimestampStartsAtTheBeginningOfTheExportedClip() {
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 10, upperBound: 20),
            playback: .init(
                rate: 2,
                videoVolume: 1,
                currentTimelineTime: 6
            )
        )

        #expect(
            ProjectsRepository.resolvedThumbnailTimestamp(
                for: 10,
                editingConfiguration: editingConfiguration
            ) == 0
        )
    }

    @Test
    func thumbnailTimestampFallsBackToTheStartOfTheExportedClipWhenNoCurrentTimeIsAvailable() {
        #expect(
            ProjectsRepository.resolvedThumbnailTimestamp(
                for: 0,
                editingConfiguration: .initial
            ) == 0
        )
        #expect(
            ProjectsRepository.resolvedThumbnailTimestamp(
                for: 3.5,
                editingConfiguration: .initial
            ) == 0
        )
        #expect(
            ProjectsRepository.resolvedThumbnailTimestamp(
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

    @Test
    func savedPlaybackVideoURLFallsBackToExportedVideoForLegacyProjects() async throws {
        let container = try makeContainer()
        let store = ProjectsRepository(modelContext: container.mainContext)
        let originalVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemBlue)
        let exportedVideoURL = try await TestFixtures.createTemporaryVideo(color: .systemGreen)
        let exportedVideo = await ExportedVideo.load(from: exportedVideoURL)

        defer { FileManager.default.removeIfExists(for: originalVideoURL) }
        defer { FileManager.default.removeIfExists(for: exportedVideoURL) }

        let project = try await store.saveExportedVideo(
            projectID: nil,
            originalVideoURL: originalVideoURL,
            exportedVideo: exportedVideo,
            editingConfiguration: .initial
        )

        #expect(project.hasSavedEditedVideo == false)
        #expect(project.hasExportedVideo)
        #expect(project.savedPlaybackVideoURL == project.exportedVideoURL)
        #expect(project.canPreviewSavedVideo)
        #expect(project.canShareSavedVideo)
    }

    // MARK: - Private Methods

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: EditedVideoProject.self,
            configurations: configuration
        )
    }

    private func systemFileNumber(for url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path())
        let fileNumber = try #require(attributes[.systemFileNumber] as? NSNumber)
        return fileNumber.uint64Value
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
            let context = CGContext(
                data: pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.translateBy(x: -clampedPoint.x, y: clampedPoint.y - size.height + 1)
        context.draw(
            cgImage,
            in: CGRect(origin: .zero, size: size)
        )

        return .init(
            redComponent: CGFloat(pixel[0]) / 255,
            greenComponent: CGFloat(pixel[1]) / 255,
            blueComponent: CGFloat(pixel[2]) / 255,
            alphaComponent: CGFloat(pixel[3]) / 255
        )
    }

}
