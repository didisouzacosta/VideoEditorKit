//
//  TextOverlayView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct TextOverlayView: View {

    // MARK: - Public Properties

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
                            .onChanged({ value in
                                if let box = viewModel.selectedTextBox {
                                    let lastFontSize =
                                        viewModel.textBoxes.first(where: { $0.id == box.id })?.lastFontSize
                                        ?? box.lastFontSize
                                    let updatedFontSize = (value * 10) + lastFontSize
                                    updateTextBox(box.id) { textBox in
                                        textBox.fontSize = updatedFontSize
                                    }
                                }
                            }).onEnded({ value in
                                if let box = viewModel.selectedTextBox {
                                    let lastFontSize =
                                        viewModel.textBoxes.first(where: { $0.id == box.id })?.lastFontSize
                                        ?? box.lastFontSize
                                    let updatedFontSize = (value * 10) + lastFontSize
                                    updateTextBox(box.id) { textBox in
                                        textBox.fontSize = updatedFontSize
                                        textBox.lastFontSize = updatedFontSize
                                    }
                                }
                            }))
            }

            ForEach(viewModel.textBoxes) { textBox in
                let isSelected = viewModel.isSelected(textBox.id)

                if textBox.timeRange.contains(currentTime) {

                    VStack(alignment: .leading, spacing: 2) {
                        if isSelected {
                            textBoxButtons(textBox)
                        }

                        Text(createAttr(textBox))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(lineWidth: 1)
                                        .foregroundStyle(Theme.selection)
                                }
                            }
                            .onTapGesture {
                                editOrSelectTextBox(textBox, isSelected)
                            }

                    }
                    .offset(textBox.offset)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 1).onChanged({ value in
                            guard isSelected else { return }
                            let current = value.translation
                            let lastOffset = textBox.lastOffset
                            let newTranslation: CGSize = .init(
                                width: current.width + lastOffset.width, height: current.height + lastOffset.height)
                            updateTextBox(textBox.id) { box in
                                box.offset = newTranslation
                            }

                        }).onEnded({ value in
                            guard isSelected else { return }
                            let current = value.translation
                            let lastOffset = textBox.lastOffset
                            let settledOffset = CGSize(
                                width: current.width + lastOffset.width, height: current.height + lastOffset.height)
                            updateTextBox(textBox.id) { box in
                                box.offset = settledOffset
                                box.lastOffset = settledOffset
                            }
                        }))
                }
            }
        }
        .allFrame()
    }

    // MARK: - Private Methods

    private func createAttr(_ textBox: TextBox) -> AttributedString {
        var result = AttributedString(textBox.text)
        result.font = .systemFont(ofSize: textBox.fontSize, weight: .medium)
        result.foregroundColor = UIColor(textBox.fontColor)
        result.backgroundColor = UIColor(textBox.bgColor)
        return result
    }

    // MARK: - Initializer

    init(currentTime: Double, viewModel: TextEditorViewModel, disabledMagnification: Bool = false) {
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

    private func editOrSelectTextBox(_ textBox: TextBox, _ isSelected: Bool) {
        if isSelected {
            viewModel.openTextEditor(isEdit: true, textBox)
        } else {
            viewModel.selectTextBox(textBox)
        }
    }

    private func updateTextBox(_ id: UUID, update: (inout TextBox) -> Void) {
        guard let index = viewModel.textBoxes.firstIndex(where: { $0.id == id }) else { return }
        update(&viewModel.textBoxes[index])
    }

}

#Preview {
    ZStack {
        Color(uiColor: .systemBackground)
        TextOverlayView(currentTime: 1.5, viewModel: makeTextOverlayPreviewViewModel())
    }
}

@MainActor
private func makeTextOverlayPreviewViewModel() -> TextEditorViewModel {
    // MARK: - Public Properties

    let viewModel = TextEditorViewModel()
    viewModel.textBoxes = TextBox.texts
    viewModel.selectTextBox(TextBox.texts[0])
    return viewModel
}
