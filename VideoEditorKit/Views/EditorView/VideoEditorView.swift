//
//  VideoEditorView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//
import AVKit
import SwiftUI

@MainActor
struct VideoEditorView: View {

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - States

    @State private var editorViewModel = EditorViewModel()
    @State private var audioRecorder = AudioRecorderManager()
    @State private var videoPlayer = VideoPlayerManager()
    @State private var lastPublishedEditingConfiguration: VideoEditingConfiguration?
    @State private var textEditor = TextEditorViewModel()

    // MARK: - Private Properties

    private let callbacks: Callbacks
    private let configuration: Configuration
    private let session: Session

    // MARK: - Body

    var body: some View {
        @Bindable var bindableEditorViewModel = editorViewModel

        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 32) {
                    PlayerHolderView(
                        editorViewModel,
                        videoPlayer: videoPlayer,
                        textEditor: textEditor
                    )
                    .disabled(isEditingLocked)

                    PlayerControl(
                        editorViewModel,
                        videoPlayer: videoPlayer,
                        recorderManager: audioRecorder,
                        textEditor: textEditor
                    )

                    if !videoPlayer.isPlaying {
                        ToolsSectionView(
                            videoPlayer,
                            editorVM: editorViewModel,
                            textEditor: textEditor,
                            configuration: configuration
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.default, value: videoPlayer.isPlaying)
                .safeAreaPadding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            dismissEditor()
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .confirm) {
                            editorViewModel.presentExporter()
                        } label: {
                            Text("Export")
                        }
                        .disabled(isEditingLocked)
                    }
                }
                .onAppear {
                    editorViewModel.setToolAvailability(configuration.tools)
                    editorViewModel.setSourceVideoIfNeeded(
                        session.sourceVideoURL,
                        editingConfiguration: session.editingConfiguration,
                        availableSize: proxy.size,
                        videoPlayer: videoPlayer
                    )
                }
            }
        }
        .onDisappear(perform: editorViewModel.cancelDeferredTasks)
        .blur(radius: textEditor.editorBlurRadius)
        .overlay {
            if textEditor.isPresentingEditor {
                TextEditorView(textEditor, onSave: editorViewModel.setText)
            }
        }
        .dynamicHeightSheet(
            isPresented: $bindableEditorViewModel.showVideoQualitySheet,
            initialHeight: 420
        ) {
            if let video = editorViewModel.currentVideo {
                let editingConfiguration =
                    editorViewModel.currentEditingConfiguration(
                        currentTimelineTime: videoPlayer.currentTime
                    ) ?? .initial

                VideoExporterView(
                    video: video,
                    editingConfiguration: editingConfiguration
                ) { exportedURL in
                    videoPlayer.pause()
                    callbacks.onExported(exportedURL, editingConfiguration)
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $bindableEditorViewModel.showRecordView) {
            RecordVideoView { url in
                editorViewModel.handleRecordedVideo(url, videoPlayer: videoPlayer)
            }
        }
        .onChange(of: videoPlayer.isPlaying) { _, isPlaying in
            handlePlaybackLockChange(isPlaying)
        }
        .onChange(of: editorViewModel.editingConfigurationChangeCounter) { _, _ in
            publishEditingConfigurationIfNeeded()
        }
        .onChange(of: configuration.tools) { _, newValue in
            editorViewModel.setToolAvailability(newValue)
        }
    }

    // MARK: - Private Properties

    private var isEditingLocked: Bool {
        videoPlayer.isPlaying
    }

    // MARK: - Initializer

    init(
        _ session: Session,
        configuration: Configuration = .init(),
        callbacks: Callbacks = .init()
    ) {
        self.callbacks = callbacks
        self.configuration = configuration
        self.session = session
    }

    init(
        _ sourceVideoURL: URL? = nil,
        editingConfiguration: VideoEditingConfiguration? = nil,
        configuration: Configuration = .init(),
        onEditingConfigurationChanged: @escaping (VideoEditingConfiguration) -> Void = { _ in },
        onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
        onExported: @escaping (ExportedVideo, VideoEditingConfiguration) -> Void = { _, _ in }
    ) {
        self.init(
            .init(
                sourceVideoURL: sourceVideoURL,
                editingConfiguration: editingConfiguration
            ),
            configuration: configuration,
            callbacks: .init(
                onEditingConfigurationChanged: onEditingConfigurationChanged,
                onDismissed: onDismissed,
                onExported: onExported
            )
        )
    }

    // MARK: - Private Methods

    private func handlePlaybackLockChange(_ isPlaying: Bool) {
        guard isPlaying else { return }

        editorViewModel.closeSelectedTool(textEditor)
        textEditor.dismissTextToolPresentation()
    }

    private func dismissEditor() {
        let currentEditingConfiguration =
            editorViewModel.currentEditingConfiguration(
                currentTimelineTime: videoPlayer.currentTime
            ) ?? session.editingConfiguration

        callbacks.onDismissed(currentEditingConfiguration)
        dismiss()
    }

    private func publishEditingConfigurationIfNeeded() {
        guard
            let currentEditingConfiguration = editorViewModel.currentEditingConfiguration(
                currentTimelineTime: videoPlayer.currentTime
            ),
            currentEditingConfiguration != lastPublishedEditingConfiguration
        else {
            return
        }

        lastPublishedEditingConfiguration = currentEditingConfiguration
        callbacks.onEditingConfigurationChanged(currentEditingConfiguration)
    }

}

