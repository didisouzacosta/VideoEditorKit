import Testing
@testable import VideoEditorKit

struct TimelineInteractionEngineTests {

    @Test func progressAndTimeClampToTheValidRange() {
        let validRange = 10.0...70.0

        #expect(TimelineInteractionEngine.progress(for: 5, in: validRange) == 0)
        #expect(TimelineInteractionEngine.progress(for: 40, in: validRange) == 0.5)
        #expect(TimelineInteractionEngine.progress(for: 90, in: validRange) == 1)

        #expect(TimelineInteractionEngine.time(for: -0.3, in: validRange) == 10)
        #expect(TimelineInteractionEngine.time(for: 0.5, in: validRange) == 40)
        #expect(TimelineInteractionEngine.time(for: 1.2, in: validRange) == 70)
    }

    @Test func updatingLowerBoundNeverCrossesTheUpperBound() {
        let selection = TimelineInteractionEngine.selectionByUpdatingLowerBound(
            progress: 0.9,
            currentSelection: 20.0...40.0,
            validRange: 0.0...100.0
        )

        #expect(selection == 40...40)
    }

    @Test func updatingUpperBoundNeverCrossesTheLowerBound() {
        let selection = TimelineInteractionEngine.selectionByUpdatingUpperBound(
            progress: 0.1,
            currentSelection: 20.0...40.0,
            validRange: 0.0...100.0
        )

        #expect(selection == 20...20)
    }
}
