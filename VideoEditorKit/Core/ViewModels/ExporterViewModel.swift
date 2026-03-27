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
    
    var showAlert = false
    var exportProgress: Double = .zero
    var selectedQuality: VideoQuality = .medium

    var renderState: ExportState = .unknown {
        didSet {
            guard renderState != oldValue else { return }
            handleRenderStateChange(renderState)
        }
    }
    
    var isInteractionDisabled: Bool {
        renderState == .loading
    }

    var canExportVideo: Bool {
        !isInteractionDisabled
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
        case loaded(URL)
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
            lhs.id == rhs.id
        }

    }

    // MARK: - Private Properties

    typealias RenderVideo =
        @Sendable (
            _ video: Video,
            _ quality: VideoQuality,
            _ onProgress: VideoEditor.ProgressHandler?
        ) async throws -> URL

    private let renderVideo: RenderVideo

    // MARK: - Initializer

    init(
        _ video: Video,
        renderVideo: @escaping RenderVideo = { video, quality, onProgress in
            try await VideoEditor.startRender(
                video: video,
                videoQuality: quality,
                onProgress: onProgress
            )
        }
    ) {
        self.video = video
        self.renderVideo = renderVideo
    }

    // MARK: - Public Methods

    func export() async -> URL? {
        renderState = .loading

        do {
            let url = try await renderVideo(video, selectedQuality) { [weak self] progress in
                await MainActor.run {
                    self?.exportProgress = progress.clamped(to: 0...1)
                }
            }
            renderState = .loaded(url)
            return url
        } catch {
            renderState = .failed(error)
            return nil
        }
    }

    func exportVideo(_ onExported: @escaping (URL) -> Void) {
        Task { [weak self] in
            guard let self, let url = await self.export() else { return }
            onExported(url)
        }
    }

    func retryExport(_ onExported: @escaping (URL) -> Void) {
        exportVideo(onExported)
    }

    func selectQuality(_ quality: VideoQuality) {
        selectedQuality = quality
    }

    func isSelectedQuality(_ quality: VideoQuality) -> Bool {
        selectedQuality == quality
    }

    func estimatedVideoSizeText(for quality: VideoQuality) -> String? {
        guard let value = quality.calculateVideoSize(duration: video.totalDuration) else { return nil }
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

    private func resetProgress() {
        exportProgress = .zero
    }

}
