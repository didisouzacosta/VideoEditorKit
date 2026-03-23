import Foundation
import UIKit

struct VideoFrameStyle: @unchecked Sendable {
    var backgroundColor: UIColor
    var scale: Double

    init(
        backgroundColor: UIColor,
        scale: Double
    ) {
        self.backgroundColor = backgroundColor
        self.scale = Self.normalizedScale(scale)
    }
}

extension VideoFrameStyle: Equatable {
    static func == (lhs: VideoFrameStyle, rhs: VideoFrameStyle) -> Bool {
        lhs.scale == rhs.scale && lhs.backgroundColor.isEqual(rhs.backgroundColor)
    }
}

extension VideoFrameStyle {
    nonisolated static func normalizedScale(_ value: Double) -> Double {
        guard value.isFinite else {
            return 1
        }

        return min(max(value, 0.5), 1)
    }
}
