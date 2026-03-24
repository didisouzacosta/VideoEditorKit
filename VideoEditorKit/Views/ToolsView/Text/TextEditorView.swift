//
//  TextEditorView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Observation
import SwiftUI

@MainActor
struct TextEditorView: View {
    @Bindable var viewModel: TextEditorViewModel
    @State private var textHeight: CGFloat = 100
    @State private var isFocused: Bool = true
    let onSave: ([TextBox]) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.scrim
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        SystemColorSwatchPicker(
                            title: "Text color",
                            selection: $viewModel.currentTextBox.fontColor,
                            options: SystemColorPalette.textForegrounds
                        )

                        SystemColorSwatchPicker(
                            title: "Background color",
                            selection: $viewModel.currentTextBox.bgColor,
                            options: SystemColorPalette.textBackgrounds
                        )

                        TextView(
                            textBox: $viewModel.currentTextBox,
                            isFirstResponder: $isFocused,
                            minHeight: textHeight,
                            calculatedHeight: $textHeight
                        )
                        .frame(maxHeight: textHeight)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .ios26Card(cornerRadius: 30, prominent: true, tint: Theme.accent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        closeKeyboard()
                        viewModel.cancelTextEditor()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(Theme.primary)
                            .ios26CircleControl()
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .principal) {
                    Text("Text")
                        .font(.headline)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    closeKeyboard()
                    viewModel.saveTapped()
                    onSave(viewModel.textBoxes)
                } label: {
                    Text("Save")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .ios26CapsuleControl(prominent: true, tint: Theme.accent)
                }
                .buttonStyle(.plain)
                .opacity(viewModel.currentTextBox.text.isEmpty ? 0.5 : 1)
                .disabled(viewModel.currentTextBox.text.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }

    private func closeKeyboard() {
        isFocused = false
    }
}

@MainActor
struct TextView: UIViewRepresentable {

    @Binding var isFirstResponder: Bool
    @Binding var textBox: TextBox

    var minHeight: CGFloat
    @Binding var calculatedHeight: CGFloat

    init(
        textBox: Binding<TextBox>, isFirstResponder: Binding<Bool>, minHeight: CGFloat,
        calculatedHeight: Binding<CGFloat>
    ) {
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

    private func setTextAttrs(_ textView: UITextView) {

        let attrStr = NSMutableAttributedString(string: textView.text)
        let range = NSRange(location: 0, length: attrStr.length)

        attrStr.addAttribute(
            NSAttributedString.Key.backgroundColor, value: UIColor(textBox.bgColor), range: range)
        attrStr.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.systemFont(ofSize: textBox.fontSize, weight: .medium), range: range)
        attrStr.addAttribute(
            NSAttributedString.Key.foregroundColor, value: UIColor(textBox.fontColor), range: range)

        textView.attributedText = attrStr
        textView.textAlignment = .center
    }

    private func recalculateHeight(view: UIView) {
        let newSize = view.sizeThatFits(
            CGSize(width: view.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
        if minHeight < newSize.height && $calculatedHeight.wrappedValue != newSize.height {
            DispatchQueue.main.async {
                self.$calculatedHeight.wrappedValue = newSize.height  // !! must be called asynchronously
            }
        } else if minHeight >= newSize.height && $calculatedHeight.wrappedValue != minHeight {
            DispatchQueue.main.async {
                self.$calculatedHeight.wrappedValue = self.minHeight  // !! must be called asynchronously
            }
        }
    }

    private func focused(_ textView: UITextView) {
        DispatchQueue.main.async {
            switch isFirstResponder {
            case true: textView.becomeFirstResponder()
            case false: textView.resignFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {

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
    }
}

struct SystemColorSwatchPicker: View {
    let title: String
    @Binding var selection: Color
    let options: [SystemColorOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(options) { option in
                        Button {
                            selection = option.color
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            isSelected(option) ? Theme.primary : Theme.outline,
                                            lineWidth: isSelected(option) ? 2 : 1
                                        )
                                }
                                .padding(5)
                                .ios26CircleControl(
                                    prominent: isSelected(option),
                                    tint: isSelected(option) ? Theme.accent : nil
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func isSelected(_ option: SystemColorOption) -> Bool {
        SystemColorPalette.matches(selection, option.color)
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
