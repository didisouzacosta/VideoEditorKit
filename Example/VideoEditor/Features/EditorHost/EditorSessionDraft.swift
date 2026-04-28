import Foundation
import VideoEditorKit

struct EditorSessionDraft: Identifiable, Equatable {

    // MARK: - Public Properties

    let id: UUID
    let session: VideoEditorView.Session
    let projectID: UUID?
    let sourceVideoURL: URL?
    let latestEditingConfiguration: VideoEditingConfiguration?

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        session: VideoEditorView.Session,
        projectID: UUID? = nil,
        sourceVideoURL: URL? = nil,
        latestEditingConfiguration: VideoEditingConfiguration? = nil
    ) {
        self.id = id
        self.session = session
        self.projectID = projectID
        self.sourceVideoURL = sourceVideoURL
        self.latestEditingConfiguration = latestEditingConfiguration
    }

    // MARK: - Public Methods

    static func imported(
        _ source: VideoEditorView.Session.Source
    ) -> Self {
        .init(
            session: .init(source: source),
            sourceVideoURL: source.fileURL
        )
    }

    static func project(
        _ project: EditedVideoProject
    ) -> Self {
        let editingConfiguration = project.editingConfiguration

        return .init(
            session: .init(
                sourceVideoURL: project.originalVideoURL,
                editingConfiguration: editingConfiguration,
                preparedOriginalExportVideo: project.preparedOriginalExportVideo
            ),
            projectID: project.id,
            sourceVideoURL: project.originalVideoURL,
            latestEditingConfiguration: editingConfiguration
        )
    }

}
