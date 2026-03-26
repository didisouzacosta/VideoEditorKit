//
//  TextBox.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import SwiftUI

struct TextBox: Identifiable {

    // MARK: - Public Properties

    var id: UUID = UUID()
    var text: String = ""
    var fontSize: CGFloat = 20
    var lastFontSize: CGFloat = .zero
    var bgColor: Color = Color(uiColor: .systemBackground)
    var fontColor: Color = Color(uiColor: .label)
    var timeRange: ClosedRange<Double> = 0...3
    var offset: CGSize = .zero
    var lastOffset: CGSize = .zero

}

extension TextBox: Equatable {}

extension TextBox {

    // MARK: - Public Properties

    static let texts: [TextBox] =

        [

            .init(
                text: "Test1",
                fontSize: 38,
                bgColor: Color(uiColor: .systemBlue),
                fontColor: Color(uiColor: .systemBackground),
                timeRange: 0...2
            ),
            .init(
                text: "Test2",
                fontSize: 38,
                bgColor: Color(uiColor: .secondarySystemBackground),
                fontColor: Color(uiColor: .label),
                timeRange: 2...6
            ),
            .init(
                text: "Test3",
                fontSize: 38,
                bgColor: Color(uiColor: .systemBackground),
                fontColor: Color(uiColor: .systemRed),
                timeRange: 3...6
            ),
            .init(
                text: "Test4",
                fontSize: 38,
                bgColor: Color(uiColor: .systemBackground),
                fontColor: Color(uiColor: .systemTeal),
                timeRange: 5...6
            ),
            .init(
                text: "Test5",
                fontSize: 38,
                bgColor: Color(uiColor: .tertiarySystemBackground),
                fontColor: Color(uiColor: .label),
                timeRange: 1...6
            ),
        ]

    static let simple = TextBox(
        text: "Test",
        fontSize: 38,
        bgColor: Color(uiColor: .systemBackground),
        fontColor: Color(uiColor: .label),
        timeRange: 1...3
    )

}
