//
//  ThumbnailsSliderView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import SwiftUI

struct ThumbnailsSliderView: View {
    private enum InteractionMode {
        case scrub
        case trim
    }

    @State var rangeDuration: ClosedRange<Double> = 0...1
    @Binding var currentTime: Double
    @Binding var video: Video?
    var isChangeState: Bool?
    let onChangeTimeValue: () -> Void
    let onRequestThumbnails: (CGSize) -> Void
    @State private var interactionMode: InteractionMode?

    private var totalDuration: Double {
        rangeDuration.upperBound - rangeDuration.lowerBound
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(totalDuration.formatterTimeString())
                .font(.subheadline)

            GeometryReader { proxy in
                ZStack {
                    thumbnailsImagesSection(proxy)
                    playbackIndicator(proxy)

                    if let video {
                        RangedSliderView(
                            value: $rangeDuration,
                            bounds: 0...video.originalDuration,
                            onEndChange: {}
                        ) {
                            Rectangle().blendMode(.destinationOut)
                        }
                        .onChange(of: self.video?.rangeDuration.upperBound) { _, upperBound in
                            if let upperBound {
                                currentTime = Double(upperBound)
                                onChangeTimeValue()
                            }
                        }
                        .onChange(of: self.video?.rangeDuration.lowerBound) { _, lowerBound in
                            if let lowerBound {
                                currentTime = Double(lowerBound)
                                onChangeTimeValue()
                            }
                        }
                        .onChange(of: rangeDuration) { _, newValue in
                            self.video?.rangeDuration = newValue
                            currentTime = currentTime.clamped(to: newValue)
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if interactionMode == nil {
                                interactionMode = resolveInteractionMode(
                                    startLocationX: value.startLocation.x,
                                    width: proxy.size.width
                                )
                            }

                            guard interactionMode == .scrub else { return }
                            updatePlaybackPosition(for: value.location.x, width: proxy.size.width)
                        }
                        .onEnded { _ in
                            interactionMode = nil
                        }
                )
                .onAppear {
                    setVideoRange()
                }
                .task(id: thumbnailRequestID(for: proxy.size)) {
                    onRequestThumbnails(proxy.size)
                }
            }
            .frame(height: 70)
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
}

struct ThumbnailsSliderView_Previews: PreviewProvider {
    static var previews: some View {
        ThumbnailsSliderView(
            currentTime: .constant(0),
            video: .constant(Video.mock),
            isChangeState: nil,
            onChangeTimeValue: {},
            onRequestThumbnails: { _ in }
        )
    }
}

extension ThumbnailsSliderView {
    private func setVideoRange() {
        if let video {
            rangeDuration = video.rangeDuration
        }
    }

    @ViewBuilder
    private func thumbnailsImagesSection(_ proxy: GeometryProxy) -> some View {
        if let video {
            if video.thumbnailsImages.isEmpty {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .overlay {
                        ProgressView()
                            .tint(Theme.accent)
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
                                    height: proxy.size.height - 5
                                )
                                .clipped()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func playbackIndicator(_ proxy: GeometryProxy) -> some View {
        if let video {
            Capsule()
                .fill(Theme.accent)
                .frame(width: 4, height: proxy.size.height + 8)
                .shadow(color: Theme.primary.opacity(0.25), radius: 4)
                .position(
                    x: playbackPositionX(for: video, width: proxy.size.width),
                    y: proxy.size.height / 2
                )
        }
    }

    private func playbackPositionX(for video: Video, width: CGFloat) -> CGFloat {
        guard video.originalDuration > 0, width > 0 else { return 2 }
        let clampedTime = currentTime.clamped(to: video.rangeDuration)
        let progress = clampedTime / video.originalDuration
        return min(max(width * progress, 2), width - 2)
    }

    private func updatePlaybackPosition(for locationX: CGFloat, width: CGFloat) {
        guard let video, width > 0 else { return }
        let progress = min(max(locationX / width, 0), 1)
        let rawTime = progress * video.originalDuration
        currentTime = rawTime.clamped(to: video.rangeDuration)
        onChangeTimeValue()
    }

    private func resolveInteractionMode(startLocationX: CGFloat, width: CGFloat) -> InteractionMode {
        guard let video, width > 0, video.originalDuration > 0 else { return .scrub }

        let lowerProgress = video.rangeDuration.lowerBound / video.originalDuration
        let upperProgress = video.rangeDuration.upperBound / video.originalDuration
        let lowerHandleX = width * lowerProgress
        let upperHandleX = width * upperProgress
        let trimHandleHitArea: CGFloat = 28

        if abs(startLocationX - lowerHandleX) <= trimHandleHitArea
            || abs(startLocationX - upperHandleX) <= trimHandleHitArea
        {
            return .trim
        }

        return .scrub
    }

    private func thumbnailRequestID(for size: CGSize) -> String {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        let videoID = video?.id.uuidString ?? "none"
        return "\(videoID)-\(width)-\(height)"
    }
}
