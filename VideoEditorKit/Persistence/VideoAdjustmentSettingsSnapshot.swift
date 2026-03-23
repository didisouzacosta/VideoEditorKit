import Foundation

struct VideoAdjustmentSettingsSnapshot: Codable, Equatable {
    var playbackRate: Double
    var rotation: VideoRotation
    var isMirrored: Bool
    var filterName: String?
    var colorCorrection: VideoColorCorrection
    var frameStyle: VideoFrameStyleSnapshot?

    init(
        playbackRate: Double = 1,
        rotation: VideoRotation = .degrees0,
        isMirrored: Bool = false,
        filterName: String? = nil,
        colorCorrection: VideoColorCorrection = .init(),
        frameStyle: VideoFrameStyleSnapshot? = nil
    ) {
        self.playbackRate = playbackRate
        self.rotation = rotation
        self.isMirrored = isMirrored
        self.filterName = filterName
        self.colorCorrection = colorCorrection
        self.frameStyle = frameStyle
    }
}
