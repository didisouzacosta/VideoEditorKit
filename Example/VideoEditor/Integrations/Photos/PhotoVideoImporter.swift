import Foundation
import PhotosUI
import SwiftUI
import VideoEditorKit

struct PhotoVideoImporter {

    enum ImportError: LocalizedError, Equatable {

        // MARK: - Public Properties

        case unableToLoadSelectedVideo
        case importFailed(String)

        var errorDescription: String? {
            switch self {
            case .unableToLoadSelectedVideo:
                return ExampleStrings.unableToLoadSelectedVideo
            case .importFailed(let message):
                return message
            }
        }

    }

    // MARK: - Private Properties

    private let videoItemLoader: @Sendable (PhotosPickerItem) async throws -> VideoItem?

    // MARK: - Initializer

    init(
        videoItemLoader: @escaping @Sendable (PhotosPickerItem) async throws -> VideoItem? = {
            try await $0.loadTransferable(type: VideoItem.self)
        }
    ) {
        self.videoItemLoader = videoItemLoader
    }

    // MARK: - Public Methods

    func makeSource(
        from item: PhotosPickerItem
    ) -> VideoEditorSessionSource {
        .importedFile(
            .init(taskIdentifier: taskIdentifier(for: item)) {
                try await importVideo {
                    try await videoItemLoader(item)
                }
            }
        )
    }

    func importVideo(
        using loader: @escaping @Sendable () async throws -> VideoItem?
    ) async throws -> URL {
        do {
            guard let importedVideo = try await loader() else {
                throw ImportError.unableToLoadSelectedVideo
            }

            return importedVideo.url
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.importFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private func taskIdentifier(
        for item: PhotosPickerItem
    ) -> String {
        let itemIdentifier = item.itemIdentifier ?? "unknown"
        let supportedContentTypes = String(describing: item.supportedContentTypes)

        return "picker:\(itemIdentifier)-\(supportedContentTypes)"
    }

}
