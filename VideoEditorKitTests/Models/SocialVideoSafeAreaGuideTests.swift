import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("SocialVideoSafeAreaGuideTests")
struct SocialVideoSafeAreaGuideTests {

    // MARK: - Public Methods

    @Test
    func instagramSafeRectUsesConfiguredInsets() {
        let canvas = CGRect(x: 0, y: 0, width: 100, height: 200)

        let safeRect = SocialVideoSafeAreaGuide.instagramReels.safeRect(in: canvas)

        #expect(safeRect == CGRect(x: 6, y: 24, width: 74, height: 136))
    }

    @Test
    func overlayRegionsMatchVisiblePlatformChromeAreas() {
        let canvas = CGRect(x: 0, y: 0, width: 100, height: 200)

        let regions = SocialVideoSafeAreaGuide.tikTok.overlayRegions(in: canvas)

        #expect(regions.count == 3)
        #expect(regions.map(\.role) == [.top, .bottom, .trailing])
        #expect(regions[0].title == "Top UI")
        #expect(regions[0].rect == CGRect(x: 0, y: 0, width: 100, height: 26))
        #expect(regions[1].title == "Bottom UI")
        #expect(regions[1].rect == CGRect(x: 0, y: 152, width: 100, height: 48))
        #expect(regions[2].title == "Actions")
        #expect(regions[2].rect == CGRect(x: 82, y: 26, width: 18, height: 126))
    }

    @Test
    func destinationMapsToItsExpectedGuidePreset() {
        #expect(
            VideoEditingConfiguration.SocialVideoDestination.instagramReels.safeAreaGuide
                == .instagramReels
        )
        #expect(
            VideoEditingConfiguration.SocialVideoDestination.tikTok.safeAreaGuide
                == .tikTok
        )
        #expect(
            VideoEditingConfiguration.SocialVideoDestination.youtubeShorts.safeAreaGuide
                == .youtubeShorts
        )
    }

}
