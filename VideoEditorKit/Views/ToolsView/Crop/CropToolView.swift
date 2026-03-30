//
//  CropToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@MainActor
struct CropToolView: View {

    // MARK: - Private Properties

    private let editorVM: EditorViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 28) {
            tabButtons
            Group {
                switch editorVM.cropTab {
                case .format:
                    formatSection
                case .rotate:
                    rotateSection
                }
            }
        }
    }

    // MARK: - Initializer

    init(_ editorVM: EditorViewModel) {
        self.editorVM = editorVM
    }

}

extension CropToolView {

    // MARK: - Private Properties

    private var rotateSection: some View {
        return HStack(spacing: 20) {
            Button {
                editorVM.rotate()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .circleControl(tint: Theme.secondary)
            }

            Button {
                editorVM.toggleMirror()
            } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .circleControl(
                        prominent: editorVM.isMirrorEnabled,
                        tint: editorVM.isMirrorEnabled ? Theme.accent : Theme.secondary
                    )
            }
        }
    }

    private var formatSection: some View {
        VStack(spacing: 16) {
            Text("Choose a canvas and drag the preview to reposition the video.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ForEach(VideoCropFormatPreset.phaseOnePresets) { preset in
                    cropFormatButton(preset)
                }
            }
        }
    }

    private var tabButtons: some View {
        HStack(spacing: 12) {
            ForEach(EditorViewModel.CropToolTab.allCases, id: \.self) { tab in
                Button {
                    editorVM.selectCropTab(tab)
                } label: {
                    Text(tab.rawValue.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .capsuleControl(
                            prominent: editorVM.isCropTabSelected(tab),
                            tint: editorVM.isCropTabSelected(tab) ? Theme.accent : Theme.secondary
                        )
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

                    if preset == .vertical9x16 {
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
        }
    }

}

#Preview {
    CropToolView(EditorViewModel())
        .padding()
        .preferredColorScheme(.dark)
}
