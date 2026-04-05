//
//  TranscriptionModelStore.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import CryptoKit
import Foundation

struct TranscriptionModelStore: TranscriptionModelStoring {

    // MARK: - Private Properties

    private let rootDirectoryURL: URL?

    // MARK: - Initializer

    init(rootDirectoryURL: URL? = nil) {
        self.rootDirectoryURL = rootDirectoryURL
    }

    // MARK: - Public Methods

    func localModelURL(for descriptor: RemoteModelDescriptor) throws -> URL {
        try modelsDirectoryURL()
            .appendingPathComponent(descriptor.localFileName)
    }

    func temporaryDownloadURL(for descriptor: RemoteModelDescriptor) throws -> URL {
        try temporaryDownloadsDirectoryURL()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(descriptor.localFileName)
    }

    func cachedModelState(for descriptor: RemoteModelDescriptor) throws -> CachedTranscriptionModelState {
        let localURL = try localModelURL(for: descriptor)

        guard FileManager.default.fileExists(atPath: localURL.path()) else {
            return .missing
        }

        if let issue = try validationIssue(
            at: localURL,
            descriptor: descriptor
        ) {
            return .invalid(localURL, issue: issue)
        }

        return .valid(localURL)
    }

    func installDownloadedModel(
        from temporaryURL: URL,
        for descriptor: RemoteModelDescriptor
    ) throws -> URL {
        guard FileManager.default.fileExists(atPath: temporaryURL.path()) else {
            throw TranscriptionError.modelNotFound
        }

        if let issue = try validationIssue(
            at: temporaryURL,
            descriptor: descriptor
        ) {
            throw modelError(for: issue)
        }

        let destinationURL = try localModelURL(for: descriptor)
        try createDirectoryIfNeeded(
            at: destinationURL.deletingLastPathComponent()
        )

        if FileManager.default.fileExists(atPath: destinationURL.path()) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(
            at: temporaryURL,
            to: destinationURL
        )

        return destinationURL
    }

    // MARK: - Private Methods

    private func modelsDirectoryURL() throws -> URL {
        try transcriptionKitRootDirectoryURL()
            .appendingPathComponent("Models", isDirectory: true)
    }

    private func temporaryDownloadsDirectoryURL() throws -> URL {
        try transcriptionKitRootDirectoryURL()
            .appendingPathComponent("TemporaryDownloads", isDirectory: true)
    }

    private func transcriptionKitRootDirectoryURL() throws -> URL {
        if let rootDirectoryURL {
            try createDirectoryIfNeeded(at: rootDirectoryURL)
            return rootDirectoryURL
        }

        guard
            let applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else {
            throw TranscriptionError.modelNotFound
        }

        let directoryURL =
            applicationSupportURL
            .appendingPathComponent("TranscriptionKit", isDirectory: true)

        try createDirectoryIfNeeded(at: directoryURL)
        return directoryURL
    }

    private func createDirectoryIfNeeded(
        at directoryURL: URL
    ) throws {
        if FileManager.default.fileExists(atPath: directoryURL.path()) {
            return
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func validationIssue(
        at fileURL: URL,
        descriptor: RemoteModelDescriptor
    ) throws -> TranscriptionModelValidationIssue? {
        let fileSize = try fileSizeInBytes(at: fileURL)

        guard fileSize > 0 else {
            return .emptyFile
        }

        if let expectedSizeInBytes = descriptor.expectedSizeInBytes,
            fileSize != expectedSizeInBytes
        {
            return .unexpectedFileSize(
                expected: expectedSizeInBytes,
                actual: fileSize
            )
        }

        if let sha256 = descriptor.sha256 {
            let actualHash = try sha256Digest(for: fileURL)
            if actualHash != sha256.lowercased() {
                return .unexpectedSHA256(
                    expected: sha256.lowercased(),
                    actual: actualHash
                )
            }
        }

        return nil
    }

    private func fileSizeInBytes(
        at fileURL: URL
    ) throws -> Int64 {
        let values = try fileURL.resourceValues(
            forKeys: [.fileSizeKey]
        )

        return Int64(values.fileSize ?? 0)
    }

    private func sha256Digest(
        for fileURL: URL
    ) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        return
            digest
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func modelError(
        for issue: TranscriptionModelValidationIssue
    ) -> TranscriptionError {
        switch issue {
        case .emptyFile, .unexpectedFileSize, .unexpectedSHA256:
            .modelIntegrityCheckFailed
        }
    }

}
