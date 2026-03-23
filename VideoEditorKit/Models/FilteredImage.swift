//
//  FilteredImage.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import CoreImage
import Foundation
import SwiftUI

struct FilteredImage: Identifiable {
    var id: UUID = UUID()
    var image: UIImage
    var filter: CIFilter
}

enum CorrectionType: String, CaseIterable {
    case brightness = "Brightness"
    case contrast = "Contrast"
    case saturation = "Saturation"

    var key: String {
        switch self {
        case .brightness: return kCIInputBrightnessKey
        case .contrast: return kCIInputContrastKey
        case .saturation: return kCIInputSaturationKey
        }
    }
}

struct ColorCorrection {
    var brightness: Double = 0
    var contrast: Double = 0
    var saturation: Double = 0
}