extension VideoEditorView {

    struct Session: Equatable {

        // MARK: - Public Properties

        let sourceVideoURL: URL?
        let editingConfiguration: VideoEditingConfiguration?

        // MARK: - Initializer

        init(
            sourceVideoURL: URL? = nil,
            editingConfiguration: VideoEditingConfiguration? = nil
        ) {
            self.sourceVideoURL = sourceVideoURL
            self.editingConfiguration = editingConfiguration
        }

    }

    struct Callbacks {

        // MARK: - Public Properties

        let onEditingConfigurationChanged: (VideoEditingConfiguration) -> Void
        let onDismissed: (VideoEditingConfiguration?) -> Void
        let onExported: (ExportedVideo, VideoEditingConfiguration) -> Void

        // MARK: - Initializer

        init(
            onEditingConfigurationChanged: @escaping (VideoEditingConfiguration) -> Void = { _ in },
            onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
            onExported: @escaping (ExportedVideo, VideoEditingConfiguration) -> Void = { _, _ in }
        ) {
            self.onEditingConfigurationChanged = onEditingConfigurationChanged
            self.onDismissed = onDismissed
            self.onExported = onExported
        }

    }

    struct Configuration {

        // MARK: - Public Properties

        static var allToolsEnabled: Self {
            Self()
        }

        let tools: [ToolAvailability]
        let onBlockedToolTap: ((ToolEnum) -> Void)?

        var visibleTools: [ToolEnum] {
            tools.map(\.tool)
        }

        // MARK: - Initializer

        init(
            tools: [ToolAvailability] = ToolAvailability.enabled(ToolEnum.all),
            onBlockedToolTap: ((ToolEnum) -> Void)? = nil
        ) {
            self.tools = tools
            self.onBlockedToolTap = onBlockedToolTap
        }

        // MARK: - Public Methods

        func availability(for tool: ToolEnum) -> ToolAvailability? {
            tools.first(where: { $0.tool == tool })
        }

        func isVisible(_ tool: ToolEnum) -> Bool {
            availability(for: tool) != nil
        }

        func isEnabled(_ tool: ToolEnum) -> Bool {
            availability(for: tool)?.isEnabled == true
        }

        func isBlocked(_ tool: ToolEnum) -> Bool {
            availability(for: tool)?.isBlocked == true
        }

        func notifyBlockedToolTap(for tool: ToolEnum) {
            onBlockedToolTap?(tool)
        }

    }

}

#Preview {
    NavigationStack {
        VideoEditorView()
    }
}
