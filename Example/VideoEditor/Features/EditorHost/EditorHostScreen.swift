import SwiftUI
import VideoEditorKit

struct EditorHostScreen: View {

    private struct PersistenceAlertPresentation: Identifiable {

        // MARK: - Public Properties

        let title: String
        let message: String

        var id: String {
            "\(title)-\(message)"
        }

    }

    // MARK: - States

    @State private var sessionController: EditorSessionController
    @State private var persistenceAlert: PersistenceAlertPresentation?

    // MARK: - Body

    var body: some View {
        @Bindable var bindableSessionController = sessionController

        VideoEditorView(
            ExampleStrings.editorTitle,
            session: sessionController.session,
            callbacks: editorCallbacks
        )
        .sheet(
            item: $bindableSessionController.shareDestination,
            onDismiss: {
                sessionController.dismissShareDestination()
            }
        ) { shareDestination in
            VideoShareSheet(
                activityItems: [shareDestination.videoURL],
                onCompletion: handleShareCompletion
            )
        }
        .alert(item: $persistenceAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .cancel(Text(ExampleStrings.ok))
            )
        }
        .onDisappear(perform: handleDisappear)
    }

    // MARK: - Private Properties

    private let repository: ProjectsRepository

    private var editorCallbacks: VideoEditorView.Callbacks {
        .init(
            onSaveStateChanged: { saveState in
                sessionController.handleSaveStateChanged(saveState)
            },
            onSavedVideo: { savedVideo in
                Task {
                    await persistSavedVideo(savedVideo)
                }
            },
            onSourceVideoResolved: { sourceVideoURL in
                sessionController.handleSourceVideoResolved(sourceVideoURL)
            },
            onExportedVideoURL: { exportedVideoURL in
                Task {
                    await persistExportedVideo(at: exportedVideoURL)
                }
            }
        )
    }

    // MARK: - Initializer

    init(
        draft: EditorSessionDraft,
        repository: ProjectsRepository
    ) {
        _sessionController = State(initialValue: EditorSessionController(draft))

        self.repository = repository
    }

    // MARK: - Private Methods

    private func handleDisappear() {
        sessionController.dismissShareDestination()
    }

    private func persistSavedVideo(_ savedVideo: SavedVideo) async {
        do {
            let persistedSave = try await repository.saveEditedVideo(
                projectID: sessionController.currentProjectID,
                savedVideo: savedVideo
            )

            sessionController.handlePersistedSavedVideo(persistedSave)
        } catch {
            presentPersistenceError(error.localizedDescription)
        }
    }

    private func persistExportedVideo(
        at exportedVideoURL: URL
    ) async {
        guard let originalVideoURL = sessionController.currentSourceVideoURL else {
            presentPersistenceError(ExampleStrings.missingSessionOriginalVideo)
            return
        }

        let editingConfiguration =
            sessionController.latestSaveState?.editingConfiguration
            ?? sessionController.session.editingConfiguration
            ?? .initial
        let exportedVideo = await ExportedVideo.load(from: exportedVideoURL)

        do {
            let project = try await repository.saveExportedVideo(
                projectID: sessionController.currentProjectID,
                originalVideoURL: originalVideoURL,
                exportedVideo: exportedVideo,
                editingConfiguration: editingConfiguration
            )

            sessionController.handlePersistedExport(project: project)
        } catch {
            presentPersistenceError(error.localizedDescription)
        }
    }

    private func presentPersistenceError(_ message: String) {
        persistenceAlert = .init(
            title: ExampleStrings.persistenceErrorTitle,
            message: message
        )
    }

    private func handleShareCompletion(_ result: VideoShareCompletionResult) {
        guard case .failed(let message) = result else { return }
        presentPersistenceError(message)
    }

}
