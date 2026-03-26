//
//  LineSlider.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct LineSlider: View {

    // MARK: - Bindings

    @Binding private var value: Double

    // MARK: - Public Properties

    private let range: ClosedRange<Double>
    private let onEditingChanged: () -> Void

    // MARK: - Body

    var body: some View {

        GeometryReader { proxy in
            CustomSlider(
                value: $value,
                in: range,
                onChanged: {

                    onEditingChanged()

                },
                track: {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                },
                thumb: {
                    Capsule()
                        .foregroundStyle(Theme.accent)
                }, thumbSize: CGSize(width: 10, height: proxy.size.height))
        }
    }

    // MARK: - Initializer

    init(value: Binding<Double>, range: ClosedRange<Double>, onEditingChanged: @escaping () -> Void) {
        self._value = value
        self.range = range
        self.onEditingChanged = onEditingChanged
    }

}

#Preview {
    LineSlider(value: .constant(100), range: 14...100) {}
        .frame(width: 250, height: 60)
        .background(Color(uiColor: .secondarySystemBackground))
}
