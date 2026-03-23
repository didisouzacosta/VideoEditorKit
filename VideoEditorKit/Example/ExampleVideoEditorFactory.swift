import Foundation
import UIKit

@MainActor
protocol ExampleVideoEditorSessionBuilding {
    func makeSession(from sourceVideoURL: URL) async throws -> ExampleEditorSession
}

@MainActor
struct ExampleVideoEditorFactory: ExampleVideoEditorSessionBuilding {
    let assetLoader: any VideoAssetLoading
    let config: VideoEditorConfig

    init(
        assetLoader: any VideoAssetLoading = AVFoundationVideoAssetLoader(),
        config: VideoEditorConfig = Self.defaultConfig
    ) {
        self.assetLoader = assetLoader
        self.config = config
    }

    func makeSession(from sourceVideoURL: URL) async throws -> ExampleEditorSession {
        let loadedAsset = try await assetLoader.loadAsset(from: sourceVideoURL)
        let controller = VideoEditorController(
            project: VideoProject(
                sourceVideoURL: sourceVideoURL,
                captions: [],
                preset: .original,
                gravity: .fit,
                selectedTimeRange: 0...loadedAsset.duration
            ),
            config: config
        )

        try controller.loadVideo(duration: loadedAsset.duration)

        return ExampleEditorSession(
            controller: controller,
            loadedAsset: loadedAsset,
            projectSourceURL: sourceVideoURL
        )
    }
}

extension ExampleVideoEditorFactory {
    @MainActor
    static var defaultConfig: VideoEditorConfig {
        let style = demoStyle

        return VideoEditorConfig(
            onCaptionAction: { action, context in
                try await Task.sleep(for: .milliseconds(350))
                return demoCaptionResponse(
                    for: action,
                    context: context,
                    style: style
                )
            }
        )
    }
}

private extension ExampleVideoEditorFactory {
    @MainActor
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

    @MainActor
    static func demoCaptionResponse(
        for action: CaptionAction,
        context: CaptionRequestContext,
        style: CaptionStyle
    ) -> [Caption] {
        let texts = switch action {
        case .generate:
            ["Scene opened", "Preset changed", "Timeline active"]
        case .translate:
            ["Cena aberta", "Mudanca de preset", "Timeline ativa"]
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
