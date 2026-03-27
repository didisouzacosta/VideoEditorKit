//
//  VideoCorrectionsToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct VideoCorrectionsToolView: View {

    // MARK: - Bindings

    @Binding private var correction: ColorCorrection

    // MARK: - Private Properties

    private let onChange: (ColorCorrection) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            correctionSlider(
                title: CorrectionType.brightness.rawValue,
                systemImage: "sun.max",
                value: $correction.brightness
            )
            correctionSlider(
                title: CorrectionType.contrast.rawValue,
                systemImage: "circle.lefthalf.filled",
                value: $correction.contrast
            )
            correctionSlider(
                title: CorrectionType.saturation.rawValue,
                systemImage: "drop",
                value: $correction.saturation
            )
        }
    }

    // MARK: - Initializer

    init(
        _ correction: Binding<ColorCorrection>,
        onChange: @escaping (ColorCorrection) -> Void
    ) {
        _correction = correction

        self.onChange = onChange
    }

}

extension VideoCorrectionsToolView {

    // MARK: - Private Methods

    fileprivate func correctionSlider(
        title: String,
        systemImage: String,
        value: Binding<Double>
    ) -> some View {
        HStack {
            Image(systemName: systemImage)
                .accessibilityLabel(title)
            Slider(value: value, in: -1...1) { change in
                if !change {
                    onChange(correction)
                }
            }
            .tint(Theme.accent)
            Text(value.wrappedValue, format: .number.precision(.fractionLength(1)))
                .monospacedDigit()
        }
        .font(.caption)
    }

}

#Preview {
    VideoCorrectionsToolView(.constant(Video.mock.colorCorrection), onChange: { _ in })
}
