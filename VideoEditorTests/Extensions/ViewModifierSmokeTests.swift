import SwiftUI
import Testing
import UIKit

@testable import VideoEditor
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
    func blockedExportQualitiesRenderInsideAHostingController() {
        struct ExporterPackageHostView: View {
            @State private var isAlertPresented = false

            var body: some View {
                VideoEditorKit.VideoExporterView(
                    isAlertPresented: $isAlertPresented,
                    state: .init(
                        selectedQuality: .medium,
                        exportProgress: 0,
                        progressText: "0%",
                        errorMessage: "Error",
                        actionTitle: "Export",
                        isInteractionDisabled: false,
                        canExportVideo: true,
                        canCancelExport: false,
                        shouldShowLoadingView: false,
                        shouldShowFailureMessage: false
                    ),
                    qualities: ExportQualityAvailability.premiumLocked,
                    estimatedVideoSizeText: { _ in "12.4Mb" },
                    onSelectQuality: { _ in },
                    onExport: {},
                    onRetry: {},
                    onCancelExport: {},
                    onClose: {}
                )
            }
        }

        let controller = makeHostingController(
            ExporterPackageHostView()
        )

        #expect(controller.view.bounds.size == CGSize(width: 240, height: 240))
    }

    @Test
    func toolButtonsWithAppliedValuesStillRenderInsideAHostingController() {
        assertRenders(
            ToolButtonView(
                "Presets",
                image: "aspectratio",
                subtitle: "Social 9:16",
                isChange: true
            ) {}
            .frame(minWidth: 120)
            .frame(height: 104)
        )
    }

    @Test
    func pagedToolsRowRendersInsideAHostingController() {
        assertRenders(
            PagedToolsRow(
                ToolEnum.all.map { ToolAvailability($0) }
            ) { _ in
                .init(
                    title: "Presets",
                    image: "aspectratio",
                    subtitle: "Social 9:16",
                    isApplied: true
                )
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
                onCopyTranscript: { _ in },
                onUpdateSegmentText: { _, _ in },
                onRevertSegmentText: { _ in },
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
                onCopyTranscript: { _ in },
                onUpdateSegmentText: { _, _ in },
                onRevertSegmentText: { _ in },
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
    func videoEditorLoadedViewCanRenderHostInjectedSections() throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        assertRenders(
            VideoEditorLoadedView(
                availableSize: CGSize(width: 320, height: 480),
                resolvedSourceVideoURL: sourceURL,
                isPlaybackFocused: false
            ) {
                Rectangle()
                    .fill(.blue)
                    .frame(height: 96)
            } controlsContent: {
                Text("Controls")
            } toolsContent: {
                Text("Tools")
            }
        )
    }

    @Test
    func videoEditorPlayerStageViewCanRenderLoadedCanvasWithInjectedOverlay() {
        let editorState = VideoCanvasEditorState()

        assertRenders(
            VideoEditorPlayerStageView(
                .loaded,
                canvasEditorState: editorState,
                source: .init(
                    naturalSize: CGSize(width: 1920, height: 1080),
                    preferredTransform: .identity,
                    userRotationDegrees: 0,
                    isMirrored: false
                ),
                isCanvasInteractive: false
            ) {
                Rectangle()
                    .fill(.blue)
            } overlay: { _ in
                Text("Transcript")
            } trailingControls: {
                Image(systemName: "arrow.counterclockwise")
            }
        )
    }

    @Test
    func videoEditorPlaybackTimelineContainerViewCanRenderInjectedControls() {
        assertRenders(
            VideoEditorPlaybackTimelineContainerView {
                Image(systemName: "play.fill")
            } timeline: {
                Rectangle()
                    .fill(.blue)
                    .frame(height: 60)
            } footer: {
                HStack {
                    Text("0:00")
                    Spacer()
                    Text("0:12")
                }
            }
        )
    }

    @Test
    func videoEditorPlaybackTimelineTrackSectionViewCanRenderInjectedBadgeAndTrack() {
        assertRenders(
            VideoEditorPlaybackTimelineTrackSectionView { _, badgeWidth in
                Text("00:01 / 00:05")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .overlay {
                        Color.clear
                            .accessibilityLabel("Badge width \(Int(badgeWidth.rounded()))")
                    }
            } track: { _ in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.blue.opacity(0.2))
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(.blue)
                            .frame(width: 2, height: 70)
                    }
            }
            .frame(width: 320)
        )
    }

    @Test
    func videoEditorPlaybackTimelineViewCanRenderInjectedPlaybackSections() {
        assertRenders(
            VideoEditorPlaybackTimelineView {
                Image(systemName: "play.fill")
                    .frame(width: 60, height: 60)
            } badge: { _, _ in
                Text("00:01 / 00:05")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
            } track: { _ in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.blue.opacity(0.2))
                    .frame(height: 60)
            } footer: {
                HStack {
                    Text("0:00")
                    Spacer()
                    Text("0:12")
                }
            }
            .frame(width: 320)
        )
    }

    @Test
    func videoEditorPlayerSurfaceViewCanRenderScaledInjectedPlayerContent() {
        assertRenders(
            VideoEditorPlayerSurfaceView(
                backgroundColor: .blue.opacity(0.2),
                scale: 0.92,
                animation: .default
            ) {
                Rectangle()
                    .fill(.blue)
            }
        )
    }

    @Test
    func hostedVideoEditorTrimSectionViewCanRenderTheHostTimelineAdapter() {
        let editorViewModel = EditorViewModel()
        editorViewModel.currentVideo = Video.mock

        assertRenders(
            HostedVideoEditorTrimSectionView(
                editorViewModel,
                videoPlayer: VideoPlayerManager()
            )
            .frame(width: 320, height: 120)
        )
    }

    @Test
    func hostedVideoEditorLoadedContentViewCanRenderTheHostLoadedShell() throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let editorViewModel = EditorViewModel()
        editorViewModel.currentVideo = Video.mock

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        assertRenders(
            HostedVideoEditorLoadedContentView(
                availableSize: CGSize(width: 320, height: 480),
                resolvedSourceVideoURL: sourceURL,
                sessionEditingConfiguration: .initial,
                configuration: .init(),
                editorViewModel: editorViewModel,
                videoPlayer: VideoPlayerManager()
            )
        )
    }

    @Test
    func hostedVideoEditorPlayerOverlayViewCanRenderTheTranscriptOverlay() {
        let activeWordID = UUID()

        assertRenders(
            HostedVideoEditorPlayerOverlayView(
                context: .init(
                    transcriptDocument: .init(
                        segments: [],
                        overlayPosition: .bottom,
                        overlaySize: .medium
                    ),
                    activeSegment: .init(
                        id: UUID(),
                        timeMapping: .init(
                            sourceStartTime: 0,
                            sourceEndTime: 2,
                            timelineStartTime: 0,
                            timelineEndTime: 2
                        ),
                        originalText: "hello world",
                        editedText: "hello world",
                        words: [
                            .init(
                                id: activeWordID,
                                timeMapping: .init(
                                    sourceStartTime: 0,
                                    sourceEndTime: 1,
                                    timelineStartTime: 0,
                                    timelineEndTime: 1
                                ),
                                originalText: "hello",
                                editedText: "hello"
                            )
                        ]
                    ),
                    activeWordID: activeWordID,
                    layoutID: "overlay"
                ),
                canvasLayout: .init(
                    previewCanvasSize: CGSize(width: 320, height: 180),
                    exportCanvasSize: CGSize(width: 1080, height: 608),
                    previewScale: 1,
                    contentBaseSize: CGSize(width: 320, height: 180),
                    contentScale: 1,
                    contentCenter: CGPoint(x: 160, y: 90),
                    totalRotationRadians: 0,
                    isMirrored: false
                )
            )
            .frame(width: 320, height: 180)
        )
    }

    @Test
    func hostedVideoEditorPlayerTrailingControlsViewCanRenderResetChrome() {
        assertRenders(
            HostedVideoEditorPlayerTrailingControlsView(
                shouldShowResetButton: true,
                onReset: {}
            )
        )
    }

    @Test
    func hostedVideoEditorExportSheetContentViewCanRenderTheHostExportAdapter() {
        let editorViewModel = EditorViewModel()
        editorViewModel.currentVideo = Video.mock

        assertRenders(
            HostedVideoEditorExportSheetContentView(
                editorViewModel: editorViewModel,
                videoPlayer: VideoPlayerManager(),
                configuration: .init(),
                callbacks: .init()
            )
        )
    }

    @Test
    func videoEditorToolSheetViewCanRenderInjectedContentAndFooter() {
        assertRenders(
            NavigationStack {
                VideoEditorToolSheetView(
                    title: "Speed",
                    contentInteraction: .resizes,
                    onClose: {},
                    onReset: {}
                ) {
                    Text("Tool body")
                } footer: {
                    Text("Apply")
                }
            }
        )
    }

    @Test
    func videoEditorToolsTrayViewCanRenderInjectedToolbarAndSheetContent() {
        struct ToolsTrayHostView: View {
            @State private var selectedTool: ToolEnum? = .speed

            var body: some View {
                VideoEditorToolsTrayView(
                    selectedTool: $selectedTool,
                    initialSheetHeight: { _ in 320 }
                ) {
                    Text("Toolbar")
                } sheetContent: { tool in
                    Text(tool.title)
                }
            }
        }

        assertRenders(ToolsTrayHostView())
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

    @Test
    func hostedVideoEditorToolContentViewCanRenderRoutedHostToolContent() {
        let editorViewModel = EditorViewModel()
        editorViewModel.currentVideo = Video.mock

        assertRenders(
            HostedVideoEditorToolContentView(
                tool: .audio,
                draftState: .constant(
                    .init(
                        audioDraft: .init(
                            selectedTrack: .recorded,
                            videoVolume: 0.9,
                            recordedVolume: 0.4
                        )
                    )
                ),
                editorViewModel: editorViewModel
            )
            .padding()
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

private struct VideoEditorPresentationSmokeHostView: View {

    // MARK: - States

    @State private var shareDestination: RootViewModel.ShareDestination?
    @State private var blockedTool: ToolEnum?

    // MARK: - Public Properties

    let sourceURL: URL
    let initialShareDestination: RootViewModel.ShareDestination

    // MARK: - Body

    var body: some View {
        HostedVideoEditorView(
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
