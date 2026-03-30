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
    case square1x1
    case portrait4x5
    case landscape16x9

    static let editorPresets = Self.allCases

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .original:
            "Original"
        case .vertical9x16:
            "9:16"
        case .square1x1:
            "1:1"
        case .portrait4x5:
            "4:5"
        case .landscape16x9:
            "16:9"
        }
    }

    var subtitle: String {
        switch self {
        case .original:
            "Keeps the imported framing"
        case .vertical9x16:
            "Instagram Reels, TikTok, Shorts"
        case .square1x1:
            "Square posts and covers"
        case .portrait4x5:
            "Portrait feed posts"
        case .landscape16x9:
            "Landscape players and embeds"
        }
    }

    var dimensionTitle: String {
        switch self {
        case .original:
            "Source"
        case .vertical9x16:
            "9:16"
        case .square1x1:
            "1:1"
        case .portrait4x5:
            "4:5"
        case .landscape16x9:
            "16:9"
        }
    }

    var aspectRatio: CGFloat? {
        switch self {
        case .original:
            nil
        case .vertical9x16:
            9.0 / 16.0
        case .square1x1:
            1
        case .portrait4x5:
            4.0 / 5.0
        case .landscape16x9:
            16.0 / 9.0
        }
    }

    var isSocialVideoPreset: Bool {
        switch self {
        case .vertical9x16:
            true
        case .original, .square1x1, .portrait4x5, .landscape16x9:
            false
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
        case .vertical9x16,
            .square1x1,
            .portrait4x5,
            .landscape16x9:
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

    static func resetRect(
        matching freeformRect: VideoEditingConfiguration.FreeformRect?,
        in referenceSize: CGSize
    ) -> VideoEditingConfiguration.FreeformRect? {
        guard
            let aspectRatio = resolvedAspectRatio(
                from: freeformRect,
                in: referenceSize
            )
        else { return nil }

        return encodedRect(
            resolvedCropRect(
                aspectRatio: aspectRatio,
                in: referenceSize
            ),
            in: referenceSize
        )
    }

    static func resizedRect(
        matching freeformRect: VideoEditingConfiguration.FreeformRect?,
        in referenceSize: CGSize,
        magnification: CGFloat
    ) -> VideoEditingConfiguration.FreeformRect? {
        guard magnification.isFinite, magnification > 0 else { return freeformRect }
        guard
            let currentRect = decodedRect(
                from: freeformRect,
                in: referenceSize
            ),
            let aspectRatio = resolvedAspectRatio(
                from: freeformRect,
                in: referenceSize
            )
        else { return freeformRect }

        let maximumRect = resolvedCropRect(
            aspectRatio: aspectRatio,
            in: referenceSize
        )
        guard maximumRect.width > 0, maximumRect.height > 0 else { return freeformRect }

        let minimumWidth = max(maximumRect.width * 0.25, referenceSize.width * 0.18)
        let minimumHeight = max(maximumRect.height * 0.25, referenceSize.height * 0.18)

        var width = currentRect.width / magnification
        var height = width / aspectRatio

        if height < minimumHeight {
            height = minimumHeight
            width = height * aspectRatio
        }

        if width < minimumWidth {
            width = minimumWidth
            height = width / aspectRatio
        }

        if width > maximumRect.width {
            width = maximumRect.width
            height = width / aspectRatio
        }

        if height > maximumRect.height {
            height = maximumRect.height
            width = height * aspectRatio
        }

        let centeredRect = CGRect(
            x: currentRect.midX - width / 2,
            y: currentRect.midY - height / 2,
            width: width,
            height: height
        )

        return encodedRect(
            boundedRect(centeredRect, in: referenceSize),
            in: referenceSize
        )
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

    private static func decodedRect(
        from freeformRect: VideoEditingConfiguration.FreeformRect?,
        in referenceSize: CGSize
    ) -> CGRect? {
        guard let freeformRect else { return nil }
        guard referenceSize.width > 0, referenceSize.height > 0 else { return nil }

        return CGRect(
            x: freeformRect.x * referenceSize.width,
            y: freeformRect.y * referenceSize.height,
            width: freeformRect.width * referenceSize.width,
            height: freeformRect.height * referenceSize.height
        )
    }

    private static func encodedRect(
        _ rect: CGRect,
        in referenceSize: CGSize
    ) -> VideoEditingConfiguration.FreeformRect? {
        guard referenceSize.width > 0, referenceSize.height > 0 else { return nil }

        return .init(
            x: rect.origin.x / referenceSize.width,
            y: rect.origin.y / referenceSize.height,
            width: rect.size.width / referenceSize.width,
            height: rect.size.height / referenceSize.height
        )
    }

    private static func resolvedAspectRatio(
        from freeformRect: VideoEditingConfiguration.FreeformRect?,
        in referenceSize: CGSize
    ) -> CGFloat? {
        guard
            let currentRect = decodedRect(
                from: freeformRect,
                in: referenceSize
            ),
            currentRect.width > 0,
            currentRect.height > 0
        else { return nil }

        return currentRect.width / currentRect.height
    }

    private static func boundedRect(
        _ rect: CGRect,
        in referenceSize: CGSize
    ) -> CGRect {
        let width = min(rect.width, referenceSize.width)
        let height = min(rect.height, referenceSize.height)

        let minX = max(0, rect.origin.x)
        let minY = max(0, rect.origin.y)
        let maxX = min(referenceSize.width - width, minX)
        let maxY = min(referenceSize.height - height, minY)

        return CGRect(
            x: maxX,
            y: maxY,
            width: width,
            height: height
        )
    }

}
