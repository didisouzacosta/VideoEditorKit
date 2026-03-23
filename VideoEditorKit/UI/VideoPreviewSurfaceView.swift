import AVFoundation
import Foundation
import SwiftUI
import UIKit

struct VideoPreviewSurfaceView: View {
    let sourceVideoURL: URL
    let gravity: VideoGravity
    let currentTime: Double
    let isPlaying: Bool
    let onPlaybackTimeUpdate: (Double) -> Void

    @State private var playbackCoordinator: VideoPreviewPlaybackCoordinator

    init(
        sourceVideoURL: URL,
        gravity: VideoGravity,
        currentTime: Double,
        isPlaying: Bool,
        onPlaybackTimeUpdate: @escaping (Double) -> Void
    ) {
        self.sourceVideoURL = sourceVideoURL
        self.gravity = gravity
        self.currentTime = currentTime
        self.isPlaying = isPlaying
        self.onPlaybackTimeUpdate = onPlaybackTimeUpdate
        _playbackCoordinator = State(
            initialValue: VideoPreviewPlaybackCoordinator(
                onTimeUpdate: onPlaybackTimeUpdate
            )
        )
    }

    var body: some View {
        VideoPreviewPlayerLayerView(
            player: playbackCoordinator.player,
            gravity: gravity
        )
        .background(Color.black)
        .task(id: sourceVideoURL) {
            guard canLoadSourceVideoURL else {
                return
            }

            playbackCoordinator.loadVideoIfNeeded(from: sourceVideoURL)
            playbackCoordinator.sync(currentTime: currentTime, isPlaying: isPlaying)
        }
        .onChange(of: currentTime) { _, newValue in
            playbackCoordinator.sync(currentTime: newValue, isPlaying: isPlaying)
        }
        .onChange(of: isPlaying) { _, newValue in
            playbackCoordinator.sync(currentTime: currentTime, isPlaying: newValue)
        }
        .accessibilityHidden(true)
    }
}

private extension VideoPreviewSurfaceView {
    var canLoadSourceVideoURL: Bool {
        sourceVideoURL.isFileURL && FileManager.default.fileExists(atPath: sourceVideoURL.path)
    }
}

private struct VideoPreviewPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let gravity: VideoGravity

    func makeUIView(context: Context) -> VideoPreviewPlayerContainerView {
        let view = VideoPreviewPlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity.avLayerVideoGravity
        return view
    }

    func updateUIView(
        _ uiView: VideoPreviewPlayerContainerView,
        context: Context
    ) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = gravity.avLayerVideoGravity
    }
}

private final class VideoPreviewPlayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        guard let playerLayer = layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer backing layer.")
        }

        return playerLayer
    }
}

private extension VideoGravity {
    var avLayerVideoGravity: AVLayerVideoGravity {
        switch self {
        case .fit:
            .resizeAspect
        case .fill:
            .resizeAspectFill
        }
    }
}

#Preview("Fit") {
    VideoPreviewSurfaceView(
        sourceVideoURL: URL(fileURLWithPath: "/tmp/missing-preview.mov"),
        gravity: .fit,
        currentTime: 0,
        isPlaying: false,
        onPlaybackTimeUpdate: { _ in }
    )
    .frame(width: 320, height: 180)
    .background(.black)
}

#Preview("Fill") {
    VideoPreviewSurfaceView(
        sourceVideoURL: URL(fileURLWithPath: "/tmp/missing-preview.mov"),
        gravity: .fill,
        currentTime: 0,
        isPlaying: false,
        onPlaybackTimeUpdate: { _ in }
    )
    .frame(width: 220, height: 360)
    .background(.black)
}
