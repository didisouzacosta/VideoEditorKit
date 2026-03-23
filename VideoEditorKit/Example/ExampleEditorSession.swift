import AVFoundation
import CoreGraphics
import Foundation
import UIKit

@MainActor
struct ExampleEditorSession {
    let controller: VideoEditorController
    let loadedAsset: LoadedVideoAsset
    let projectSourceURL: URL

    var videoSize: CGSize {
        loadedAsset.naturalSize
    }

    var preferredTransform: CGAffineTransform {
        loadedAsset.preferredTransform
    }
}

@MainActor
extension ExampleEditorSession {
    static func preview() -> ExampleEditorSession {
        let sourceVideoURL = URL(fileURLWithPath: "/tmp/example-preview.mov")
        let style = CaptionStyle(
            fontName: UIFont.boldSystemFont(ofSize: 24).fontName,
            fontSize: 24,
            textColor: .white,
            backgroundColor: UIColor.black.withAlphaComponent(0.72),
            padding: 12,
            cornerRadius: 14
        )
        let controller = VideoEditorController(
            project: VideoProject(
                sourceVideoURL: sourceVideoURL,
                captions: [
                    Caption(
                        id: UUID(),
                        text: "Imported from device",
                        startTime: 0,
                        endTime: 18,
                        position: CGPoint(x: 0.5, y: 0.5),
                        placementMode: .preset(.bottom),
                        style: style
                    )
                ],
                preset: .original,
                gravity: .fit,
                selectedTimeRange: 0...30
            ),
            config: ExampleVideoEditorFactory.defaultConfig
        )

        try? controller.loadVideo(duration: 30)
        controller.seek(to: 6)

        return ExampleEditorSession(
            controller: controller,
            loadedAsset: LoadedVideoAsset(
                asset: AVMutableComposition(),
                duration: 30,
                naturalSize: CGSize(width: 1920, height: 1080),
                preferredTransform: .identity,
                presentationSize: CGSize(width: 1920, height: 1080),
                nominalFrameRate: 30
            ),
            projectSourceURL: sourceVideoURL
        )
    }
}
