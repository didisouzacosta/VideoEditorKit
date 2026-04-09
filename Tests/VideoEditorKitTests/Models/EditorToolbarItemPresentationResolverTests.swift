#if os(iOS)
    import Foundation
    import Testing

    @testable import VideoEditorKit

    @Suite("EditorToolbarItemPresentationResolverTests")
    struct EditorToolbarItemPresentationResolverTests {

        // MARK: - Public Methods

        @Test
        func speedToolUsesTheAppliedRateAsSubtitle() {
            let video = video(
                appliedTool: .speed,
                rate: 1.4
            )
            let expectedSubtitle =
                "\(Float(1.4).formatted(.number.precision(.fractionLength(1))))x"

            let presentation = EditorToolbarItemPresentationResolver.resolve(
                for: .speed,
                video: video,
                cropPresentationSummary: nil,
                transcriptDocument: nil
            )

            #expect(presentation.isApplied)
            #expect(presentation.title == "Speed")
            #expect(presentation.subtitle == expectedSubtitle)
        }

        @Test
        func presetsToolDescribesTheSelectedPresetAndAspectRatio() {
            let video = video(appliedTool: .presets)
            let cropPresentationSummary = EditorCropPresentationSummary(
                selectedPreset: .vertical9x16,
                socialVideoDestination: nil,
                shouldShowCropOverlay: true,
                isCropOverlayInteractive: true,
                shouldUseCropPresetSpotlight: true,
                shouldShowCropPresetBadge: true,
                shouldShowCanvasResetButton: false,
                badgeTitle: "Social",
                badgeDimension: "9:16",
                badgeText: "Social • 9:16"
            )

            let presentation = EditorToolbarItemPresentationResolver.resolve(
                for: .presets,
                video: video,
                cropPresentationSummary: cropPresentationSummary,
                transcriptDocument: nil
            )

            #expect(presentation.isApplied)
            #expect(presentation.subtitle == "Social 9:16")
        }

        @Test
        func audioToolPrefersTheRecordedTrackWhenItExists() {
            var video = video(appliedTool: .audio)
            video.audio = Audio(
                url: URL(fileURLWithPath: "/tmp/recorded-audio.m4a"),
                duration: 8,
                volume: 0.35
            )

            let presentation = EditorToolbarItemPresentationResolver.resolve(
                for: .audio,
                video: video,
                cropPresentationSummary: nil,
                transcriptDocument: nil
            )

            #expect(presentation.isApplied)
            #expect(presentation.subtitle == "35%")
        }

        @Test
        func audioToolShowsOnlyTheVideoTrackPercentageWhenNoRecordingExists() {
            var video = video(appliedTool: .audio)
            video.volume = 0.33

            let presentation = EditorToolbarItemPresentationResolver.resolve(
                for: .audio,
                video: video,
                cropPresentationSummary: nil,
                transcriptDocument: nil
            )

            #expect(presentation.isApplied)
            #expect(presentation.subtitle == "33%")
        }

        @Test
        func adjustsToolReportsHowManyControlsAreChanged() {
            var video = video(appliedTool: .adjusts)
            video.colorAdjusts = .init(
                brightness: 0.2,
                contrast: -0.15,
                saturation: 0
            )

            let presentation = EditorToolbarItemPresentationResolver.resolve(
                for: .adjusts,
                video: video,
                cropPresentationSummary: nil,
                transcriptDocument: nil
            )

            #expect(presentation.isApplied)
            #expect(presentation.subtitle == "2 adjustments")
        }

        @Test
        func transcriptToolDescribesOverlayPositionAndSize() {
            let video = video(appliedTool: .transcript)
            let transcriptDocument = TranscriptDocument(
                segments: [],
                overlayPosition: .bottom,
                overlaySize: .medium
            )

            let presentation = EditorToolbarItemPresentationResolver.resolve(
                for: .transcript,
                video: video,
                cropPresentationSummary: nil,
                transcriptDocument: transcriptDocument
            )

            #expect(presentation.isApplied)
            #expect(presentation.subtitle == "B/M")
        }

        @Test
        func unappliedToolsDoNotShowASubtitle() {
            let presentation = EditorToolbarItemPresentationResolver.resolve(
                for: .presets,
                video: nil,
                cropPresentationSummary: nil,
                transcriptDocument: nil
            )

            #expect(presentation.isApplied == false)
            #expect(presentation.subtitle == nil)
        }

        // MARK: - Private Methods

        private func video(
            appliedTool: ToolEnum,
            rate: Float = 1
        ) -> Video {
            var video = Video(
                url: URL(fileURLWithPath: "/tmp/editor-toolbar-video.mp4"),
                rangeDuration: 0...12,
                rate: rate
            )
            video.appliedTool(for: appliedTool)
            return video
        }

    }

#endif
