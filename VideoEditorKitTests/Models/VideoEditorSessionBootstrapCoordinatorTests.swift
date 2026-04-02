import Foundation
import PhotosUI
import SwiftUI
import Testing

@testable import VideoEditorKit

@Suite("VideoEditorSessionBootstrapCoordinatorTests")
struct VideoEditorSessionBootstrapCoordinatorTests {

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
    func initialStateIsLoadingForPhotosPickerSources() {
        let state = VideoEditorSessionBootstrapCoordinator.initialState(
            for: .photosPickerItem(PhotosPickerItem(itemIdentifier: "test"))
        )

        #expect(state == .loading)
    }

    @Test
    func resolveStateReturnsALoadedStateWhenTheImportSucceeds() async throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        let state = await VideoEditorSessionBootstrapCoordinator.resolveState(
            for: .photosPickerItem(PhotosPickerItem(itemIdentifier: "test")),
            using: VideoEditorSessionSourceResolver(
                videoItemLoader: { _ in
                    VideoItem(url: sourceURL)
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
            for: .photosPickerItem(PhotosPickerItem(itemIdentifier: "test")),
            using: VideoEditorSessionSourceResolver(
                videoItemLoader: { _ in
                    throw ImportFailure()
                }
            )
        )

        #expect(state == .failed("Import failed."))
    }

}
