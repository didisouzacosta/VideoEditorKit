//
//  ExporterViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ExporterViewModel {

    // MARK: - Public Properties

    let video: Video
    let editingConfiguration: VideoEditingConfiguration

    var showAlert = false
    var exportProgress: Double = .zero
    var selectedQuality: VideoQuality = .medium

    var renderState: ExportState = .unknown {
        didSet {
            guard shouldHandleRenderStateTransition(from: oldValue, to: renderState) else { return }
            handleRenderStateChange(renderState)
        }
    }

    var isInteractionDisabled: Bool {
        renderState == .loading
    }

    var canExportVideo: Bool {
        !isInteractionDisabled
    }

    var canCancelExport: Bool {
        renderState == .loading
    }

    var shouldShowLoadingView: Bool {
        switch renderState {
        case .loading:
            true
        case .unknown, .loaded, .failed:
            false
        }
    }

    var shouldShowFailureMessage: Bool {
        if case .failed = renderState {
            return true
        }

        return false
    }

    var exportActionTitle: String {
        shouldShowFailureMessage ? "Try Again" : "Export"
    }

    var progressText: String {
        exportProgress.formatted(.percent.precision(.fractionLength(0)))
    }

    var errorMessage: String {
        if case .failed(let error) = renderState {
            error.localizedDescription
        } else {
            "The video could not be exported right now. Please try again."
        }
    }

    enum ExportState: Identifiable, Equatable {

        case unknown, loading
        case loaded(ExportedVideo)
        case failed(Error)

        var id: Int {
            switch self {
            case .unknown: return 0
            case .loading: return 1
            case .loaded: return 2
            case .failed: return 3
            }
        }

        static func == (lhs: ExporterViewModel.ExportState, rhs: ExporterViewModel.ExportState) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown), (.loading, .loading):
                true
            case (.loaded(let lhsVideo), .loaded(let rhsVideo)):
                lhsVideo == rhsVideo
            case (.failed, .failed):
                true
            default:
                false
            }
        }

    }

    // MARK: - Private Properties

    typealias RenderVideo =
        @Sendable (
            _ video: Video,
            _ editingConfiguration: VideoEditingConfiguration,
            _ quality: VideoQuality,
            _ onProgress: VideoEditor.ProgressHandler?
        ) async throws -> URL

    private let renderVideo: RenderVideo
    private let loadExportedVideo: @Sendable (URL) async -> ExportedVideo

    @ObservationIgnored private var exportTask: Task<Void, Never>?

    // MARK: - Initializer

    init(
        _ video: Video,
        editingConfiguration: VideoEditingConfiguration = .initial,
        renderVideo: @escaping RenderVideo = { video, editingConfiguration, quality, onProgress in
            try await VideoEditor.startRender(
                video: video,
                editingConfiguration: editingConfiguration,
                videoQuality: quality,
                onProgress: onProgress
            )
        },
        loadExportedVideo: @escaping @Sendable (URL) async -> ExportedVideo = { url in
            await ExportedVideo.load(from: url)
        }
    ) {
        self.video = video
        self.editingConfiguration = editingConfiguration
        self.renderVideo = renderVideo
        self.loadExportedVideo = loadExportedVideo
    }

    // MARK: - Public Methods

    func export() async -> ExportedVideo? {
        renderState = .loading

        do {
            let url = try await renderVideo(video, editingConfiguration, selectedQuality) { [weak self] progress in
                await MainActor.run {
                    self?.exportProgress = progress.clamped(to: 0...1)
                }
            }
            try Task.checkCancellation()

            let exportedVideo = await loadExportedVideo(url)
            try Task.checkCancellation()

            renderState = .loaded(exportedVideo)
            return exportedVideo
        } catch is CancellationError {
            renderState = .unknown
            return nil
        } catch {
            renderState = .failed(error)
            return nil
        }
    }

    func exportVideo(_ onExported: @escaping (ExportedVideo) -> Void) {
        exportTask?.cancel()
        renderState = .loading

        exportTask = Task { [weak self] in
            guard let self else { return }

            defer {
                Task { @MainActor [weak self] in
                    self?.exportTask = nil
                }
            }

            guard let exportedVideo = await self.export(), !Task.isCancelled else { return }
            onExported(exportedVideo)
        }
    }

    func retryExport(_ onExported: @escaping (ExportedVideo) -> Void) {
        showAlert = false
        exportVideo(onExported)
    }

    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        renderState = .unknown
    }

    func selectQuality(_ quality: VideoQuality) {
        selectedQuality = quality
    }

    func isSelectedQuality(_ quality: VideoQuality) -> Bool {
        selectedQuality == quality
    }

    func estimatedVideoSizeText(for quality: VideoQuality) -> String? {
        let renderSize = VideoEditor.resolvedOutputRenderSize(
            for: video.presentationSize,
            editingConfiguration: editingConfiguration,
            videoQuality: quality
        )
        guard let value = quality.calculateVideoSize(duration: video.totalDuration, renderSize: renderSize) else {
            return nil
        }

        return "\(value.formatted(.number.precision(.fractionLength(1))))Mb"
    }

    // MARK: - Private Methods

    private func handleRenderStateChange(_ state: ExportState) {
        switch state {
        case .unknown:
            showAlert = false
            resetProgress()
        case .loading:
            showAlert = false
            exportProgress = .zero
        case .loaded:
            exportProgress = 1
        case .failed:
            resetProgress()
            showAlert = true
        }
    }

    private func shouldHandleRenderStateTransition(
        from oldState: ExportState,
        to newState: ExportState
    ) -> Bool {
        switch (oldState, newState) {
        case (.failed, .failed):
            true
        default:
            oldState != newState
        }
    }

    private func resetProgress() {
        exportProgress = .zero
    }

}
