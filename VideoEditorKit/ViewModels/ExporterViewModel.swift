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

    private var timer: Timer?
    
    init(video: Video){
        self.video = video
    }
    
    
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
    
    private func resetTimer(){
        timer?.invalidate()
        timer = nil
        progressTimer = .zero
    }
    
    enum ExportState: Identifiable, Equatable {
        
        case unknown, loading, loaded(URL), failed(Error)
        
        var id: Int{
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
    
}
