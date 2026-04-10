import SwiftUI
import VideoEditorKit

struct EditorHostScreen: View {

    private enum Constants {
        static let editingStateSaveDebounceInNanoseconds: UInt64 = 250_000_000
    }

    private enum AlertPresentation: Identifiable {

        // MARK: - Public Properties

        case persistenceError(String)
        case blockedTool(ToolEnum)
        case blockedExportQuality(VideoQuality)

        var id: String {
            switch self {
            case .persistenceError(let message):
                "persistence-\(message)"
            case .blockedTool(let tool):
                "tool-\(tool.rawValue)"
            case .blockedExportQuality(let quality):
                "quality-\(quality.rawValue)"
            }
        }

        var title: String {
            switch self {
            case .persistenceError:
                "Unable to Save Project"
            case .blockedTool:
                "Premium Tool"
            case .blockedExportQuality:
                "Premium Export"
            }
        }

        var message: String {
            switch self {
            case .persistenceError(let message):
                message
            case .blockedTool(let tool):
                "\(tool.title) is locked in this demo. Connect `onBlockedToolTap` to your paywall or upgrade flow in the host app."
            case .blockedExportQuality(let quality):
                "\(quality.title) export is locked in this demo. Connect `onBlockedExportQualityTap` to your paywall or upgrade flow in the host app."
            }
        }

    }

    // MARK: - States

    @State private var sessionController: EditorSessionController
    @State private var saveStateTask: Task<Void, Never>?
    @State private var alertPresentation: AlertPresentation?

    // MARK: - Body

    var body: some View {
        @Bindable var bindableSessionController = sessionController

        VideoEditorView(
            "Editor",
            session: sessionController.session,
            configuration: editorConfiguration,
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
        .alert(item: $alertPresentation) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .cancel(Text("OK"))
            )
        }
        .onDisappear(perform: handleDisappear)
    }

    // MARK: - Private Properties

    private let repository: ProjectsRepository

    private var editorConfiguration: VideoEditorView.Configuration {
        .init(
            tools: ToolAvailability.enabled(ToolEnum.all),
            exportQualities: ExportQualityAvailability.allEnabled,
            transcription: .init(),
            onBlockedToolTap: { tool in
                alertPresentation = .blockedTool(tool)
            },
            onBlockedExportQualityTap: { quality in
                alertPresentation = .blockedExportQuality(quality)
            }
        )
    }

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
            onDismissed: { _ in },
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
        sessionController.handleDisappear()
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
            presentPersistenceError(
                "The original video for this editing session could not be resolved."
            )
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
            presentPersistenceError(
                "The original video for this editing session could not be resolved."
            )
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
        alertPresentation = .persistenceError(message)
    }

}
