import XCTest
@testable import VideoEditorKit

@MainActor
final class TextEditorViewModelTests: XCTestCase {
    func testSaveTappedTrimsWhitespaceBeforePersisting() {
        let viewModel = TextEditorViewModel()

        viewModel.openTextEditor(isEdit: false, timeRange: 2...4)
        viewModel.currentTextBox.text = "  Hello world  "

        viewModel.saveTapped()

        XCTAssertEqual(viewModel.textBoxes.count, 1)
        XCTAssertEqual(viewModel.textBoxes.first?.text, "Hello world")
        XCTAssertEqual(viewModel.selectedTextBox?.text, "Hello world")
        XCTAssertFalse(viewModel.showEditor)
    }

    func testSaveTappedIgnoresWhitespaceOnlyText() {
        let viewModel = TextEditorViewModel()

        viewModel.openTextEditor(isEdit: false, timeRange: 1...3)
        viewModel.currentTextBox.text = "   \n  "

        viewModel.saveTapped()

        XCTAssertTrue(viewModel.textBoxes.isEmpty)
        XCTAssertFalse(viewModel.showEditor)
        XCTAssertNil(viewModel.selectedTextBox)
    }

    func testRemoveTextBoxClearsSelection() {
        let viewModel = TextEditorViewModel()
        let textBox = TextBox(text: "Remove me")

        viewModel.textBoxes = [textBox]
        viewModel.selectTextBox(textBox)

        viewModel.removeTextBox()

        XCTAssertTrue(viewModel.textBoxes.isEmpty)
        XCTAssertNil(viewModel.selectedTextBox)
    }

    func testCopyDuplicatesWithOffset() {
        let viewModel = TextEditorViewModel()
        let textBox = TextBox(text: "Copy me", offset: CGSize(width: 5, height: 7))

        viewModel.copy(textBox)

        XCTAssertEqual(viewModel.textBoxes.count, 1)
        XCTAssertEqual(viewModel.textBoxes[0].text, "Copy me")
        XCTAssertEqual(viewModel.textBoxes[0].offset, CGSize(width: 15, height: 17))
        XCTAssertNotEqual(viewModel.textBoxes[0].id, textBox.id)
    }
}
