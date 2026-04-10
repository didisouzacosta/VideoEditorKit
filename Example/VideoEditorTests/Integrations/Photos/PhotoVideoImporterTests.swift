import Foundation
import Testing

@testable import VideoEditor

@Suite("PhotoVideoImporterTests")
struct PhotoVideoImporterTests {

    // MARK: - Public Methods

    @Test
    func importVideoReturnsTheImportedVideoURL() async throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let importer = PhotoVideoImporter()

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        let resolvedURL = try await importer.importVideo {
            VideoItem(url: sourceURL)
        }

        #expect(resolvedURL == sourceURL)
    }

    @Test
    func importVideoFailsWhenTheSelectedVideoCannotBeLoaded() async {
        let importer = PhotoVideoImporter()

        do {
            _ = try await importer.importVideo {
                nil
            }
            Issue.record("Expected the importer to fail when the transfer loader returns nil.")
        } catch let error as PhotoVideoImporter.ImportError {
            #expect(error == .unableToLoadSelectedVideo)
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }
    }

    @Test
    func importVideoWrapsUnderlyingTransferErrors() async {
        struct LoaderFailure: LocalizedError {

            // MARK: - Public Properties

            var errorDescription: String? {
                "Transfer import failed."
            }

        }

        let importer = PhotoVideoImporter()

        do {
            _ = try await importer.importVideo {
                throw LoaderFailure()
            }
            Issue.record("Expected the importer to wrap transfer loader failures.")
        } catch let error as PhotoVideoImporter.ImportError {
            #expect(error == .importFailed("Transfer import failed."))
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }
    }

}
