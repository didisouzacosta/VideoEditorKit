//
//  VideoQuality.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import Foundation

enum VideoQuality: Int, CaseIterable {

    // MARK: - Public Properties

    case low, medium, high

    enum RenderLayout: Sendable {
        case landscape
        case portrait
    }

    var exportPresetName: String {
        switch self {
        case .low:
            return AVAssetExportPresetMediumQuality
        case .high, .medium:
            return AVAssetExportPresetHighestQuality
        }
    }

    var order: Int {
        switch self {
        case .high:
            0
        case .medium:
            1
        case .low:
            2
        }
    }

    var title: String {
        switch self {
        case .low: return "qHD - 480"
        case .medium: return "HD - 720p"
        case .high: return "Full HD - 1080p"
        }
    }

    var subtitle: String {
        switch self {
        case .low: return "Fast loading and small size, low quality"
        case .medium: return "Optimal size to quality ratio"
        case .high: return "Ideal for publishing on social networks"
        }
    }

    var size: CGSize {
        switch self {
        case .low: return .init(width: 854, height: 480)
        case .medium: return .init(width: 1280, height: 720)
        case .high: return .init(width: 1920, height: 1080)
        }
    }

    var portraitSize: CGSize {
        CGSize(width: size.height, height: size.width)
    }

    var frameRate: Double {
        switch self {
        case .low, .medium: return 30
        case .high: return 60
        }
    }

    var bitrate: Double {
        switch self {
        case .low: return 2.5
        case .medium: return 5
        case .high: return 8
        }
    }

    var megaBytesPerSecond: Double {
        megaBytesPerSecond(for: .landscape)
    }

    // MARK: - Public Methods

    func size(for layout: RenderLayout) -> CGSize {
        switch layout {
        case .landscape:
            size
        case .portrait:
            portraitSize
        }
    }

    func megaBytesPerSecond(for layout: RenderLayout) -> Double {
        megaBytesPerSecond(for: size(for: layout))
    }

    func megaBytesPerSecond(for renderSize: CGSize) -> Double {
        let totalPixels = renderSize.width * renderSize.height
        let bitsPerSecond = bitrate * Double(totalPixels)
        let bytesPerSecond = bitsPerSecond / 8.0  // Convert to bytes

        return bytesPerSecond / (1024 * 1024)
    }

    func calculateVideoSize(
        duration: Double,
        layout: RenderLayout = .landscape
    ) -> Double? {
        duration * megaBytesPerSecond(for: layout)
    }

    func calculateVideoSize(
        duration: Double,
        renderSize: CGSize
    ) -> Double? {
        duration * megaBytesPerSecond(for: renderSize)
    }

}

struct ExportQualityAvailability: Hashable, Identifiable {

    // MARK: - Public Properties

    static var allEnabled: [Self] {
        enabled(VideoQuality.allCases)
    }

    static var premiumLocked: [Self] {
        [
            .enabled(.low),
            .blocked(.medium),
            .blocked(.high),
        ]
    }

    let quality: VideoQuality
    let access: ToolAvailability.Access
    let order: Int

    var id: VideoQuality {
        quality
    }

    var isBlocked: Bool {
        access == .blocked
    }

    var isEnabled: Bool {
        access == .enabled
    }

    // MARK: - Initializer

    init(
        _ quality: VideoQuality,
        access: ToolAvailability.Access = .enabled,
        order: Int? = nil
    ) {
        self.quality = quality
        self.access = access
        self.order = order ?? quality.order
    }

    static func enabled(
        _ quality: VideoQuality,
        order: Int? = nil
    ) -> Self {
        .init(quality, order: order)
    }

    static func blocked(
        _ quality: VideoQuality,
        order: Int? = nil
    ) -> Self {
        .init(quality, access: .blocked, order: order)
    }

    static func enabled(_ qualities: [VideoQuality]) -> [Self] {
        qualities.map { Self.enabled($0) }
    }

}
