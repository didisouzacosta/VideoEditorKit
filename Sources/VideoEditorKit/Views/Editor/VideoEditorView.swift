import SwiftUI

/// The main SwiftUI entry point for embedding the VideoEditorKit editor in a host app.
///
/// Create it with a `VideoEditorSession` when you need asynchronous source loading or resume
/// behavior, or use one of the convenience initializers when you already have a local file URL.
@MainActor
public struct VideoEditorView: View {

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - States

    @State private var editorViewModel = EditorViewModel()
    @State private var exportLifecycleState: ExportLifecycleState = .active
    @State private var cancelConfirmationState: VideoEditorCancelConfirmationState?
    @State private var manualSaveCoordinator = VideoEditorManualSaveCoordinator()
    @State private var videoPlayer = VideoPlayerManager()

    // MARK: - Public Properties

    /// The continuous-save payload emitted by the editor.
    public typealias SaveState = VideoEditorSaveState
    /// The manual-save payload emitted by the editor.
    public typealias SavedVideo = VideoEditorKit.SavedVideo
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
            onCancel: requestEditorDismissal,
            onBootstrapStateChanged: syncPlayerLoadState
        ) {
            editorToolbarActions
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
        .onChange(of: scenePhase) { _, newScenePhase in
            handleScenePhaseChange(newScenePhase)
        }
        .task(id: scenePhase) {
            handleScenePhaseChange(scenePhase)
        }
        .dynamicHeightSheet(
            isPresented: $bindablePresentationState.showVideoQualitySheet,
            initialHeight: 420
        ) {
            exportSheetContent
        }
        .fullScreenCover(isPresented: $bindablePresentationState.showRecordView) {
            RecordVideoView(handleRecordedVideo)
        }
        .alert(
            VideoEditorStrings.unsavedChangesAlertTitle,
            isPresented: cancelConfirmationBinding,
            presenting: cancelConfirmationState
        ) { _ in
            Button(VideoEditorStrings.save, action: saveChangesAndDismiss)

            Button(VideoEditorStrings.discardUnsavedChanges, role: .destructive) {
                discardChangesAndDismiss()
            }

            Button(VideoEditorStrings.cancel, role: .cancel) {
                cancelConfirmationState = nil
            }
        } message: { _ in
            Text(VideoEditorStrings.unsavedChangesAlertMessage)
        }
        .onChange(of: videoPlayer.isPlaybackFocusActive) { _, isPlaybackFocusActive in
            handlePlaybackLockChange(isPlaybackFocusActive)
        }
        .onChange(of: editorViewModel.presentationState.editingConfigurationRevision) { _, _ in
            handleEditingConfigurationChange()
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
                lifecycleState: $exportLifecycleState,
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
        editorViewModel.exportEditingConfiguration() ?? .initial
    }

    private var canSaveCurrentEdit: Bool {
        Self.canPresentManualSaveAction(
            hasLoadedVideo: editorViewModel.currentVideo != nil,
            hasUnsavedChanges: manualSaveCoordinator.hasUnsavedChanges,
            isSaving: manualSaveCoordinator.isSaving
        )
    }

    private var cancelConfirmationBinding: Binding<Bool> {
        .init(
            get: { cancelConfirmationState != nil },
            set: { isPresented in
                guard isPresented == false else { return }
                cancelConfirmationState = nil
            }
        )
    }

    @ViewBuilder
    private var editorToolbarActions: some View {
        if editorViewModel.currentVideo != nil {
            HStack(spacing: 12) {
                Button(action: presentExporter) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(VideoEditorStrings.export)
                .disabled(manualSaveCoordinator.isSaving)

                Button(action: saveCurrentEdit) {
                    Text(VideoEditorStrings.save)
                }
                .buttonStyle(.primary)
                .disabled(!canSaveCurrentEdit)
            }
        }
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
        onSavedVideo: @escaping (SavedVideo) -> Void = { _ in },
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
                onSavedVideo: onSavedVideo,
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
        onSavedVideo: @escaping (SavedVideo) -> Void = { _ in },
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
            onSavedVideo: onSavedVideo,
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

    private func requestEditorDismissal() {
        Self.handleCancelRequest(
            hasUnsavedChanges: manualSaveCoordinator.hasUnsavedChanges,
            presentConfirmation: { state in
                cancelConfirmationState = state
            },
            dismiss: dismissEditorImmediately
        )
    }

    private func dismissEditorImmediately() {
        Self.dismissEditor(
            editorViewModel: editorViewModel,
            fallbackEditingConfiguration: session.editingConfiguration,
            callbacks: callbacks,
            dismiss: dismiss.callAsFunction
        )
    }

    private func presentExporter() {
        Task {
            await Self.prepareExporterPresentation(
                editorViewModel: editorViewModel,
                fallbackSourceVideoURL: session.sourceVideoURL,
                manualSaveCoordinator: manualSaveCoordinator,
                videoPlayer: videoPlayer,
                callbacks: callbacks
            )
        }
    }

    private func saveCurrentEdit() {
        Task {
            await performCurrentManualSave()
        }
    }

    @discardableResult
    private func performCurrentManualSave() async -> SavedVideo? {
        await Self.performManualSave(
            editorViewModel: editorViewModel,
            fallbackSourceVideoURL: session.sourceVideoURL,
            manualSaveCoordinator: manualSaveCoordinator,
            callbacks: callbacks
        )
    }

    private func handleEditingConfigurationChange() {
        Self.handleEditingConfigurationChange(
            editorViewModel: editorViewModel,
            manualSaveCoordinator: manualSaveCoordinator
        )
    }

    private func saveChangesAndDismiss() {
        cancelConfirmationState = nil
        Task {
            guard await performCurrentManualSave() != nil else { return }
            dismissEditorImmediately()
        }
    }

    private func discardChangesAndDismiss() {
        cancelConfirmationState = nil
        manualSaveCoordinator.reset()
        dismissEditorImmediately()
    }

    private func handleRecordedVideo(_ url: URL) {
        manualSaveCoordinator.reset()
        Self.handleRecordedVideo(
            url,
            editorViewModel: editorViewModel,
            videoPlayer: videoPlayer
        )
    }

    private func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        exportLifecycleState = .init(scenePhase: scenePhase)
    }

    private func handleDisappear() {
        Self.handleDisappear(editorViewModel: editorViewModel)
    }

    private func syncPlayerLoadState(
        for bootstrapState: VideoEditorSessionBootstrapCoordinator.BootstrapState
    ) {
        if case .loaded = bootstrapState {
            manualSaveCoordinator.reset()
        }

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
