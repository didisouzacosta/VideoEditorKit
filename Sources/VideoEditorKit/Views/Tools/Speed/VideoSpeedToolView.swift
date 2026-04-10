//
//  VideoSpeedToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct VideoSpeedToolView: View {

    // MARK: - Bindings

    @Binding private var value: Double

    // MARK: - Public Properties

    // MARK: - Body

    var body: some View {
        HStack {
            Image(systemName: "speedometer")
            Slider(value: $value, in: rateRange, step: 0.2)
            Text("\(value, format: .number.precision(.fractionLength(1)))x")
                .monospacedDigit()
        }
        .font(.caption)
        .safeAreaPadding()
    }

    // MARK: - Private Properties

    private let rateRange = 0.1...8

    // MARK: - Initializer

    init(_ value: Binding<Double>) {
        _value = value
    }

}

#Preview {
    VideoSpeedToolView(.constant(1))
}
