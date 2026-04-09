#if os(iOS)
    import SwiftUI

    @MainActor
    public struct VideoEditorView: View {

        // MARK: - Environments

        @Environment(\.dismiss) private var dismiss

        // MARK: - States

        @State private var editorViewModel = EditorViewModel()
        @State private var saveEmissionCoordinator = VideoEditorSaveEmissionCoordinator()
        @State private var videoPlayer = VideoPlayerManager()

        // MARK: - Public Properties

        public typealias SaveState = VideoEditorSaveState
        public typealias Session = VideoEditorSession
        public typealias Callbacks = VideoEditorCallbacks
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
                        Text("Export")
                    }
                    .disabled(isEditingLocked)
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
            }
            .animation(.default, value: videoPlayer.isPlaybackFocusActive)
            .safeAreaPadding()
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
        }

        // MARK: - Private Properties

        private let title: String?
        private let session: Session
        private let configuration: Configuration
        private let callbacks: Callbacks

        private var isEditingLocked: Bool {
            videoPlayer.isPlaybackFocusActive
        }

        @ViewBuilder
        private var exportSheetContent: some View {
            if let video = editorViewModel.currentVideo {
                VideoExporterContainerView(
                    video: video,
                    editingConfiguration: resolvedExportEditingConfiguration,
                    exportQualities: configuration.exportQualities,
                    onBlockedQualityTap: configuration.notifyBlockedExportQualityTap(for:)
                ) { exportedVideo in
                    HostedVideoEditorShellCoordinator.handleExportedVideo(
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
            HostedVideoEditorRuntimeCoordinator.bootstrapEditorContent(
                availableSize: availableSize,
                resolvedSourceVideoURL: resolvedSourceVideoURL,
                sessionEditingConfiguration: session.editingConfiguration,
                configuration: configuration,
                editorViewModel: editorViewModel,
                videoPlayer: videoPlayer
            )
        }

        private func handlePlaybackLockChange(_ isPlaybackFocusActive: Bool) {
            HostedVideoEditorRuntimeCoordinator.handlePlaybackFocusChange(
                isPlaybackFocusActive,
                editorViewModel: editorViewModel
            )
        }

        private func dismissEditor() {
            HostedVideoEditorShellCoordinator.dismissEditor(
                editorViewModel: editorViewModel,
                currentTimelineTime: videoPlayer.currentTime,
                fallbackEditingConfiguration: session.editingConfiguration,
                callbacks: callbacks,
                dismiss: dismiss.callAsFunction
            )
        }

        private func presentExporter() {
            HostedVideoEditorShellCoordinator.presentExporter(
                editorViewModel: editorViewModel
            )
        }

        private func handleRecordedVideo(_ url: URL) {
            HostedVideoEditorShellCoordinator.handleRecordedVideo(
                url,
                editorViewModel: editorViewModel,
                videoPlayer: videoPlayer
            )
        }

        private func publishEditingConfigurationIfNeeded() {
            HostedVideoEditorShellCoordinator.publishEditingConfigurationIfNeeded(
                editorViewModel: editorViewModel,
                currentTimelineTime: videoPlayer.currentTime,
                fallbackSourceVideoURL: session.sourceVideoURL,
                saveEmissionCoordinator: saveEmissionCoordinator,
                callbacks: callbacks
            )
        }

        private func handleDisappear() {
            HostedVideoEditorRuntimeCoordinator.handleDisappear(
                saveEmissionCoordinator: saveEmissionCoordinator,
                editorViewModel: editorViewModel
            )
        }

        private func syncPlayerLoadState(
            for bootstrapState: VideoEditorSessionBootstrapCoordinator.BootstrapState
        ) {
            videoPlayer.loadState = HostedVideoEditorRuntimeCoordinator.resolvedPlayerLoadState(
                for: bootstrapState,
                currentVideoURL: editorViewModel.currentVideo?.url
            )
        }

    }

    #Preview {
        VideoEditorView(
            "Preview",
            session: VideoEditorSession(source: nil)
        )
    }

#endif
