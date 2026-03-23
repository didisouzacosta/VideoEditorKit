import CoreGraphics
import Foundation

struct Caption: Identifiable, Equatable {
    let id: UUID
    var text: String
    var startTime: Double
    var endTime: Double
    var position: CGPoint
    var placementMode: CaptionPlacementMode
    var style: CaptionStyle
}
