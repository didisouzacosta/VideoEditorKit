//
//  SystemColorSwatchPicker.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 30.03.2026.
//

import SwiftUI

struct SystemColorSwatchPicker: View {

    // MARK: - Bindings

    @Binding private var selectedColor: Color

    // MARK: - Public Properties

    let title: String
    let options: [SystemColorOption]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(options) { option in
                        swatchButton(option)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Initializer

    init(
        _ selectedColor: Binding<Color>,
        title: String,
        options: [SystemColorOption]
    ) {
        _selectedColor = selectedColor

        self.title = title
        self.options = options
    }

    // MARK: - Private Methods

    private func swatchButton(_ option: SystemColorOption) -> some View {
        Button {
            selectedColor = option.color
        } label: {
            Circle()
                .fill(option.color)
                .overlay {
                    Circle()
                        .strokeBorder(borderColor(for: option), lineWidth: borderWidth(for: option))
                }
                .overlay {
                    if isSelected(option) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(checkmarkColor(for: option))
                    }
                }
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.id)
        .accessibilityValue(isSelected(option) ? "Selected" : "Not selected")
    }

    private func isSelected(_ option: SystemColorOption) -> Bool {
        SystemColorPalette.matches(selectedColor, option.color)
    }

    private func borderColor(for option: SystemColorOption) -> Color {
        if isSelected(option) {
            return Theme.accent
        }

        return Color.primary.opacity(0.14)
    }

    private func borderWidth(for option: SystemColorOption) -> CGFloat {
        isSelected(option) ? 3 : 1
    }

    private func checkmarkColor(for option: SystemColorOption) -> Color {
        let resolvedColor = UIColor(option.color).resolvedColor(with: .current)

        if resolvedColor.isLightColor {
            return .black.opacity(0.75)
        }

        return .white
    }

}

extension UIColor {

    // MARK: - Private Properties

    fileprivate var isLightColor: Bool {
        guard
            let components = cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)?
                .components
        else {
            return true
        }

        let rgbComponents: [CGFloat]

        switch components.count {
        case 2:
            rgbComponents = [components[0], components[0], components[0]]
        default:
            rgbComponents = Array(components.prefix(3))
        }

        let luminance =
            (0.299 * rgbComponents[0]) + (0.587 * rgbComponents[1]) + (0.114 * rgbComponents[2])

        return luminance > 0.72
    }

}
