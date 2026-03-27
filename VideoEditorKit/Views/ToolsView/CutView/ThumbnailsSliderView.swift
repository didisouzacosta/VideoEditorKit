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
    @State private var playbackScrubStartTime: Double?
    @State private var isSynchronizingAnchoredPlayback = false
    @State private var playheadBadgeWidth: CGFloat = 84

    // MARK: - Private Properties

    private let isChangeState: Bool?
    private let onChangeTimeValue: (ClosedRange<Double>) -> Void
    private let onRequestThumbnails: (CGSize) -> Void
    private let onPlaybackScrubStarted: (ClosedRange<Double>) -> Void
    private let onPlaybackScrubChanged: (Double, ClosedRange<Double>) -> Void
    private let onPlaybackScrubEnded: (Double, ClosedRange<Double>) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            timelineSection
            footerSection
        }
        .onChange(of: isChangeState) { _, isChange in
            if !(isChange ?? true) {
                setVideoRange()
            }
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

    // MARK: - Initializer

    init(
        _ currentTime: Binding<Double>,
        video: Binding<Video?>,
        isChangeState: Bool? = nil,
        onChangeTimeValue: @escaping (ClosedRange<Double>) -> Void,
        onRequestThumbnails: @escaping (CGSize) -> Void,
        onPlaybackScrubStarted: @escaping (ClosedRange<Double>) -> Void,
        onPlaybackScrubChanged: @escaping (Double, ClosedRange<Double>) -> Void,
        onPlaybackScrubEnded: @escaping (Double, ClosedRange<Double>) -> Void
    ) {
        _currentTime = currentTime
        _video = video

        self.isChangeState = isChangeState
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
                    playheadBadge(proxy, video: video, range: rangeDuration)
                }
                .frame(height: playheadLabelHeight)
            }

            GeometryReader { proxy in
                ZStack {
                    timelineBackground
                    thumbnailsImagesSection(proxy)

                    if let video {
                        playbackIndicator(proxy, video: video, range: rangeDuration)
                            .zIndex(999)

                        RangedSliderView(
                            $rangeDuration,
                            bounds: 0...video.originalDuration,
                            step: 0.001,
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
            if video != nil {
                footerTime(rangeDuration.lowerBound)
                Spacer()
                footerTime(rangeDuration.upperBound)
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
        guard video?.rangeDuration != newRange else { return }

        let tolerance = 0.001

        if abs(currentTime - oldRange.lowerBound) <= tolerance, oldRange.lowerBound != newRange.lowerBound {
            beginAnchoredPlaybackSynchronizationIfNeeded(oldRange)
            currentTime = newRange.lowerBound
            onPlaybackScrubChanged(newRange.lowerBound, newRange)
            return
        }

        if abs(currentTime - oldRange.upperBound) <= tolerance, oldRange.upperBound != newRange.upperBound {
            beginAnchoredPlaybackSynchronizationIfNeeded(oldRange)
            currentTime = newRange.upperBound
            onPlaybackScrubChanged(newRange.upperBound, newRange)
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
        if isSynchronizingAnchoredPlayback {
            onPlaybackScrubEnded(currentTime, rangeDuration)
            isSynchronizingAnchoredPlayback = false
        }

        guard let video else { return }
        guard video.rangeDuration != rangeDuration else { return }

        self.video?.rangeDuration = rangeDuration
        onChangeTimeValue(rangeDuration)
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
        video: Video,
        range: ClosedRange<Double>
    ) -> some View {
        let metrics = timelineMetrics(for: video, range: range, width: proxy.size.width)

        return Capsule(style: .continuous)
            .fill(.blue)
            .frame(width: playheadLineWidth, height: proxy.size.height + 10)
            .position(
                x: metrics.playbackPositionX(),
                y: proxy.size.height / 2
            )
            .allowsHitTesting(false)
    }

    private func playheadBadge(_ proxy: GeometryProxy, video: Video, range: ClosedRange<Double>) -> some View {
        let metrics = timelineMetrics(for: video, range: range, width: proxy.size.width)
        let clampedX = metrics.badgePositionX(for: playheadBadgeWidth)
        let clipDuration = range.upperBound - range.lowerBound

        return Text("\(metrics.currentClipTime().formatterTimeString()) / \(clipDuration.formatterTimeString())")
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
                    range: range,
                    width: proxy.size.width
                )
            )
    }

    private func playbackIndicatorGesture(
        video: Video,
        range: ClosedRange<Double>,
        width: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isScrubbingPlaybackIndicator {
                    isScrubbingPlaybackIndicator = true
                    playbackScrubStartTime = currentTime.clamped(to: range)
                    onPlaybackScrubStarted(range)
                }

                let scrubTime = playbackTime(
                    for: gesture.translation.width,
                    startingAt: playbackScrubStartTime ?? currentTime,
                    video: video,
                    range: range,
                    width: width
                )
                currentTime = scrubTime
                onPlaybackScrubChanged(scrubTime, range)
            }
            .onEnded { gesture in
                let scrubTime = playbackTime(
                    for: gesture.translation.width,
                    startingAt: playbackScrubStartTime ?? currentTime,
                    video: video,
                    range: range,
                    width: width
                )
                currentTime = scrubTime
                isScrubbingPlaybackIndicator = false
                playbackScrubStartTime = nil
                onPlaybackScrubEnded(scrubTime, range)
            }
    }

    private func playbackTime(
        for translationWidth: CGFloat,
        startingAt startTime: Double,
        video: Video,
        range: ClosedRange<Double>,
        width: CGFloat
    ) -> Double {
        guard width > 0, video.originalDuration > 0 else {
            return range.lowerBound
        }

        let deltaTime = Double(translationWidth / width) * video.originalDuration
        return (startTime + deltaTime).clamped(to: range)
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
        range: ClosedRange<Double>,
        width: CGFloat
    ) -> TimelineMetrics {
        TimelineMetrics(
            originalDuration: video.originalDuration,
            playbackRange: range,
            currentTime: currentTime,
            width: width,
            handleInset: handleInnerInset
        )
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
        isChangeState: nil,
        onChangeTimeValue: { _ in },
        onRequestThumbnails: { _ in },
        onPlaybackScrubStarted: { _ in },
        onPlaybackScrubChanged: { _, _ in },
        onPlaybackScrubEnded: { _, _ in }
    )
}
