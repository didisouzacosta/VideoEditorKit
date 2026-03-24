//
//  View+Style.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import UIKit

enum Theme {
    static let accent = Color.accentColor
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let selection = Color(uiColor: .systemBlue)
    static let destructive = Color(uiColor: .systemRed)
    static let outline = Color(uiColor: .separator).opacity(0.35)
    static let sliderTrack = Color(uiColor: .quaternaryLabel).opacity(0.35)
    static let sliderThumb = Color(uiColor: .systemBackground)
    static let rootBackground = LinearGradient(
        colors: [
            Color(uiColor: .systemBackground),
            Color(uiColor: .secondarySystemBackground),
            Color(uiColor: .tertiarySystemBackground),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let editorBackground = LinearGradient(
        colors: [
            Color(uiColor: .systemBackground),
            Color(uiColor: .secondarySystemBackground),
            Color(uiColor: .tertiarySystemBackground),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let editorGlow = RadialGradient(
        colors: [
            accent.opacity(0.24),
            .clear,
        ],
        center: .topTrailing,
        startRadius: 40,
        endRadius: 520
    )
    static let scrim = Color(uiColor: .label).opacity(0.18)
}

extension View {
    @ViewBuilder
    nonisolated func ios26Card(
        cornerRadius: CGFloat = 28,
        prominent: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if let tint {
            self.glassEffect(
                .regular.tint(tint.opacity(prominent ? 0.30 : 0.18)),
                in: .rect(cornerRadius: cornerRadius))
        } else {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    nonisolated func ios26CircleControl(
        prominent: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if let tint {
            self.glassEffect(
                .regular.tint(tint.opacity(prominent ? 0.30 : 0.18)).interactive(), in: .circle)
        } else {
            self.glassEffect(.regular.interactive(), in: .circle)
        }
    }

    @ViewBuilder
    nonisolated func ios26CapsuleControl(
        prominent: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if let tint {
            self.glassEffect(
                .regular.tint(tint.opacity(prominent ? 0.30 : 0.18)).interactive(), in: .capsule)
        } else {
            self.glassEffect(.regular.interactive(), in: .capsule)
        }
    }
}
