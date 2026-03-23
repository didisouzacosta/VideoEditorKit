import Foundation

struct VideoProjectSnapshot: Codable, Equatable {
    var sourceVideoPath: String
    var captions: [CaptionSnapshot]
    var preset: ExportPresetSnapshot
    var gravity: VideoGravitySnapshot
    var selectedTimeRange: ClosedRange<Double>
    var adjustments: VideoAdjustmentSettingsSnapshot = .init()

    init(
        sourceVideoPath: String,
        captions: [CaptionSnapshot],
        preset: ExportPresetSnapshot,
        gravity: VideoGravitySnapshot,
        selectedTimeRange: ClosedRange<Double>,
        adjustments: VideoAdjustmentSettingsSnapshot = .init()
    ) {
        self.sourceVideoPath = sourceVideoPath
        self.captions = captions
        self.preset = preset
        self.gravity = gravity
        self.selectedTimeRange = selectedTimeRange
        self.adjustments = adjustments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceVideoPath = try container.decode(String.self, forKey: .sourceVideoPath)
        captions = try container.decode([CaptionSnapshot].self, forKey: .captions)
        preset = try container.decode(ExportPresetSnapshot.self, forKey: .preset)
        gravity = try container.decode(VideoGravitySnapshot.self, forKey: .gravity)
        selectedTimeRange = try container.decode(ClosedRange<Double>.self, forKey: .selectedTimeRange)
        adjustments = try container.decodeIfPresent(VideoAdjustmentSettingsSnapshot.self, forKey: .adjustments) ?? .init()
    }
}
