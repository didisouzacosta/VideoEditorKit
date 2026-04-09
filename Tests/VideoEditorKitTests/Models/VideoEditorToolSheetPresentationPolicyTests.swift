#if os(iOS)
    import Testing

    @testable import VideoEditorKit

    @Suite("VideoEditorToolSheetPresentationPolicyTests")
    struct VideoEditorToolSheetPresentationPolicyTests {

        // MARK: - Public Methods

        @Test
        func transcriptToolUsesTheTallestInitialSheetHeight() {
            #expect(VideoEditorToolSheetPresentationPolicy.initialSheetHeight(for: .transcript) == 520)
            #expect(VideoEditorToolSheetPresentationPolicy.initialSheetHeight(for: .audio) == 300)
        }

        @Test
        func cutToolDoesNotRequireAnExplicitApplyAction() {
            #expect(!VideoEditorToolSheetPresentationPolicy.requiresExplicitApply(.cut))
            #expect(VideoEditorToolSheetPresentationPolicy.requiresExplicitApply(.adjusts))
        }

    }

#endif
