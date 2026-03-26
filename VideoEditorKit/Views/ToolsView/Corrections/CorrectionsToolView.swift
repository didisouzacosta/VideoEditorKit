//
//  CorrectionsToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct CorrectionsToolView: View {
    @State var currentTab: CorrectionType = .brightness
    @Binding var correction: ColorCorrection
    let onChange: (ColorCorrection) -> Void
    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                ForEach(CorrectionType.allCases, id: \.self) { type in
                    Button {
                        currentTab = type
                    } label: {
                        Text(type.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .capsuleControl(
                                prominent: currentTab == type,
                                tint: currentTab == type ? Theme.accent : Theme.accent
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            slider
        }
    }
}

#Preview {
    CorrectionsToolView(correction: .constant(Video.mock.colorCorrection), onChange: { _ in })
}

extension CorrectionsToolView {
    private var slider: some View {
        let value = getValue(currentTab)

        return VStack(spacing: 14) {
            Text(value.wrappedValue, format: .number.precision(.fractionLength(1)))
                .font(.title3.monospacedDigit().weight(.semibold))
            Slider(value: value, in: -1...1) { change in
                if !change {
                    onChange(correction)
                }
            }
            .tint(Theme.accent)
        }
    }

    func getValue(_ type: CorrectionType) -> Binding<Double> {
        switch type {
        case .brightness: $correction.brightness
        case .contrast: $correction.contrast
        case .saturation: $correction.saturation
        }
    }
}
