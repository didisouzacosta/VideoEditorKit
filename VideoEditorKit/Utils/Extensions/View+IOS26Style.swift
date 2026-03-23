//
//  View+IOS26Style.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

enum IOS26Theme {
    static let accent = Color(red: 0.49, green: 0.84, blue: 0.95)
    static let accentSecondary = Color(red: 0.45, green: 0.60, blue: 0.98)
    static let rootBackground = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.10, blue: 0.18),
            Color(red: 0.17, green: 0.27, blue: 0.42),
            Color(red: 0.56, green: 0.65, blue: 0.82),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let editorBackground = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.04, blue: 0.08),
            Color(red: 0.07, green: 0.12, blue: 0.20),
            Color(red: 0.16, green: 0.21, blue: 0.31),
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
    static let scrim = Color.black.opacity(0.32)
}

extension View {
    @ViewBuilder
    nonisolated func ios26Card(
        cornerRadius: CGFloat = 28,
        prominent: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                self.glassEffect(
                    .regular.tint(tint.opacity(prominent ? 0.30 : 0.18)),
                    in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        }
    }

    @ViewBuilder
    nonisolated func ios26CircleControl(
        prominent: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                self.glassEffect(
                    .regular.tint(tint.opacity(prominent ? 0.30 : 0.18)).interactive(), in: .circle)
            } else {
                self.glassEffect(.regular.interactive(), in: .circle)
            }
        } else {
            let fill =
                tint?.opacity(prominent ? 0.26 : 0.14) ?? Color.white.opacity(prominent ? 0.18 : 0.10)
            self
                .background(fill, in: .circle)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
        }
    }

    @ViewBuilder
    nonisolated func ios26CapsuleControl(
        prominent: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                self.glassEffect(
                    .regular.tint(tint.opacity(prominent ? 0.30 : 0.18)).interactive(), in: .capsule)
            } else {
                self.glassEffect(.regular.interactive(), in: .capsule)
            }
        } else {
            let fill =
                tint?.opacity(prominent ? 0.26 : 0.14) ?? Color.white.opacity(prominent ? 0.18 : 0.10)
            self
                .background(fill, in: .capsule)
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
        }
    }
}
