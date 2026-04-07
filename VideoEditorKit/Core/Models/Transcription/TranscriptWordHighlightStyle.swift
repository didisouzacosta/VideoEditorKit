//
//  TranscriptWordHighlightStyle.swift
//  VideoEditorKit
//
//  Created by Codex on 07.04.2026.
//

import CoreGraphics
import Foundation

enum TranscriptWordHighlightStyle {

    // MARK: - Public Properties

    static let cornerRadius: CGFloat = 6
    static let horizontalInset: CGFloat = 32
    static let interWordSpacing: CGFloat = 2
    static let activeOpacity: Float = 1
    static let inactiveOpacity: Float = 0
    static let activeScale: CGFloat = 1
    static let inactiveScale: CGFloat = 0.94
    static let overshootScale: CGFloat = 1.06
    static let shadowOpacity: Float = 0.22
    static let shadowRadius: CGFloat = 8
    static let shadowYOffset: CGFloat = 3
    static let animationDuration = 0.22
    static let animationBounce = 0.14

    static var previewInitialScale: CGFloat {
        activeScale
    }

    static var previewInitialOpacity: Double {
        Double(activeOpacity)
    }

    // MARK: - Public Methods

    static func resolvedScaleAnimationValues() -> [CGFloat] {
        [
            inactiveScale,
            overshootScale,
            activeScale,
            activeScale,
            overshootScale,
            inactiveScale,
        ]
    }

    static func resolvedScaleAnimationKeyTimes() -> [NSNumber] {
        [0, 0.14, 0.24, 0.76, 0.9, 1]
    }

    static func resolvedOpacityAnimationValues() -> [Float] {
        [
            inactiveOpacity,
            activeOpacity,
            activeOpacity,
            inactiveOpacity,
        ]
    }

    static func resolvedOpacityAnimationKeyTimes() -> [NSNumber] {
        [0, 0.0001, 0.999, 1]
    }

    static func resolvedPreviewScaleKeyframes() -> [(value: CGFloat, duration: Double)] {
        let keyTimes = resolvedScaleAnimationKeyTimes().map(\.doubleValue)

        return [
            (
                value: overshootScale,
                duration: animationDuration * keyTimes[1]
            ),
            (
                value: activeScale,
                duration: animationDuration
                    * max(
                        keyTimes[2] - keyTimes[1],
                        0.001
                    )
            ),
            (
                value: activeScale,
                duration: animationDuration
                    * max(
                        keyTimes[3] - keyTimes[2],
                        0.001
                    )
            ),
            (
                value: activeScale,
                duration: animationDuration
                    * max(
                        keyTimes[4] - keyTimes[3],
                        0.001
                    )
            ),
            (
                value: activeScale,
                duration: animationDuration
                    * max(
                        keyTimes[5] - keyTimes[4],
                        0.001
                    )
            ),
        ]
    }

    static func resolvedPreviewOpacityKeyframes() -> [(value: Double, duration: Double)] {
        let keyTimes = resolvedOpacityAnimationKeyTimes().map(\.doubleValue)

        return [
            (
                value: Double(activeOpacity),
                duration: animationDuration
                    * max(keyTimes[1], 0.001)
            ),
            (
                value: Double(activeOpacity),
                duration: animationDuration
                    * max(keyTimes[2] - keyTimes[1], 0.001)
            ),
            (
                value: Double(activeOpacity),
                duration: animationDuration
                    * max(keyTimes[3] - keyTimes[2], 0.001)
            ),
        ]
    }

}
