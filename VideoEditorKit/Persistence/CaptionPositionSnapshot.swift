import Foundation

struct CaptionPositionSnapshot: Codable, Equatable {
    var mode: CaptionPlacementModeSnapshot
    var normalizedX: Double
    var normalizedY: Double
}
