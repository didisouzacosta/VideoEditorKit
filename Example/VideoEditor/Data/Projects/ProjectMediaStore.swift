import AVFoundation
import Foundation
import VideoEditorKit

struct ProjectMediaStore {

    // MARK: - Private Properties

    private let fileManager: FileManager

    // MARK: - Initializer

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Public Methods

    func ensureProjectDirectory(for id: UUID) throws -> URL {
        let projectsDirectoryURL = EditedVideoProject.projectsDirectoryURL()
        let projectDirectoryURL = EditedVideoProject.directoryURL(for: id)

        try fileManager.createDirectory(
            at: projectsDirectoryURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: projectDirectoryURL,
            withIntermediateDirectories: true
        )

        return projectDirectoryURL
    }

    func persistOriginalVideo(
        from sourceURL: URL,
        to projectDirectoryURL: URL
    ) throws -> URL {
        try persistFile(
            from: sourceURL,
            to: resolvedMediaDestinationURL(
                in: projectDirectoryURL,
                prefix: "original",
                sourceURL: sourceURL
            )
        )
    }

    func persistExportedVideo(
        from sourceURL: URL,
        to projectDirectoryURL: URL
    ) throws -> URL {
        try persistFile(
            from: sourceURL,
            to: resolvedMediaDestinationURL(
                in: projectDirectoryURL,
                prefix: "exported",
                sourceURL: sourceURL
            )
        )
    }

    func persistRecordedAudioIfNeeded(
        _ editingConfiguration: VideoEditingConfiguration,
        in projectDirectoryURL: URL
    ) throws -> VideoEditingConfiguration {
        var persistedEditingConfiguration = editingConfiguration

        guard var recordedClip = editingConfiguration.audio.recordedClip else {
            removePersistedRecordedAudioIfNeeded(in: projectDirectoryURL)
            return persistedEditingConfiguration
        }

        let destinationURL = resolvedMediaDestinationURL(
            in: projectDirectoryURL,
            prefix: "recorded-audio",
            sourceURL: recordedClip.url,
            defaultExtension: "m4a"
        )

        if recordedClip.url.standardizedFileURL != destinationURL.standardizedFileURL {
            removePersistedRecordedAudioIfNeeded(in: projectDirectoryURL)
            recordedClip.url = try persistFile(from: recordedClip.url, to: destinationURL)
        }

        persistedEditingConfiguration.audio.recordedClip = recordedClip
        return persistedEditingConfiguration
    }

    static func makeThumbnailData(
        fromExportedVideoAt url: URL,
        editingConfiguration: VideoEditingConfiguration
    ) async -> Data? {
        let asset = AVURLAsset(url: url)
        let duration = (try? await asset.load(.duration).seconds) ?? .zero
        let timestamp = Self.resolvedThumbnailTimestamp(
            for: duration,
            editingConfiguration: editingConfiguration
        )
        let image = await asset.generateImage(
            at: timestamp,
            maximumSize: CGSize(width: 720, height: 720),
            requiresExactFrame: true
        )

        return image?.jpegData(compressionQuality: 0.85)
    }

    func cleanupTransientMediaIfNeeded(
        _ originalURL: URL,
        protectedURL: URL
    ) {
        guard originalURL.standardizedFileURL != protectedURL.standardizedFileURL else { return }
        guard isTransientMediaURL(originalURL) else { return }
        fileManager.removeIfExists(for: originalURL)
    }

    func cleanupTransientAudioIfNeeded(
        originalConfiguration: VideoEditingConfiguration,
        persistedConfiguration: VideoEditingConfiguration
    ) {
        guard
            let originalURL = originalConfiguration.audio.recordedClip?.url,
            let persistedURL = persistedConfiguration.audio.recordedClip?.url
        else {
            return
        }

        cleanupTransientMediaIfNeeded(originalURL, protectedURL: persistedURL)
    }

    func deleteProjectDirectory(for id: UUID) {
        fileManager.removeIfExists(for: EditedVideoProject.directoryURL(for: id))
    }

    static func resolvedThumbnailTimestamp(
        for duration: Double,
        editingConfiguration: VideoEditingConfiguration
    ) -> Double {
        VideoEditingThumbnailTimestampResolver.exportedAssetTimestamp(
            for: editingConfiguration,
            exportedDuration: duration
        )
    }

    // MARK: - Private Methods

    private func resolvedMediaDestinationURL(
        in projectDirectoryURL: URL,
        prefix: String,
        sourceURL: URL,
        defaultExtension: String = "mp4"
    ) -> URL {
        let fileExtension = sourceURL.pathExtension.isEmpty ? defaultExtension : sourceURL.pathExtension
        return projectDirectoryURL.appending(path: "\(prefix).\(fileExtension)")
    }

    private func removePersistedRecordedAudioIfNeeded(in projectDirectoryURL: URL) {
        guard
            let projectFiles = try? fileManager.contentsOfDirectory(
                at: projectDirectoryURL,
                includingPropertiesForKeys: nil
            )
        else {
            return
        }

        for fileURL in projectFiles where fileURL.lastPathComponent.hasPrefix("recorded-audio.") {
            fileManager.removeIfExists(for: fileURL)
        }
    }

    private func persistFile(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws -> URL {
        if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return destinationURL
        }

        fileManager.removeIfExists(for: destinationURL)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func isTransientMediaURL(_ url: URL) -> Bool {
        let standardizedPath = url.standardizedFileURL.path()
        return standardizedPath.hasPrefix(URL.cachesDirectory.path())
            || standardizedPath.hasPrefix(URL.temporaryDirectory.path())
    }

}
