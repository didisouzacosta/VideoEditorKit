#if os(iOS)
    //
    //  TimelineMetrics.swift
    //  VideoEditorKit
    //
    //  Created by Adriano Souza Costa on 26.03.2026.
    //

    import CoreGraphics

    struct TimelineMetrics {

        // MARK: - Public Properties

        let duration: Double
        let playbackRange: ClosedRange<Double>
        let currentTime: Double
        let width: CGFloat
        let handleInset: CGFloat
        let minimumX: CGFloat

        // MARK: - Private Properties

        private var clampedCurrentTime: Double {
            currentTime.clamped(to: playbackRange)
        }

        private var rangeStartX: CGFloat {
            (CGFloat(playbackRange.lowerBound / duration) * width) + handleInset
        }

        private var rangeEndX: CGFloat {
            (CGFloat(playbackRange.upperBound / duration) * width) - handleInset
        }

        // MARK: - Initializer

        init(
            duration: Double,
            playbackRange: ClosedRange<Double>,
            currentTime: Double,
            width: CGFloat,
            handleInset: CGFloat = 4,
            minimumX: CGFloat = 2
        ) {
            self.duration = duration
            self.playbackRange = playbackRange
            self.currentTime = currentTime
            self.width = width
            self.handleInset = handleInset
            self.minimumX = minimumX
        }

        // MARK: - Public Methods

        func playbackPositionX() -> CGFloat {
            guard duration > 0, width > 0 else { return minimumX }
            guard rangeEndX > rangeStartX else {
                return min(max(rangeStartX, minimumX), width - minimumX)
            }

            let absoluteProgress = clampedCurrentTime / duration
            let positionX = CGFloat(absoluteProgress) * width

            return min(max(positionX, rangeStartX), rangeEndX)
        }

        func currentClipTime() -> Double {
            max(clampedCurrentTime - playbackRange.lowerBound, 0)
        }

        func playbackTime(for locationX: CGFloat) -> Double {
            guard width > 0, duration > 0 else {
                return playbackRange.lowerBound
            }

            let clampedX = min(max(locationX, 0), width)
            let progress = clampedX / width
            let time = Double(progress) * duration

            return time.clamped(to: playbackRange)
        }

        func badgePositionX(for badgeWidth: CGFloat, minimumHalfWidth: CGFloat = 24) -> CGFloat {
            let badgeHalfWidth = max(badgeWidth / 2, minimumHalfWidth)

            return min(
                max(playbackPositionX(), badgeHalfWidth),
                max(width - badgeHalfWidth, badgeHalfWidth)
            )
        }

    }

#endif
