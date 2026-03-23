import Foundation

struct TimeRangeResult: Equatable {
    let validRange: ClosedRange<Double>
    let selectedRange: ClosedRange<Double>
    let isVideoTooShort: Bool
    let exceedsMaximum: Bool
}
