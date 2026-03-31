import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("SocialPlatformSafeAreaTests")
struct SocialPlatformSafeAreaTests {

    // MARK: - Public Methods

    @Test
    func safeAreaInsetsComputeTheSafeFrameUsingNormalizedRatios() {
        let insets = SafeAreaInsets(
            top: 0.1,
            bottom: 0.2,
            left: 0.05,
            right: 0.15
        )

        let safeFrame = insets.safeFrame(
            in: CGSize(width: 1000, height: 2000)
        )

        expect(
            safeFrame,
            equals: CGRect(x: 50, y: 200, width: 800, height: 1400)
        )
    }

    @Test
    func guideLayoutCreatesAdaptiveUnsafeRegionsAroundTheSafeFrame() {
        let insets = SafeAreaInsets(
            top: 128 / 1920,
            bottom: 320 / 1920,
            left: 60 / 1080,
            right: 120 / 1080
        )

        let guideLayout = insets.guideLayout(
            in: CGSize(width: 1080, height: 1920)
        )

        expect(
            guideLayout.safeFrame,
            equals: CGRect(x: 60, y: 128, width: 900, height: 1472)
        )
        #expect(guideLayout.unsafeRegions.map(\.role) == [.top, .bottom, .left, .right])
        expect(
            guideLayout.unsafeRegions[0].rect,
            equals: CGRect(x: 0, y: 0, width: 1080, height: 128)
        )
        expect(
            guideLayout.unsafeRegions[1].rect,
            equals: CGRect(x: 0, y: 1600, width: 1080, height: 320)
        )
        expect(
            guideLayout.unsafeRegions[2].rect,
            equals: CGRect(x: 0, y: 128, width: 60, height: 1472)
        )
        expect(
            guideLayout.unsafeRegions[3].rect,
            equals: CGRect(x: 960, y: 128, width: 120, height: 1472)
        )
    }

    @Test
    func instagramSafeAreaMatchesTheReferenceGuide() throws {
        let safeFrame = try #require(
            SocialPlatform.instagram.safeAreaInsets?.safeFrame(
                in: CGSize(width: 1080, height: 1920)
            )
        )

        expect(
            safeFrame,
            equals: CGRect(x: 0, y: 240, width: 1080, height: 1440)
        )
    }

    @Test
    func tikTokSafeAreaMatchesTheReferenceGuide() throws {
        let safeFrame = try #require(
            SocialPlatform.tiktok.safeAreaInsets?.safeFrame(
                in: CGSize(width: 1080, height: 1920)
            )
        )

        expect(
            safeFrame,
            equals: CGRect(x: 60, y: 128, width: 900, height: 1472)
        )
    }

    @Test
    func youtubeShortsSafeAreaMatchesTheReferenceGuide() throws {
        let safeFrame = try #require(
            SocialPlatform.youtubeShorts.safeAreaInsets?.safeFrame(
                in: CGSize(width: 1080, height: 1920)
            )
        )

        expect(
            safeFrame,
            equals: CGRect(x: 48, y: 288, width: 840, height: 960)
        )
    }

    @Test
    func socialVideoDestinationsMapToTheExpectedPlatforms() {
        #expect(
            VideoEditingConfiguration.SocialVideoDestination.instagramReels.socialPlatform
                == .instagram
        )
        #expect(
            VideoEditingConfiguration.SocialVideoDestination.tikTok.socialPlatform
                == .tiktok
        )
        #expect(
            VideoEditingConfiguration.SocialVideoDestination.youtubeShorts.socialPlatform
                == .youtubeShorts
        )
    }

    // MARK: - Private Methods

    private func expect(
        _ lhs: CGRect,
        equals rhs: CGRect,
        tolerance: CGFloat = 0.0001
    ) {
        #expect(abs(lhs.minX - rhs.minX) < tolerance)
        #expect(abs(lhs.minY - rhs.minY) < tolerance)
        #expect(abs(lhs.width - rhs.width) < tolerance)
        #expect(abs(lhs.height - rhs.height) < tolerance)
    }

}
