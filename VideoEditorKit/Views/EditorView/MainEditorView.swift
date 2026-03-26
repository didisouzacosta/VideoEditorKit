//
//  MainEditorView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//
import AVKit
import SwiftUI

@MainActor
struct MainEditorView: View {

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - States

    @State private var isFullScreen = false
    @State private var editorVM = EditorViewModel()
    @State private var audioRecorder = AudioRecorderManager()
    @State private var videoPlayer = VideoPlayerManager()
    @State private var textEditor = TextEditorViewModel()

    // MARK: - Private Properties

    private let sourceVideoURL: URL?
    private let onExported: (URL) -> Void

    // MARK: - Body

    var body: some View {
        @Bindable var bindableEditorVM = editorVM
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 32) {
                    PlayerHolderView(
                        $isFullScreen,
                        editorVM: editorVM,
                        videoPlayer: videoPlayer,
                        textEditor: textEditor
                    )

                    PlayerControl(
                        $isFullScreen,
                        editorVM: editorVM,
                        videoPlayer: videoPlayer,
                        recorderManager: audioRecorder,
                        textEditor: textEditor
                    )

                    if !isFullScreen {
                        ToolsSectionView(
                            videoPlayer,
                            editorVM: editorVM,
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
                            editorVM.presentExporter()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up.fill")
                        }
                    }
                }
                .onAppear {
                    editorVM.setSourceVideoIfNeeded(
                        sourceVideoURL,
                        availableSize: proxy.size,
                        isFullScreen: isFullScreen,
                        videoPlayer: videoPlayer
                    )
                }
            }

            if let video = editorVM.exportVideo {
                VideoExporterBottomSheetView($bindableEditorVM.showVideoQualitySheet, video: video) {
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
                TextEditorView(textEditor, onSave: editorVM.setText)
            }
        }
        .onDisappear(perform: editorVM.cancelDeferredTasks)
        .fullScreenCover(isPresented: $bindableEditorVM.showRecordView) {
            RecordVideoView { url in
                editorVM.handleRecordedVideo(url, videoPlayer: videoPlayer)
            }
        }
    }

    // MARK: - Initializer

    init(_ sourceVideoURL: URL? = nil, onExported: @escaping (URL) -> Void = { _ in }) {
        self.sourceVideoURL = sourceVideoURL
        self.onExported = onExported
    }

}

#Preview {
    NavigationStack {
        MainEditorView()
    }
}
