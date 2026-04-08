import CoreGraphics
import Foundation

public struct VideoCanvasTransform: Codable, Equatable, Sendable {

    // MARK: - Public Properties

    public static let identity = Self()

    public var normalizedOffset: CGPoint = .zero
    public var zoom: CGFloat = 1
    public var rotationRadians: CGFloat = 0

    public var isIdentity: Bool {
        abs(normalizedOffset.x) < Constants.numericTolerance
            && abs(normalizedOffset.y) < Constants.numericTolerance
            && abs(zoom - 1) < Constants.numericTolerance
            && abs(rotationRadians) < Constants.numericTolerance
    }

    public var shouldShowResetButton: Bool {
        isIdentity == false
    }

    // MARK: - Private Properties

    private enum Constants {
        static let numericTolerance: CGFloat = 0.001
    }

    // MARK: - Initializer

    public init(
        normalizedOffset: CGPoint = .zero,
        zoom: CGFloat = 1,
        rotationRadians: CGFloat = 0
    ) {
        self.normalizedOffset = normalizedOffset
        self.zoom = zoom
        self.rotationRadians = rotationRadians
    }

}

public struct VideoCanvasSnapshot: Codable, Equatable, Sendable {

    // MARK: - Public Properties

    public static let initial = Self()

    public var preset: VideoCanvasPreset = .original
    public var freeCanvasSize = CGSize(width: 1080, height: 1080)
    public var transform: VideoCanvasTransform = .identity
    public var showsSafeAreaOverlay = false

    public var isIdentity: Bool {
        preset == .original
            && transform.isIdentity
    }

    // MARK: - Initializer

    public init(
        preset: VideoCanvasPreset = .original,
        freeCanvasSize: CGSize = CGSize(width: 1080, height: 1080),
        transform: VideoCanvasTransform = .identity,
        showsSafeAreaOverlay: Bool = false
    ) {
        self.preset = preset
        self.freeCanvasSize = freeCanvasSize
        self.transform = transform
        self.showsSafeAreaOverlay = showsSafeAreaOverlay
    }

}
