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

    // MARK: - Public Properties

    private let onChange: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            SystemColorSwatchPicker(
                selection: $selectedColor, title: "Frame color",
                options: SystemColorPalette.frameColors
            )

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

    init(selectedColor: Binding<Color>, scaleValue: Binding<Double>, onChange: @escaping () -> Void) {
        self._selectedColor = selectedColor
        self._scaleValue = scaleValue
        self.onChange = onChange
    }

}

#Preview {
    FramesToolView(
        selectedColor: .constant(Color(uiColor: .systemBackground)),
        scaleValue: .constant(0.3)
    ) {}
    .frame(height: 300)
}
