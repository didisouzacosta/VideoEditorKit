//
//  Helpers.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import CoreImage
import Foundation

enum Helpers {

    // MARK: - Public Methods

    static func createColorCorrectionFilter(_ colorCorrection: ColorCorrection?) -> CIFilter? {
        guard let colorCorrection else { return nil }

        let colorCorrectionFilter = CIFilter(name: "CIColorControls")

        colorCorrectionFilter?.setValue(
            colorCorrection.brightness,
            forKey: CorrectionType.brightness.key
        )

        colorCorrectionFilter?.setValue(
            colorCorrection.contrast + 1,
            forKey: CorrectionType.contrast.key
        )

        colorCorrectionFilter?.setValue(
            colorCorrection.saturation + 1,
            forKey: CorrectionType.saturation.key
        )

        return colorCorrectionFilter
    }

    static func createColorCorrectionFilters(
        colorCorrection: ColorCorrection?
    ) -> [CIFilter] {
        guard let correctionFilter = createColorCorrectionFilter(colorCorrection) else {
            return []
        }

        return [correctionFilter]
    }

}
