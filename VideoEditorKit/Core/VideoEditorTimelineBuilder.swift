import Foundation

struct VideoEditorTimelineBuilder {
    nonisolated static func build(
        project: VideoProject,
        videoDuration: Double,
        currentTime: Double
    ) -> VideoEditorTimelineSnapshot {
        let timeRange = TimeRangeEngine.resolve(
            videoDuration: videoDuration,
            currentSelection: project.selectedTimeRange,
            preset: project.preset
        )
        let validation = ProjectValidator.validateProject(
            project: project,
            videoDuration: videoDuration,
            timeRange: timeRange
        )
        let clampedCurrentTime = TimeRangeEngine.clampTime(
            currentTime,
            to: timeRange.selectedRange
        )

        return VideoEditorTimelineSnapshot(
            validRange: timeRange.validRange,
            selectedRange: timeRange.selectedRange,
            currentTime: clampedCurrentTime,
            selectionStartProgress: TimelineInteractionEngine.progress(
                for: timeRange.selectedRange.lowerBound,
                in: timeRange.validRange
            ),
            selectionEndProgress: TimelineInteractionEngine.progress(
                for: timeRange.selectedRange.upperBound,
                in: timeRange.validRange
            ),
            playheadProgress: TimelineInteractionEngine.progress(
                for: clampedCurrentTime,
                in: timeRange.validRange
            ),
            captions: captionSegments(
                from: project.captions,
                validRange: timeRange.validRange
            ),
            validation: validation
        )
    }
}

private extension VideoEditorTimelineBuilder {
    nonisolated static func captionSegments(
        from captions: [Caption],
        validRange: ClosedRange<Double>
    ) -> [VideoEditorTimelineCaptionSegment] {
        captions
            .sorted { $0.startTime < $1.startTime }
            .compactMap { caption in
                let startTime = max(caption.startTime, validRange.lowerBound)
                let endTime = min(caption.endTime, validRange.upperBound)

                guard endTime > startTime else {
                    return nil
                }

                return VideoEditorTimelineCaptionSegment(
                    id: caption.id,
                    text: caption.text,
                    startProgress: TimelineInteractionEngine.progress(
                        for: startTime,
                        in: validRange
                    ),
                    endProgress: TimelineInteractionEngine.progress(
                        for: endTime,
                        in: validRange
                    )
                )
            }
    }
}
