//
//  View+Extension.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import UIKit

extension View {
    
    func vBottom() -> some View {
        frame(maxHeight: .infinity, alignment: .bottom)
    }

    func hCenter() -> some View {
        frame(maxWidth: .infinity, alignment: .center)
    }

    func hLeading() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }

    func allFrame() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    nonisolated func card(
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
    nonisolated func circleControl(
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
    nonisolated func capsuleControl(
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
