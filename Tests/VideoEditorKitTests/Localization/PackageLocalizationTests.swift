import Testing

@testable import VideoEditorKit

@Suite("PackageLocalizationTests")
struct PackageLocalizationTests {

    // MARK: - Public Methods

    @Test
    func toolTitlesResolveFromThePackageLocalizationLayer() {
        #expect(ToolEnum.cut.title == "Cut")
        #expect(ToolEnum.speed.title == "Speed")
        #expect(ToolEnum.presets.title == "Presets")
        #expect(ToolEnum.audio.title == "Audio")
        #expect(ToolEnum.transcript.title == "Transcript")
        #expect(ToolEnum.adjusts.title == "Adjusts")
    }

    @Test
    func exportQualityMetadataUsesLocalizedTitlesAndSubtitles() {
        #expect(VideoQuality.low.title == "qHD - 480")
        #expect(VideoQuality.medium.title == "HD - 720p")
        #expect(VideoQuality.high.title == "Full HD - 1080p")
        #expect(VideoQuality.low.subtitle == "Fast loading and small size, low quality")
        #expect(VideoQuality.medium.subtitle == "Optimal size to quality ratio")
        #expect(VideoQuality.high.subtitle == "Ideal for publishing on social networks")
    }

    @Test
    func transcriptOverlayEnumsResolveLocalizedLabels() {
        #expect(TranscriptOverlayPosition.top.title == "Top")
        #expect(TranscriptOverlayPosition.center.title == "Center")
        #expect(TranscriptOverlayPosition.bottom.title == "Bottom")
        #expect(TranscriptOverlaySize.small.title == "Small")
        #expect(TranscriptOverlaySize.medium.title == "Medium")
        #expect(TranscriptOverlaySize.large.title == "Large")
    }

    @Test
    func safeAreaProfilesUseLocalizedPackageCopy() {
        #expect(SafeAreaGuideProfile.universalSocial.title == "Universal Social Safe Zone")
        #expect(SocialPlatform.instagram.title == "Instagram Reels & Stories")
        #expect(SocialPlatform.tiktok.title == "TikTok")
        #expect(SocialPlatform.youtubeShorts.title == "YouTube Shorts")
    }

}
