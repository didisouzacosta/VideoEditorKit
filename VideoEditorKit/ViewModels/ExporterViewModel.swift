//
//  ExporterViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import Photos
import UIKit
import SwiftUI
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

    private var action: ActionEnum = .save
    private var timer: Timer?
    
    init(video: Video){
        self.video = video
    }
    
    
    @MainActor
    private func renderVideo() async{
        renderState = .loading
        do{
            let url = try await VideoEditor.startRender(video: video, videoQuality: selectedQuality)
            renderState = .loaded(url)
        }catch{
            renderState = .failed(error)
        }
    }
    
    
   
    func action(_ action: ActionEnum) async{
        self.action = action
        await renderVideo()
    }

    private func handleRenderStateChange(_ state: ExportState) {
        switch state {
        case .unknown:
            showAlert = false
            resetTimer()
        case .loading:
            showAlert = false
            startProgressTimer()
        case .loaded(let url):
            resetTimer()
            if action == .save {
                saveVideoInLib(url)
            } else {
                showShareSheet(data: url)
            }
        case .failed:
            resetTimer()
            showAlert = true
        case .saved:
            showAlert = false
            resetTimer()
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
    
    private func showShareSheet(data: Any){
        renderState = .unknown
        UIActivityViewController(activityItems: [data], applicationActivities: nil).presentInKeyWindow()
    }
    
    private func saveVideoInLib(_ url: URL){
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) {[weak self] saved, error in
            guard let self = self else {return}
            if saved {
                Task { @MainActor in
                    self.renderState = .saved
                }
            }
        }
    }

    enum ActionEnum: Int{
        case save, share
    }
    
    
    
    enum ExportState: Identifiable, Equatable {
        
        case unknown, loading, loaded(URL), failed(Error), saved
        
        var id: Int{
            switch self {
            case .unknown: return 0
            case .loading: return 1
            case .loaded: return 2
            case .failed: return 3
            case .saved: return 4
            }
        }
        
        static func == (lhs: ExporterViewModel.ExportState, rhs: ExporterViewModel.ExportState) -> Bool {
            lhs.id == rhs.id
        }
    }
    
}
