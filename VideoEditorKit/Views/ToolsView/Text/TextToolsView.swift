//
//  TextToolsView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct TextToolsView: View {

    // MARK: - Private Properties

    private let video: Video
    private let editor: TextEditorViewModel

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 15) {
                ForEach(editor.textBoxes) { box in
                    cellView(box)
                }
                addTextButton
            }
        }
        .scrollIndicators(.hidden)
        .animation(.easeIn(duration: 0.2), value: editor.textBoxes)
        .onAppear(perform: editor.handleTextToolAppear)
        .onDisappear(perform: editor.handleTextToolDisappear)
    }

    // MARK: - Initializer

    init(_ video: Video, editor: TextEditorViewModel) {
        self.video = video
        self.editor = editor
    }

}

extension TextToolsView {

    // MARK: - Private Properties

    private var addTextButton: some View {
        Button {
            editor.addText(timeRange: video.rangeDuration)
        } label: {
            ZStack {
                Text("+T")
                    .font(.title2.weight(.light))
            }
            .frame(width: 80, height: 80)
            .card(cornerRadius: 20, tint: Theme.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Private Methods

    private func cellView(_ textBox: TextBox) -> some View {
        let isSelected = editor.isSelected(textBox.id)
        return Button {
            editor.handleTextBoxTap(textBox)
        } label: {
            ZStack {
                Text(textBox.text)
                    .lineLimit(1)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal)
            }
            .frame(width: 80, height: 80)
            .card(
                cornerRadius: 20, prominent: isSelected,
                tint: isSelected ? Theme.accent : Theme.accent)
        }
        .overlay(alignment: .topLeading) {
            if isSelected {
                Button {
                    editor.removeTextBox()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 28, height: 28)
                        .circleControl()
                }
                .padding(5)
            }
        }
        .buttonStyle(.plain)
    }

}

#Preview {
    TextToolsView(Video.mock, editor: makeTextToolsPreviewViewModel())
        .padding()
}

@MainActor
private func makeTextToolsPreviewViewModel() -> TextEditorViewModel {
    let editor = TextEditorViewModel()
    editor.textBoxes = TextBox.texts
    return editor
}
