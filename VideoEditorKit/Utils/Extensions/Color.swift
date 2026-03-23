//
//  Color.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import SwiftUI

extension Color {
    private static func hexComponent(from value: Float) -> String {
        let component = String(Int((value * 255).rounded()), radix: 16, uppercase: true)
        return component.count == 1 ? "0\(component)" : component
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        let color = UIColor(self)
        guard let components = color.cgColor.components, components.count >= 3 else {
            return nil
        }

        let red = Float(components[0])
        let green = Float(components[1])
        let blue = Float(components[2])
        let alpha = Float(components.count >= 4 ? components[3] : 1)

        if alpha != 1 {
            return [
                Self.hexComponent(from: red),
                Self.hexComponent(from: green),
                Self.hexComponent(from: blue),
                Self.hexComponent(from: alpha),
            ].joined()
        }

        return [
            Self.hexComponent(from: red),
            Self.hexComponent(from: green),
            Self.hexComponent(from: blue),
        ].joined()
    }
}
