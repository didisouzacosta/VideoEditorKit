import AVFoundation
import CoreGraphics
import Foundation

public enum VideoQuality: Int, CaseIterable, Sendable {

    // MARK: - Public Properties

    case low
    case medium
    case high

    public enum RenderLayout: Sendable {
        case landscape
        case portrait
    }

    public var exportPresetName: String {
        switch self {
        case .low:
            AVAssetExportPresetMediumQuality
        case .high, .medium:
            AVAssetExportPresetHighestQuality
        }
    }

    public var order: Int {
        switch self {
        case .high:
            0
        case .medium:
            1
        case .low:
            2
        }
    }

    public var title: String {
        switch self {
        case .low:
            "qHD - 480"
        case .medium:
            "HD - 720p"
        case .high:
            "Full HD - 1080p"
        }
    }

    public var subtitle: String {
        switch self {
        case .low:
            "Fast loading and small size, low quality"
        case .medium:
            "Optimal size to quality ratio"
        case .high:
            "Ideal for publishing on social networks"
        }
    }

    public var size: CGSize {
        switch self {
        case .low:
            .init(width: 854, height: 480)
        case .medium:
            .init(width: 1280, height: 720)
        case .high:
            .init(width: 1920, height: 1080)
        }
    }

    public var portraitSize: CGSize {
        CGSize(width: size.height, height: size.width)
    }

    public var frameRate: Double {
        switch self {
        case .low, .medium:
            30
        case .high:
            60
        }
    }

    public var bitrate: Double {
        switch self {
        case .low:
            2.5
        case .medium:
            5
        case .high:
            8
        }
    }

    public var megaBytesPerSecond: Double {
        megaBytesPerSecond(for: .landscape)
    }

    // MARK: - Public Methods

    public func size(for layout: RenderLayout) -> CGSize {
        switch layout {
        case .landscape:
            size
        case .portrait:
            portraitSize
        }
    }

    public func megaBytesPerSecond(for layout: RenderLayout) -> Double {
        megaBytesPerSecond(for: size(for: layout))
    }

    public func megaBytesPerSecond(for renderSize: CGSize) -> Double {
        let totalPixels = renderSize.width * renderSize.height
        let bitsPerSecond = bitrate * Double(totalPixels)
        let bytesPerSecond = bitsPerSecond / 8.0

        return bytesPerSecond / (1024 * 1024)
    }

    public func calculateVideoSize(
        duration: Double,
        layout: RenderLayout = .landscape
    ) -> Double? {
        duration * megaBytesPerSecond(for: layout)
    }

    public func calculateVideoSize(
        duration: Double,
        renderSize: CGSize
    ) -> Double? {
        duration * megaBytesPerSecond(for: renderSize)
    }

}

public struct ExportQualityAvailability: Hashable, Identifiable {

    // MARK: - Public Properties

    public static var allEnabled: [Self] {
        enabled(VideoQuality.allCases)
    }

    public static var premiumLocked: [Self] {
        [
            .enabled(.low),
            .blocked(.medium),
            .blocked(.high),
        ]
    }

    public let quality: VideoQuality
    public let access: ToolAvailability.Access
    public let order: Int

    public var id: VideoQuality {
        quality
    }

    public var isBlocked: Bool {
        access == .blocked
    }

    public var isEnabled: Bool {
        access == .enabled
    }

    // MARK: - Initializer

    public init(
        _ quality: VideoQuality,
        access: ToolAvailability.Access = .enabled,
        order: Int? = nil
    ) {
        self.quality = quality
        self.access = access
        self.order = order ?? quality.order
    }

    public static func enabled(
        _ quality: VideoQuality,
        order: Int? = nil
    ) -> Self {
        .init(quality, order: order)
    }

    public static func blocked(
        _ quality: VideoQuality,
        order: Int? = nil
    ) -> Self {
        .init(quality, access: .blocked, order: order)
    }

    public static func enabled(_ qualities: [VideoQuality]) -> [Self] {
        qualities.map { Self.enabled($0) }
    }

}
