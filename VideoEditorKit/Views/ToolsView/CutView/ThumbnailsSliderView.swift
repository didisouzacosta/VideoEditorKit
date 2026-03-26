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
    private var totalDuration: Double {
        rangeDuration.upperBound - rangeDuration.lowerBound
    }

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
        .frame(height: 80)
    }

    private var footerSection: some View {
        HStack(spacing: 8) {
            if let video {
                footerTime(title: "Start", value: video.rangeDuration.lowerBound, alignment: .leading)
                Spacer()
                footerTime(title: "End", value: video.rangeDuration.upperBound, alignment: .trailing)
            }
        }
        .padding(.horizontal)
    }

    private var timelineBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground).opacity(0.5))
    }

    // MARK: - Private Methods

    private func timeChip(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.secondary)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(uiColor: .systemBackground).opacity(0.75), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Theme.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func footerTime(title: String, value: Double, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.secondary)

            Text(value.formatterTimeString())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primary)
        }
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .overlay {
                        ProgressView()
                    }
            } else {
                HStack(spacing: 0) {
                    ForEach(video.thumbnailsImages) { trimData in
                        if let image = trimData.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: proxy.size.width / CGFloat(video.thumbnailsImages.count),
                                    height: proxy.size.height
                                )
                                .clipped()
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func playbackIndicator(_ proxy: GeometryProxy, video: Video) -> some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .frame(width: 36, height: proxy.size.height + 20)

            Capsule(style: .continuous)
                .fill(.red)
                .frame(width: 4, height: proxy.size.height + 10)
        }
        .contentShape(Rectangle())
        .position(
            x: playbackPositionX(for: video, width: proxy.size.width),
            y: proxy.size.height / 2
        )
        .gesture(playbackIndicatorGesture(video: video, width: proxy.size.width))
    }

    private func playheadBadge(_ proxy: GeometryProxy, video: Video) -> some View {
        let clampedX = min(max(playbackPositionX(for: video, width: proxy.size.width), 42), proxy.size.width - 42)

        return Text(currentClipTime(for: video).formatterTimeString())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.72), in: Capsule(style: .continuous))
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
