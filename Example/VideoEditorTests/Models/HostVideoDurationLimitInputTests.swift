import Testing

@testable import VideoEditor

@Suite("HostVideoDurationLimitInputTests")
struct HostVideoDurationLimitInputTests {

    // MARK: - Public Methods

    @Test
    func emptyAndNonPositiveValuesKeepTheHostWithoutALimit() {
        #expect(HostVideoDurationLimitInput.maximumVideoDuration(from: "") == nil)
        #expect(HostVideoDurationLimitInput.maximumVideoDuration(from: "0") == nil)
        #expect(HostVideoDurationLimitInput.maximumVideoDuration(from: "000") == nil)
    }

    @Test
    func numericSecondsMapDirectlyToTheEditorLimit() {
        #expect(HostVideoDurationLimitInput.maximumVideoDuration(from: "300") == 300)
        #expect(HostVideoDurationLimitInput.maximumVideoDuration(from: "45") == 45)
    }

    @Test
    func sanitizationKeepsOnlyDigitsBeforeResolvingTheLimit() {
        let sanitizedValue = HostVideoDurationLimitInput.sanitizedStoredValue(
            from: " 3m00s "
        )

        #expect(sanitizedValue == "300")
        #expect(HostVideoDurationLimitInput.maximumVideoDuration(from: sanitizedValue) == 300)
    }

}
