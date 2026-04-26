//
//  EditedVideoProjectCard.swift
//  VideoEditorKit
//
//  Created by Codex on 28.03.2026.
//

import AVKit
import ImageIO
import SwiftUI
import UIKit
import VideoEditorKit

struct EditedVideoProjectCard: View {

    // MARK: - Public Properties

    let project: EditedVideoProject
    let onOpenProject: () -> Void
    let onShareSavedVideo: () -> Void
    let onDelete: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: onOpenProject) {
            thumbnailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    if project.duration > 0 {
                        durationBadge
                            .padding(6)
                            .allowsHitTesting(false)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .clipShape(cardShape)
        .overlay {
            cardShape
                .stroke(Theme.outline, lineWidth: 1)
        }
        .contentShape(cardShape)
        .contextMenu {
            Button(action: onOpenProject) {
                Label(
                    SavedVideoContextMenuActionPresentation.open.title,
                    systemImage: SavedVideoContextMenuActionPresentation.open.systemImage
                )
            }

            Button(action: onShareSavedVideo) {
                Label(
                    SavedVideoContextMenuActionPresentation.share.title,
                    systemImage: SavedVideoContextMenuActionPresentation.share.systemImage
                )
            }
            .disabled(project.canShareSavedVideo == false)

            Button(role: SavedVideoContextMenuActionPresentation.delete.role, action: onDelete) {
                Label(
                    SavedVideoContextMenuActionPresentation.delete.title,
                    systemImage: SavedVideoContextMenuActionPresentation.delete.systemImage
                )
            }
        } preview: {
            projectPreview
        }
    }

    // MARK: - Private Properties

    private let cornerRadius: CGFloat = 16

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var durationBadge: some View {
        Text(project.duration.formatterTimeString())
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.78), in: Capsule())
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let resolvedThumbnailImage {
            Rectangle()
                .overlay {
                    Image(decorative: resolvedThumbnailImage, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.black, Theme.secondary.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: project.hasExportedVideo ? "play.rectangle.fill" : "square.and.pencil")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
        }
    }

    private var resolvedThumbnailImage: CGImage? {
        guard let thumbnailData = project.thumbnailData else { return nil }
        guard
            let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil)
        else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }

    @ViewBuilder
    private var projectPreview: some View {
        if let url = project.savedPlaybackVideoURL {
            SavedVideoContextPreview(url: url)
                .id(project.savedPlaybackPreviewIdentity)
        } else {
            thumbnailContent
                .frame(width: 260, height: 260)
        }
    }

}

enum SavedVideoContextMenuActionPresentation: CaseIterable, Equatable {

    // MARK: - Public Properties

    case open
    case share
    case delete

    var title: String {
        switch self {
        case .open:
            ExampleStrings.projectOpen
        case .share:
            ExampleStrings.projectShare
        case .delete:
            ExampleStrings.projectDelete
        }
    }

    var systemImage: String {
        switch self {
        case .open:
            "rectangle.portrait.and.arrow.right"
        case .share:
            "square.and.arrow.up"
        case .delete:
            "trash"
        }
    }

    var role: ButtonRole? {
        switch self {
        case .open, .share:
            nil
        case .delete:
            .destructive
        }
    }

}

private struct SavedVideoContextPreview: View {

    // MARK: - States

    @State private var player: AVPlayer

    // MARK: - Public Properties

    let url: URL

    // MARK: - Body

    var body: some View {
        AspectFillVideoPlayer(player: player)
            .frame(
                width: SavedVideoContextPreviewPresentation.previewSize.width,
                height: SavedVideoContextPreviewPresentation.previewSize.height
            )
            .clipped()
            .task {
                player.isMuted = true
                player.seek(to: .zero)
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }

    // MARK: - Initializer

    init(url: URL) {
        self.url = url

        _player = State(initialValue: AVPlayer(url: url))
    }

}

enum SavedVideoContextPreviewPresentation {

    // MARK: - Public Properties

    static let previewSize = CGSize(width: 260, height: 320)
    static let videoGravity: AVLayerVideoGravity = .resizeAspectFill

}

private struct AspectFillVideoPlayer: UIViewRepresentable {

    // MARK: - Public Properties

    let player: AVPlayer

    // MARK: - Public Methods

    func makeUIView(context: Context) -> AspectFillPlayerView {
        let view = AspectFillPlayerView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: AspectFillPlayerView, context: Context) {
        uiView.player = player
    }

}

private final class AspectFillPlayerView: UIView {

    // MARK: - Public Properties

    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var player: AVPlayer? {
        get {
            playerLayer?.player
        }
        set {
            guard let playerLayer else { return }

            playerLayer.player = newValue
            playerLayer.videoGravity = SavedVideoContextPreviewPresentation.videoGravity
        }
    }

    // MARK: - Private Properties

    private var playerLayer: AVPlayerLayer? {
        layer as? AVPlayerLayer
    }

}

@MainActor
private enum EditedVideoProjectCardPreviewFixture {

    // MARK: - Private Properties

    static let project = EditedVideoProject(
        createdAt: .now,
        updatedAt: .now,
        displayName: "Preview Clip",
        originalVideoFileName: "original.mp4",
        exportedVideoFileName: "exported.mp4",
        editingConfigurationData: encodedEditingConfiguration,
        thumbnailData: thumbnailData,
        duration: 24,
        width: 1080,
        height: 1080,
        fileSize: 5_242_880
    )

    private static let encodedEditingConfiguration =
        (try? JSONEncoder().encode(VideoEditingConfiguration.initial)) ?? Data()

    private static let thumbnailData: Data? = nil

}

#Preview("Edited Video Project Card") {
    EditedVideoProjectCard(
        project: EditedVideoProjectCardPreviewFixture.project,
        onOpenProject: {},
        onShareSavedVideo: {},
        onDelete: {}
    )
    .frame(width: 120, height: 120)
    .padding()
    .background(Theme.rootBackground)
}
