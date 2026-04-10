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
            return
                "Leave the field empty to keep the editor without a trim limit. Example: enter 300 to cap trim and export at 5 minutes."
        }

        return
            "The host is limiting trim and export to \(Int(maximumVideoDuration)) seconds. The user can still move the selected window anywhere in the source video, but the trim selection itself cannot exceed that duration."
    }

}
