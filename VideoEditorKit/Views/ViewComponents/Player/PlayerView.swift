//
//  PlayerView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import SwiftUI

struct PlayerView: UIViewControllerRepresentable {

    // MARK: - Public Properties

    typealias UIViewControllerType = AVPlayerViewController

    // MARK: - Private Properties

    private let player: AVPlayer
    private let showControls: Bool
    private let videoGravity: AVLayerVideoGravity

    // MARK: - Initializer

    init(
        _ player: AVPlayer,
        showControls: Bool = false,
        videoGravity: AVLayerVideoGravity = .resizeAspect
    ) {
        self.player = player
        self.showControls = showControls
        self.videoGravity = videoGravity
    }

    // MARK: - Public Methods

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = showControls
        controller.allowsVideoFrameAnalysis = false
        controller.videoGravity = videoGravity
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = showControls

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.showsPlaybackControls = showControls
        uiViewController.allowsVideoFrameAnalysis = false
        uiViewController.videoGravity = videoGravity
        uiViewController.view.backgroundColor = .clear
        uiViewController.view.isUserInteractionEnabled = showControls
    }

}
