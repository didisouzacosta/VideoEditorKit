//
//  Video.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import AVKit

struct Video: Identifiable, @unchecked Sendable {
    
    var id: UUID = UUID()
    var url: URL
    var asset: AVAsset
    let originalDuration: Double
    var rangeDuration: ClosedRange<Double>
    var thumbnailsImages = [ThumbnailImage]()
    var rate: Float = 1.0
    var rotation: Double = 0
    var frameSize: CGSize = .zero
    var geometrySize: CGSize = .zero
    var isMirror: Bool = false
    var toolsApplied = [Int]()
    var filterName: String? = nil
    var colorCorrection = ColorCorrection()
    var videoFrames: VideoFrames? = nil
    var textBoxes: [TextBox] = []
    var audio: Audio?
    var volume: Float = 1.0

    var totalDuration: Double{
        rangeDuration.upperBound - rangeDuration.lowerBound
    }
    
    init(url: URL){
        self.url = url
        self.asset = AVURLAsset(url: url)
        self.originalDuration = Self.loadDuration(for: url)
        self.rangeDuration = 0...originalDuration
    }
    
    init(url: URL, rangeDuration: ClosedRange<Double>, rate: Float = 1.0, rotation: Double = 0){
        self.url = url
        self.asset = AVURLAsset(url: url)
        self.originalDuration = Self.loadDuration(for: url)
        self.rangeDuration = rangeDuration
        self.rate = rate
        self.rotation = rotation
    }
    
    mutating func updateThumbnails(containerSize: CGSize){
        thumbnailsImages.removeAll(keepingCapacity: true)
        let imagesCount = thumbnailCount(containerSize)
        guard imagesCount > 0 else { return }
        
        var offset: Float64 = 0
        for i in 0..<imagesCount{
            let thumbnailImage = ThumbnailImage(image: asset.getImage(Int(offset)))
            offset = Double(i) * (originalDuration / Double(imagesCount))
            thumbnailsImages.append(thumbnailImage)
        }
    }
        
    ///reset and update
    mutating func updateRate(_ rate: Float){
       
        let lowerBound = (rangeDuration.lowerBound * Double(self.rate)) / Double(rate)
        let upperBound = (rangeDuration.upperBound *  Double(self.rate)) / Double(rate)
        rangeDuration = lowerBound...upperBound
        
        self.rate = rate
    }
    
    mutating func resetRangeDuration(){
        self.rangeDuration = 0...originalDuration
    }
    
    mutating func resetRate(){
        updateRate(1.0)
    }
    
    mutating func rotate(){
        rotation = rotation.nextAngle()
    }
    
    mutating func appliedTool(for tool: ToolEnum){
        if !isAppliedTool(for: tool){
            toolsApplied.append(tool.rawValue)
        }
    }
    
    mutating func setVolume(_ value: Float){
        volume = value
    }
    
    mutating func removeTool(for tool: ToolEnum){
        if isAppliedTool(for: tool){
            toolsApplied.removeAll(where: {$0 == tool.rawValue})
        }
    }
    
    mutating func setFilter(_ filter: String?){
        filterName = filter
    }
    
    func isAppliedTool(for tool: ToolEnum) -> Bool{
        toolsApplied.contains(tool.rawValue)
    }
    
    
    private func thumbnailCount(_ containerSize: CGSize) -> Int {
        let num = Double(containerSize.width - 32) / Double(70 / 1.5)
        
        return Int(ceil(num))
    }
    
    
    @MainActor
    static let mock: Video = .init(url:URL(string: "https://www.google.com/")!, rangeDuration: 0...250)

    private static func loadDuration(for url: URL) -> Double {
        let box = SynchronousValueBox<Double>()
        let semaphore = DispatchSemaphore(value: 0)

        Task.detached {
            defer { semaphore.signal() }
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration) {
                box.value = duration.seconds
            }
        }

        semaphore.wait()
        return box.value ?? .zero
    }
}


extension Video: Equatable{
    
    static func == (lhs: Video, rhs: Video) -> Bool {
        lhs.id == rhs.id
    }
}

extension Double{
    func nextAngle() -> Double {
        var next = Int(self) + 90
        if next >= 360 {
            next = 0
        } else if next < 0 {
            next = 360 - abs(next % 360)
        }
        return Double(next)
    }
}



struct ThumbnailImage: Identifiable{
    var id: UUID = UUID()
    var image: UIImage?
    
    
    init(image: UIImage? = nil) {
        self.image = image?.resize(to: .init(width: 250, height: 350))
    }
}


struct VideoFrames{
    var scaleValue: Double = 0
    var frameColor: Color = .white
    
    var scale: Double{
        1 - scaleValue
    }
    
    var isActive: Bool{
        scaleValue > 0
    }
    
    mutating func reset(){
        scaleValue = 0
        frameColor = .white
    }
}

private final class SynchronousValueBox<Value>: @unchecked Sendable {
    var value: Value?
}
