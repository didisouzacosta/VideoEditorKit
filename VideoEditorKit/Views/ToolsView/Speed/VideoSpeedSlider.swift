//
//  VideoSpeedSlider.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct VideoSpeedSlider: View {
    @State var value: Double = 1
    var isChangeState: Bool?
    let onEditingChanged: (Float) -> Void
    private let rateRange = 0.1...8
    var body: some View {
        VStack(spacing: 16) {
            (Text(value, format: .number.precision(.fractionLength(1))) + Text("x"))
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
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
                        .fill(.white.opacity(0.28))
                        .frame(width: 250, height: 5)
                },
                thumb: {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                }, thumbSize: CGSize(width: 20, height: 20))
        }
        .onChange(of: isChangeState) { _, isChange in
            if !(isChange ?? true) {
                value = 1
            }
        }
    }
}

struct VideoSpeedSlider_Previews: PreviewProvider {
    static var previews: some View {
        VideoSpeedSlider(isChangeState: false) { _ in }
    }
}
