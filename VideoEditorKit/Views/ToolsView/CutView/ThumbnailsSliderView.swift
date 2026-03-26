//
//  ThumbnailsSliderView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import SwiftUI

struct ThumbnailsSliderView: View {

    // MARK: - Bindings

    @Binding private var currentTime: Double
    @Binding private var video: Video?

    // MARK: - States

    @State private var rangeDuration: ClosedRange<Double> = 0...1
    @State private var isScrubbingPlaybackIndicator = false

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
    }

    // MARK: - Private Properties

    private let handleInnerInset: CGFloat = 4
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
                            .zIndex(9)

                        RangedSliderView(
                            $rangeDuration,
                            bounds: 0...video.originalDuration,
                            step: 0.001,
                            onEndChange: {}
                        )
                        .onChange(of: rangeDuration) { _, newValue in
                            self.video?.rangeDuration = newValue
                            onChangeTimeValue(newValue)
                        }
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
                footerTime(
                    video.rangeDuration.lowerBound,
                    alignment: .leading
                )
                Spacer()
                footerTime(
                    video.rangeDuration.upperBound,
                    alignment: .trailing
                )
            }
        }
        .padding(.horizontal, 4)
    }

    private var timelineBackground: some View {
        Rectangle()
            .fill(Color(uiColor: .secondarySystemBackground).opacity(0.5))
    }

    // MARK: - Private Methods

    private func footerTime(
        _ value: Double,
        alignment: HorizontalAlignment
    ) -> some View {
        Text(value.formatterTimeString())
            .foregroundStyle(Theme.primary)
            .font(.caption2.weight(.medium))
    }

    private func setVideoRange() {
        if let video {
            rangeDuration = video.rangeDuration
        }
    }

    @ViewBuilder
    private func thumbnailsImagesSection(_ proxy: GeometryProxy) -> some View {
        if let video {
            if video.thumbnailsImages.isEmpty {
                Rectangle()
                    .fill(.tertiary)
                    .overlay {
                        ProgressView()
                    }
            } else {
                HStack(spacing: 0) {
                    ForEach(video.thumbnailsImages) { trimData in
                        if let image = trimData.image {
                            let width = proxy.size.width / CGFloat(video.thumbnailsImages.count)
                            let height = proxy.size.height
                            
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: width,
                                    height: height
                                )
                                .clipped()
                        }
                    }
                }
            }
        }
    }

    private func playbackIndicator(_ proxy: GeometryProxy, video: Video) -> some View {
        Capsule(style: .continuous)
            .fill(.red)
            .frame(width: 4, height: proxy.size.height + 10)
            .position(
                x: playbackPositionX(for: video, width: proxy.size.width),
                y: proxy.size.height / 2
            )
            .gesture(playbackIndicatorGesture(video: video, width: proxy.size.width))
    }

    private func playheadBadge(_ proxy: GeometryProxy, video: Video) -> some View {
        let clampedX = min(max(playbackPositionX(for: video, width: proxy.size.width), 42), proxy.size.width - 42)

        return Text("\(currentClipTime(for: video).formatterTimeString()) / \(video.totalDuration.formatterTimeString())")
            .font(.caption2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .capsuleControl()
            .position(x: clampedX, y: 12)
            .allowsHitTesting(false)
    }

    private func playbackPositionX(for video: Video, width: CGFloat) -> CGFloat {
        guard video.originalDuration > 0, width > 0 else { return 2 }
        let clampedTime = currentTime.clamped(to: video.rangeDuration)
        let rangeStartX = (CGFloat(video.rangeDuration.lowerBound / video.originalDuration) * width) + handleInnerInset
        let rangeEndX = (CGFloat(video.rangeDuration.upperBound / video.originalDuration) * width) - handleInnerInset

        guard rangeEndX > rangeStartX else {
            return min(max(rangeStartX, 2), width - 2)
        }

        let absoluteProgress = clampedTime / video.originalDuration
        let positionX = CGFloat(absoluteProgress) * width

        return min(max(positionX, rangeStartX), rangeEndX)
    }

    private func currentClipTime(for video: Video) -> Double {
        let displayTime = currentTime.clamped(to: video.rangeDuration)
        return max(displayTime - video.rangeDuration.lowerBound, 0)
    }

    private func playbackIndicatorGesture(video: Video, width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isScrubbingPlaybackIndicator {
                    isScrubbingPlaybackIndicator = true
                    onPlaybackScrubStarted(video.rangeDuration)
                }

                let scrubTime = playbackTime(for: gesture.location.x, video: video, width: width)
                currentTime = scrubTime
                onPlaybackScrubChanged(scrubTime, video.rangeDuration)
            }
            .onEnded { gesture in
                let scrubTime = playbackTime(for: gesture.location.x, video: video, width: width)
                currentTime = scrubTime
                isScrubbingPlaybackIndicator = false
                onPlaybackScrubEnded(scrubTime, video.rangeDuration)
            }
    }

    private func playbackTime(for locationX: CGFloat, video: Video, width: CGFloat) -> Double {
        guard width > 0, video.originalDuration > 0 else {
            return video.rangeDuration.lowerBound
        }

        let clampedX = min(max(locationX, 0), width)
        let progress = clampedX / width
        let time = Double(progress) * video.originalDuration

        return time.clamped(to: video.rangeDuration)
    }

    private func thumbnailRequestID(for size: CGSize) -> String {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        let videoID = video?.id.uuidString ?? "none"
        return "\(videoID)-\(width)-\(height)"
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
