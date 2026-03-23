import Foundation

struct VideoProject {
    let sourceVideoURL: URL
    var captions: [Caption]
    var preset: ExportPreset
    var gravity: VideoGravity
    var selectedTimeRange: ClosedRange<Double>
}
