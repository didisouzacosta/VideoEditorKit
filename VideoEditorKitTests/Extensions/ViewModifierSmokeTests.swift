import SwiftUI
import Testing

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
                "Adjusts",
                image: "circle.righthalf.filled",
                isChange: false,
                isBlocked: true
            ) {}
            .frame(width: 96, height: 96)
        )
    }

    @Test
    func pagedToolsRowRendersInsideAHostingController() {
        assertRenders(
            PagedToolsRow(
                ToolEnum.all.map { ToolAvailability($0) }
            ) { _ in
                false
            } action: { _ in
            }
        )
    }

    @Test
    func transcriptOverlayPreviewRendersInsideAHostingController() {
        let activeWordID = UUID()

        assertRenders(
            TranscriptOverlayPreview(
                segment: .init(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 10,
                        sourceEndTime: 14,
                        timelineStartTime: 5,
                        timelineEndTime: 7
                    ),
                    originalText: "Original segment",
                    editedText: "Edited segment",
                    words: [
                        .init(
                            id: activeWordID,
                            timeMapping: .init(
                                sourceStartTime: 10,
                                sourceEndTime: 12,
                                timelineStartTime: 5,
                                timelineEndTime: 6
                            ),
                            originalText: "Edited",
                            editedText: "Edited"
                        ),
                        .init(
                            id: UUID(),
                            timeMapping: .init(
                                sourceStartTime: 12,
                                sourceEndTime: 14,
                                timelineStartTime: 6,
                                timelineEndTime: 7
                            ),
                            originalText: "segment",
                            editedText: "segment"
                        ),
                    ]
                ),
                activeWordID: activeWordID,
                style: .init(
                    id: UUID(),
                    name: "Classic",
                    fontWeight: .bold,
                    hasStroke: true,
                    textColor: .white,
                    strokeColor: .black
                ),
                overlayPosition: .bottom,
                overlaySize: .medium,
                previewCanvasSize: CGSize(width: 320, height: 180),
                exportCanvasSize: CGSize(width: 1080, height: 608)
            )
            .frame(width: 320, height: 180)
        )
    }

    @Test
    func transcriptToolViewRendersUnavailableStateInsideAHostingController() {
        assertRenders(
            TranscriptToolView(
                isTranscriptionAvailable: false,
                transcriptState: .idle,
                document: nil,
                onTranscribe: {},
                onRetry: {},
                onUpdateSegmentText: { _, _ in },
                onUpdatePosition: { _ in },
                onUpdateSize: { _ in }
            )
        )
    }

    @Test
    func transcriptToolViewRendersLoadedStateWithoutStyleControls() {
        assertRenders(
            TranscriptToolView(
                isTranscriptionAvailable: true,
                transcriptState: .loaded,
                document: TranscriptDocument(
                    segments: [
                        .init(
                            id: UUID(),
                            timeMapping: .init(
                                sourceStartTime: 0,
                                sourceEndTime: 1,
                                timelineStartTime: 0,
                                timelineEndTime: 1
                            ),
                            originalText: "hello world",
                            editedText: "hello world"
                        )
                    ],
                    overlayPosition: .bottom,
                    overlaySize: .medium
                ),
                onTranscribe: {},
                onRetry: {},
                onUpdateSegmentText: { _, _ in },
                onUpdatePosition: { _ in },
                onUpdateSize: { _ in }
            )
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
    func videoShareSheetRendersInsideAHostingController() throws {
        let videoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: videoURL) }

        assertRenders(
            VideoShareSheet(activityItems: [videoURL])
        )
    }

    @Test
    func videoEditorViewCanRenderWithInlineShellPresentationModifiers() throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let shareURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: sourceURL) }
        defer { FileManager.default.removeIfExists(for: shareURL) }

        assertRenders(
            VideoEditorPresentationSmokeHostView(
                sourceURL: sourceURL,
                shareDestination: .init(videoURL: shareURL)
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
                Text("Social • 9:16")
                    .padding(.bottom, 12)
            }
            .frame(width: 240, height: 426)
        )
    }

    @Test
    func refactoredToolViewsRenderInsideAHostingController() {
        assertRenders(
            VStack(spacing: 16) {
                VideoSpeedToolView(.constant(1.8))
                VideoAdjustsToolView(
                    .constant(
                        .init(
                            brightness: 0.2,
                            contrast: -0.15,
                            saturation: 0.1
                        )
                    )
                )
                VideoAudioToolView(
                    draft: .constant(
                        .init(
                            selectedTrack: .recorded,
                            videoVolume: 0.9,
                            recordedVolume: 0.35
                        )
                    ),
                    hasRecordedAudioTrack: true
                )
                PresentToolView(
                    selectedPreset: .constant(.portrait4x5),
                    onSelect: { _ in }
                )
            }
            .padding()
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

private struct VideoEditorPresentationSmokeHostView: View {

    // MARK: - States

    @State private var shareDestination: RootViewModel.ShareDestination?
    @State private var blockedTool: ToolEnum?

    // MARK: - Public Properties

    let sourceURL: URL
    let initialShareDestination: RootViewModel.ShareDestination

    // MARK: - Body

    var body: some View {
        VideoEditorView(
            "Editor",
            session: .init(sourceVideoURL: sourceURL),
            configuration: .init()
        )
        .sheet(item: $shareDestination) { shareDestination in
            VideoShareSheet(activityItems: [shareDestination.videoURL])
        }
        .alert(
            "Premium Tool",
            isPresented: blockedToolAlertBinding,
            presenting: blockedTool
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { _ in
            Text("")
        }
        .task {
            shareDestination = initialShareDestination
        }
    }

    // MARK: - Private Properties

    private var blockedToolAlertBinding: Binding<Bool> {
        Binding(
            get: { blockedTool != nil },
            set: { isPresented in
                if !isPresented {
                    blockedTool = nil
                }
            }
        )
    }

    // MARK: - Initializer

    init(
        sourceURL: URL,
        shareDestination: RootViewModel.ShareDestination
    ) {
        self.sourceURL = sourceURL
        initialShareDestination = shareDestination
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
