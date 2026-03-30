//
//  FramesToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct FramesToolView: View {

    // MARK: - Bindings

    @Binding private var selectedColor: Color
    @Binding private var scaleValue: Double

    // MARK: - Private Properties

    private let onChange: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            SystemColorSwatchPicker(
                $selectedColor,
                title: "Frame color",
                options: SystemColorPalette.frameColors
            )
            .onChange(of: selectedColor) { _, _ in
                onChange()
            }

            VStack(spacing: 12) {
                Text("Frame Scale")
                    .font(.subheadline.weight(.semibold))
                Slider(value: $scaleValue, in: 0...0.5) { change in
                    if !change {
                        onChange()
                    }
                }
                .tint(Theme.accent)
            }
        }
    }

    // MARK: - Initializer

    init(_ selectedColor: Binding<Color>, scaleValue: Binding<Double>, onChange: @escaping () -> Void) {
        _selectedColor = selectedColor
        _scaleValue = scaleValue

        self.onChange = onChange
    }

}

#Preview {
    FramesToolView(
        .constant(Color(uiColor: .systemBackground)),
        scaleValue: .constant(0.3)
    ) {}
    .frame(height: 300)
}
