import SwiftUI

/// The main SwiftUI entry point for embedding the VideoEditorKit editor in a host app.
///
/// Create it with a `VideoEditorSession` when you need asynchronous source loading or resume
/// behavior, or use one of the convenience initializers when you already have a local file URL.
@MainActor
public struct VideoEditorView: View {

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - States

    @State private var editorViewModel = EditorViewModel()
    @State private var saveEmissionCoordinator = VideoEditorSaveEmissionCoordinator()
    @State private var videoPlayer = VideoPlayerManager()

    // MARK: - Public Properties

    /// The continuous-save payload emitted by the editor.
    public typealias SaveState = VideoEditorSaveState
    /// The host-controlled source and restore payload for one editing run.
    public typealias Session = VideoEditorSession
    /// Callback bundle invoked as the user edits, dismisses, and exports content.
    public typealias Callbacks = VideoEditorCallbacks
    /// Runtime configuration that controls tool visibility, export options, and integrations.
    public typealias Configuration = VideoEditorConfiguration

    // MARK: - Body

    public var body: some View {
        @Bindable var bindablePresentationState = editorViewModel.presentationState

        VideoEditorShellView(
            title,
            session: session,
            callbacks: callbacks,
            onCancel: dismissEditor,
            onBootstrapStateChanged: syncPlayerLoadState
        ) {
            if editorViewModel.currentVideo != nil {
                Button(role: .confirm, action: presentExporter) {
                    Text(VideoEditorStrings.export)
                }
            }
        } loadedContent: { availableSize, resolvedSourceVideoURL in
            VideoEditorLoadedView(
                availableSize: availableSize,
                resolvedSourceVideoURL: resolvedSourceVideoURL,
                isPlaybackFocused: videoPlayer.isPlaybackFocusActive,
                onLoad: bootstrapEditorContent
            ) {
                PlayerHolderView(
                    editorViewModel,
                    videoPlayer: videoPlayer
                )
            } controlsContent: {
                VideoEditorTrimSectionView(
                    editorViewModel,
                    videoPlayer: videoPlayer
                )
            } toolsContent: {
                ToolsSectionView(
                    videoPlayer,
                    editorVM: editorViewModel,
                    configuration: configuration
                )
            }
            .safeAreaPadding(.horizontal)
            .safeAreaPadding(.top)
        }
        .onDisappear(perform: handleDisappear)
        .dynamicHeightSheet(
            isPresented: $bindablePresentationState.showVideoQualitySheet,
            initialHeight: 420
        ) {
            exportSheetContent
        }
        .fullScreenCover(isPresented: $bindablePresentationState.showRecordView) {
            RecordVideoView(handleRecordedVideo)
        }
        .onChange(of: videoPlayer.isPlaybackFocusActive) { _, isPlaybackFocusActive in
            handlePlaybackLockChange(isPlaybackFocusActive)
        }
        .onChange(of: editorViewModel.presentationState.editingConfigurationRevision) { _, _ in
            publishEditingConfigurationIfNeeded()
        }
        .onChange(of: configuration.tools) { _, newValue in
            editorViewModel.setToolAvailability(newValue)
        }
        .onChange(of: configuration.maximumVideoDuration) { _, newValue in
            Self.handleMaximumVideoDurationChange(
                newValue,
                editorViewModel: editorViewModel,
                videoPlayer: videoPlayer
            )
        }
    }

    // MARK: - Private Properties

    private let title: String?
    private let session: Session
    private let configuration: Configuration
    private let callbacks: Callbacks

    @ViewBuilder
    private var exportSheetContent: some View {
        if let video = editorViewModel.currentVideo {
            VideoExporterContainerView(
                video: video,
                editingConfiguration: resolvedExportEditingConfiguration,
                exportQualities: configuration.exportQualities,
                onBlockedQualityTap: configuration.notifyBlockedExportQualityTap(for:)
            ) { exportedVideo in
                Self.handleExportedVideo(
                    exportedVideo,
                    videoPlayer: videoPlayer,
                    callbacks: callbacks
                )
            }
        }
    }

    private var resolvedExportEditingConfiguration: VideoEditingConfiguration {
        editorViewModel.exportEditingConfiguration(
            currentTimelineTime: videoPlayer.currentTime
        ) ?? .initial
    }

    // MARK: - Initializer

    /// Creates the editor from an explicit session object.
    public init(
        _ title: String? = nil,
        session: Session,
        configuration: Configuration = .init(),
        callbacks: Callbacks = .init()
    ) {
        self.title = title
        self.session = session
        self.configuration = configuration
        self.callbacks = callbacks
    }

