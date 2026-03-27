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

                    PlayerControl(
                        editorViewModel,
                        videoPlayer: videoPlayer,
                        recorderManager: audioRecorder,
                        textEditor: textEditor
                    )

                    ToolsSectionView(
                        videoPlayer,
                        editorVM: editorViewModel,
                        textEditor: textEditor
                    )
                }
                .safeAreaPadding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Export") {
                            editorViewModel.presentExporter()
                        }
                    }
                }
                .onAppear {
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
        .sheet(isPresented: $bindableEditorViewModel.showVideoQualitySheet) {
            if let video = editorViewModel.currentVideo {
                VideoExporterBottomSheetView(video: video) { exportedURL in
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
    }

    // MARK: - Initializer

    init(
        _ sourceVideoURL: URL? = nil,
        configuration: Configuration = .init(),
        onExported: @escaping (URL) -> Void = { _ in }
    ) {
        self.sourceVideoURL = sourceVideoURL
        self.onExported = onExported
    }

}

extension VideoEditorView {

    struct Configuration {

        // MARK: - Public Properties

        // MARK: - Initializer

        init() {}

    }

}

#Preview {
    NavigationStack {
        VideoEditorView()
    }
}
