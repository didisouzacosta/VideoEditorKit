//
//  FiltersViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Observation
import SwiftUI

@MainActor
@Observable
final class FiltersViewModel {

    // MARK: - Public Properties

    var images = [FilteredImage]()
    var colorCorrection = ColorCorrection()
    var value = 1.0
    var image: UIImage?
    var selectedFilterName: String?
    var hasPreviewImage: Bool {
        image != nil
    }

    // MARK: - Public Methods

    func loadFilters(for image: UIImage) {
        self.image = image
        images.removeAll()

        guard let ciImage = CIImage(image: image) else {
            return
        }

        let context = CIContext()
        images = FilterDefinition.allCases.compactMap { definition in
            let filter = definition.makeFilter()
            filter.setValue(ciImage, forKey: kCIInputImageKey)

            guard let outputImage = filter.outputImage,
                let cgImage = context.createCGImage(outputImage, from: ciImage.extent)
            else {
                return nil
            }

            return FilteredImage(image: UIImage(cgImage: cgImage), filter: filter)
        }
        .sorted { $0.filter.name < $1.filter.name }
    }

    func loadFiltersIfNeeded(from image: UIImage?) {
        guard let image else { return }
        loadFilters(for: image)
    }

    func selectFilter(_ filterName: String?) {
        selectedFilterName = filterName
    }

    func isSelected(_ filterName: String?) -> Bool {
        selectedFilterName == filterName
    }

    func sync(with video: Video) {
        colorCorrection = video.colorCorrection
        selectedFilterName = video.filterName
    }

}

private enum FilterDefinition: CaseIterable {
    case chrome
    case fade
    case instant
    case mono
    case noir
    case process
    case tonal
    case transfer
    case sepia
    case thermal
    case vignette
    case vignetteEffect
    case xRay
    case gaussianBlur

    func makeFilter() -> CIFilter {
        switch self {
        case .chrome: return .photoEffectChrome()
        case .fade: return .photoEffectFade()
        case .instant: return .photoEffectInstant()
        case .mono: return .photoEffectMono()
        case .noir: return .photoEffectNoir()
        case .process: return .photoEffectProcess()
        case .tonal: return .photoEffectTonal()
        case .transfer: return .photoEffectTransfer()
        case .sepia: return .sepiaTone()
        case .thermal: return .thermal()
        case .vignette: return .vignette()
        case .vignetteEffect: return .vignetteEffect()
        case .xRay: return .xRay()
        case .gaussianBlur: return .gaussianBlur()
        }
    }
}
