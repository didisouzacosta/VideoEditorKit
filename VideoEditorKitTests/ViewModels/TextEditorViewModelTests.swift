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
        #expect(viewModel.textBoxes[0].lastOffset == CGSize(width: 15, height: 17))
        #expect(viewModel.textBoxes[0].id != textBox.id)
    }

    @Test
    func openTextEditorUsesTheDefaultRangeForNewText() {
        let viewModel = TextEditorViewModel()

        viewModel.openTextEditor(isEdit: false)

        #expect(viewModel.showEditor)
        #expect(viewModel.currentTextBox.timeRange == 1...5)
    }

    @Test
    func saveTappedUpdatesExistingTextWhenEditingInsteadOfAppending() {
        let viewModel = TextEditorViewModel()
        let textBox = TextBox(text: "Before")
        viewModel.textBoxes = [textBox]

        viewModel.openTextEditor(isEdit: true, textBox)
        viewModel.currentTextBox.text = "After"
        viewModel.saveTapped()

        #expect(viewModel.textBoxes.count == 1)
        #expect(viewModel.textBoxes[0].text == "After")
        #expect(viewModel.selectedTextBox?.text == "After")
    }

    @Test
    func setTimeUpdatesOnlyTheSelectedTextBoxRange() {
        let viewModel = TextEditorViewModel()
        let first = TextBox(text: "One", timeRange: 0...2)
        let second = TextBox(text: "Two", timeRange: 3...5)
        viewModel.textBoxes = [first, second]
        viewModel.selectTextBox(second)

        viewModel.setTime(10...12)

        #expect(viewModel.textBoxes[0].timeRange == 0...2)
        #expect(viewModel.textBoxes[1].timeRange == 10...12)
    }

    @Test
    func prepareForToolPresentationOpensEditorWhenThereAreNoTextBoxes() {
        let viewModel = TextEditorViewModel()

        viewModel.prepareForToolPresentation(timeRange: 7...9)

        #expect(viewModel.showEditor)
        #expect(viewModel.currentTextBox.timeRange == 7...9)
    }

    @Test
    func prepareForToolPresentationSelectsTheFirstTextWhenNeeded() {
        let viewModel = TextEditorViewModel()
        let first = TextBox(text: "One")
        let second = TextBox(text: "Two")
        viewModel.textBoxes = [first, second]

        viewModel.prepareForToolPresentation(timeRange: nil)

        #expect(viewModel.selectedTextBox == first)
    }

    @Test
    func dismissTextToolPresentationCancelsTheEditorAndClearsSelection() {
        let viewModel = TextEditorViewModel()
        let textBox = TextBox(text: "Hello")
        viewModel.textBoxes = [textBox]
        viewModel.selectTextBox(textBox)
        viewModel.openTextEditor(isEdit: true, textBox)

        viewModel.dismissTextToolPresentation()

        #expect(viewModel.showEditor == false)
        #expect(viewModel.selectedTextBox == nil)
    }

    @Test
    func handleTextBoxTapSelectsFirstAndOpensEditorOnSecondTap() {
        let viewModel = TextEditorViewModel()
        let textBox = TextBox(text: "Tap me")
        viewModel.textBoxes = [textBox]

        viewModel.handleTextBoxTap(textBox)
        #expect(viewModel.selectedTextBox == textBox)
        #expect(viewModel.showEditor == false)

        viewModel.handleTextBoxTap(textBox)
        #expect(viewModel.showEditor)
        #expect(viewModel.currentTextBox.id == textBox.id)
    }

    @Test
    func magnificationUpdatesSelectedTextFontSizeAndPersistsItAtGestureEnd() throws {
        let viewModel = TextEditorViewModel()
        var textBox = TextBox(text: "Scale me")
        textBox.lastFontSize = 20
        viewModel.textBoxes = [textBox]
        viewModel.selectTextBox(textBox)

        viewModel.handleMagnificationChanged(2)
        #expect(abs(viewModel.textBoxes[0].fontSize - 40) < 0.0001)

        viewModel.handleMagnificationEnded(2)

        let updated = try #require(viewModel.textBoxes.first)
        #expect(abs(updated.fontSize - 40) < 0.0001)
        #expect(abs(updated.lastFontSize - 40) < 0.0001)
    }

    @Test
    func dragUpdatesTheCurrentOffsetAndPersistsItWhenTheGestureEnds() {
        let viewModel = TextEditorViewModel()
        var textBox = TextBox(text: "Drag me")
        textBox.lastOffset = CGSize(width: 20, height: 30)
        viewModel.textBoxes = [textBox]
        viewModel.selectTextBox(textBox)

        viewModel.handleDragChanged(for: textBox.id, translation: CGSize(width: 5, height: -10))
        #expect(viewModel.textBoxes[0].offset == CGSize(width: 25, height: 20))

        viewModel.handleDragEnded(for: textBox.id, translation: CGSize(width: 5, height: -10))
        #expect(viewModel.textBoxes[0].offset == CGSize(width: 25, height: 20))
        #expect(viewModel.textBoxes[0].lastOffset == CGSize(width: 25, height: 20))
    }

    @Test
    func loadKeepsTheSelectedTextBoxInSyncWithUpdatedContent() {
        let viewModel = TextEditorViewModel()
        let original = TextBox(text: "Before")
        let updated = TextBox(
            id: original.id,
            text: "After",
            offset: CGSize(width: 12, height: -8),
            lastOffset: CGSize(width: 12, height: -8)
        )
        viewModel.textBoxes = [original]
        viewModel.selectTextBox(original)

        viewModel.load(textBoxes: [updated])

        #expect(viewModel.selectedTextBox?.text == "After")
        #expect(viewModel.selectedTextBox?.offset == CGSize(width: 12, height: -8))
    }

    @Test
    func saveStatePropertiesReflectWhetherTrimmedTextCanBePersisted() {
        let viewModel = TextEditorViewModel()

        viewModel.currentTextBox.text = "   "
        #expect(viewModel.isSaveEnabled == false)
        #expect(viewModel.isSaveDisabled)
        #expect(abs(viewModel.saveButtonOpacity - 0.5) < 0.0001)

        viewModel.currentTextBox.text = "Hello"
        #expect(viewModel.isSaveEnabled)
        #expect(viewModel.isSaveDisabled == false)
        #expect(abs(viewModel.saveButtonOpacity - 1.0) < 0.0001)
    }

}
