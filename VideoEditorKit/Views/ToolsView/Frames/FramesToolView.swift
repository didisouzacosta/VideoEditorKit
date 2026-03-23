//
//  FramesToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct FramesToolView: View {
    @Binding var selectedColor: Color
    @Binding var scaleValue: Double
    let colors: [Color] = [.white, .black, .blue, .brown, .cyan, .green, .orange]
    let onChange: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            selectedColor = color
                            onChange()
                        } label: {
                            color
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            selectedColor == color ? .white : .white.opacity(0.16),
                                            lineWidth: selectedColor == color ? 2 : 1)
                                }
                                .padding(5)
                                .ios26CircleControl(
                                    prominent: selectedColor == color,
                                    tint: selectedColor == color ? IOS26Theme.accentSecondary : nil
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            VStack(spacing: 12) {
                Text("Frame Scale")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Slider(value: $scaleValue, in: 0...0.5) { change in
                    if !change {
                        onChange()
                    }
                }
                .tint(IOS26Theme.accent)
            }
        }
    }
}

struct FramesToolView_Previews: PreviewProvider {
    static var previews: some View {
        FramesToolView(selectedColor: .constant(.white), scaleValue: .constant(0.3)) {}
            .frame(height: 300)
    }
}
