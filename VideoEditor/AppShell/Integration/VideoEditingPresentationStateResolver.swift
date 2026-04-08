import CoreGraphics
import Foundation
import VideoEditorKit

struct VideoEditingPresentationStateResolver {

    // MARK: - Public Methods

    static func resolve(
        from configuration: VideoEditingConfiguration,
        referenceSize: CGSize,
        hasRecordedAudioTrack: Bool,
        enabledTools: Set<ToolEnum>
    ) async -> ResolvedVideoEditingPresentationState {
        await VideoEditorKit.VideoEditingPresentationStateResolver.resolve(
            from: configuration,
            referenceSize: referenceSize,
            hasRecordedAudioTrack: hasRecordedAudioTrack,
            enabledTools: enabledTools
        )
    }

    static func selectedCropPreset(
        canvasPreset: VideoCanvasPreset,
        freeformRect: VideoEditingConfiguration.FreeformRect?,
        referenceSize: CGSize?
    ) -> VideoCropFormatPreset {
        VideoEditorKit.VideoEditingPresentationStateResolver.selectedCropPreset(
            canvasPreset: canvasPreset,
            freeformRect: freeformRect,
            referenceSize: referenceSize
        )
    }

    static func selectedCropPreset(
        from canvasPreset: VideoCanvasPreset
    ) -> VideoCropFormatPreset {
        VideoEditorKit.VideoEditingPresentationStateResolver.selectedCropPreset(
            from: canvasPreset
        )
    }

    static func resolveCanvasSnapshot(
        from configuration: VideoEditingConfiguration,
        referenceSize: CGSize
    ) async -> VideoCanvasSnapshot {
        await VideoEditorKit.VideoEditingPresentationStateResolver.resolveCanvasSnapshot(
            from: configuration,
            referenceSize: referenceSize
        )
    }

    static func selectedLegacyCropPreset(
        from freeformRect: VideoEditingConfiguration.FreeformRect?,
        referenceSize: CGSize
    ) -> VideoCropFormatPreset {
        VideoEditorKit.VideoEditingPresentationStateResolver.selectedLegacyCropPreset(
            from: freeformRect,
            referenceSize: referenceSize
        )
    }

}
