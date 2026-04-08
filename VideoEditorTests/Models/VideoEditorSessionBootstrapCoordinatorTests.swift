import Foundation
import Testing

@testable import VideoEditor

@Suite("VideoEditorSessionBootstrapCoordinatorTests")
struct VideoEditorBootstrapTests {

    // MARK: - Public Methods

    @Test
    func initialStateIsIdleWhenTheSessionHasNoSource() {
        let state = VideoEditorSessionBootstrapCoordinator.initialState(
            for: nil
        )

        #expect(state == .idle)
    }

    @Test
    func initialStateIsLoadedForFileURLSources() throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        let state = VideoEditorSessionBootstrapCoordinator.initialState(
            for: .fileURL(sourceURL)
        )

        #expect(state == .loaded(sourceURL))
    }

    @Test
    func initialStateIsLoadingForImportedSources() {
        let state = VideoEditorSessionBootstrapCoordinator.initialState(
            for: .importedFile(
                .init(taskIdentifier: "picker:test") {
                    URL(fileURLWithPath: "/tmp/source.mp4")
                }
            )
        )

        #expect(state == .loading)
    }

    @Test
    func resolveStateReturnsALoadedStateWhenTheImportSucceeds() async throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        let state = await VideoEditorSessionBootstrapCoordinator.resolveState(
            for: .importedFile(
                .init(taskIdentifier: "picker:test") {
                    sourceURL
                }
            )
        )

        #expect(state == .loaded(sourceURL))
    }

    @Test
    func resolveStateReturnsAFailureStateWhenTheImportFails() async {
        struct ImportFailure: LocalizedError {

            // MARK: - Public Properties

            var errorDescription: String? {
                "Import failed."
            }

        }

        let state = await VideoEditorSessionBootstrapCoordinator.resolveState(
            for: .importedFile(
                .init(taskIdentifier: "picker:test") {
                    throw ImportFailure()
                }
            )
        )

        #expect(state == .failed("Import failed."))
    }

}
