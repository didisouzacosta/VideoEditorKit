//
//  TextEditorViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class TextEditorViewModel {

    // MARK: - Public Properties

    var textBoxes: [TextBox] = []
    var showEditor = false
    var currentTextBox = TextBox()
    var selectedTextBox: TextBox?
    var isSaveEnabled: Bool {
        !currentTextBox.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var saveButtonOpacity: Double {
        isSaveEnabled ? 1 : 0.5
    }

    var isSaveDisabled: Bool {
        !isSaveEnabled
    }

    var isPresentingEditor: Bool {
        showEditor
    }

    var editorBlurRadius: CGFloat {
        showEditor ? 10 : 0
    }

    // MARK: - Private Properties

    private var isEditMode = false

    // MARK: - Public Methods

    func cancelTextEditor() {
        showEditor = false
    }

    func selectTextBox(_ texBox: TextBox) {
        selectedTextBox = texBox
    }

    func isSelected(_ id: UUID) -> Bool {
        selectedTextBox?.id == id
    }

    func setTime(_ time: ClosedRange<Double>) {
        guard let selectedTextBox else { return }
        if let index = textBoxes.firstIndex(where: { $0.id == selectedTextBox.id }) {
            textBoxes[index].timeRange = time
        }
    }

    func removeTextBox() {
        guard let selectedTextBox else { return }
        textBoxes.removeAll(where: { $0.id == selectedTextBox.id })
        self.selectedTextBox = nil
    }

    func copy(_ textBox: TextBox) {
        var new = textBox
        new.id = UUID()
        new.offset = .init(width: new.offset.width + 10, height: new.offset.height + 10)
        textBoxes.append(new)
    }

    func openTextEditor(
        isEdit: Bool, _ textBox: TextBox? = nil, timeRange: ClosedRange<Double>? = nil
    ) {
        if let textBox, isEdit {
            isEditMode = true
            currentTextBox = textBox
        } else {
            currentTextBox = TextBox(timeRange: timeRange ?? (1...5))
            isEditMode = false
        }
        showEditor = true
    }

    func saveTapped() {
        currentTextBox.text = currentTextBox.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !currentTextBox.text.isEmpty else {
            cancelTextEditor()
            return
        }

        if isEditMode {
            if let index = textBoxes.firstIndex(where: { $0.id == currentTextBox.id }) {
                textBoxes[index] = currentTextBox
            }
        } else {
            textBoxes.append(currentTextBox)
        }
        selectedTextBox = currentTextBox
        cancelTextEditor()
    }

    func load(textBoxes: [TextBox]) {
        self.textBoxes = textBoxes
    }

    func prepareForToolPresentation(timeRange: ClosedRange<Double>?) {
        if textBoxes.isEmpty {
            openTextEditor(isEdit: false, timeRange: timeRange)
        } else if selectedTextBox == nil {
            selectedTextBox = textBoxes.first
        }
    }

    func handleTextToolAppear() {
        if selectedTextBox == nil {
            selectedTextBox = textBoxes.first
        }
    }

    func handleTextToolDisappear() {
        selectedTextBox = nil
    }

    func addText(timeRange: ClosedRange<Double>) {
        openTextEditor(isEdit: false, timeRange: timeRange)
    }

    func handleTextBoxTap(_ textBox: TextBox) {
        if isSelected(textBox.id) {
            openTextEditor(isEdit: true, textBox)
        } else {
            selectTextBox(textBox)
        }
    }

    func attributedText(for textBox: TextBox) -> AttributedString {
        var result = AttributedString(textBox.text)
        result.font = .systemFont(ofSize: textBox.fontSize, weight: .medium)
        result.foregroundColor = UIColor(textBox.fontColor)
        result.backgroundColor = UIColor(textBox.bgColor)
        return result
    }

    func handleMagnificationChanged(_ value: CGFloat) {
        guard let box = selectedTextBox else { return }

        let lastFontSize = textBoxes.first(where: { $0.id == box.id })?.lastFontSize ?? box.lastFontSize
        let updatedFontSize = (value * 10) + lastFontSize
        updateTextBox(box.id) { textBox in
            textBox.fontSize = updatedFontSize
        }
    }

    func handleMagnificationEnded(_ value: CGFloat) {
        guard let box = selectedTextBox else { return }

        let lastFontSize = textBoxes.first(where: { $0.id == box.id })?.lastFontSize ?? box.lastFontSize
        let updatedFontSize = (value * 10) + lastFontSize
        updateTextBox(box.id) { textBox in
            textBox.fontSize = updatedFontSize
            textBox.lastFontSize = updatedFontSize
        }
    }

    func handleDragChanged(for id: UUID, translation: CGSize) {
        guard isSelected(id) else { return }
        guard let textBox = textBoxes.first(where: { $0.id == id }) else { return }

        let newTranslation = CGSize(
            width: translation.width + textBox.lastOffset.width,
            height: translation.height + textBox.lastOffset.height
        )
        updateTextBox(id) { box in
            box.offset = newTranslation
        }
    }

    func handleDragEnded(for id: UUID, translation: CGSize) {
        guard isSelected(id) else { return }
        guard let textBox = textBoxes.first(where: { $0.id == id }) else { return }

        let settledOffset = CGSize(
            width: translation.width + textBox.lastOffset.width,
            height: translation.height + textBox.lastOffset.height
        )
        updateTextBox(id) { box in
            box.offset = settledOffset
            box.lastOffset = settledOffset
        }
    }

    // MARK: - Private Methods

    private func updateTextBox(_ id: UUID, update: (inout TextBox) -> Void) {
        guard let index = textBoxes.firstIndex(where: { $0.id == id }) else { return }
        update(&textBoxes[index])
    }

}
