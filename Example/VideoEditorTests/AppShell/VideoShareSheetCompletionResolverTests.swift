import Foundation
import Testing

@testable import VideoEditor

@MainActor
@Suite("VideoShareSheetCompletionResolverTests")
struct VideoShareSheetCompletionResolverTests {

    // MARK: - Public Methods

    @Test
    func cancelledShareCompletesSilentlyWhenNoActivityErrorIsProvided() {
        let result = VideoShareSheetCompletionResolver.result(
            completed: false,
            error: nil
        )

        #expect(result == .cancelled)
    }

    @Test
    func cancelledShareCompletesSilentlyWhenTheActivityReportsUserCancellation() {
        let result = VideoShareSheetCompletionResolver.result(
            completed: false,
            error: CocoaError(.userCancelled)
        )

        #expect(result == .cancelled)
    }

    @Test
    func failedShareKeepsNonCancellationErrorsActionable() {
        let result = VideoShareSheetCompletionResolver.result(
            completed: false,
            error: ShareTestError()
        )

        #expect(result == .failed("Share failed"))
    }

}

private struct ShareTestError: LocalizedError {

    // MARK: - Public Properties

    var errorDescription: String? {
        "Share failed"
    }

}
