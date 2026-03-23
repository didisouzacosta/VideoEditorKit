//
//  TextEditorView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import Observation

@MainActor
struct TextEditorView: View{
    @Bindable var viewModel: TextEditorViewModel
    @State private var textHeight: CGFloat = 100
    @State private var isFocused: Bool = true
    let onSave: ([TextBox]) -> Void
    var body: some View{
        IOS26Theme.scrim
                .ignoresSafeArea()
        VStack(spacing: 24) {
            HStack {
                Button{
                    closeKeyboard()
                    viewModel.cancelTextEditor()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                        .ios26CircleControl()
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 14){
                    ColorPicker(selection: $viewModel.currentTextBox.fontColor, supportsOpacity: true) {
                    }
                    .labelsHidden()
                    .padding(10)
                    .ios26CircleControl(tint: IOS26Theme.accent)

                    ColorPicker(selection: $viewModel.currentTextBox.bgColor, supportsOpacity: true) {
                    }
                    .labelsHidden()
                    .padding(10)
                    .ios26CircleControl(tint: IOS26Theme.accentSecondary)
                }
            }

            Spacer()

            TextView(textBox: $viewModel.currentTextBox, isFirstResponder: $isFocused, minHeight: textHeight, calculatedHeight: $textHeight)
                .frame(maxHeight: textHeight)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .ios26Card(cornerRadius: 30, prominent: true, tint: IOS26Theme.accentSecondary)

            Spacer()

            Button {
                closeKeyboard()
                viewModel.saveTapped()
                onSave(viewModel.textBoxes)
            } label: {
                Text("Save")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .ios26CapsuleControl(prominent: true, tint: IOS26Theme.accent)
            }
            .buttonStyle(.plain)
            .opacity(viewModel.currentTextBox.text.isEmpty ? 0.5 : 1)
            .disabled(viewModel.currentTextBox.text.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    
    private func closeKeyboard(){
        isFocused = false
    }
}

@MainActor
struct TextView: UIViewRepresentable {
    
    @Binding var isFirstResponder: Bool
    @Binding var textBox: TextBox

    var minHeight: CGFloat
    @Binding var calculatedHeight: CGFloat

    init(textBox: Binding<TextBox>, isFirstResponder: Binding<Bool>, minHeight: CGFloat, calculatedHeight: Binding<CGFloat>) {
        self._textBox = textBox
        self._isFirstResponder = isFirstResponder
        self.minHeight = minHeight
        self._calculatedHeight = calculatedHeight
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator

        // Decrease priority of content resistance, so content would not push external layout set in SwiftUI
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.text = self.textBox.text
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.textAlignment = .center
        textView.isUserInteractionEnabled = true
        textView.backgroundColor = UIColor.clear

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        
        focused(textView)
        recalculateHeight(view: textView)
        setTextAttrs(textView)
    
    }
    
    private func setTextAttrs(_ textView: UITextView){
        
        let attrStr = NSMutableAttributedString(string: textView.text)
        let range = NSRange(location: 0, length: attrStr.length)
        
        attrStr.addAttribute(NSAttributedString.Key.backgroundColor, value: UIColor(textBox.bgColor), range: range)
        attrStr.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: textBox.fontSize, weight: .medium), range: range)
        attrStr.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor(textBox.fontColor), range: range)
        
        textView.attributedText = attrStr
        textView.textAlignment = .center
    }

   private func recalculateHeight(view: UIView) {
        let newSize = view.sizeThatFits(CGSize(width: view.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
        if minHeight < newSize.height && $calculatedHeight.wrappedValue != newSize.height {
            DispatchQueue.main.async {
                self.$calculatedHeight.wrappedValue = newSize.height // !! must be called asynchronously
            }
        } else if minHeight >= newSize.height && $calculatedHeight.wrappedValue != minHeight {
            DispatchQueue.main.async {
                self.$calculatedHeight.wrappedValue = self.minHeight // !! must be called asynchronously
            }
        }
    }
    
    private func focused(_ textView: UITextView){
        DispatchQueue.main.async {
            switch isFirstResponder {
            case true: textView.becomeFirstResponder()
            case false: textView.resignFirstResponder()
            }
        }
    }

    final class Coordinator : NSObject, UITextViewDelegate {

        var parent: TextView

        init(_ uiTextView: TextView) {
            self.parent = uiTextView
        }

        func textViewDidChange(_ textView: UITextView) {
            if textView.markedTextRange == nil {
                parent.textBox.text = textView.text ?? String()
                parent.recalculateHeight(view: textView)
            }
        }
        
//        func textViewDidBeginEditing(_ textView: UITextView) {
//            parent.isFirstResponder = true
//        }
    }
}

@MainActor
private func makeTextEditorPreviewModel() -> TextEditorViewModel {
    let viewModel = TextEditorViewModel()
    viewModel.openTextEditor(isEdit: false, timeRange: 0...5)
    return viewModel
}

#Preview {
    TextEditorView(viewModel: makeTextEditorPreviewModel(), onSave: { _ in })
        .preferredColorScheme(.dark)
}
