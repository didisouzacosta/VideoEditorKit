import AVFoundation
import SwiftUI
import Testing
import UIKit
import VideoEditorKit

@testable import VideoEditor

@MainActor
@Suite("ViewModifierSmokeTests")
struct ViewModifierSmokeTests {

    // MARK: - Public Methods

    @Test
    func basicSwiftUIViewRendersInsideAHostingController() {
        assertRenders(
            VStack(spacing: 12) {
                Text("Layout")
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.blue.opacity(0.2))
                    .frame(height: 80)
            }
            .padding()
        )
    }

    @Test
    func videoShareSheetRendersInsideAHostingController() throws {
        let videoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: videoURL) }

        assertRenders(
            VideoShareSheet(activityItems: [videoURL])
        )
    }

    @Test
    func savedVideoContextPreviewUsesAspectFillPlayback() {
        #expect(SavedVideoContextPreviewPresentation.videoGravity == .resizeAspectFill)
    }

    @Test
    func savedVideoContextMenuShowsOpenBeforeShareAndDelete() {
        let actions = SavedVideoContextMenuActionPresentation.allCases

        #expect(actions == [.open, .share, .delete])
        #expect(actions.map(\.title) == ["Open", "Share", "Delete"])
        #expect(actions.map(\.systemImage) == ["rectangle.portrait.and.arrow.right", "square.and.arrow.up", "trash"])
        #expect(actions.map(\.role) == [nil, nil, .destructive])
    }

    @Test
    func publicVideoEditorViewCanRenderWithABasicSession() throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        assertRenders(
            VideoEditorView(
                "Editor",
                session: .init(sourceVideoURL: sourceURL),
                configuration: .init(),
                callbacks: .init()
            )
        )
    }

    // MARK: - Private Methods

    private func assertRenders<Content: View>(_ content: Content) {
        let controller = makeHostingController(content)

        #expect(controller.view.bounds.size == CGSize(width: 240, height: 240))
    }

    private func makeHostingController<Content: View>(_ content: Content) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: content)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 240, height: 240)
        controller.view.layoutIfNeeded()

        return controller
    }

}
