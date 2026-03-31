//
//  PresentToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@MainActor
struct PresentToolView: View {

    // MARK: - Private Properties

    private let editorVM: EditorViewModel

    // MARK: - Body

    var body: some View {
        formatSection
    }

    // MARK: - Initializer

    init(_ editorVM: EditorViewModel) {
        self.editorVM = editorVM
    }

}

extension PresentToolView {

    // MARK: - Private Properties

    private var formatSection: some View {
        VStack(spacing: 16) {
            Text("Choose a preset. Drag the video to reposition, pinch to resize, and double tap to go back to full.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                ForEach(VideoCropFormatPreset.editorPresets) { preset in
                    cropFormatButton(preset)
                }
            }
        }
    }

    private func cropFormatButton(_ preset: VideoCropFormatPreset) -> some View {
        let isSelected = editorVM.isCropFormatSelected(preset)

        return Button {
            editorVM.selectCropFormat(preset)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    cropFormatPreview(preset, isSelected: isSelected)
                    Spacer(minLength: 12)

                    if preset.isSocialVideoPreset {
                        Text("Social")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .capsuleControl(
                                prominent: isSelected,
                                tint: isSelected ? Theme.accent : Theme.secondary
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.primary)

                    Text(preset.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .padding(16)
            .card(
                cornerRadius: 24,
                prominent: isSelected,
                tint: isSelected ? Theme.accent : Theme.secondary
            )
        }
        .buttonStyle(.plain)
    }

    private func cropFormatPreview(
        _ preset: VideoCropFormatPreset,
        isSelected: Bool
    ) -> some View {
        let previewSize = cropFormatPreviewSize(for: preset)

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.secondary.opacity(0.16))
                .frame(width: 58, height: 58)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.clear)
                .frame(width: previewSize.width, height: previewSize.height)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isSelected ? Theme.accent : Theme.primary,
                            lineWidth: isSelected ? 2.5 : 1.5
                        )
                }
        }
    }

    private func cropFormatPreviewSize(for preset: VideoCropFormatPreset) -> CGSize {
        switch preset {
        case .original:
            CGSize(width: 34, height: 22)
        case .vertical9x16:
            CGSize(width: 24, height: 42)
        case .square1x1:
            CGSize(width: 34, height: 34)
        case .portrait4x5:
            CGSize(width: 30, height: 38)
        case .landscape16x9:
            CGSize(width: 40, height: 22)
        }
    }

}

#Preview {
    PresentToolView(EditorViewModel())
        .padding()
        .preferredColorScheme(.dark)
}
