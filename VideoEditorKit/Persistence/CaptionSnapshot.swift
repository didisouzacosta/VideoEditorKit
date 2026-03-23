import Foundation

struct CaptionSnapshot: Codable, Equatable {
    var id: UUID
    var text: String
    var startTime: Double
    var endTime: Double
    var position: CaptionPositionSnapshot
    var style: CaptionStyleSnapshot
}
