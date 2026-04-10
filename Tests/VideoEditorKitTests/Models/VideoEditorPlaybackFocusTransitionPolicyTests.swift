import Testing

@testable import VideoEditorKit

@Suite("VideoEditorPlaybackFocusTransitionPolicyTests")
struct VideoEditorPlaybackFocusTransitionPolicyTests {

    // MARK: - Public Methods

    @Test
    func usesTheExpectedSharedAnimationDuration() {
        #expect(
            VideoEditorPlaybackFocusTransitionPolicy.animationDuration == 0.24
        )
    }

}
