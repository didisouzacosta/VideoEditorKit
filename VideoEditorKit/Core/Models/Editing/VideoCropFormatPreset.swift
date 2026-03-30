//
//  VideoCropFormatPreset.swift
//  VideoEditorKit
//
//  Created by Codex on 30.03.2026.
//

import CoreGraphics
import Foundation

enum VideoCropFormatPreset: String, CaseIterable, Identifiable, Sendable {

    // MARK: - Public Properties

    case original
    case vertical9x16

    static let phaseOnePresets: [Self] = [
        .original,
        .vertical9x16,
    ]

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .original:
            "Original"
        case .vertical9x16:
            "9:16"
        }
    }

    var subtitle: String {
        switch self {
        case .original:
            "Keeps the imported framing"
        case .vertical9x16:
            "Instagram Reels, TikTok, Shorts"
        }
    }

    var aspectRatio: CGFloat? {
        switch self {
        case .original:
            nil
        case .vertical9x16:
            9.0 / 16.0
        }
    }

    // MARK: - Public Methods

    func makeFreeformRect(
        for referenceSize: CGSize
    ) -> VideoEditingConfiguration.FreeformRect? {
        guard let aspectRatio else { return nil }
        guard referenceSize.width > 0, referenceSize.height > 0 else { return nil }

        let cropRect = Self.resolvedCropRect(
            aspectRatio: aspectRatio,
            in: referenceSize
        )

        guard cropRect.width > 0, cropRect.height > 0 else { return nil }

        return .init(
            x: cropRect.minX / referenceSize.width,
            y: cropRect.minY / referenceSize.height,
            width: cropRect.width / referenceSize.width,
            height: cropRect.height / referenceSize.height
        )
    }

    func matches(
        _ freeformRect: VideoEditingConfiguration.FreeformRect?,
        in referenceSize: CGSize
    ) -> Bool {
        switch self {
        case .original:
            return freeformRect == nil
        case .vertical9x16:
            guard let aspectRatio else { return false }
            guard let freeformRect else { return false }
            guard referenceSize.width > 0, referenceSize.height > 0 else { return false }

            let resolvedWidth = freeformRect.width * referenceSize.width
            let resolvedHeight = freeformRect.height * referenceSize.height
            guard resolvedWidth > 0, resolvedHeight > 0 else { return false }

            let resolvedAspectRatio = resolvedWidth / resolvedHeight
            return abs(resolvedAspectRatio - aspectRatio) < 0.001
        }
    }

    // MARK: - Private Methods

    private static func resolvedCropRect(
        aspectRatio: CGFloat,
        in referenceSize: CGSize
    ) -> CGRect {
        guard referenceSize.width > 0, referenceSize.height > 0 else { return .zero }

        let referenceAspectRatio = referenceSize.width / referenceSize.height

        if referenceAspectRatio > aspectRatio {
            let height = referenceSize.height
            let width = height * aspectRatio
            return CGRect(
                x: (referenceSize.width - width) / 2,
                y: 0,
                width: width,
                height: height
            )
        }

        let width = referenceSize.width
        let height = width / aspectRatio
        return CGRect(
            x: 0,
            y: (referenceSize.height - height) / 2,
            width: width,
            height: height
        )
    }

}
