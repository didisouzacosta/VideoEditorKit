import Foundation

struct VideoEditorTimelineSnapshot: Equatable {
    let validRange: ClosedRange<Double>
    let selectedRange: ClosedRange<Double>
    let currentTime: Double
    let selectionStartProgress: Double
    let selectionEndProgress: Double
    let playheadProgress: Double
    let captions: [VideoEditorTimelineCaptionSegment]
    let validation: ValidationResult
}

struct VideoEditorTimelineCaptionSegment: Identifiable, Equatable {
    let id: Caption.ID
    let text: String
    let startProgress: Double
    let endProgress: Double
}
