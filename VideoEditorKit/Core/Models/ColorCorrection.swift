//
//  ColorCorrection.swift
//  VideoEditorKit
//
//  Created by Codex on 30.03.2026.
//

import CoreImage
import Foundation

enum CorrectionType: String, CaseIterable {

    // MARK: - Public Properties

    case brightness = "Brightness"
    case contrast = "Contrast"
    case saturation = "Saturation"

    var key: String {
        switch self {
        case .brightness: kCIInputBrightnessKey
        case .contrast: kCIInputContrastKey
        case .saturation: kCIInputSaturationKey
        }
    }

}

struct ColorCorrection: Equatable, Sendable {

    // MARK: - Public Properties

    var brightness: Double = 0
    var contrast: Double = 0
    var saturation: Double = 0

    var isIdentity: Bool {
        abs(brightness) <= 0.001
            && abs(contrast) <= 0.001
            && abs(saturation) <= 0.001
    }

    // MARK: - Public Methods

    func updating(
        _ keyPath: WritableKeyPath<Self, Double>,
        to newValue: Double
    ) -> Self {
        var updatedCorrection = self
        updatedCorrection[keyPath: keyPath] = newValue
        return updatedCorrection
    }

}
