//
//  ContentView.swift
//  VideoEditorKit
//
//  Created by Didi on 22/03/26.
//

import Foundation
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
        let style = demoStyle
        let controller = VideoEditorController(
            project: VideoProject(
                sourceVideoURL: URL(fileURLWithPath: "/tmp/demo.mov"),
                captions: demoCaptions(style: style),
                preset: .instagram,
                gravity: .fit,
                selectedTimeRange: 0...35
            ),
            config: VideoEditorConfig(
                onCaptionAction: { action, context in
                    try await Task.sleep(for: .milliseconds(350))
                    return demoCaptionResponse(
                        for: action,
                        context: context,
                        style: style
                    )
                }
            )
        )

        try? controller.loadVideo(duration: 45)
        controller.seek(to: 12)
        return controller
    }

    static var demoStyle: CaptionStyle {
        CaptionStyle(
            fontName: UIFont.boldSystemFont(ofSize: 28).fontName,
            fontSize: 28,
            textColor: .white,
            backgroundColor: UIColor.black.withAlphaComponent(0.72),
            padding: 14,
            cornerRadius: 16
        )
    }

    static func demoCaptions(style: CaptionStyle) -> [Caption] {
        [
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
    }

    static func demoCaptionResponse(
        for action: CaptionAction,
        context: CaptionRequestContext,
        style: CaptionStyle
    ) -> [Caption] {
        let texts = switch action {
        case .generate:
            ["Cena aberta", "Mudanca de preset", "Timeline ativa"]
        case .translate:
            ["Scene opened", "Preset changed", "Timeline active"]
        }
        let range = context.selectedTimeRange
        let totalDuration = max(range.upperBound - range.lowerBound, 1)
        let step = totalDuration / Double(texts.count)

        return texts.enumerated().map { index, text in
            let startTime = range.lowerBound + (step * Double(index))
            let endTime = min(startTime + step, range.upperBound)

            return Caption(
                id: UUID(),
                text: text,
                startTime: startTime,
                endTime: endTime,
                position: CGPoint(x: 0.5, y: 0.58 + (Double(index) * 0.08)),
                placementMode: .freeform,
                style: style
            )
        }
    }
}

#Preview {
    ContentView()
}
