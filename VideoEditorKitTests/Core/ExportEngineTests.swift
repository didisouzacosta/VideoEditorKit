import AVFoundation
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct ExportEngineTests {

    @Test func exportBlocksConcurrentExportPerInstance() async throws {
        let gate = AsyncGate()
        let renderer = TestVideoExportRenderer { request, _ in
            await gate.wait()
            return request.destinationURL
        }
        let engine = ExportEngine(
            assetLoader: TestVideoAssetLoader(),
            renderer: renderer
        )
        let project = makeProject()

        let firstTask = Task {
            try await engine.export(
                project: project,
                destinationURL: URL(fileURLWithPath: "/tmp/export-1.mov")
            )
        }

        await renderer.waitUntilStarted()

        await #expect(throws: VideoEditorError.exportAlreadyInProgress) {
            try await engine.export(
                project: project,
                destinationURL: URL(fileURLWithPath: "/tmp/export-2.mov")
            )
        }

        await gate.open()
        let exportedURL = try await firstTask.value
        #expect(exportedURL == URL(fileURLWithPath: "/tmp/export-1.mov"))
    }

    @Test func exportSanitizesSnapshotAndUsesResolvedSelectedTimeRange() async throws {
        let renderer = TestVideoExportRenderer { request, _ in
            request.destinationURL
        }
        let engine = ExportEngine(
            assetLoader: TestVideoAssetLoader(duration: 30),
            renderer: renderer
        )
        let project = makeProject(
            captions: [
                makeCaption(text: "   ", startTime: 1, endTime: 3),
                makeCaption(text: "Trim me", startTime: 2, endTime: 28)
            ],
            selectedTimeRange: 5...25
        )

        let exportedURL = try await engine.export(
            project: project,
            destinationURL: URL(fileURLWithPath: "/tmp/export-sanitized.mov")
        )
        let request = try #require(await renderer.latestRequest())

        #expect(exportedURL == request.destinationURL)
        #expect(request.timeRange.selectedRange == 5...25)
        #expect(request.snapshot.selectedTimeRange == 5...25)
        #expect(request.snapshot.captions.count == 1)
        #expect(request.snapshot.captions[0].text == "Trim me")
        #expect(request.snapshot.captions[0].startTime == 5)
        #expect(request.snapshot.captions[0].endTime == 25)
    }

    @Test func exportFailsWhenAssetCannotBeLoaded() async {
        let engine = ExportEngine(
            assetLoader: FailingVideoAssetLoader(error: .invalidAsset),
            renderer: TestVideoExportRenderer { request, _ in request.destinationURL }
        )

        await #expect(throws: VideoEditorError.invalidAsset) {
            try await engine.export(
                project: makeProject(),
                destinationURL: URL(fileURLWithPath: "/tmp/export-invalid.mov")
            )
        }
    }
}

private extension ExportEngineTests {
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

private struct TestVideoAssetLoader: VideoAssetLoading {
    var duration: Double = 10

    func loadAsset(from sourceVideoURL: URL) async throws -> LoadedVideoAsset {
        LoadedVideoAsset(
            asset: AVMutableComposition(),
            duration: duration,
            naturalSize: CGSize(width: 1920, height: 1080),
            preferredTransform: .identity,
            presentationSize: CGSize(width: 1920, height: 1080),
            nominalFrameRate: 30
        )
    }
}

private struct FailingVideoAssetLoader: VideoAssetLoading {
    let error: VideoEditorError

    func loadAsset(from sourceVideoURL: URL) async throws -> LoadedVideoAsset {
        throw error
    }
}

private actor TestVideoExportRenderer: VideoExportRendering {
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
