import Foundation

struct VideoColorCorrection: Codable, Equatable, Sendable {
    var brightness: Double
    var contrast: Double
    var saturation: Double

    init(
        brightness: Double = 0,
        contrast: Double = 0,
        saturation: Double = 0
    ) {
        self.brightness = Self.normalizedChannel(brightness)
        self.contrast = Self.normalizedChannel(contrast)
        self.saturation = Self.normalizedChannel(saturation)
    }
}

extension VideoColorCorrection {
    nonisolated var isIdentity: Bool {
        brightness == 0 && contrast == 0 && saturation == 0
    }

    nonisolated static func normalizedChannel(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }

        return min(max(value, -1), 1)
    }
}
