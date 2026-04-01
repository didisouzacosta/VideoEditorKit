import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("EditorCropEditingCoordinatorTests")
struct EditorCropEditingCoordinatorTests {

    // MARK: - Public Methods

    @Test
    func selectingOriginalCropFormatResetsTheCropEditingState() throws {
        let state = EditorCropEditingState(
            freeformRect: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
            socialVideoDestination: .instagramReels,
            showsSafeAreaOverlay: true,
            canvasSnapshot: .init(
                preset: .social(platform: .instagram),
                transform: .init(
                    normalizedOffset: CGPoint(x: 0.1, y: 0.2),
                    zoom: 1.5
                ),
                showsSafeAreaOverlay: true
            )
        )

        let nextState = try #require(
            EditorCropEditingCoordinator.selectingCropFormat(
                .original,
                from: state,
                referenceSize: CGSize(width: 1080, height: 1920)
            )
        )

        #expect(nextState == .initial)
    }

    @Test
    func selectingVerticalCropFormatEnablesStoryPresetAndResetsTransform() throws {
        let state = EditorCropEditingState(
            canvasSnapshot: .init(
                preset: .free,
                transform: .init(
                    normalizedOffset: CGPoint(x: 0.2, y: -0.1),
                    zoom: 2,
                    rotationRadians: 0.4
                )
            )
        )

        let nextState = try #require(
            EditorCropEditingCoordinator.selectingCropFormat(
                .vertical9x16,
                from: state,
                referenceSize: CGSize(width: 1920, height: 1080)
            )
        )

        #expect(nextState.canvasSnapshot.preset == VideoCanvasPreset.story)
        #expect(nextState.canvasSnapshot.transform == .identity)
        #expect(nextState.showsSafeAreaOverlay == true)
        #expect(nextState.canvasSnapshot.showsSafeAreaOverlay == true)
        #expect(nextState.freeformRect != nil)
    }

    @Test
    func selectingSocialVideoDestinationPromotesTheStateToASocialPreset() throws {
        let nextState = try #require(
            EditorCropEditingCoordinator.selectingSocialVideoDestination(
                VideoEditingConfiguration.SocialVideoDestination.tikTok,
                from: .initial,
                referenceSize: CGSize(width: 1920, height: 1080)
            )
        )

        #expect(nextState.socialVideoDestination == .tikTok)
        #expect(
            nextState.canvasSnapshot.preset
                == VideoCanvasPreset.social(platform: .tiktok)
        )
        #expect(nextState.showsSafeAreaOverlay == true)
        #expect(nextState.canvasSnapshot.showsSafeAreaOverlay == true)
    }

    @Test
    func togglingSafeAreaOverlayRequiresASupportedPreset() {
        #expect(
            EditorCropEditingCoordinator.togglingSafeAreaOverlay(
                from: .initial
            ) == nil
        )
    }

    @Test
    @MainActor
    func shouldApplyPresetToolTracksLegacyCropAndCanvasState() {
        let video = Video.mock
        let rotatedVideo = {
            var copy = video
            copy.rotation = 90
            return copy
        }()

        #expect(
            EditorCropEditingCoordinator.shouldApplyPresetTool(
                for: video,
                state: .initial
            ) == false
        )
        #expect(
            EditorCropEditingCoordinator.shouldApplyPresetTool(
                for: rotatedVideo,
                state: .initial
            ) == true
        )
        #expect(
            EditorCropEditingCoordinator.shouldApplyPresetTool(
                for: video,
                state: .init(
                    canvasSnapshot: .init(
                        preset: .original,
                        transform: .init(zoom: 1.2)
                    )
                )
            ) == true
        )
    }

}
