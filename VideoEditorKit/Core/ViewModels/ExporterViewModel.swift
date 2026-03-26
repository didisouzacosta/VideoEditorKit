//
//  ExporterViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ExporterViewModel {

    // MARK: - Public Properties

    let video: Video
    var renderState: ExportState = .unknown {
        didSet {
            guard renderState != oldValue else { return }
            handleRenderStateChange(renderState)
        }
    }

    var showAlert = false
    var progressTimer: TimeInterval = .zero
    var selectedQuality: VideoQuality = .medium

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

    private var timer: Timer?

    // MARK: - Initializer

    init(_ video: Video) {
        self.video = video
    }

    // MARK: - Public Methods

    func export() async -> URL? {
        renderState = .loading
        do {
            let url = try await VideoEditor.startRender(video: video, videoQuality: selectedQuality)
            renderState = .loaded(url)
            return url
        } catch {
            renderState = .failed(error)
            return nil
        }
    }

    // MARK: - Private Methods

    private func handleRenderStateChange(_ state: ExportState) {
        switch state {
        case .unknown:
            showAlert = false
            resetTimer()
        case .loading:
            showAlert = false
            startProgressTimer()
        case .loaded:
            resetTimer()
        case .failed:
            resetTimer()
            showAlert = true
        }
    }

    private func startProgressTimer() {
        resetTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.progressTimer += 0.1
            }
        }
    }

    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        progressTimer = .zero
    }

}
