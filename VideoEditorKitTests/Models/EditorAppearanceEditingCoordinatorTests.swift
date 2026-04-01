import SwiftUI
import Testing

@testable import VideoEditorKit

@Suite("EditorAppearanceEditingCoordinatorTests")
struct EditorAppearanceEditingCoordinatorTests {

    // MARK: - Public Methods

    @Test
    @MainActor
    func setCorrectionsAppliesAndRemovesTheCorrectionsTool() {
        var video = Video.mock

        let didApply = EditorAppearanceEditingCoordinator.setCorrections(
            .init(brightness: 0.2, contrast: 0.15, saturation: 0.1),
            in: &video
        )

        #expect(didApply == true)
        #expect(abs(video.colorCorrection.brightness - 0.2) < 0.0001)
        #expect(video.isAppliedTool(for: .corrections) == true)

        let didReset = EditorAppearanceEditingCoordinator.setCorrections(
            .init(),
            in: &video
        )

        #expect(didReset == true)
        #expect(video.colorCorrection == .init())
        #expect(video.isAppliedTool(for: .corrections) == false)
    }

    @Test
    @MainActor
    func restoreDefaultCorrectionsKeepsTheToolAppliedUntilDeferredCleanup() {
        var video = Video.mock
        video.colorCorrection = .init(brightness: 0.2)
        video.appliedTool(for: .corrections)

        let didRestore = EditorAppearanceEditingCoordinator.restoreDefaultCorrections(
            in: &video
        )

        #expect(didRestore == true)
        #expect(video.colorCorrection == .init())
        #expect(video.isAppliedTool(for: .corrections) == true)
    }

    @Test
    @MainActor
    func configurationVideoOmitsInactiveFramesButPreservesActiveOnes() {
        var video = Video.mock
        video.videoFrames = .init(
            scaleValue: 0,
            frameColor: .red
        )

        let inactiveConfigurationVideo = EditorAppearanceEditingCoordinator.configurationVideo(
            from: video,
            frames: .init(
                scaleValue: 0,
                frameColor: .red
            )
        )
        let activeConfigurationVideo = EditorAppearanceEditingCoordinator.configurationVideo(
            from: video,
            frames: .init(
                scaleValue: 0.35,
                frameColor: .red
            )
        )

        #expect(inactiveConfigurationVideo.videoFrames == nil)
        #expect(abs((activeConfigurationVideo.videoFrames?.scaleValue ?? 0) - 0.35) < 0.0001)
        #expect(
            SystemColorPalette.matches(
                activeConfigurationVideo.videoFrames?.frameColor ?? .clear,
                .red
            )
        )
    }

}
