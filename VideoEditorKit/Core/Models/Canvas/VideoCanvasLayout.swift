//
//  VideoCanvasLayout.swift
//  VideoEditorKit
//
//  Created by Codex on 31.03.2026.
//

import CoreGraphics
import Foundation

struct VideoCanvasLayout: Equatable, Sendable {

    // MARK: - Public Properties

    let previewCanvasSize: CGSize
    let exportCanvasSize: CGSize
    let previewScale: CGFloat
    let contentBaseSize: CGSize
    let contentScale: CGFloat
    let contentCenter: CGPoint
    let totalRotationRadians: CGFloat
    let isMirrored: Bool

}
