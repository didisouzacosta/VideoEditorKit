import Foundation
import VideoEditorKit

enum VideoEditingThumbnailTimestampResolver {

    // MARK: - Public Methods

    static func exportedAssetTimestamp(
        for editingConfiguration: VideoEditingConfiguration,
        exportedDuration: Double
    ) -> Double {
        let resolvedExportedDuration =
            exportedDuration.isFinite
            ? max(exportedDuration, 0)
            : 0

        guard
            let currentTimelineTime = editingConfiguration.playback.currentTimelineTime,
            currentTimelineTime.isFinite
        else {
            return 0
        }

        let outputRange = PlaybackTimeMapping.scaledTimelineRange(
            sourceRange: editingConfiguration.trim.lowerBound...editingConfiguration.trim.upperBound,
            rate: editingConfiguration.playback.rate,
            originalDuration: editingConfiguration.trim.upperBound
        )
        let clampedTimelineTime = min(
            max(currentTimelineTime, outputRange.lowerBound),
            outputRange.upperBound
        )
        let normalizedExportedTime = clampedTimelineTime - outputRange.lowerBound

        return min(
            max(normalizedExportedTime, 0),
            resolvedExportedDuration
        )
    }

}
