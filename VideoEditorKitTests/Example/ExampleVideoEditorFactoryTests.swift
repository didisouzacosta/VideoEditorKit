import AVFoundation
import CoreGraphics
import Testing
@testable import VideoEditorKit

@MainActor
struct ExampleVideoEditorFactoryTests {

    @Test func makeSessionBuildsEditorSessionFromLoadedAsset() async throws {
        let sourceVideoURL = URL(fileURLWithPath: "/tmp/imported-video.mov")
        let expectedTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
        let loadedAsset = LoadedVideoAsset(
            asset: AVMutableComposition(),
            duration: 42,
            naturalSize: CGSize(width: 1920, height: 1080),
            preferredTransform: expectedTransform,
            presentationSize: CGSize(width: 1080, height: 1920),
            nominalFrameRate: 30
        )
        let assetLoader = TestExampleVideoAssetLoader(result: .success(loadedAsset))
        let factory = ExampleVideoEditorFactory(
            assetLoader: assetLoader,
            config: .init()
        )

        let session = try await factory.makeSession(from: sourceVideoURL)

        #expect(assetLoader.loadedSourceVideoURL == sourceVideoURL)
        #expect(session.projectSourceURL == sourceVideoURL)
        #expect(session.controller.project.sourceVideoURL == sourceVideoURL)
        #expect(session.controller.project.preset == .original)
        #expect(session.controller.project.gravity == .fit)
        #expect(session.controller.project.selectedTimeRange == 0...42)
        #expect(session.controller.playerEngine.duration == 42)
        #expect(session.videoSize == CGSize(width: 1920, height: 1080))
        assertTransform(
            session.preferredTransform,
            equals: expectedTransform
        )
    }

    @Test func makeSessionPropagatesAssetLoaderFailure() async {
        let assetLoader = TestExampleVideoAssetLoader(result: .failure(.invalidAsset))
        let factory = ExampleVideoEditorFactory(
            assetLoader: assetLoader,
            config: .init()
        )

        await #expect(throws: VideoEditorError.invalidAsset) {
            try await factory.makeSession(from: URL(fileURLWithPath: "/tmp/missing.mov"))
        }
    }
}

private extension ExampleVideoEditorFactoryTests {
    func assertTransform(
        _ actual: CGAffineTransform,
        equals expected: CGAffineTransform,
        tolerance: CGFloat = 0.0001
    ) {
        #expect(abs(actual.a - expected.a) <= tolerance)
        #expect(abs(actual.b - expected.b) <= tolerance)
        #expect(abs(actual.c - expected.c) <= tolerance)
        #expect(abs(actual.d - expected.d) <= tolerance)
        #expect(abs(actual.tx - expected.tx) <= tolerance)
        #expect(abs(actual.ty - expected.ty) <= tolerance)
    }
}

private final class TestExampleVideoAssetLoader: VideoAssetLoading {
    private let result: Result<LoadedVideoAsset, VideoEditorError>
    private(set) var loadedSourceVideoURL: URL?

    init(result: Result<LoadedVideoAsset, VideoEditorError>) {
        self.result = result
    }

    func loadAsset(from sourceVideoURL: URL) async throws -> LoadedVideoAsset {
        loadedSourceVideoURL = sourceVideoURL
        return try result.get()
    }
}
