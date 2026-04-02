import Foundation
import Testing

@testable import VideoEditorKit

@Suite("VideoEditorSessionSourceResolverTests")
struct VideoEditorSessionSourceResolverTests {

    // MARK: - Public Methods

    @Test
    func fileURLSourcesResolveImmediatelyWithoutTransferLoading() async throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let resolver = VideoEditorSessionSourceResolver(
            videoItemLoader: { _ in
                fatalError("The transfer loader should not run for file URL sources.")
            }
        )

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        let resolvedURL = try await resolver.resolve(.fileURL(sourceURL))

        #expect(resolvedURL == sourceURL)
    }

    @Test
    func resolveImportedVideoReturnsTheImportedVideoURL() async throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let resolver = VideoEditorSessionSourceResolver()

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        let resolvedURL = try await resolver.resolveImportedVideo {
            VideoItem(url: sourceURL)
        }

        #expect(resolvedURL == sourceURL)
    }

    @Test
    func resolveImportedVideoFailsWhenTheSelectedVideoCannotBeLoaded() async {
        let resolver = VideoEditorSessionSourceResolver()

        do {
            _ = try await resolver.resolveImportedVideo {
                nil
            }
            Issue.record("Expected the resolver to fail when the transfer loader returns nil.")
        } catch let error as VideoEditorSessionSourceResolver.ResolutionError {
            #expect(error == .unableToLoadSelectedVideo)
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }
    }

    @Test
    func resolveImportedVideoWrapsUnderlyingTransferErrors() async {
        struct LoaderFailure: LocalizedError {

            // MARK: - Public Properties

            var errorDescription: String? {
                "Transfer import failed."
            }

        }

        let resolver = VideoEditorSessionSourceResolver()

        do {
            _ = try await resolver.resolveImportedVideo {
                throw LoaderFailure()
            }
            Issue.record("Expected the resolver to wrap transfer loader failures.")
        } catch let error as VideoEditorSessionSourceResolver.ResolutionError {
            #expect(error == .importFailed("Transfer import failed."))
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }
    }

}