    /// Creates the editor from a session source and an optional restore snapshot.
    public init(
        _ title: String? = nil,
        source: Session.Source? = nil,
        editingConfiguration: VideoEditingConfiguration? = nil,
        configuration: Configuration = .init(),
        onSaveStateChanged: @escaping (SaveState) -> Void = { _ in },
        onSourceVideoResolved: @escaping (URL) -> Void = { _ in },
        onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
        onExportedVideoURL: @escaping (URL) -> Void = { _ in }
    ) {
        self.init(
            title,
            session: .init(
                source: source,
                editingConfiguration: editingConfiguration
            ),
            configuration: configuration,
            callbacks: .init(
                onSaveStateChanged: onSaveStateChanged,
                onSourceVideoResolved: onSourceVideoResolved,
                onDismissed: onDismissed,
                onExportedVideoURL: onExportedVideoURL
            )
        )
    }

    /// Creates the editor directly from a local source file URL.
    public init(
        _ title: String? = nil,
        sourceVideoURL: URL?,
        editingConfiguration: VideoEditingConfiguration? = nil,
        configuration: Configuration = .init(),
        onSaveStateChanged: @escaping (SaveState) -> Void = { _ in },
        onSourceVideoResolved: @escaping (URL) -> Void = { _ in },
        onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
        onExportedVideoURL: @escaping (URL) -> Void = { _ in }
    ) {
        self.init(
            title,
            source: sourceVideoURL.map { .fileURL($0) },
            editingConfiguration: editingConfiguration,
            configuration: configuration,
            onSaveStateChanged: onSaveStateChanged,
            onSourceVideoResolved: onSourceVideoResolved,
            onDismissed: onDismissed,
            onExportedVideoURL: onExportedVideoURL
        )
    }

    // MARK: - Private Methods

    private func bootstrapEditorContent(
        _ availableSize: CGSize,
        _ resolvedSourceVideoURL: URL
    ) {
        Self.bootstrapEditorContent(
            availableSize: availableSize,
            resolvedSourceVideoURL: resolvedSourceVideoURL,
            sessionEditingConfiguration: session.editingConfiguration,
            configuration: configuration,
            editorViewModel: editorViewModel,
            videoPlayer: videoPlayer
        )
    }

    private func handlePlaybackLockChange(_ isPlaybackFocusActive: Bool) {
        guard isPlaybackFocusActive else { return }
        editorViewModel.closeSelectedTool()
    }

    private func dismissEditor() {
        Self.dismissEditor(
            editorViewModel: editorViewModel,
            currentTimelineTime: videoPlayer.currentTime,
            fallbackEditingConfiguration: session.editingConfiguration,
            callbacks: callbacks,
            dismiss: dismiss.callAsFunction
        )
    }

    private func presentExporter() {
        Self.presentExporter(
            editorViewModel: editorViewModel,
            videoPlayer: videoPlayer
        )
    }

    private func handleRecordedVideo(_ url: URL) {
        Self.handleRecordedVideo(
            url,
            editorViewModel: editorViewModel,
            videoPlayer: videoPlayer
        )
    }

    private func publishEditingConfigurationIfNeeded() {
        Self.scheduleSaveIfNeeded(
            editorViewModel: editorViewModel,
            currentTimelineTime: videoPlayer.currentTime,
            fallbackSourceVideoURL: session.sourceVideoURL,
            saveEmissionCoordinator: saveEmissionCoordinator,
            onPublish: { publishedSave in
                callbacks.onSaveStateChanged(
                    .init(
                        editingConfiguration: publishedSave.editingConfiguration,
                        thumbnailData: publishedSave.thumbnailData
                    )
                )
            }
        )
    }

    private func handleDisappear() {
        Self.handleDisappear(
            saveEmissionCoordinator: saveEmissionCoordinator,
            editorViewModel: editorViewModel
        )
    }

    private func syncPlayerLoadState(
        for bootstrapState: VideoEditorSessionBootstrapCoordinator.BootstrapState
    ) {
        videoPlayer.loadState = Self.resolvedPlayerLoadState(
            for: bootstrapState,
            currentVideoURL: editorViewModel.currentVideo?.url
        )
    }

}

#Preview {
    let previewVideoURL = Bundle.module.url(
        forResource: "preview",
        withExtension: "mp4"
    )

    Group {
        if let previewVideoURL {
            VideoEditorView(
                "Preview",
                sourceVideoURL: previewVideoURL
            )
        } else {
            ContentUnavailableView(
                VideoEditorStrings.previewVideoMissingTitle,
                systemImage: "video.slash",
                description: Text(VideoEditorStrings.previewVideoMissingDescription)
            )
        }
    }
}
