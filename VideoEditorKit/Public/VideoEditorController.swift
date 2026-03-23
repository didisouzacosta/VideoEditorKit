import Foundation
import Observation

@MainActor
@Observable
final class VideoEditorController {
    var editorState: EditorState
    var project: VideoProject
    var config: VideoEditorConfig
    private let exportEngine: ExportEngine

    init(
        project: VideoProject,
        editorState: EditorState = .init(),
        config: VideoEditorConfig = .init(),
        exportEngine: ExportEngine = .init()
    ) {
        self.project = project
        self.editorState = editorState
        self.config = config
        self.exportEngine = exportEngine
    }

    func performCaptionAction(
        _ action: CaptionAction,
        videoDuration: Double
    ) async throws {
        guard editorState.captionState != .loading else {
            throw VideoEditorError.captionGenerationInProgress
        }

        guard let onCaptionAction = config.onCaptionAction else {
            editorState.captionState = .failed(message: Messages.providerUnavailable)
            throw VideoEditorError.captionProviderUnavailable
        }

        editorState.captionState = .loading

        let context = CaptionRequestContext(
            videoURL: project.sourceVideoURL,
            duration: videoDuration,
            selectedTimeRange: project.selectedTimeRange
        )

        do {
            let incomingCaptions = try await onCaptionAction(action, context)
            let normalizedIncoming = CaptionEngine.normalizeCaptions(
                incomingCaptions,
                to: project.selectedTimeRange
            )
            let mergedCaptions = CaptionMergeEngine.apply(
                incoming: normalizedIncoming,
                to: project.captions,
                strategy: config.captionApplyStrategy
            )

            project.captions = CaptionEngine.normalizeCaptions(
                mergedCaptions,
                to: project.selectedTimeRange
            )
            clearSelectionIfNeeded()
            editorState.captionState = .idle
        } catch let error as VideoEditorError {
            let message = message(for: error)
            editorState.captionState = .failed(message: message)
            throw error
        } catch {
            let message = message(for: error)
            editorState.captionState = .failed(message: message)
            throw VideoEditorError.captionProviderFailed(reason: message)
        }
    }

    func performExport(to destinationURL: URL) async throws {
        if case .exporting = editorState.exportState {
            throw VideoEditorError.exportAlreadyInProgress
        }

        beginExport()

        let progressHandler: ExportProgressHandler = { progress in
            self.publishExportProgress(progress)
        }

        do {
            let exportedURL = try await exportEngine.export(
                project: project,
                destinationURL: destinationURL,
                progressHandler: progressHandler
            )
            completeExport(at: exportedURL)
        } catch let error as VideoEditorError {
            if error != .exportAlreadyInProgress {
                editorState.exportState = .failed(error)
            }
            throw error
        } catch {
            let mappedError = VideoEditorError.exportFailed(reason: error.localizedDescription)
            editorState.exportState = .failed(mappedError)
            throw mappedError
        }
    }
}

private extension VideoEditorController {
    enum Messages {
        static let providerUnavailable = "Caption provider is unavailable."
        static let providerFailedFallback = "Caption provider failed."
    }

    func beginExport() {
        editorState.exportState = .exporting(progress: 0)
        config.onExportProgress?(0)
    }

    func publishExportProgress(_ progress: Double) {
        let normalizedProgress = min(max(progress, 0), 1)
        let nextState = ExportState.exporting(progress: normalizedProgress)

        if editorState.exportState != nextState {
            editorState.exportState = nextState
            config.onExportProgress?(normalizedProgress)
        }
    }

    func completeExport(at exportedURL: URL) {
        if editorState.exportState != .exporting(progress: 1) {
            editorState.exportState = .exporting(progress: 1)
            config.onExportProgress?(1)
        }

        editorState.exportState = .completed(exportedURL)
    }

    func clearSelectionIfNeeded() {
        guard let selectedCaptionID = editorState.selectedCaptionID else {
            return
        }

        if project.captions.contains(where: { $0.id == selectedCaptionID }) == false {
            editorState.selectedCaptionID = nil
        }
    }

    func message(for error: Error) -> String {
        if let videoEditorError = error as? VideoEditorError {
            switch videoEditorError {
            case .captionProviderFailed(let reason):
                return reason
            case .captionProviderUnavailable:
                return Messages.providerUnavailable
            default:
                return Messages.providerFailedFallback
            }
        }

        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           description.isEmpty == false {
            return description
        }

        return Messages.providerFailedFallback
    }
}
