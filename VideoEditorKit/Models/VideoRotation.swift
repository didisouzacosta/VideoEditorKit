import Foundation

enum VideoRotation: String, CaseIterable, Codable, Equatable, Sendable {
    case degrees0
    case degrees90
    case degrees180
    case degrees270

    nonisolated var degrees: Double {
        switch self {
        case .degrees0:
            0
        case .degrees90:
            90
        case .degrees180:
            180
        case .degrees270:
            270
        }
    }

    nonisolated func rotatedClockwise() -> VideoRotation {
        switch self {
        case .degrees0:
            .degrees90
        case .degrees90:
            .degrees180
        case .degrees180:
            .degrees270
        case .degrees270:
            .degrees0
        }
    }
}
