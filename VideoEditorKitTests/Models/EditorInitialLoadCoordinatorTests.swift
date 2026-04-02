import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("EditorInitialLoadCoordinatorTests")
struct EditorInitialLoadCoordinatorTests {

    // MARK: - Public Methods

    @Test
    func prepareResetsPresentationStateAndPreservesTimelineTime() {
        let configuration = VideoEditingConfiguration(
            playback: .init(currentTimelineTime: 12),
            presentation: .init(.adjusts)
        )

        let preparedState = EditorInitialLoadCoordinator.prepare(configuration)

        #expect(preparedState.pendingEditingConfiguration == configuration)
        #expect(preparedState.selectedAudioTrack == .video)
        #expect(preparedState.selectedTool == nil)
        #expect(preparedState.cropEditingState == .initial)
        #expect(preparedState.initialTimelineTime == 12)
    }

    @Test
    @MainActor
    func applyPendingEditingConfigurationAppliesMappedStateAndResolvedLayout() {
        let configuration = VideoEditingConfiguration(
            trim: .init(lowerBound: 4, upperBound: 16),
            playback: .init(rate: 1.5, videoVolume: 0.6),
            crop: .init(rotationDegrees: 90, isMirrored: true),
            adjusts: .init(brightness: 0.2, contrast: 1.1, saturation: 0.8)
        )
        var video = Video.mock

        EditorInitialLoadCoordinator.applyPendingEditingConfiguration(
            configuration,
            to: &video,
            containerSize: CGSize(width: 320, height: 240)
        ) { _, _ in
            CGSize(width: 200, height: 120)
        }

        #expect(video.rangeDuration == 4...16)
        #expect(abs(Double(video.rate) - 1.5) < 0.0001)
        #expect(abs(Double(video.volume) - 0.6) < 0.0001)
        #expect(video.rotation == 90)
        #expect(video.isMirror == true)
        #expect(video.frameSize == CGSize(width: 200, height: 120))
        #expect(video.geometrySize == CGSize(width: 200, height: 120))
    }

    @Test
    func restorePendingEditingPresentationStateBuildsTheEditorPresentationState() async throws {
        let persistedSnapshot = VideoCanvasSnapshot(
            preset: .facebookPost,
            freeCanvasSize: CGSize(width: 1080, height: 1350),
            transform: .init(
                normalizedOffset: CGPoint(x: 0.2, y: -0.1),
                zoom: 1.4
            ),
            showsSafeAreaOverlay: false
        )
        let configuration = VideoEditingConfiguration(
            canvas: .init(snapshot: persistedSnapshot),
            audio: .init(selectedTrack: .recorded),
            presentation: .init(
                .adjusts,
                socialVideoDestination: .instagramReels,
                showsSafeAreaGuides: true
            )
        )

        let resolvedState = await EditorInitialLoadCoordinator.restorePendingEditingPresentationState(
            from: configuration,
            referenceSize: CGSize(width: 1920, height: 1080),
            hasRecordedAudioTrack: true,
            enabledTools: Set(ToolEnum.all)
        )
        let restoredState = try #require(resolvedState)

        #expect(restoredState.cropEditingState.canvasSnapshot == persistedSnapshot)
        #expect(restoredState.cropEditingState.socialVideoDestination == .instagramReels)
        #expect(restoredState.cropEditingState.showsSafeAreaOverlay == false)
        #expect(restoredState.selectedAudioTrack == .recorded)
        #expect(restoredState.selectedTool == .adjusts)
    }

}
