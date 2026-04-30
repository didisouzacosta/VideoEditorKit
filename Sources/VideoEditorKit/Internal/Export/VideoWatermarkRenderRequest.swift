import CoreGraphics
import SwiftUI

struct VideoWatermarkRenderRequest: @unchecked Sendable {

    // MARK: - Public Properties

    let image: CGImage
    let imageSize: CGSize
    let imageScale: CGFloat
    let position: VideoWatermarkPosition

    // MARK: - Initializer

    @MainActor
    init?(_ configuration: VideoWatermarkConfiguration?) {
        guard let configuration else { return nil }
        guard let cgImage = configuration.image.cgImage else { return nil }

        image = cgImage
        imageSize = configuration.image.size
        imageScale = max(configuration.image.scale, 1)
        position = configuration.position
    }

}
