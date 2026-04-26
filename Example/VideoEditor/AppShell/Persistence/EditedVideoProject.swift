//
//  EditedVideoProject.swift
//  VideoEditorKit
//
//  Created by Codex on 28.03.2026.
//

import Foundation
import SwiftData
import VideoEditorKit

@Model
final class EditedVideoProject {

    // MARK: - Public Properties

    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var editingConfigurationData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?

    var createdAt: Date
    var updatedAt: Date
    var displayName: String
    var originalVideoFileName: String
    var savedEditedVideoFileName: String = ""
    var exportedVideoFileName: String
    var duration: Double
    var width: Double
    var height: Double
    var fileSize: Int64

    var originalVideoURL: URL {
        directoryURL.appending(path: originalVideoFileName)
    }

    var exportedVideoURL: URL {
        directoryURL.appending(path: exportedVideoFileName)
    }

    var savedEditedVideoURL: URL {
        directoryURL.appending(path: savedEditedVideoFileName)
    }

    var aspectRatio: Double {
        guard width > 0, height > 0 else { return 1 }
        return width / height
    }

    var editingConfiguration: VideoEditingConfiguration? {
        guard
            var editingConfiguration = try? JSONDecoder().decode(
                VideoEditingConfiguration.self,
                from: editingConfigurationData
            )
        else {
            return nil
        }

        editingConfiguration.playback.currentTimelineTime = nil
        return editingConfiguration
    }

    var hasOriginalVideo: Bool {
        FileManager.default.fileExists(atPath: originalVideoURL.path())
    }

    var hasExportedVideo: Bool {
        guard exportedVideoFileName.isEmpty == false else { return false }

        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(
            atPath: exportedVideoURL.path(),
            isDirectory: &isDirectory
        )
        return fileExists && isDirectory.boolValue == false
    }

    var hasSavedEditedVideo: Bool {
        guard savedEditedVideoFileName.isEmpty == false else { return false }

        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(
            atPath: savedEditedVideoURL.path(),
            isDirectory: &isDirectory
        )
        return fileExists && isDirectory.boolValue == false
    }

    var hasRequiredMedia: Bool {
        hasOriginalVideo && (hasSavedEditedVideo || hasExportedVideo)
    }

    var savedPlaybackVideoURL: URL? {
        if hasSavedEditedVideo {
            return savedEditedVideoURL
        }

        if hasExportedVideo {
            return exportedVideoURL
        }

        return nil
    }

    var canPreviewSavedVideo: Bool {
        savedPlaybackVideoURL != nil
    }

    var canShareSavedVideo: Bool {
        savedPlaybackVideoURL != nil
    }

    // MARK: - Private Properties

    private var directoryURL: URL {
        Self.directoryURL(for: id)
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        createdAt: Date,
        updatedAt: Date,
        displayName: String,
        originalVideoFileName: String,
        savedEditedVideoFileName: String = "",
        exportedVideoFileName: String,
        editingConfigurationData: Data,
        thumbnailData: Data?,
        duration: Double,
        width: Double,
        height: Double,
        fileSize: Int64
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.displayName = displayName
        self.originalVideoFileName = originalVideoFileName
        self.savedEditedVideoFileName = savedEditedVideoFileName
        self.exportedVideoFileName = exportedVideoFileName
        self.editingConfigurationData = editingConfigurationData
        self.thumbnailData = thumbnailData
        self.duration = duration
        self.width = width
        self.height = height
        self.fileSize = fileSize
    }

    // MARK: - Public Methods

    static func projectsDirectoryURL() -> URL {
        URL.documentsDirectory.appending(
            path: "EditedVideoProjects",
            directoryHint: .isDirectory
        )
    }

    static func directoryURL(for id: UUID) -> URL {
        projectsDirectoryURL().appending(
            path: id.uuidString,
            directoryHint: .isDirectory
        )
    }

}
