import Foundation

struct ExportRenderRequest: @unchecked Sendable {
    nonisolated let snapshot: FrozenExportProject
    nonisolated let asset: LoadedVideoAsset
    nonisolated let layout: LayoutResult
    nonisolated let timeRange: TimeRangeResult
    nonisolated let destinationURL: URL

    nonisolated init(
        snapshot: FrozenExportProject,
        asset: LoadedVideoAsset,
        layout: LayoutResult,
        timeRange: TimeRangeResult,
        destinationURL: URL
    ) {
        self.snapshot = snapshot
        self.asset = asset
        self.layout = layout
        self.timeRange = timeRange
        self.destinationURL = destinationURL
    }
}
