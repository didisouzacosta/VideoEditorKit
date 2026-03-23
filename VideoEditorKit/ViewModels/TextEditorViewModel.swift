//
//  TextEditorViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class TextEditorViewModel {
    var textBoxes: [TextBox] = []
    var showEditor = false
    var currentTextBox = TextBox()
    var selectedTextBox: TextBox?

    private var isEditMode = false
    
    func cancelTextEditor(){
        showEditor = false
    }
    
    func selectTextBox(_ texBox: TextBox){
        selectedTextBox = texBox
    }
    
    func isSelected(_ id: UUID) -> Bool{
        selectedTextBox?.id == id
    }
    
    func setTime(_ time: ClosedRange<Double>){
        guard let selectedTextBox else {return}
        if let index = textBoxes.firstIndex(where: {$0.id == selectedTextBox.id}){
            textBoxes[index].timeRange = time
        }
    }
    
    func removeTextBox(){
        guard let selectedTextBox else {return}
        textBoxes.removeAll(where: {$0.id == selectedTextBox.id})
        self.selectedTextBox = nil
    }
    
    func copy(_ textBox: TextBox){
        var new = textBox
        new.id = UUID()
        new.offset = .init(width: new.offset.width + 10, height: new.offset.height + 10)
        textBoxes.append(new)
    }
    
    func openTextEditor(isEdit: Bool, _ textBox: TextBox? = nil, timeRange: ClosedRange<Double>? = nil){
        if let textBox, isEdit{
            isEditMode = true
            currentTextBox = textBox
        }else{
            currentTextBox = TextBox(timeRange: timeRange ?? (1...5))
            isEditMode = false
        }
        showEditor = true
    }
    
    func saveTapped(){
        currentTextBox.text = currentTextBox.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !currentTextBox.text.isEmpty else {
            cancelTextEditor()
            return
        }

        if isEditMode{
            if let index = textBoxes.firstIndex(where: {$0.id == currentTextBox.id}){
                textBoxes[index] = currentTextBox
            }
        }else{
            textBoxes.append(currentTextBox)
        }
        selectedTextBox = currentTextBox
        cancelTextEditor()
    }
}
