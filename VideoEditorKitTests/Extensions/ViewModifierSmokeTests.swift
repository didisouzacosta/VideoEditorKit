import SwiftUI
import Testing
import UIKit

@testable import VideoEditorKit

@MainActor
@Suite("ViewModifierSmokeTests")
struct ViewModifierSmokeTests {

    // MARK: - Public Methods

    @Test
    func frameConvenienceModifiersRenderInsideAHostingController() {
        assertRenders(
            Text("Layout")
                .vBottom()
                .hCenter()
                .hLeading()
                .allFrame()
        )
    }

    @Test
    func glassEffectConvenienceModifiersCanBeAppliedToViews() {
        assertRenders(
            VStack {
                Text("Card").card(prominent: true, tint: .blue)
                Text("Circle").circleControl(tint: .red)
                Text("Capsule").capsuleControl(prominent: true, tint: .green)
            }
        )
    }

    @Test
    func dynamicHeightSheetModifiersAreComposable() {
        assertRenders(BooleanSheetHostView())
        assertRenders(ItemSheetHostView())
    }

    // MARK: - Private Methods

    private func assertRenders<Content: View>(_ content: Content) {
        let controller = UIHostingController(rootView: content)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 240, height: 240)
        controller.view.layoutIfNeeded()

        #expect(controller.view.bounds.size == CGSize(width: 240, height: 240))
    }

}

private struct BooleanSheetHostView: View {

    // MARK: - States

    @State private var isPresented = false

    // MARK: - Body

    var body: some View {
        Color.clear.dynamicHeightSheet(isPresented: $isPresented) {
            Text("Sheet")
        }
    }

}

private struct SheetItem: Identifiable {

    // MARK: - Public Properties

    let id = UUID()
    let height: CGFloat

}

private struct ItemSheetHostView: View {

    // MARK: - States

    @State private var item: SheetItem?

    // MARK: - Body

    var body: some View {
        Color.clear.dynamicHeightSheet(item: $item, initialHeight: \.height) { item in
            Text("\(item.height)")
        }
    }

}
