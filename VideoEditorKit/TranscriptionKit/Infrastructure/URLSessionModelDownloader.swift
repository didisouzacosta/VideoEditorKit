//
//  URLSessionModelDownloader.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

struct URLSessionModelDownloader: ModelDownloading {

    // MARK: - Private Properties

    private let session: URLSession

    // MARK: - Initializer

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public Methods

    func downloadModel(
        from remoteURL: URL,
        to temporaryURL: URL,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws {
        progress(0)

        do {
            var request = URLRequest(url: remoteURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await session.data(for: request)
            try validate(response: response, remoteURL: remoteURL)

            try createParentDirectoryIfNeeded(
                for: temporaryURL
            )

            if FileManager.default.fileExists(atPath: temporaryURL.path()) {
                try FileManager.default.removeItem(at: temporaryURL)
            }

            try data.write(
                to: temporaryURL,
                options: .atomic
            )

            progress(1)
        } catch is CancellationError {
            throw TranscriptionError.cancelled
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.modelDownloadFailed(
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Private Methods

    private func validate(
        response: URLResponse,
        remoteURL: URL
    ) throws {
        if let httpResponse = response as? HTTPURLResponse,
            !(200...299).contains(httpResponse.statusCode)
        {
            throw TranscriptionError.modelDownloadFailed(
                message: "Model download failed with HTTP \(httpResponse.statusCode) for \(remoteURL.absoluteString)."
            )
        }
    }

    private func createParentDirectoryIfNeeded(
        for fileURL: URL
    ) throws {
        let directoryURL = fileURL.deletingLastPathComponent()

        guard !FileManager.default.fileExists(atPath: directoryURL.path()) else {
            return
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

}
