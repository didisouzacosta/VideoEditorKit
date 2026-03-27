import CoreGraphics
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("TextEditorViewModelTests")
struct TextEditorViewModelTests {

    // MARK: - Public Methods

    @Test
    func saveTappedTrimsWhitespaceBeforePersisting() throws {
        let viewModel = TextEditorViewModel()

        viewModel.openTextEditor(isEdit: false, timeRange: 2...4)
        viewModel.currentTextBox.text = "  Hello world  "

        viewModel.saveTapped()

        let firstTextBox = try #require(viewModel.textBoxes.first)

        #expect(viewModel.textBoxes.count == 1)
        #expect(firstTextBox.text == "Hello world")
        #expect(viewModel.selectedTextBox?.text == "Hello world")
        #expect(viewModel.showEditor == false)
    }

    @Test
    func saveTappedIgnoresWhitespaceOnlyText() {
        let viewModel = TextEditorViewModel()

        viewModel.openTextEditor(isEdit: false, timeRange: 1...3)
        viewModel.currentTextBox.text = "   \n  "

        viewModel.saveTapped()

        #expect(viewModel.textBoxes.isEmpty)
        #expect(viewModel.showEditor == false)
        #expect(viewModel.selectedTextBox == nil)
    }

    @Test
    func removeTextBoxClearsSelection() {
        let viewModel = TextEditorViewModel()
        let textBox = TextBox(text: "Remove me")

        viewModel.textBoxes = [textBox]
        viewModel.selectTextBox(textBox)

        viewModel.removeTextBox()

        #expect(viewModel.textBoxes.isEmpty)
        #expect(viewModel.selectedTextBox == nil)
    }

    @Test
    func copyDuplicatesWithOffset() {
        let viewModel = TextEditorViewModel()
        let textBox = TextBox(text: "Copy me", offset: CGSize(width: 5, height: 7))

        viewModel.copy(textBox)

        #expect(viewModel.textBoxes.count == 1)
        #expect(viewModel.textBoxes[0].text == "Copy me")
        #expect(viewModel.textBoxes[0].offset == CGSize(width: 15, height: 17))
        #expect(viewModel.textBoxes[0].id != textBox.id)
    }

}
