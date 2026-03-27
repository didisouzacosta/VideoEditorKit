//
//  ThumbnailsSliderView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct ThumbnailsSliderView: View {

    // MARK: - Bindings

    @Binding private var currentTime: Double
    @Binding private var video: Video?

    // MARK: - States

    @State private var rangeDuration: ClosedRange<Double> = 0...1
    @State private var isScrubbingPlaybackIndicator = false
    @State private var playbackScrubStartSourceTime: Double?
    @State private var isSynchronizingAnchoredPlayback = false
    @State private var playheadBadgeWidth: CGFloat = 84

    // MARK: - Private Properties

    private let isPlaying: Bool
    private let isChangeState: Bool?
    private let onPlayPauseTapped: () -> Void
    private let onChangeTimeValue: (ClosedRange<Double>) -> Void
    private let onRequestThumbnails: (CGSize) -> Void
    private let onPlaybackScrubStarted: (ClosedRange<Double>) -> Void
    private let onPlaybackScrubChanged: (Double, ClosedRange<Double>) -> Void
    private let onPlaybackScrubEnded: (Double, ClosedRange<Double>) -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 32) {
            Button {
                onPlayPauseTapped()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: timelineHeight, height: timelineHeight)
                    .circleControl()
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                timelineSection
                footerSection
            }
            .padding(.trailing, 8)
            .disabled(isPlaying)
        }
        .onChange(of: isChangeState) { _, isChange in
            guard let isChange, !isChange else { return }
            setVideoRange()
        }
        .onChange(of: video?.id) { _, _ in
            setVideoRange()
        }
        .onChange(of: rangeDuration) { oldRange, newRange in
            syncAnchoredPlaybackIfNeeded(from: oldRange, to: newRange)
        }
    }

    // MARK: - Private Properties

    private let handleInnerInset: CGFloat = 4
    private let playheadLineWidth: CGFloat = 2
    private let playheadLabelHeight: CGFloat = 28
    private let timelineHeight: CGFloat = 60
    private let minimumClipDuration: Double = 3

    // MARK: - Initializer

    init(
        _ currentTime: Binding<Double>,
        video: Binding<Video?>,
        isPlaying: Bool,
        isChangeState: Bool? = nil,
        onPlayPauseTapped: @escaping () -> Void,
        onChangeTimeValue: @escaping (ClosedRange<Double>) -> Void,
        onRequestThumbnails: @escaping (CGSize) -> Void,
        onPlaybackScrubStarted: @escaping (ClosedRange<Double>) -> Void,
        onPlaybackScrubChanged: @escaping (Double, ClosedRange<Double>) -> Void,
        onPlaybackScrubEnded: @escaping (Double, ClosedRange<Double>) -> Void
    ) {
        _currentTime = currentTime
        _video = video

        self.isPlaying = isPlaying
        self.isChangeState = isChangeState
        self.onPlayPauseTapped = onPlayPauseTapped
        self.onChangeTimeValue = onChangeTimeValue
        self.onRequestThumbnails = onRequestThumbnails
        self.onPlaybackScrubStarted = onPlaybackScrubStarted
        self.onPlaybackScrubChanged = onPlaybackScrubChanged
        self.onPlaybackScrubEnded = onPlaybackScrubEnded
    }

}

extension ThumbnailsSliderView {

    // MARK: - Private Properties

    @ViewBuilder
    private var timelineSection: some View {
        VStack(spacing: 4) {
            if let video {
                GeometryReader { proxy in
                    playheadBadge(proxy, video: video)
                }
                .frame(height: playheadLabelHeight)
            }

            GeometryReader { proxy in
                ZStack {
                    timelineBackground
                    thumbnailsImagesSection(proxy)

                    if let video {
                        playbackIndicator(proxy, video: video)
                            .zIndex(999)

                        RangedSliderView(
                            $rangeDuration,
                            bounds: 0...video.originalDuration,
                            step: 0.001,
                            minimumDistance: min(minimumClipDuration, video.originalDuration),
                            onEndChange: commitRangeChange
                        )
                    }
                }
                .onAppear {
                    setVideoRange()
                }
                .task(id: thumbnailRequestID(for: proxy.size)) {
                    onRequestThumbnails(proxy.size)
                }
            }
            .frame(height: timelineHeight)
        }
    }

