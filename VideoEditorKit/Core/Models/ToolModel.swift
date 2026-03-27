//
//  ToolModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation

enum ToolEnum: Int, CaseIterable, Identifiable {
    
    case cut, speed, crop, audio, text, filters, corrections, frames

    var id: Int {
        rawValue
    }

    static var all: [ToolEnum] {
        allCases.filter { $0 != .cut }
    }

    var title: String {
        switch self {
        case .cut: "Cut"
        case .speed: "Speed"
        case .crop: "Crop"
        case .audio: "Audio"
        case .text: "Text"
        case .filters: "Filters"
        case .corrections: "Corrections"
        case .frames: "Frames"
        }
    }

    var image: String {
        switch self {
        case .cut: "scissors"
        case .speed: "timer"
        case .crop: "crop"
        case .audio: "waveform"
        case .text: "t.square.fill"
        case .filters: "camera.filters"
        case .corrections: "circle.righthalf.filled"
        case .frames: "person.crop.artframe"
        }
    }
    
}
