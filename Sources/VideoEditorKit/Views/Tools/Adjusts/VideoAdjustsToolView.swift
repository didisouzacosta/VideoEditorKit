//
//  VideoAdjustsToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct VideoAdjustsToolView: View {

    // MARK: - Bindings

    @Binding private var adjusts: ColorAdjusts

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            adjustSlider(
                title: ColorAdjustType.brightness.title,
                systemImage: "sun.max",
                value: $adjusts.brightness
            )
            adjustSlider(
                title: ColorAdjustType.contrast.title,
                systemImage: "circle.lefthalf.filled",
                value: $adjusts.contrast
            )
            adjustSlider(
                title: ColorAdjustType.saturation.title,
                systemImage: "drop",
                value: $adjusts.saturation
            )
        }
        .safeAreaPadding(32)
    }

    // MARK: - Initializer

    init(_ adjusts: Binding<ColorAdjusts>) {
        _adjusts = adjusts
    }

}

extension VideoAdjustsToolView {

    // MARK: - Private Methods

    fileprivate func adjustSlider(
        title: String,
        systemImage: String,
        value: Binding<Double>
    ) -> some View {
        HStack {
            Image(systemName: systemImage)
                .accessibilityLabel(title)
            Slider(value: value, in: -1...1)
                .tint(Theme.accent)
            Text(value.wrappedValue, format: .number.precision(.fractionLength(1)))
                .monospacedDigit()
        }
        .font(.caption)
    }

}

#Preview {
    VideoAdjustsToolView(.constant(Video.mock.colorAdjusts))
}
