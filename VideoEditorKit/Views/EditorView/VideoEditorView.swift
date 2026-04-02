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

    struct SaveState: Equatable, Sendable {

        // MARK: - Public Properties

        let editingConfiguration: VideoEditingConfiguration
        let thumbnailData: Data?
        var continuousSaveFingerprint: VideoEditingConfiguration {
            editingConfiguration.continuousSaveFingerprint
        }

        // MARK: - Initializer

        init(
            editingConfiguration: VideoEditingConfiguration,
            thumbnailData: Data? = nil
        ) {
            self.editingConfiguration = editingConfiguration
            self.thumbnailData = thumbnailData
        }

    }

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - States

    @State private var editorViewModel = EditorViewModel()
    @State private var audioRecorder = AudioRecorderManager()
    @State private var saveEmissionCoordinator = VideoEditorSaveEmissionCoordinator()
    @State private var videoPlayer = VideoPlayerManager()

    // MARK: - Private Properties

    private let callbacks: Callbacks
    private let configuration: Configuration
    private let session: Session

    // MARK: - Body

    var body: some View {
        @Bindable var bindablePresentationState = editorViewModel.presentationState

        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 32) {
                    PlayerHolderView(
                        editorViewModel,
                        videoPlayer: videoPlayer
                    )
                    .layoutPriority(1)
                    .disabled(isEditingLocked)

                    PlayerControl(
                        editorViewModel,
                        videoPlayer: videoPlayer,
                        recorderManager: audioRecorder
                    )

                    if !videoPlayer.isPlaying {
                        ToolsSectionView(
                            videoPlayer,
                            editorVM: editorViewModel,
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
        .onDisappear(perform: handleDisappear)
        .dynamicHeightSheet(
            isPresented: $bindablePresentationState.showVideoQualitySheet,
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
                ) { exportedVideo in
                    videoPlayer.pause()
                    callbacks.onExportedVideoURL(exportedVideo.url)
                }
            }
        }
        .fullScreenCover(isPresented: $bindablePresentationState.showRecordView) {
            RecordVideoView { url in
                editorViewModel.handleRecordedVideo(url, videoPlayer: videoPlayer)
            }
        }
        .onChange(of: videoPlayer.isPlaying) { _, isPlaying in
            handlePlaybackLockChange(isPlaying)
        }
        .onChange(of: editorViewModel.presentationState.editingConfigurationRevision) { _, _ in
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
        onSaveStateChanged: @escaping (SaveState) -> Void = { _ in },
        onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
        onExportedVideoURL: @escaping (URL) -> Void = { _ in }
    ) {
        self.init(
            .init(
                sourceVideoURL: sourceVideoURL,
                editingConfiguration: editingConfiguration
            ),
            configuration: configuration,
            callbacks: .init(
                onSaveStateChanged: onSaveStateChanged,
                onDismissed: onDismissed,
                onExportedVideoURL: onExportedVideoURL
            )
        )
    }

    // MARK: - Private Methods

    private func handlePlaybackLockChange(_ isPlaying: Bool) {
        guard isPlaying else { return }
        editorViewModel.closeSelectedTool()
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
            )
        else {
            return
        }

        let sourceVideoURL = editorViewModel.currentVideo?.url ?? session.sourceVideoURL

        saveEmissionCoordinator.scheduleSave(
            editingConfiguration: currentEditingConfiguration,
            sourceVideoURL: sourceVideoURL
        ) { publishedSave in
            callbacks.onSaveStateChanged(
                .init(
                    editingConfiguration: publishedSave.editingConfiguration,
                    thumbnailData: publishedSave.thumbnailData
                )
            )
        }
    }

    private func handleDisappear() {
        saveEmissionCoordinator.reset()
        editorViewModel.cancelDeferredTasks()
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

        let onSaveStateChanged: (SaveState) -> Void
        let onDismissed: (VideoEditingConfiguration?) -> Void
        let onExportedVideoURL: (URL) -> Void

        // MARK: - Initializer

        init(
            onSaveStateChanged: @escaping (SaveState) -> Void = { _ in },
            onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
            onExportedVideoURL: @escaping (URL) -> Void = { _ in }
        ) {
            self.onSaveStateChanged = onSaveStateChanged
            self.onDismissed = onDismissed
            self.onExportedVideoURL = onExportedVideoURL
        }

    }

    struct Configuration {

        // MARK: - Public Properties

        static var allToolsEnabled: Self {
            Self()
        }

        let tools: [ToolAvailability]

        // MARK: - Private Properties

        private let onBlockedToolTap: ((ToolEnum) -> Void)?

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

        func isBlocked(_ tool: ToolEnum) -> Bool {
            availability(for: tool)?.isBlocked == true
        }

        func isEnabled(_ tool: ToolEnum) -> Bool {
            availability(for: tool)?.isEnabled == true
        }

        func notifyBlockedToolTap(for tool: ToolEnum) {
            onBlockedToolTap?(tool)
        }

    }

}
