//
//  HostedVideoEditorView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@MainActor
struct HostedVideoEditorView: View {

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - States

    @State private var editorViewModel = EditorViewModel()
    @State private var saveEmissionCoordinator = VideoEditorSaveEmissionCoordinator()
    @State private var videoPlayer = VideoPlayerManager()

    // MARK: - Private Properties

    private let title: String?
    private let callbacks: VideoEditorView.Callbacks
    private let configuration: VideoEditorView.Configuration
    private let session: VideoEditorView.Session

    // MARK: - Body

    var body: some View {
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
            HostedVideoEditorLoadedContentView(
                availableSize: availableSize,
                resolvedSourceVideoURL: resolvedSourceVideoURL,
                sessionEditingConfiguration: session.editingConfiguration,
                configuration: configuration,
                editorViewModel: editorViewModel,
                videoPlayer: videoPlayer
            )
        }
        .animation(.default, value: videoPlayer.isPlaybackFocusActive)
        .safeAreaPadding()
        .onDisappear(perform: handleDisappear)
        .dynamicHeightSheet(
            isPresented: $bindablePresentationState.showVideoQualitySheet,
            initialHeight: 420
        ) {
            HostedVideoEditorExportSheetContentView(
                editorViewModel: editorViewModel,
                videoPlayer: videoPlayer,
                configuration: configuration,
                callbacks: callbacks
            )
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

    private var isEditingLocked: Bool {
        videoPlayer.isPlaybackFocusActive
    }

    // MARK: - Initializer

    init(
        _ title: String? = nil,
        session: VideoEditorView.Session,
        configuration: VideoEditorView.Configuration = .init(),
        callbacks: VideoEditorView.Callbacks = .init()
    ) {
        self.title = title
        self.callbacks = callbacks
        self.configuration = configuration
        self.session = session
    }

    init(
        _ title: String? = nil,
        source: VideoEditorView.Session.Source? = nil,
        editingConfiguration: VideoEditingConfiguration? = nil,
        configuration: VideoEditorView.Configuration = .init(),
        onSaveStateChanged: @escaping (VideoEditorView.SaveState) -> Void = { _ in },
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

    init(
        _ title: String? = nil,
        sourceVideoURL: URL?,
        editingConfiguration: VideoEditingConfiguration? = nil,
        configuration: VideoEditorView.Configuration = .init(),
        onSaveStateChanged: @escaping (VideoEditorView.SaveState) -> Void = { _ in },
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
    HostedVideoEditorView(
        "Preview",
        session: VideoEditorSession(source: nil)
    )
}
