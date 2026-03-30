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
        let view = AVPlayerViewController()
        view.player = player
        view.showsPlaybackControls = showControls
        view.videoGravity = videoGravity
        view.view.backgroundColor = .clear
        view.view.isUserInteractionEnabled = showControls
        return view
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.showsPlaybackControls = showControls
        uiViewController.videoGravity = videoGravity
        uiViewController.view.backgroundColor = .clear
        uiViewController.view.isUserInteractionEnabled = showControls
    }

}
