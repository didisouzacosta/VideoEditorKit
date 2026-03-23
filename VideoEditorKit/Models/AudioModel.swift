//
//  AudioModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import AVKit

struct Audio: Identifiable, Equatable{
    
    var id: UUID = UUID()
    var url: URL
    var duration: Double
    var volume: Float = 1.0
    
    var asset: AVAsset{
        AVURLAsset(url: url)
    }
    
    func createSimples(_ size: CGFloat) -> [AudioSimple]{
        let simplesCount = Int(size / 3)
        return (1...simplesCount).map({.init(id: $0)})
    }
    
    mutating func setVolume(_ value: Float){
        volume = value
    }
    
    struct AudioSimple: Identifiable{
        var id: Int
        var size: CGFloat = CGFloat((5...25).randomElement() ?? 5)
    }
}
