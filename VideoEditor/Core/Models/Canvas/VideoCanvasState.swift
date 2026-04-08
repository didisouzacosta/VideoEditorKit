//
//  VideoCanvasState.swift
//  VideoEditorKit
//
//  Created by Codex on 31.03.2026.
//

import CoreGraphics
import Foundation

struct VideoCanvasTransform: Codable, Equatable, Sendable {

    // MARK: - Public Properties

    static let identity = Self()

    var normalizedOffset: CGPoint = .zero
    var zoom: CGFloat = 1
    var rotationRadians: CGFloat = 0

    var isIdentity: Bool {
        abs(normalizedOffset.x) < Constants.numericTolerance
            && abs(normalizedOffset.y) < Constants.numericTolerance
            && abs(zoom - 1) < Constants.numericTolerance
            && abs(rotationRadians) < Constants.numericTolerance
    }

    var shouldShowResetButton: Bool {
        isIdentity == false
    }

    // MARK: - Private Properties

    private enum Constants {
        static let numericTolerance: CGFloat = 0.001
    }

}

struct VideoCanvasSnapshot: Codable, Equatable, Sendable {

    // MARK: - Public Properties

    static let initial = Self()

    var preset: VideoCanvasPreset = .original
    var freeCanvasSize = CGSize(width: 1080, height: 1080)
    var transform: VideoCanvasTransform = .identity
    var showsSafeAreaOverlay = false

    var isIdentity: Bool {
        preset == .original
            && transform.isIdentity
    }

}
