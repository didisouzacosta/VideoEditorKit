//
//  VideoSpeedToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct VideoSpeedToolView: View {

    // MARK: - States

    @State private var value: Double = 1

    // MARK: - Private Properties

    private let isChangeState: Bool?
    private let onEditingChanged: (Float) -> Void

    // MARK: - Body

    var body: some View {
        HStack {
            Image(systemName: "speedometer")
            Slider(value: $value, in: rateRange, step: 0.2) { isEditing in
                if !isEditing {
                    onEditingChanged(Float(value))
                }
            }
            Text("\(value, format: .number.precision(.fractionLength(1)))x")
                .monospacedDigit()
        }
        .font(.caption)
        .onChange(of: isChangeState) { _, isChange in
            if !(isChange ?? true) {
                value = 1
            }
        }
    }

    // MARK: - Private Properties

    private let rateRange = 0.1...8

    // MARK: - Initializer

    init(_ value: Double = 1, isChangeState: Bool?, onEditingChanged: @escaping (Float) -> Void) {
        _value = State(initialValue: value)

        self.isChangeState = isChangeState
        self.onEditingChanged = onEditingChanged
    }

}

#Preview {
    VideoSpeedToolView(isChangeState: false) { _ in }
}
