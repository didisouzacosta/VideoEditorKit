//
//  EditorViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import AVKit
import Observation

@MainActor
@Observable
final class EditorViewModel {
    var currentVideo: Video?
    var selectedTools: ToolEnum?
    var frames = VideoFrames()
    var isSelectVideo = true
    @ObservationIgnored private var loadVideoTask: Task<Void, Never>?
    @ObservationIgnored private var thumbnailsTask: Task<Void, Never>?

    func setNewVideo(_ url: URL, containerSize: CGSize){
        loadVideoTask?.cancel()
        thumbnailsTask?.cancel()
        currentVideo = nil

        loadVideoTask = Task { [weak self] in
            let video = await Video.load(from: url)
            guard !Task.isCancelled else { return }

            self?.currentVideo = video
            self?.loadThumbnails(for: video, containerSize: containerSize)
        }
    }

    deinit {
        loadVideoTask?.cancel()
        thumbnailsTask?.cancel()
    }
}

extension EditorViewModel {
    private func loadThumbnails(for video: Video, containerSize: CGSize) {
        let videoID = video.id
        thumbnailsTask = Task.detached(priority: .userInitiated) {
            let thumbnails = await video.makeThumbnails(containerSize: containerSize)
            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self, self.currentVideo?.id == videoID else { return }
                self.currentVideo?.thumbnailsImages = thumbnails
            }
        }
    }
}

//MARK: - Tools logic
extension EditorViewModel{
    
    
    func setFilter(_ filter: String?){
        currentVideo?.setFilter(filter)
        if filter != nil{
            setTools()
        }else{
            removeTool()
        }
    }
    
    
    func setText(_ textBox: [TextBox]){
        currentVideo?.textBoxes = textBox
        setTools()
    }
    
    func setFrames(){
        currentVideo?.videoFrames = frames
        setTools()
    }
    
    func setCorrections(_ correction: ColorCorrection){
        currentVideo?.colorCorrection = correction
        setTools()
    }
    
    func updateRate(rate: Float){
        currentVideo?.updateRate(rate)
        setTools()
    }
    
    func rotate(){
        currentVideo?.rotate()
        setTools()
    }
    
    func toggleMirror(){
        currentVideo?.isMirror.toggle()
        setTools()
    }
    
    func setAudio(_ audio: Audio){
        currentVideo?.audio = audio
        setTools()
    }
    
    func setTools(){
        guard let selectedTools else { return }
        currentVideo?.appliedTool(for: selectedTools)
    }
    
    func removeTool(){
        guard let selectedTools else { return }
        self.currentVideo?.removeTool(for: selectedTools)
    }
    
    func removeAudio(){
        guard let url = currentVideo?.audio?.url else {return}
        FileManager.default.removefileExists(for: url)
        currentVideo?.audio = nil
        isSelectVideo = true
        removeTool()
    }
  
    func reset(){
        guard let selectedTools else {return}
       
        switch selectedTools{
            
        case .cut:
            currentVideo?.resetRangeDuration()
        case .speed:
            currentVideo?.resetRate()
        case .text, .audio, .crop:
            break
        case .filters:
            currentVideo?.setFilter(nil)
        case .corrections:
            currentVideo?.colorCorrection = ColorCorrection()
        case .frames:
            frames.reset()
            currentVideo?.videoFrames = nil
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            self?.removeTool()
        }
    }
}