    private var footerSection: some View {
        HStack(spacing: 8) {
            if let video {
                let playbackRange = outputRange(for: video, sourceRange: rangeDuration)

                footerTime(playbackRange.lowerBound)
                Spacer()
                footerTime(playbackRange.upperBound)
            }
        }
        .padding(.horizontal, 4)
    }

    private var timelineBackground: some View {
        Rectangle()
            .fill(Color(uiColor: .secondarySystemBackground).opacity(0.5))
    }

    // MARK: - Private Methods

    private func footerTime(_ value: Double) -> some View {
        Text(value.formatterTimeString())
            .foregroundStyle(Theme.primary)
            .font(.caption2.weight(.medium))
    }

    private func syncAnchoredPlaybackIfNeeded(
        from oldRange: ClosedRange<Double>,
        to newRange: ClosedRange<Double>
    ) {
        guard let video else { return }
        guard video.rangeDuration != newRange else { return }
        guard oldRange != newRange else { return }

        let previousOutputRange = outputRange(for: video, sourceRange: oldRange)
        let newOutputRange = outputRange(for: video, sourceRange: newRange)

        if currentTime < newOutputRange.lowerBound {
            beginAnchoredPlaybackSynchronizationIfNeeded(previousOutputRange)
            currentTime = newOutputRange.lowerBound
            onPlaybackScrubChanged(newOutputRange.lowerBound, newOutputRange)
            return
        }

        if currentTime > newOutputRange.upperBound {
            beginAnchoredPlaybackSynchronizationIfNeeded(previousOutputRange)
            currentTime = newOutputRange.upperBound
            onPlaybackScrubChanged(newOutputRange.upperBound, newOutputRange)
        }
    }

    private func beginAnchoredPlaybackSynchronizationIfNeeded(_ range: ClosedRange<Double>) {
        guard !isSynchronizingAnchoredPlayback else { return }

        isSynchronizingAnchoredPlayback = true
        onPlaybackScrubStarted(range)
    }

    private func setVideoRange() {
        if let video {
            rangeDuration = video.rangeDuration
        }
    }

    private func commitRangeChange() {
        guard let video else { return }

        self.video?.rangeDuration = rangeDuration

        guard let updatedVideo = self.video else { return }
        let updatedOutputRange = updatedVideo.outputRangeDuration

        if isSynchronizingAnchoredPlayback {
            onPlaybackScrubEnded(currentTime, updatedOutputRange)
            isSynchronizingAnchoredPlayback = false
        }

        guard video.rangeDuration != rangeDuration else { return }

        onChangeTimeValue(updatedOutputRange)
    }

    @ViewBuilder
    private func thumbnailsImagesSection(_ proxy: GeometryProxy) -> some View {
        if let video {
            if video.thumbnailsImages.isEmpty {
                ProgressView()
            } else {
                HStack(spacing: 0) {
                    ForEach(video.thumbnailsImages) { trimData in
                        thumbnailCell(
                            trimData,
                            in: proxy.size,
                            thumbnailCount: video.thumbnailsImages.count
                        )
                    }
                }
            }
        }
    }

    private func playbackIndicator(
        _ proxy: GeometryProxy,
        video: Video
    ) -> some View {
        let metrics = timelineMetrics(for: video, width: proxy.size.width)

        return Capsule(style: .continuous)
            .fill(.blue)
            .frame(width: playheadLineWidth, height: proxy.size.height + 10)
            .position(
                x: metrics.playbackPositionX(),
                y: proxy.size.height / 2
            )
            .allowsHitTesting(false)
    }

