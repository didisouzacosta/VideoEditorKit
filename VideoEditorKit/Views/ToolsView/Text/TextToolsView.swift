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
            HStack(spacing: 15){
                ForEach(editor.textBoxes) { box in
                    cellView(box)
                }
                addTextButton
            }
        }
        .scrollIndicators(.hidden)
        .animation(.easeIn(duration: 0.2), value: editor.textBoxes)
        .onAppear{
            editor.selectedTextBox = editor.textBoxes.first
        }
        .onDisappear{
            editor.selectedTextBox = nil
        }
    }
}

extension TextToolsView{
    
    private func cellView(_ textBox: TextBox) -> some View{
        let isSelected = editor.isSelected(textBox.id)
        return ZStack{
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(isSelected ?  .systemGray : .systemGray4))
            Text(textBox.text)
                .lineLimit(1)
                .font(.caption)
        }
        .frame(width: 80, height: 80)
        .overlay(alignment: .topLeading) {
            if isSelected{
                Button {
                    editor.removeTextBox()
                } label: {
                    Image(systemName: "xmark")
                        .imageScale(.small)
                        .foregroundStyle(Color(.systemGray2))
                        .padding(5)
                        .background(Color.black, in: Circle())
                }
                .padding(5)
            }
        }
        .onTapGesture {
            if isSelected{
                editor.openTextEditor(isEdit: true, textBox)
            }else{
                editor.selectTextBox(textBox)
            }
        }
    }
    
    private var addTextButton: some View{
        ZStack{
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray4))
            Text("+T")
                .font(.title2.weight(.light))
        }
        .frame(width: 80, height: 80)
        .onTapGesture {
            editor.openTextEditor(isEdit: false, timeRange: video.rangeDuration)
        }
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
