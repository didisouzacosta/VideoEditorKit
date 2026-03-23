import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class VideoEditorController {
    var editorState: EditorState
    var project: VideoProject
    var config: VideoEditorConfig
    let playerEngine: PlayerEngine
    private let exportEngine: ExportEngine

    init(
        project: VideoProject,
        editorState: EditorState = .init(),
        config: VideoEditorConfig = .init(),
        playerEngine: PlayerEngine = .init(),
        exportEngine: ExportEngine = .init()
    ) {
        self.project = project
        self.editorState = editorState
        self.config = config
        self.playerEngine = playerEngine
        self.exportEngine = exportEngine
    }

    func loadVideo(duration: Double) throws {
        try playerEngine.load(duration: duration)
        resolveProjectState(using: project.selectedTimeRange)
    }

    func selectPreset(_ preset: ExportPreset) {
        guard project.preset != preset else {
            return
        }

        project.preset = preset
        resolveProjectState(using: project.selectedTimeRange)
    }

    func updateSelectedTimeRange(_ selectedTimeRange: ClosedRange<Double>) {
        guard project.selectedTimeRange != selectedTimeRange else {
            return
        }

        resolveProjectState(using: selectedTimeRange)
    }

    func updatePlaybackRate(_ playbackRate: Double) {
        let normalizedPlaybackRate = VideoAdjustmentSettings.normalizedPlaybackRate(playbackRate)

        guard project.adjustments.playbackRate != normalizedPlaybackRate else {
            return
        }

        project.adjustments.playbackRate = normalizedPlaybackRate
    }

    func rotateVideoClockwise() {
        project.adjustments.rotation = project.adjustments.rotation.rotatedClockwise()
    }

    func setVideoMirroring(_ isMirrored: Bool) {
        guard project.adjustments.isMirrored != isMirrored else {
            return
        }

        project.adjustments.isMirrored = isMirrored
    }

    func setFilterName(_ filterName: String?) {
        let normalizedFilterName = VideoAdjustmentSettings.normalizedFilterName(filterName)

        guard project.adjustments.filterName != normalizedFilterName else {
            return
        }

        project.adjustments.filterName = normalizedFilterName
    }

    func updateColorCorrection(_ colorCorrection: VideoColorCorrection) {
        guard project.adjustments.colorCorrection != colorCorrection else {
            return
        }

        project.adjustments.colorCorrection = colorCorrection
    }

    func updateFrameStyle(_ frameStyle: VideoFrameStyle?) {
        let normalizedFrameStyle = frameStyle.map {
            VideoFrameStyle(
                backgroundColor: $0.backgroundColor,
                scale: $0.scale
            )
        }

        guard project.adjustments.frameStyle != normalizedFrameStyle else {
            return
        }

        project.adjustments.frameStyle = normalizedFrameStyle
    }

    func selectCaption(_ captionID: Caption.ID?) {
        guard let captionID else {
            editorState.selectedCaptionID = nil
            return
        }

        if project.captions.contains(where: { $0.id == captionID }) {
            editorState.selectedCaptionID = captionID
        } else {
            editorState.selectedCaptionID = nil
        }
    }

    func moveCaption(
        _ captionID: Caption.ID,
        to displayPoint: CGPoint,
        displaySize: CGSize,
        renderSize: CGSize,
        safeFrame: CGRect
    ) {
        guard let index = project.captions.firstIndex(where: { $0.id == captionID }) else {
            return
        }

        project.captions[index] = CaptionDragEngine.reposition(
            project.captions[index],
            to: displayPoint,
            displaySize: displaySize,
            renderSize: renderSize,
            safeFrame: safeFrame
        )
        editorState.selectedCaptionID = captionID
    }

    func seek(to time: Double) {
        playerEngine.seek(to: time, in: project.selectedTimeRange)
        syncEditorStateFromPlayer()
    }

    func togglePlayback() {
        if editorState.isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        playerEngine.play()
        syncEditorStateFromPlayer()
    }

    func pause() {
        playerEngine.pause()
        syncEditorStateFromPlayer()
    }

    func handlePlaybackTimeUpdate(_ time: Double) {
        playerEngine.handlePlaybackTimeUpdate(time)
        syncEditorStateFromPlayer()
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

    func resolveProjectState(using selectedTimeRange: ClosedRange<Double>) {
        guard playerEngine.duration > 0 else {
            project.selectedTimeRange = selectedTimeRange
            project.captions = CaptionEngine.normalizeCaptions(
                project.captions,
                to: selectedTimeRange
            )
            clearSelectionIfNeeded()
            editorState.currentTime = TimeRangeEngine.clampTime(
                editorState.currentTime,
                to: selectedTimeRange
            )
            return
        }

        let resolvedTimeRange = TimeRangeEngine.resolve(
            videoDuration: playerEngine.duration,
            currentSelection: selectedTimeRange,
            preset: project.preset
        )

        project.selectedTimeRange = resolvedTimeRange.selectedRange
        project.captions = CaptionEngine.normalizeCaptions(
            project.captions,
            to: resolvedTimeRange.selectedRange
        )
        clearSelectionIfNeeded()
        playerEngine.handleSelectedTimeRangeChange(resolvedTimeRange.selectedRange)
        syncEditorStateFromPlayer()
    }

    func syncEditorStateFromPlayer() {
        editorState.currentTime = playerEngine.currentTime
        editorState.isPlaying = playerEngine.isPlaying
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