    private func playheadBadge(_ proxy: GeometryProxy, video: Video) -> some View {
        let metrics = timelineMetrics(for: video, width: proxy.size.width)
        let clampedX = metrics.badgePositionX(for: playheadBadgeWidth)
        let playbackRange = video.outputRangeDuration
        let currentClipTime = max(currentTime.clamped(to: playbackRange) - playbackRange.lowerBound, 0)
        let clipDuration = playbackRange.upperBound - playbackRange.lowerBound

        return Text("\(currentClipTime.formatterTimeString()) / \(clipDuration.formatterTimeString())")
            .font(.caption2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .capsuleControl()
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: PlayheadBadgeWidthPreferenceKey.self, value: geometry.size.width)
                }
            }
            .onPreferenceChange(PlayheadBadgeWidthPreferenceKey.self) { width in
                playheadBadgeWidth = width
            }
            .position(x: clampedX, y: 12)
            .gesture(
                playbackIndicatorGesture(
                    video: video,
                    width: proxy.size.width
                )
            )
    }

    private func playbackIndicatorGesture(
        video: Video,
        width: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isScrubbingPlaybackIndicator {
                    isScrubbingPlaybackIndicator = true
                    playbackScrubStartSourceTime = sourceTime(for: video, timelineTime: currentTime)
                    onPlaybackScrubStarted(video.outputRangeDuration)
                }

                let scrubTime = playbackTime(
                    for: gesture.translation.width,
                    startingAt: playbackScrubStartSourceTime ?? sourceTime(for: video, timelineTime: currentTime),
                    video: video,
                    width: width
                )
                currentTime = scrubTime
                onPlaybackScrubChanged(scrubTime, video.outputRangeDuration)
            }
            .onEnded { gesture in
                let scrubTime = playbackTime(
                    for: gesture.translation.width,
                    startingAt: playbackScrubStartSourceTime ?? sourceTime(for: video, timelineTime: currentTime),
                    video: video,
                    width: width
                )
                currentTime = scrubTime
                isScrubbingPlaybackIndicator = false
                playbackScrubStartSourceTime = nil
                onPlaybackScrubEnded(scrubTime, video.outputRangeDuration)
            }
    }

    private func playbackTime(
        for translationWidth: CGFloat,
        startingAt startSourceTime: Double,
        video: Video,
        width: CGFloat
    ) -> Double {
        guard width > 0, video.originalDuration > 0 else {
            return video.outputRangeDuration.lowerBound
        }

        let deltaSourceTime = Double(translationWidth / width) * video.originalDuration
        let sourceTime = (startSourceTime + deltaSourceTime).clamped(to: rangeDuration)

        return PlaybackTimeMapping.timelineTime(fromSourceTime: sourceTime, rate: video.rate)
    }

    private func thumbnailRequestID(for size: CGSize) -> String {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        let videoID = video?.id.uuidString ?? "none"
        return "\(videoID)-\(width)-\(height)"
    }

    @ViewBuilder
    private func thumbnailCell(
        _ trimData: ThumbnailImage,
        in size: CGSize,
        thumbnailCount: Int
    ) -> some View {
        let width = size.width / CGFloat(max(thumbnailCount, 1))
        let height = size.height

        Group {
            if let image = trimData.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.tertiary)
            }
        }
        .frame(
            width: width,
            height: height
        )
        .clipped()
    }

    private func timelineMetrics(
        for video: Video,
        width: CGFloat
    ) -> TimelineMetrics {
        TimelineMetrics(
            duration: video.originalDuration,
            playbackRange: rangeDuration,
            currentTime: sourceTime(for: video, timelineTime: currentTime),
            width: width,
            handleInset: handleInnerInset
        )
    }

    private func outputRange(
        for video: Video,
        sourceRange: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        PlaybackTimeMapping.scaledTimelineRange(
            sourceRange: sourceRange,
            rate: video.rate,
            originalDuration: video.originalDuration
        )
    }

    private func sourceTime(
        for video: Video,
        timelineTime: Double
    ) -> Double {
        PlaybackTimeMapping.sourceTime(
            forTimelineTime: timelineTime,
            rate: video.rate,
            originalDuration: video.originalDuration
        )
        .clamped(to: rangeDuration)
    }

}

private struct PlayheadBadgeWidthPreferenceKey: PreferenceKey {

    static let defaultValue: CGFloat = 84

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }

}

#Preview {
    ThumbnailsSliderView(
        .constant(0),
        video: .constant(Video.mock),
        isPlaying: false,
        isChangeState: nil,
        onPlayPauseTapped: {},
        onChangeTimeValue: { _ in },
        onRequestThumbnails: { _ in },
        onPlaybackScrubStarted: { _ in },
        onPlaybackScrubChanged: { _, _ in },
        onPlaybackScrubEnded: { _, _ in }
    )
}
