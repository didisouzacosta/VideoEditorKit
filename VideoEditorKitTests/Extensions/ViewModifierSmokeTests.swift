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

    @Test
    func blockedToolButtonsStillRenderInsideAHostingController() {
        assertRenders(
            ToolButtonView(
                "Corrections",
                image: "circle.righthalf.filled",
                isChange: false,
                isBlocked: true
            ) {}
        )
    }

    @Test
    func editedVideoProjectCardRendersInsideAHostingController() {
        assertRenders(
            EditedVideoProjectCard(
                project: .init(
                    createdAt: .now,
                    updatedAt: .now,
                    displayName: "Shared Clip",
                    originalVideoFileName: "original.mp4",
                    exportedVideoFileName: "exported.mp4",
                    editingConfigurationData: (try? JSONEncoder().encode(VideoEditingConfiguration.initial)) ?? Data(),
                    thumbnailData: nil,
                    duration: 12,
                    width: 1080,
                    height: 1920,
                    fileSize: 1_024
                ),
                onOpen: {},
                onEdit: {},
                onDelete: {}
            )
        )
    }

    @Test
    func cropViewRendersPresetClippingModeInsideAHostingController() {
        assertRenders(
            CropView(
                CGSize(width: 300, height: 600),
                freeformRect: .constant(
                    .init(
                        x: 0.2,
                        y: 0.1,
                        width: 0.45,
                        height: 0.8
                    )
                ),
                rotation: 0,
                isMirror: false,
                showsCropOverlay: true,
                isInteractiveCrop: false
            ) {
                LinearGradient(
                    colors: [.red, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }

    @Test
    func cropViewRendersPresetClippingModeWithSeparateReferenceAndContentSizes() {
        assertRenders(
            CropView(
                CGSize(width: 1080, height: 1920),
                freeformRect: .constant(
                    .init(
                        x: 0.2,
                        y: 0.1,
                        width: 0.45,
                        height: 0.8
                    )
                ),
                contentSize: CGSize(width: 180, height: 320),
                rotation: 0,
                isMirror: false,
                showsCropOverlay: true,
                isInteractiveCrop: false,
                viewportSize: CGSize(width: 180, height: 320)
            ) {
                LinearGradient(
                    colors: [.orange, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }

    @Test
    func safeAreaOverlayRendersAsAGuideWithoutAffectingLayout() {
        assertRenders(
            ZStack {
                Rectangle()
                    .fill(.black)

                SafeAreaOverlayView(
                    platform: .tiktok,
                    cornerRadius: 24
                )
            }
            .frame(width: 240, height: 426)
        )
    }

    @Test
    func videoCanvasPreviewViewCanRenderAnOverlayInsideThePresetCanvas() {
        let editorState = VideoCanvasEditorState()
        editorState.preset = .social(platform: .instagram)
        editorState.showsSafeAreaOverlay = true

        assertRenders(
            VideoCanvasPreviewView(
                editorState,
                source: .init(
                    naturalSize: CGSize(width: 1920, height: 1080),
                    preferredTransform: .identity,
                    userRotationDegrees: 0,
                    isMirrored: false
                ),
                isInteractive: false,
                cornerRadius: 24
            ) {
                Rectangle()
                    .fill(.blue)
            } overlay: {
                ZStack(alignment: .bottom) {
                    SafeAreaOverlayView(
                        platform: .instagram,
                        cornerRadius: 24
                    )

                    Text("Social • 9:16")
                        .padding(.bottom, 12)
                }
            }
            .frame(width: 240, height: 426)
        )
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
