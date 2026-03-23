import Foundation

struct CaptionRequestContext: Equatable {
    let videoURL: URL
    let duration: Double
    let selectedTimeRange: ClosedRange<Double>
}
