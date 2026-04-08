//
//  ImpactHaptics.swift
//  VideoEditorKit
//
//  Created by Codex on 07.04.2026.
//

import SwiftUI

@MainActor
enum ImpactHaptics {

    // MARK: - Public Methods

    static func light(intensity: CGFloat = 0.75) {
        impact(
            style: .light,
            intensity: intensity
        )
    }

    static func soft(intensity: CGFloat = 1) {
        impact(
            style: .soft,
            intensity: intensity
        )
    }

    // MARK: - Private Methods

    private static func impact(
        style: UIImpactFeedbackGenerator.FeedbackStyle,
        intensity: CGFloat
    ) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

}
