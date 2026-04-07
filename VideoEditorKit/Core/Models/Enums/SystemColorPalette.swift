//
//  SystemColorPalette.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct SystemColorOption: Identifiable, Hashable {

    // MARK: - Public Properties

    let id: String
    let color: Color

}

enum SystemColorPalette {
    // MARK: - Public Properties

    static let textBackgrounds: [SystemColorOption] = [
        .init(id: "background", color: Color(uiColor: .systemBackground)),
        .init(id: "secondaryBackground", color: Color(uiColor: .secondarySystemBackground)),
        .init(id: "tertiaryBackground", color: Color(uiColor: .tertiarySystemBackground)),
        .init(id: "blue", color: Color(uiColor: .systemBlue)),
        .init(id: "teal", color: Color(uiColor: .systemTeal)),
        .init(id: "green", color: Color(uiColor: .systemGreen)),
        .init(id: "orange", color: Color(uiColor: .systemOrange)),
        .init(id: "red", color: Color(uiColor: .systemRed)),
    ]

    static let textForegrounds: [SystemColorOption] = [
        .init(id: "label", color: Color(uiColor: .label)),
        .init(id: "secondaryLabel", color: Color(uiColor: .secondaryLabel)),
        .init(id: "tertiaryLabel", color: Color(uiColor: .tertiaryLabel)),
        .init(id: "background", color: Color(uiColor: .systemBackground)),
        .init(id: "blue", color: Color(uiColor: .systemBlue)),
        .init(id: "teal", color: Color(uiColor: .systemTeal)),
        .init(id: "orange", color: Color(uiColor: .systemOrange)),
        .init(id: "red", color: Color(uiColor: .systemRed)),
    ]

    static let frameColors: [SystemColorOption] = [
        .init(id: "background", color: Color(uiColor: .systemBackground)),
        .init(id: "secondaryBackground", color: Color(uiColor: .secondarySystemBackground)),
        .init(id: "blue", color: Color(uiColor: .systemBlue)),
        .init(id: "teal", color: Color(uiColor: .systemTeal)),
        .init(id: "green", color: Color(uiColor: .systemGreen)),
        .init(id: "orange", color: Color(uiColor: .systemOrange)),
        .init(id: "red", color: Color(uiColor: .systemRed)),
    ]

    // MARK: - Public Methods

    static func matches(_ lhs: Color, _ rhs: Color) -> Bool {
        UIColor(lhs).resolvedColor(with: .current).cgColor == UIColor(rhs).resolvedColor(with: .current).cgColor
    }
}
