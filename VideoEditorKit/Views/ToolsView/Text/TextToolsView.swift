//
//  TextToolsView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct TextToolsView: View {
    var video: Video
    var editor: TextEditorViewModel
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
        .onAppear {
            editor.selectedTextBox = editor.textBoxes.first
        }
        .onDisappear {
            editor.selectedTextBox = nil
        }
    }
}

extension TextToolsView {

    private func cellView(_ textBox: TextBox) -> some View {
        let isSelected = editor.isSelected(textBox.id)
        return Button {
            if isSelected {
                editor.openTextEditor(isEdit: true, textBox)
            } else {
                editor.selectTextBox(textBox)
            }
        } label: {
            ZStack {
                Text(textBox.text)
                    .lineLimit(1)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
            }
            .frame(width: 80, height: 80)
            .ios26Card(
                cornerRadius: 20, prominent: isSelected,
                tint: isSelected ? IOS26Theme.accent : IOS26Theme.accentSecondary)
        }
        .overlay(alignment: .topLeading) {
            if isSelected {
                Button {
                    editor.removeTextBox()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .ios26CircleControl()
                }
                .padding(5)
            }
        }
        .buttonStyle(.plain)
    }

    private var addTextButton: some View {
        Button {
            editor.openTextEditor(isEdit: false, timeRange: video.rangeDuration)
        } label: {
            ZStack {
                Text("+T")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.white)
            }
            .frame(width: 80, height: 80)
            .ios26Card(cornerRadius: 20, tint: IOS26Theme.accentSecondary)
        }
        .buttonStyle(.plain)
    }
}

struct TextToolsView_Previews: PreviewProvider {
    static var previews: some View {
        let editor = TextEditorViewModel()
        editor.textBoxes = TextBox.texts

        return TextToolsView(video: Video.mock, editor: editor)
            .padding()
    }
}
