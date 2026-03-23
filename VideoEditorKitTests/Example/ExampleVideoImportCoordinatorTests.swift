import AVFoundation
import Testing
@testable import VideoEditorKit

@MainActor
struct ExampleVideoImportCoordinatorTests {

    @Test func prepareEditorSessionStagesVideoBeforeBuildingEditorSession() async throws {
        let pickedVideoURL = URL(fileURLWithPath: "/tmp/picked-video.mov")
        let stagedVideoURL = URL(fileURLWithPath: "/tmp/staged-video.mov")
        let expectedSession = makeSession(sourceVideoURL: stagedVideoURL)
        let stager = TestExampleVideoFileStager(result: .success(stagedVideoURL))
        let factory = TestExampleVideoEditorSessionBuilder(result: .success(expectedSession))
        let coordinator = ExampleVideoImportCoordinator(
            fileStager: stager,
            factory: factory
        )

        let session = try await coordinator.prepareEditorSession(fromPickedVideoAt: pickedVideoURL)

        #expect(stager.stagedSourceVideoURL == pickedVideoURL)
        #expect(factory.loadedSourceVideoURL == stagedVideoURL)
        #expect(session.projectSourceURL == stagedVideoURL)
    }

    @Test func prepareEditorSessionStopsWhenStagingFails() async {
        let stager = TestExampleVideoFileStager(result: .failure(.failedToStageImportedVideo))
        let factory = TestExampleVideoEditorSessionBuilder(
            result: .success(makeSession(sourceVideoURL: URL(fileURLWithPath: "/tmp/unused.mov")))
        )
        let coordinator = ExampleVideoImportCoordinator(
            fileStager: stager,
            factory: factory
        )

        await #expect(throws: ExampleVideoImportError.failedToStageImportedVideo) {
            try await coordinator.prepareEditorSession(
                fromPickedVideoAt: URL(fileURLWithPath: "/tmp/picked-video.mov")
            )
        }
        #expect(factory.loadedSourceVideoURL == nil)
    }
}

private extension ExampleVideoImportCoordinatorTests {
    func makeSession(sourceVideoURL: URL) -> ExampleEditorSession {
        let controller = VideoEditorController(
            project: VideoProject(
                sourceVideoURL: sourceVideoURL,
                captions: [],
                preset: .original,
                gravity: .fit,
                selectedTimeRange: 0...10
            ),
            config: .init()
        )
        try? controller.loadVideo(duration: 10)

        return ExampleEditorSession(
            controller: controller,
            loadedAsset: LoadedVideoAsset(
                asset: AVMutableComposition(),
                duration: 10,
                naturalSize: CGSize(width: 1920, height: 1080),
                preferredTransform: .identity,
                presentationSize: CGSize(width: 1920, height: 1080),
                nominalFrameRate: 30
            ),
            projectSourceURL: sourceVideoURL
        )
    }
}

private final class TestExampleVideoFileStager: ExampleVideoFileStaging {
    private let result: Result<URL, ExampleVideoImportError>
    private(set) var stagedSourceVideoURL: URL?

    init(result: Result<URL, ExampleVideoImportError>) {
        self.result = result
    }

    func stageVideo(at sourceVideoURL: URL) throws -> URL {
        stagedSourceVideoURL = sourceVideoURL
        return try result.get()
    }
}

private final class TestExampleVideoEditorSessionBuilder: ExampleVideoEditorSessionBuilding {
    private let result: Result<ExampleEditorSession, Error>
    private(set) var loadedSourceVideoURL: URL?

    init(result: Result<ExampleEditorSession, Error>) {
        self.result = result
    }

    func makeSession(from sourceVideoURL: URL) async throws -> ExampleEditorSession {
        loadedSourceVideoURL = sourceVideoURL
        return try result.get()
    }
}
