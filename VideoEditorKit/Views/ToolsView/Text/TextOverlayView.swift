//
//  TextOverlayView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct TextOverlayView: View {

    // MARK: - Private Properties

    private let currentTime: Double
    private let viewModel: TextEditorViewModel
    private let disabledMagnification: Bool

    // MARK: - Body

    var body: some View {
        ZStack {
            if !disabledMagnification {
                Color.secondary.opacity(0.001)
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged(viewModel.handleMagnificationChanged)
                            .onEnded(viewModel.handleMagnificationEnded))
            }

            ForEach(viewModel.textBoxes) { textBox in
                let isSelected = viewModel.isSelected(textBox.id)

                if textBox.timeRange.contains(currentTime) {

                    VStack(alignment: .leading, spacing: 2) {
                        if isSelected {
                            textBoxButtons(textBox)
                        }

                        Text(viewModel.attributedText(for: textBox))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(lineWidth: 1)
                                        .foregroundStyle(Theme.selection)
                                }
                            }
                            .onTapGesture { viewModel.handleTextBoxTap(textBox) }

                    }
                    .offset(textBox.offset)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 1).onChanged({ value in
                            viewModel.handleDragChanged(for: textBox.id, translation: value.translation)
                        }).onEnded({ value in
                            viewModel.handleDragEnded(for: textBox.id, translation: value.translation)
                        }))
                }
            }
        }
        .allFrame()
    }

    // MARK: - Initializer

    init(
        _ currentTime: Double,
        viewModel: TextEditorViewModel,
        disabledMagnification: Bool = false
    ) {
        self.currentTime = currentTime
        self.viewModel = viewModel
        self.disabledMagnification = disabledMagnification
    }

}

extension TextOverlayView {

    // MARK: - Private Methods

    private func textBoxButtons(_ textBox: TextBox) -> some View {
        HStack(spacing: 10) {
            Button {
                viewModel.removeTextBox()
            } label: {
                Image(systemName: "xmark")
                    .padding(5)
                    .background(Color(.systemGray2), in: Circle())
            }
            Button {
                viewModel.copy(textBox)
            } label: {
                Image(systemName: "doc.on.doc")
                    .imageScale(.small)
                    .padding(5)
                    .background(Color(.systemGray2), in: Circle())
            }
        }
        .foregroundStyle(Theme.primary)
    }

}

#Preview {
    ZStack {
        Color(uiColor: .systemBackground)
        TextOverlayView(1.5, viewModel: makeTextOverlayPreviewViewModel())
    }
}

@MainActor
private func makeTextOverlayPreviewViewModel() -> TextEditorViewModel {
    let viewModel = TextEditorViewModel()
    viewModel.textBoxes = TextBox.texts
    viewModel.selectTextBox(TextBox.texts[0])
    return viewModel
}
