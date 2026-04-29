import Foundation
import Observation
import VideoEditorKit

@MainActor
@Observable
final class EditorSessionController {

    struct ShareDestination: Identifiable, Equatable {

        // MARK: - Public Properties

        let videoURL: URL

        var id: URL {
            videoURL
        }

    }

    // MARK: - Public Properties

    let session: VideoEditorView.Session

    var shareDestination: ShareDestination?

    private(set) var currentProjectID: UUID?
    private(set) var currentSourceVideoURL: URL?
    private(set) var latestEditingConfiguration: VideoEditingConfiguration?

    // MARK: - Initializer

    init(_ draft: EditorSessionDraft) {
        session = draft.session
        currentProjectID = draft.projectID
        currentSourceVideoURL = draft.sourceVideoURL
        latestEditingConfiguration = draft.latestEditingConfiguration
    }

    // MARK: - Public Methods

    func handleSavedVideo(_ savedVideo: SavedVideo) {
        latestEditingConfiguration = savedVideo.editingConfiguration
    }

    func handleSourceVideoResolved(_ url: URL) {
        currentSourceVideoURL = url
    }

    func handlePersistedSavedVideo(
        _ persistedSave: ProjectsRepository.PersistedSavedVideo
    ) {
        currentProjectID = persistedSave.project.id
        currentSourceVideoURL = persistedSave.project.originalVideoURL
        latestEditingConfiguration = persistedSave.savedVideo.editingConfiguration
    }

    func handlePersistedExport(
        project: EditedVideoProject
    ) {
        currentProjectID = project.id
        currentSourceVideoURL = project.originalVideoURL
        shareDestination = .init(videoURL: project.exportedVideoURL)
    }

    func dismissShareDestination() {
        shareDestination = nil
    }

}
