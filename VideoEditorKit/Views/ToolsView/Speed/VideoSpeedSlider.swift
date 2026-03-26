//
//  VideoSpeedSlider.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct VideoSpeedSlider: View {

    // MARK: - States

    @State var value: Double = 1

    // MARK: - Public Properties

    var isChangeState: Bool?
    let onEditingChanged: (Float) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            Text("\(value, format: .number.precision(.fractionLength(1)))x")
                .font(.title3.monospacedDigit().weight(.semibold))
            CustomSlider(
                value: $value,
                in: rateRange,
                step: 0.2,
                onEditingChanged: { started in
                    if !started {
                        onEditingChanged(Float(value))
                    }
                },
                track: {
                    Capsule()
                        .fill(Theme.sliderTrack)
                        .frame(width: 250, height: 5)
                },
                thumb: {
                    Circle()
                        .fill(Theme.sliderThumb)
                }, thumbSize: CGSize(width: 20, height: 20))
        }
        .onChange(of: isChangeState) { _, isChange in
            if !(isChange ?? true) {
                value = 1
            }
        }
    }

    // MARK: - Private Properties

    private let rateRange = 0.1...8

}

#Preview {
    VideoSpeedSlider(isChangeState: false) { _ in }
}
