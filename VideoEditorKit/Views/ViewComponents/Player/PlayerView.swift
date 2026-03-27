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

    // MARK: - Initializer

    init(_ player: AVPlayer, showControls: Bool = false) {
        self.player = player
        self.showControls = showControls
    }

    // MARK: - Public Methods

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let view = AVPlayerViewController()
        view.player = player
        view.showsPlaybackControls = showControls
        view.videoGravity = .resizeAspect
        return view
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }

}
