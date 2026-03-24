//
//  ToolModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation

enum ToolEnum: Int, CaseIterable {
    case cut, speed, crop, audio, text, filters, corrections, frames

    static var menuCases: [ToolEnum] {
        allCases.filter { $0 != .cut }
    }

    var title: String {
        switch self {
        case .cut: return "Cut"
        case .speed: return "Speed"
        case .crop: return "Crop"
        case .audio: return "Audio"
        case .text: return "Text"
        case .filters: return "Filters"
        case .corrections: return "Corrections"
        case .frames: return "Frames"
        }
    }

    var image: String {
        switch self {
        case .cut: return "scissors"
        case .speed: return "timer"
        case .crop: return "crop"
        case .audio: return "waveform"
        case .text: return "t.square.fill"
        case .filters: return "camera.filters"
        case .corrections: return "circle.righthalf.filled"
        case .frames: return "person.crop.artframe"
        }
    }

}
