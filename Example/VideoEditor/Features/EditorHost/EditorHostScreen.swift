import SwiftUI
import VideoEditorKit

struct EditorHostScreen: View {

    private enum Constants {
        static let editingStateSaveDebounceInNanoseconds: UInt64 = 250_000_000
    }

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
    @State private var saveStateTask: Task<Void, Never>?
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
            VideoShareSheet(activityItems: [shareDestination.videoURL])
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
                if sessionController.registerSaveStateChange(saveState) {
                    scheduleEditingStateSave(saveState)
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
        saveStateTask?.cancel()
        saveStateTask = nil
        sessionController.dismissShareDestination()
    }

    private func scheduleEditingStateSave(
        _ saveState: VideoEditorView.SaveState
    ) {
        saveStateTask?.cancel()
        saveStateTask = Task {
            try? await Task.sleep(nanoseconds: Constants.editingStateSaveDebounceInNanoseconds)
            guard Task.isCancelled == false else {
                sessionController.clearPendingEditingStateSave(for: saveState)
                return
            }

            await persistEditingState(saveState)
        }
    }

    private func persistEditingState(
        _ saveState: VideoEditorView.SaveState
    ) async {
        guard let originalVideoURL = sessionController.currentSourceVideoURL else {
            presentPersistenceError(ExampleStrings.missingSessionOriginalVideo)
            return
        }

        do {
            let persistedState = try await repository.saveEditingState(
                projectID: sessionController.currentProjectID,
                originalVideoURL: originalVideoURL,
                saveState: saveState
            )

            guard Task.isCancelled == false else {
                sessionController.clearPendingEditingStateSave(for: saveState)
                return
            }

            sessionController.handlePersistedEditingStateSave(persistedState)
        } catch {
            guard Task.isCancelled == false else {
                sessionController.clearPendingEditingStateSave(for: saveState)
                return
            }

            sessionController.clearPendingEditingStateSave(for: saveState)
            presentPersistenceError(error.localizedDescription)
        }
    }

    private func persistExportedVideo(
        at exportedVideoURL: URL
    ) async {
        saveStateTask?.cancel()
        saveStateTask = nil

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

}
