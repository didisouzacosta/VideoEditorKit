//
//  FiltersViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
final class FiltersViewModel: ObservableObject {
    @Published var images = [FilteredImage]()
    @Published var colorCorrection = ColorCorrection()
    @Published var value = 1.0
    var image: UIImage?
    
    func loadFilters(for image: UIImage){
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
                  let cgImage = context.createCGImage(outputImage, from: ciImage.extent) else {
                return nil
            }

            return FilteredImage(image: UIImage(cgImage: cgImage), filter: filter)
        }
        .sorted { $0.filter.name < $1.filter.name }
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
