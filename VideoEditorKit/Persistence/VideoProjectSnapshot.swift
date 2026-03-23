import Foundation

struct VideoProjectSnapshot: Codable, Equatable {
    var sourceVideoPath: String
    var captions: [CaptionSnapshot]
    var preset: ExportPresetSnapshot
    var gravity: VideoGravitySnapshot
    var selectedTimeRange: ClosedRange<Double>
}
