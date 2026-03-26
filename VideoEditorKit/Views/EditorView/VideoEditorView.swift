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

    @State private var isFullScreen = false
    @State private var editorViewModel = EditorViewModel()
    @State private var audioRecorder = AudioRecorderManager()
    @State private var videoPlayer = VideoPlayerManager()
    @State private var textEditor = TextEditorViewModel()

    // MARK: - Private Properties

    private let sourceVideoURL: URL?
    private let onExported: (URL) -> Void

    // MARK: - Body

    var body: some View {
        @Bindable var bindableEditorViewModel = editorViewModel

        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 32) {
                    PlayerHolderView(
                        $isFullScreen,
                        editorVM: editorViewModel,
                        videoPlayer: videoPlayer,
                        textEditor: textEditor
                    )

                    PlayerControl(
                        $isFullScreen,
                        editorViewModel: editorViewModel,
                        videoPlayer: videoPlayer,
                        recorderManager: audioRecorder,
                        textEditor: textEditor
                    )

                    if !isFullScreen {
                        ToolsSectionView(
                            videoPlayer,
                            editorVM: editorViewModel,
                            textEditor: textEditor
                        )
                    }
                }
                .safeAreaPadding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editorViewModel.presentExporter()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up.fill")
                        }
                    }
                }
                .onAppear {
                    editorViewModel.setSourceVideoIfNeeded(
                        sourceVideoURL,
                        availableSize: proxy.size,
                        isFullScreen: isFullScreen,
                        videoPlayer: videoPlayer
                    )
                }
            }

            if let video = editorViewModel.exportVideo {
                VideoExporterBottomSheetView($bindableEditorViewModel.showVideoQualitySheet, video: video) {
                    exportedURL in
                    videoPlayer.pause()
                    onExported(exportedURL)
                    dismiss()
                }
            }
        }
        .blur(radius: textEditor.editorBlurRadius)
        .overlay {
            if textEditor.isPresentingEditor {
                TextEditorView(textEditor, onSave: editorViewModel.setText)
            }
        }
        .onChange(of: isFullScreen) { _, newValue in
            if newValue {
                editorViewModel.closeSelectedTool(textEditor: textEditor)
            }
        }
        .onDisappear(perform: editorViewModel.cancelDeferredTasks)
        .fullScreenCover(isPresented: $bindableEditorViewModel.showRecordView) {
            RecordVideoView { url in
                editorViewModel.handleRecordedVideo(url, videoPlayer: videoPlayer)
            }
        }
    }

    // MARK: - Initializer

    init(
        _ sourceVideoURL: URL? = nil,
        configuration: Configuration = .init(),
        onExported: @escaping (URL) -> Void = { _ in }
    ) {
        _isFullScreen = State(initialValue: configuration.isFullScreen)

        self.sourceVideoURL = sourceVideoURL
        self.onExported = onExported
    }

}

extension VideoEditorView {

    struct Configuration {

        // MARK: - Public Properties

        let isFullScreen: Bool

        // MARK: - Initializer

        init(isFullScreen: Bool = false) {
            self.isFullScreen = isFullScreen
        }

    }

}

#Preview {
    NavigationStack {
        VideoEditorView()
    }
}
