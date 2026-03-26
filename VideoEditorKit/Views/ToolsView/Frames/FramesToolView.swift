//
//  FramesToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct FramesToolView: View {

    // MARK: - Bindings

    @Binding var selectedColor: Color
    @Binding var scaleValue: Double

    // MARK: - Public Properties

    let onChange: () -> Void

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

}

#Preview {
    FramesToolView(
        selectedColor: .constant(Color(uiColor: .systemBackground)),
        scaleValue: .constant(0.3)
    ) {}
    .frame(height: 300)
}
