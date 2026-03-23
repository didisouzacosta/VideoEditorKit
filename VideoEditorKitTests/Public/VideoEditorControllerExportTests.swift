import AVFoundation
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct VideoEditorControllerExportTests {

    @Test func performExportPublishesProgressAndCompletion() async throws {
        let progressRecorder = ProgressRecorder()
        let renderer = TestControllerVideoExportRenderer { request, progressHandler in
            await progressHandler?(0.25)
            await progressHandler?(0.75)
            return request.destinationURL
        }
        let controller = VideoEditorController(
            project: makeProject(),
            config: VideoEditorConfig(
                onExportProgress: { progress in
                    progressRecorder.record(progress)
                }
            ),
            exportEngine: ExportEngine(
                assetLoader: TestControllerVideoAssetLoader(),
                renderer: renderer
            )
        )

        let destinationURL = URL(fileURLWithPath: "/tmp/controller-export.mov")
        try await controller.performExport(to: destinationURL)

        #expect(controller.editorState.exportState == .completed(destinationURL))
        #expect(progressRecorder.values == [0, 0.25, 0.75, 1])
    }

    @Test func performExportUsesFrozenSnapshotEvenIfProjectChangesDuringExport() async throws {
        let gate = AsyncGate()
        let renderer = TestControllerVideoExportRenderer { request, _ in
            await gate.wait()
            return request.destinationURL
        }
        let controller = VideoEditorController(
            project: makeProject(
                captions: [makeCaption(text: "Original", startTime: 1, endTime: 9)],
                preset: .instagram,
                selectedTimeRange: 2...8
            ),
            exportEngine: ExportEngine(
                assetLoader: TestControllerVideoAssetLoader(),
                renderer: renderer
            )
        )

        let exportTask = Task {
            try await controller.performExport(to: URL(fileURLWithPath: "/tmp/frozen-export.mov"))
        }

        await renderer.waitUntilStarted()

        controller.project.preset = .tiktok
        controller.project.selectedTimeRange = 0...3
        controller.project.captions = [makeCaption(text: "Mutated", startTime: 0, endTime: 2)]

        await gate.open()
        try await exportTask.value

        let request = try #require(await renderer.latestRequest())
        #expect(request.snapshot.preset == .instagram)
        #expect(request.snapshot.selectedTimeRange == 2...8)
        #expect(request.snapshot.captions.map(\.text) == ["Original"])
    }

    @Test func performExportRejectsConcurrentRequestsWithoutOverwritingActiveState() async throws {
        let gate = AsyncGate()
        let renderer = TestControllerVideoExportRenderer { request, _ in
            await gate.wait()
            return request.destinationURL
        }
        let controller = VideoEditorController(
            project: makeProject(),
            exportEngine: ExportEngine(
                assetLoader: TestControllerVideoAssetLoader(),
                renderer: renderer
            )
        )

        let firstTask = Task {
            try await controller.performExport(to: URL(fileURLWithPath: "/tmp/first-export.mov"))
        }

        await renderer.waitUntilStarted()

        await #expect(throws: VideoEditorError.exportAlreadyInProgress) {
            try await controller.performExport(to: URL(fileURLWithPath: "/tmp/second-export.mov"))
        }

        #expect(controller.editorState.exportState == .exporting(progress: 0))

        await gate.open()
        try await firstTask.value
    }
}

private extension VideoEditorControllerExportTests {
    func makeProject(
        captions: [Caption] = [],
        preset: ExportPreset = .original,
        gravity: VideoGravity = .fit,
        selectedTimeRange: ClosedRange<Double> = 0...10
    ) -> VideoProject {
        VideoProject(
            sourceVideoURL: URL(fileURLWithPath: "/tmp/source-video.mov"),
            captions: captions,
            preset: preset,
            gravity: gravity,
            selectedTimeRange: selectedTimeRange
        )
    }

    func makeCaption(
        text: String,
        startTime: Double,
        endTime: Double
    ) -> Caption {
        Caption(
            id: UUID(),
            text: text,
            startTime: startTime,
            endTime: endTime,
            position: CGPoint(x: 0.5, y: 0.5),
            placementMode: .freeform,
            style: CaptionStyle(
                fontName: "SFProText-Regular",
                fontSize: 16,
                textColor: .white,
                backgroundColor: .black,
                padding: 12,
                cornerRadius: 8
            )
        )
    }
}

private struct TestControllerVideoAssetLoader: VideoAssetLoading {
    func loadAsset(from sourceVideoURL: URL) async throws -> LoadedVideoAsset {
        LoadedVideoAsset(
            asset: AVMutableComposition(),
            duration: 10,
            naturalSize: CGSize(width: 1920, height: 1080),
            preferredTransform: .identity,
            presentationSize: CGSize(width: 1920, height: 1080),
            nominalFrameRate: 30
        )
    }
}

private actor TestControllerVideoExportRenderer: VideoExportRendering {
    private let behavior: @Sendable (ExportRenderRequest, ExportProgressHandler?) async throws -> URL
    private var requests: [ExportRenderRequest] = []
    private var startedContinuation: CheckedContinuation<Void, Never>?

    init(
        behavior: @escaping @Sendable (ExportRenderRequest, ExportProgressHandler?) async throws -> URL
    ) {
        self.behavior = behavior
    }

    func export(
        request: ExportRenderRequest,
        progressHandler: ExportProgressHandler?
    ) async throws -> URL {
        requests.append(request)
        startedContinuation?.resume()
        startedContinuation = nil
        return try await behavior(request, progressHandler)
    }

    func waitUntilStarted() async {
        guard requests.isEmpty else {
            return
        }

        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    func latestRequest() -> ExportRenderRequest? {
        requests.last
    }
}

private final class ProgressRecorder {
    private(set) var values: [Double] = []

    func record(_ value: Double) {
        values.append(value)
    }
}

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}
