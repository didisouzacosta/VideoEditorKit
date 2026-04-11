import Foundation

enum HostVideoDurationLimitInput {

    // MARK: - Public Methods

    static func sanitizedStoredValue(
        from rawValue: String
    ) -> String {
        rawValue.filter(\.isNumber)
    }

    static func maximumVideoDuration(
        from rawValue: String
    ) -> TimeInterval? {
        let sanitizedValue = sanitizedStoredValue(from: rawValue)

        guard let seconds = TimeInterval(sanitizedValue) else { return nil }
        guard seconds.isFinite, seconds > 0 else { return nil }

        return seconds
    }

    static func detail(
        for rawValue: String
    ) -> String {
        guard let maximumVideoDuration = maximumVideoDuration(from: rawValue) else {
            return ExampleStrings.hostDurationLimitEmptyDetail
        }

        return ExampleStrings.hostDurationLimitDetail(
            maximumDurationInSeconds: Int(maximumVideoDuration)
        )
    }

}
