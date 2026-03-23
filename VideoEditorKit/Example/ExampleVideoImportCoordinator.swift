import Foundation
import PhotosUI
import SwiftUI

enum ExampleVideoImportError: Error, Equatable {
    case failedToLoadSelectedVideo
    case failedToStageImportedVideo
}

extension ExampleVideoImportError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .failedToLoadSelectedVideo:
            "The selected video could not be accessed."
        case .failedToStageImportedVideo:
            "The selected video could not be copied into the app sandbox."
        }
    }
}

protocol ExamplePickedVideoItemLoading {
    func loadURL(from item: PhotosPickerItem) async throws -> URL
}

protocol ExampleVideoFileStaging {
    func stageVideo(at sourceVideoURL: URL) throws -> URL
}

@MainActor
protocol ExampleVideoImportCoordinating {
    func prepareEditorSession(fromPickedVideoAt sourceVideoURL: URL) async throws -> ExampleEditorSession
}

struct PhotosPickerVideoItemLoader: ExamplePickedVideoItemLoading {
    func loadURL(from item: PhotosPickerItem) async throws -> URL {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw ExampleVideoImportError.failedToLoadSelectedVideo
        }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("picked-video-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension(for: item))

        do {
            try data.write(to: destinationURL, options: [.atomic])
            return destinationURL
        } catch {
            throw ExampleVideoImportError.failedToLoadSelectedVideo
        }
    }
}

struct ExampleVideoFileStager: ExampleVideoFileStaging {
    private let fileManager = FileManager.default

    func stageVideo(at sourceVideoURL: URL) throws -> URL {
        guard
            sourceVideoURL.isFileURL,
            sourceVideoURL.path.isEmpty == false,
            fileManager.fileExists(atPath: sourceVideoURL.path)
        else {
            throw ExampleVideoImportError.failedToStageImportedVideo
        }

        do {
            let applicationSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let importDirectoryURL = applicationSupportURL
                .appendingPathComponent("ImportedVideos", isDirectory: true)
            if fileManager.fileExists(atPath: importDirectoryURL.path) == false {
                try fileManager.createDirectory(
                    at: importDirectoryURL,
                    withIntermediateDirectories: true
                )
            }

            let destinationURL = importDirectoryURL
                .appendingPathComponent("video-\(UUID().uuidString)")
                .appendingPathExtension(sourceVideoURL.pathExtension.isEmpty ? "mov" : sourceVideoURL.pathExtension)

            try fileManager.copyItem(at: sourceVideoURL, to: destinationURL)
            return destinationURL
        } catch {
            throw ExampleVideoImportError.failedToStageImportedVideo
        }
    }
}

@MainActor
struct ExampleVideoImportCoordinator: ExampleVideoImportCoordinating {
    let fileStager: any ExampleVideoFileStaging
    let factory: any ExampleVideoEditorSessionBuilding

    init(
        fileStager: any ExampleVideoFileStaging = ExampleVideoFileStager(),
        factory: any ExampleVideoEditorSessionBuilding = ExampleVideoEditorFactory()
    ) {
        self.fileStager = fileStager
        self.factory = factory
    }

    func prepareEditorSession(fromPickedVideoAt sourceVideoURL: URL) async throws -> ExampleEditorSession {
        let stagedVideoURL = try fileStager.stageVideo(at: sourceVideoURL)
        return try await factory.makeSession(from: stagedVideoURL)
    }
}

private extension PhotosPickerVideoItemLoader {
    func fileExtension(for item: PhotosPickerItem) -> String {
        item.supportedContentTypes.first?.preferredFilenameExtension ?? "mov"
    }
}
