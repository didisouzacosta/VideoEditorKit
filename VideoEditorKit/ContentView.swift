//
//  ContentView.swift
//  VideoEditorKit
//
//  Created by Didi on 22/03/26.
//

import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @State private var controller: VideoEditorController

    init() {
        _controller = State(initialValue: Self.makeController())
    }

    var body: some View {
        VideoEditorView(
            controller: controller,
            videoSize: CGSize(width: 1920, height: 1080)
        )
    }
}

private extension ContentView {
    static func makeController() -> VideoEditorController {
        let style = CaptionStyle(
            fontName: UIFont.boldSystemFont(ofSize: 28).fontName,
            fontSize: 28,
            textColor: .white,
            backgroundColor: UIColor.black.withAlphaComponent(0.72),
            padding: 14,
            cornerRadius: 16
        )
        let captions = [
            Caption(
                id: UUID(),
                text: "Preview = Export",
                startTime: 0,
                endTime: 20,
                position: CGPoint(x: 0.5, y: 0.5),
                placementMode: .preset(.bottom),
                style: style
            ),
            Caption(
                id: UUID(),
                text: "Preset muda layout imediatamente",
                startTime: 20,
                endTime: 40,
                position: CGPoint(x: 0.5, y: 0.32),
                placementMode: .freeform,
                style: style
            )
        ]
        let controller = VideoEditorController(
            project: VideoProject(
                sourceVideoURL: URL(fileURLWithPath: "/tmp/demo.mov"),
                captions: captions,
                preset: .instagram,
                gravity: .fit,
                selectedTimeRange: 0...35
            )
        )

        try? controller.loadVideo(duration: 45)
        controller.seek(to: 12)
        return controller
    }
}
