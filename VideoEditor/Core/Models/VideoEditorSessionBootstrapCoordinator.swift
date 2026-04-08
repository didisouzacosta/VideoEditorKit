//
//  VideoEditorSessionBootstrapCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 02.04.2026.
//

import Foundation
import VideoEditorKit

struct VideoEditorSessionBootstrapCoordinator {

    typealias BootstrapState = VideoEditorKit.VideoEditorSessionBootstrapCoordinator.BootstrapState

    // MARK: - Public Methods

    static func initialState(
        for source: VideoEditorSessionSource?
    ) -> BootstrapState {
        VideoEditorKit.VideoEditorSessionBootstrapCoordinator.initialState(
            for: source
        )
    }

    static func resolveState(
        for source: VideoEditorSessionSource?
    ) async -> BootstrapState {
        await VideoEditorKit.VideoEditorSessionBootstrapCoordinator.resolveState(
            for: source
        )
    }

}
