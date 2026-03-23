import SwiftUI

struct PresetToolbarView: View {
    let selectedPreset: ExportPreset
    let onSelect: (ExportPreset) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(ExportPreset.allCases, id: \.title) { preset in
                    PresetToolbarButton(
                        title: preset.title,
                        isSelected: preset == selectedPreset
                    ) {
                        onSelect(preset)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PresetToolbarButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(backgroundShape.fill(backgroundColor))
                .overlay {
                    backgroundShape.strokeBorder(borderColor, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundColor)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension PresetToolbarButton {
    var backgroundShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

    var backgroundColor: Color {
        isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06)
    }

    var borderColor: Color {
        isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.08)
    }

    var foregroundColor: Color {
        isSelected ? .white : Color.white.opacity(0.72)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PresetToolbarView(selectedPreset: .instagram) { _ in }
            .padding()
    }
}
