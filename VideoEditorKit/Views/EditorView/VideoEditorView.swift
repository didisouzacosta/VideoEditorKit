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
    @State private var textEditor = TextEditorViewModel()

    // MARK: - Private Properties

    private let configuration: Configuration
    private let sourceVideoURL: URL?
    private let onExported: (URL) -> Void

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
                            dismiss()
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
                        sourceVideoURL,
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
                VideoExporterView(video: video) { exportedURL in
                    videoPlayer.pause()
                    onExported(exportedURL)
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
        _ sourceVideoURL: URL? = nil,
        configuration: Configuration = .init(),
        onExported: @escaping (URL) -> Void = { _ in }
    ) {
        self.configuration = configuration
        self.sourceVideoURL = sourceVideoURL
        self.onExported = onExported
    }

    // MARK: - Private Methods

    private func handlePlaybackLockChange(_ isPlaying: Bool) {
        guard isPlaying else { return }

        editorViewModel.closeSelectedTool(textEditor)
        textEditor.dismissTextToolPresentation()
    }

}

extension VideoEditorView {

    struct Configuration {

        // MARK: - Public Properties

        let tools: [ToolAvailability]
        let onBlockedToolTap: ((ToolEnum) -> Void)?

        // MARK: - Initializer

        init(
            tools: [ToolAvailability] = ToolEnum.all.map { ToolAvailability($0) },
            onBlockedToolTap: ((ToolEnum) -> Void)? = nil
        ) {
            self.tools = tools
            self.onBlockedToolTap = onBlockedToolTap
        }

        // MARK: - Public Methods

        func availability(for tool: ToolEnum) -> ToolAvailability? {
            tools.first(where: { $0.tool == tool })
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
