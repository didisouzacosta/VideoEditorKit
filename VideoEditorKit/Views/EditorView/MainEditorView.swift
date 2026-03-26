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
    @State private var showVideoQualitySheet = false
    @State private var showRecordView = false
    @State private var exportSheetTask: Task<Void, Never>?
    @State private var hasLoadedSourceVideo = false
    @State private var editorVM = EditorViewModel()
    @State private var audioRecorder = AudioRecorderManager()
    @State private var videoPlayer = VideoPlayerManager()
    @State private var textEditor = TextEditorViewModel()

    // MARK: - Public Properties

    let sourceVideoURL: URL?
    let onExported: (URL) -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 32) {
                    PlayerHolderView(
                        isFullScreen: $isFullScreen,
                        editorVM: editorVM,
                        videoPlayer: videoPlayer,
                        textEditor: textEditor
                    )

                    PlayerControl(
                        editorVM: editorVM,
                        videoPlayer: videoPlayer,
                        isFullScreen: $isFullScreen,
                        recorderManager: audioRecorder,
                        textEditor: textEditor
                    )

                    if !isFullScreen {
                        ToolsSectionView(
                            videoPlayer: videoPlayer,
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
                            presentExporter()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up.fill")
                        }
                    }
                }
                .onAppear {
                    setVideoIfNeeded(proxy.size)
                }
            }

            if showVideoQualitySheet, let video = editorVM.currentVideo {
                VideoExporterBottomSheetView(isPresented: $showVideoQualitySheet, video: video) {
                    exportedURL in
                    videoPlayer.pause()
                    onExported(exportedURL)
                    dismiss()
                }
            }
        }
        .blur(radius: textEditor.showEditor ? 10 : 0)
        .overlay {
            if textEditor.showEditor {
                TextEditorView(viewModel: textEditor, onSave: editorVM.setText)
            }
        }
        .fullScreenCover(isPresented: $showRecordView) {
            RecordVideoView { url in
                videoPlayer.loadState = .loaded(url)
            }
        }
        .onDisappear {
            cancelDeferredTasks()
        }
    }

    // MARK: - Initializer

    init(sourceVideoURL: URL? = nil, onExported: @escaping (URL) -> Void = { _ in }) {
        self.sourceVideoURL = sourceVideoURL
        self.onExported = onExported
    }

}

extension MainEditorView {

    // MARK: - Private Methods

    private func setVideoIfNeeded(_ availableSize: CGSize) {
        guard !hasLoadedSourceVideo, let sourceVideoURL else { return }
        hasLoadedSourceVideo = true
        videoPlayer.loadState = .loaded(sourceVideoURL)
        editorVM.setNewVideo(sourceVideoURL, containerSize: playerContainerSize(in: availableSize))
    }

    private func playerHeight(in availableSize: CGSize) -> CGFloat {
        let heightRatio = isFullScreen ? 0.62 : 0.40
        let proposedHeight = availableSize.height * heightRatio
        return max(220, proposedHeight)
    }

    private func playerContainerSize(in availableSize: CGSize) -> CGSize {
        CGSize(
            width: max(availableSize.width - 32, 1),
            height: playerHeight(in: availableSize)
        )
    }

    private func presentExporter() {
        exportSheetTask?.cancel()
        editorVM.selectedTools = nil
        exportSheetTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            showVideoQualitySheet.toggle()
        }
    }

    private func cancelDeferredTasks() {
        exportSheetTask?.cancel()
        exportSheetTask = nil
    }

}

#Preview {
    NavigationStack {
        MainEditorView()
    }
}
