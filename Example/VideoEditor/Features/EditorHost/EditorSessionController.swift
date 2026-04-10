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
    private(set) var latestSaveState: VideoEditorView.SaveState?

    // MARK: - Private Properties

    private var lastPersistedSaveFingerprint: VideoEditingConfiguration?
    private var pendingSaveFingerprint: VideoEditingConfiguration?

    // MARK: - Initializer

    init(_ draft: EditorSessionDraft) {
        session = draft.session
        currentProjectID = draft.projectID
        currentSourceVideoURL = draft.sourceVideoURL
        latestSaveState = draft.latestSaveState
        lastPersistedSaveFingerprint = draft.latestSaveState?.continuousSaveFingerprint
    }

    // MARK: - Public Methods

    func registerSaveStateChange(
        _ saveState: VideoEditorView.SaveState
    ) -> Bool {
        latestSaveState = saveState

        let fingerprint = saveState.continuousSaveFingerprint
        guard
            fingerprint != lastPersistedSaveFingerprint,
            fingerprint != pendingSaveFingerprint
        else {
            return false
        }

        pendingSaveFingerprint = fingerprint
        return true
    }

    func handleSourceVideoResolved(_ url: URL) {
        currentSourceVideoURL = url
    }

    func handlePersistedEditingStateSave(
        _ persistedState: ProjectsRepository.PersistedEditingState
    ) {
        currentProjectID = persistedState.project.id
        currentSourceVideoURL = persistedState.project.originalVideoURL
        latestSaveState = persistedState.saveState

        let fingerprint = persistedState.saveState.continuousSaveFingerprint
        lastPersistedSaveFingerprint = fingerprint

        if pendingSaveFingerprint == fingerprint {
            pendingSaveFingerprint = nil
        }
    }

    func handlePersistedExport(
        project: EditedVideoProject
    ) {
        currentProjectID = project.id
        currentSourceVideoURL = project.originalVideoURL

        if let latestSaveState {
            lastPersistedSaveFingerprint = latestSaveState.continuousSaveFingerprint
        }

        pendingSaveFingerprint = nil
        shareDestination = .init(videoURL: project.exportedVideoURL)
    }

    func clearPendingEditingStateSave(
        for saveState: VideoEditorView.SaveState
    ) {
        let fingerprint = saveState.continuousSaveFingerprint

        if pendingSaveFingerprint == fingerprint {
            pendingSaveFingerprint = nil
        }
    }

    func dismissShareDestination() {
        shareDestination = nil
    }

    func handleDisappear() {
        shareDestination = nil
    }

}
