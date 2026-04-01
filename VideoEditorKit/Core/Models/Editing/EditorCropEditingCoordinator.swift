//
//  EditorCropEditingCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 01.04.2026.
//

import CoreGraphics
import Foundation

struct EditorCropEditingState: Equatable, Sendable {

    // MARK: - Public Properties

    static let initial = Self()

    var freeformRect: VideoEditingConfiguration.FreeformRect?
    var socialVideoDestination: VideoEditingConfiguration.SocialVideoDestination?
    var showsSafeAreaOverlay = false
    var canvasSnapshot = VideoCanvasSnapshot.initial

}

struct EditorCropEditingCoordinator {

    // MARK: - Public Methods

    static func selectingCropFormat(
        _ preset: VideoCropFormatPreset,
        from state: EditorCropEditingState,
        referenceSize: CGSize
    ) -> EditorCropEditingState? {
        var nextState = state

        switch preset {
        case .original:
            nextState = .initial
        case .vertical9x16,
            .square1x1,
            .portrait4x5,
            .landscape16x9:
            guard let nextCropRect = preset.makeFreeformRect(for: referenceSize) else { return nil }

            nextState.freeformRect = nextCropRect
            nextState.socialVideoDestination = nil

            if preset.isSocialVideoPreset {
                let hadSafeAreaGuide = activeSafeAreaGuideProfile(for: state) != nil
                if !hadSafeAreaGuide {
                    nextState.showsSafeAreaOverlay = true
                }
                nextState.canvasSnapshot.preset = .story
            } else {
                nextState.showsSafeAreaOverlay = false
                nextState.canvasSnapshot.preset = canvasPreset(
                    for: preset,
                    socialVideoDestination: nextState.socialVideoDestination
                )
            }

            nextState.canvasSnapshot.transform = .identity
            nextState.canvasSnapshot.showsSafeAreaOverlay = shouldShowSafeAreaOverlay(
                for: nextState
            )
        }

        return nextState
    }

    static func selectingSocialVideoDestination(
        _ destination: VideoEditingConfiguration.SocialVideoDestination,
        from state: EditorCropEditingState,
        referenceSize: CGSize
    ) -> EditorCropEditingState? {
        guard
            let cropRect = VideoCropFormatPreset.vertical9x16.makeFreeformRect(
                for: referenceSize
            )
        else {
            return nil
        }

        var nextState = state
        let hadSocialDestination = state.socialVideoDestination != nil

        nextState.socialVideoDestination = destination
        nextState.freeformRect = cropRect
        if !hadSocialDestination {
            nextState.showsSafeAreaOverlay = true
        }
        nextState.canvasSnapshot.preset = .social(platform: destination.socialPlatform)
        nextState.canvasSnapshot.showsSafeAreaOverlay = shouldShowSafeAreaOverlay(
            for: nextState
        )

        return nextState
    }

    static func togglingSafeAreaOverlay(
        from state: EditorCropEditingState
    ) -> EditorCropEditingState? {
        guard activeSafeAreaGuideProfile(for: state) != nil else { return nil }

        var nextState = state
        nextState.showsSafeAreaOverlay.toggle()
        nextState.canvasSnapshot.showsSafeAreaOverlay = shouldShowSafeAreaOverlay(
            for: nextState
        )
        return nextState
    }

    static func selectedCropPreset(
        from state: EditorCropEditingState,
        referenceSize: CGSize?
    ) -> VideoCropFormatPreset {
        VideoEditingPresentationStateResolver.selectedCropPreset(
            canvasPreset: state.canvasSnapshot.preset,
            freeformRect: state.freeformRect,
            referenceSize: referenceSize
        )
    }

    static func shouldShowSafeAreaOverlay(
        for state: EditorCropEditingState
    ) -> Bool {
        state.showsSafeAreaOverlay
            && activeSafeAreaGuideProfile(for: state) != nil
    }

    static func activeSafeAreaGuideProfile(
        for state: EditorCropEditingState
    ) -> SafeAreaGuideProfile? {
        VideoEditingPresentationStateResolver.resolvedSafeAreaGuideProfile(
            for: state.canvasSnapshot.preset
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

    // MARK: - Private Methods

    private static func canvasPreset(
        for preset: VideoCropFormatPreset,
        socialVideoDestination: VideoEditingConfiguration.SocialVideoDestination?
    ) -> VideoCanvasPreset {
        VideoCanvasPreset.fromLegacySelection(
            preset: preset,
            socialVideoDestination: socialVideoDestination
        )
    }

}
