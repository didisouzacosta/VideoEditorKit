//
//  HostedVideoEditorPlayerOverlayView.swift
//  VideoEditorKit
//
//  Created by Codex on 09.04.2026.
//

import SwiftUI

@MainActor
struct HostedVideoEditorPlayerOverlayView: View {

    // MARK: - Public Properties

    let context: HostedVideoEditorPlayerStageCoordinator.TranscriptOverlayContext?
    let canvasLayout: VideoCanvasLayout

    // MARK: - Body

    var body: some View {
        content
    }

    // MARK: - Private Properties

    @ViewBuilder
    private var content: some View {
        if let context {
            TranscriptOverlayPreview(
                segment: context.activeSegment,
                activeWordID: context.activeWordID,
                style: nil,
                overlayPosition: context.transcriptDocument.overlayPosition,
                overlaySize: context.transcriptDocument.overlaySize,
                previewCanvasSize: canvasLayout.previewCanvasSize,
                exportCanvasSize: canvasLayout.exportCanvasSize
            )
            .id(context.layoutID)
        } else {
            EmptyView()
        }
    }

}
