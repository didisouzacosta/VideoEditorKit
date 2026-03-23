import Foundation

struct FrozenExportProject: @unchecked Sendable {
    nonisolated let sourceVideoURL: URL
    nonisolated let captions: [Caption]
    nonisolated let preset: ExportPreset
    nonisolated let gravity: VideoGravity
    nonisolated let selectedTimeRange: ClosedRange<Double>

    nonisolated init(
        sourceVideoURL: URL,
        captions: [Caption],
        preset: ExportPreset,
        gravity: VideoGravity,
        selectedTimeRange: ClosedRange<Double>
    ) {
        self.sourceVideoURL = sourceVideoURL
        self.captions = captions
        self.preset = preset
        self.gravity = gravity
        self.selectedTimeRange = selectedTimeRange
    }
}
