#if os(iOS)
    //
    //  VideoEditingThumbnailTimestampResolver.swift
    //  VideoEditorKit
    //
    //  Created by Codex on 02.04.2026.
    //

    import Foundation

    enum VideoEditingThumbnailTimestampResolver {

        // MARK: - Public Methods

        static func sourceAssetTimestamp(
            for editingConfiguration: VideoEditingConfiguration,
            originalDuration: Double
        ) -> Double {
            let resolvedOriginalDuration =
                originalDuration.isFinite
                ? max(originalDuration, 0)
                : 0
            let fallbackTimestamp = editingConfiguration.trim.lowerBound.clamped(
                to: 0...resolvedOriginalDuration
            )

            guard
                let currentTimelineTime = editingConfiguration.playback.currentTimelineTime,
                currentTimelineTime.isFinite
            else {
                return fallbackTimestamp
            }

            let outputRange = PlaybackTimeMapping.scaledTimelineRange(
                sourceRange: editingConfiguration.trim.lowerBound...editingConfiguration.trim.upperBound,
                rate: editingConfiguration.playback.rate,
                originalDuration: resolvedOriginalDuration
            )
            let clampedTimelineTime = currentTimelineTime.clamped(to: outputRange)

            return PlaybackTimeMapping.sourceTime(
                forTimelineTime: clampedTimelineTime,
                rate: editingConfiguration.playback.rate,
                originalDuration: resolvedOriginalDuration
            )
        }

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
            let clampedTimelineTime = currentTimelineTime.clamped(to: outputRange)
            let normalizedExportedTime = clampedTimelineTime - outputRange.lowerBound

            return normalizedExportedTime.clamped(to: 0...resolvedExportedDuration)
        }

    }

#endif
