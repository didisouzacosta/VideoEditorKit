import CoreGraphics
import Foundation
import VideoEditorKit

struct EditorCropEditingCoordinator {

    // MARK: - Public Methods

    static func selectingCropFormat(
        _ preset: VideoCropFormatPreset,
        from state: EditorCropEditingState,
        referenceSize: CGSize
    ) -> EditorCropEditingState? {
        VideoEditorKit.EditorCropEditingCoordinator.selectingCropFormat(
            preset,
            from: state,
            referenceSize: referenceSize
        )
    }

    static func selectingSocialVideoDestination(
        _ destination: VideoEditingConfiguration.SocialVideoDestination,
        from state: EditorCropEditingState,
        referenceSize: CGSize
    ) -> EditorCropEditingState? {
        VideoEditorKit.EditorCropEditingCoordinator.selectingSocialVideoDestination(
            destination,
            from: state,
            referenceSize: referenceSize
        )
    }

    static func selectedCropPreset(
        from state: EditorCropEditingState,
        referenceSize: CGSize?
    ) -> VideoCropFormatPreset {
        VideoEditorKit.EditorCropEditingCoordinator.selectedCropPreset(
            from: state,
            referenceSize: referenceSize
        )
    }

    static func shouldApplyPresetTool(
        for video: Video,
        state: EditorCropEditingState
    ) -> Bool {
        let hasRotation =
            abs(video.rotation.truncatingRemainder(dividingBy: 360))
            > 0.001
        let hasMirror = video.isMirror
        let hasFreeformRect = state.freeformRect != nil
        let hasCanvasState = state.canvasSnapshot.isIdentity == false

        return hasRotation || hasMirror || hasFreeformRect || hasCanvasState
    }

}
