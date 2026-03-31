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

    // MARK: - States

    @State private var draftCorrection: ColorCorrection

    // MARK: - Private Properties

    private let onChange: (ColorCorrection) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            correctionSlider(
                title: CorrectionType.brightness.rawValue,
                systemImage: "sun.max",
                value: draftBinding(\.brightness)
            )
            correctionSlider(
                title: CorrectionType.contrast.rawValue,
                systemImage: "circle.lefthalf.filled",
                value: draftBinding(\.contrast)
            )
            correctionSlider(
                title: CorrectionType.saturation.rawValue,
                systemImage: "drop",
                value: draftBinding(\.saturation)
            )
        }
        .onChange(of: correction) { _, newValue in
            guard newValue != draftCorrection else { return }
            draftCorrection = newValue
        }
        .onChange(of: draftCorrection) { _, newValue in
            guard newValue != correction else { return }
            correction = newValue
            onChange(newValue)
        }
    }

    // MARK: - Initializer

    init(
        _ correction: Binding<ColorCorrection>,
        onChange: @escaping (ColorCorrection) -> Void
    ) {
        _correction = correction
        _draftCorrection = State(initialValue: correction.wrappedValue)

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
            Slider(value: value, in: -1...1)
                .tint(Theme.accent)
            Text(value.wrappedValue, format: .number.precision(.fractionLength(1)))
                .monospacedDigit()
        }
        .font(.caption)
    }

    private func draftBinding(
        _ keyPath: WritableKeyPath<ColorCorrection, Double>
    ) -> Binding<Double> {
        Binding(
            get: { draftCorrection[keyPath: keyPath] },
            set: { draftCorrection[keyPath: keyPath] = $0 }
        )
    }

}

#Preview {
    VideoCorrectionsToolView(.constant(Video.mock.colorCorrection), onChange: { _ in })
}
