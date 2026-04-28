import Foundation

/// Input used by the external export sheet to render a video outside `VideoEditorView`.
public struct VideoExportSheetRequest: Equatable, Identifiable, Sendable {

    // MARK: - Public Properties

    /// Stable identity for SwiftUI sheet presentation.
    public let id: String
    /// Local playable source video URL.
    public let sourceVideoURL: URL
    /// Editing snapshot that should be applied during export.
    public let editingConfiguration: VideoEditingConfiguration
    /// Ready-to-use video that can satisfy an `.original` export without rendering again.
    public let preparedOriginalExportVideo: ExportedVideo?
    /// Editing snapshot used to create `preparedOriginalExportVideo`.
    public let preparedOriginalExportEditingConfiguration: VideoEditingConfiguration?

    // MARK: - Initializer

    public init(
        id: String? = nil,
        sourceVideoURL: URL,
        editingConfiguration: VideoEditingConfiguration = .initial,
        preparedOriginalExportVideo: ExportedVideo? = nil,
        preparedOriginalExportEditingConfiguration: VideoEditingConfiguration? = nil
    ) {
        self.id = id ?? sourceVideoURL.absoluteString
        self.sourceVideoURL = sourceVideoURL
        self.editingConfiguration = editingConfiguration
        self.preparedOriginalExportVideo = preparedOriginalExportVideo
        self.preparedOriginalExportEditingConfiguration = preparedOriginalExportVideo.map { _ in
            preparedOriginalExportEditingConfiguration ?? editingConfiguration
        }
    }

}

/// Public preparation result used by advanced export-sheet integrations.
public enum VideoExportPreparationResult: Equatable, Sendable {

    // MARK: - Public Properties

    case render
    case usePreparedVideo(ExportedVideo)
    case cancelled

}
