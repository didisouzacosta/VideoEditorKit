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
    @Environment(\.dismiss) private var dismiss
    let sourceVideoURL: URL?
    let onExported: (URL) -> Void
    @State private var isFullScreen = false
    @State private var showVideoQualitySheet = false
    @State private var showRecordView = false
    @State private var exportSheetTask: Task<Void, Never>?
    @State private var hasLoadedSourceVideo = false
    @State private var editorVM = EditorViewModel()
    @State private var audioRecorder = AudioRecorderManager()
    @State private var videoPlayer = VideoPlayerManager()
    @State private var textEditor = TextEditorViewModel()

    init(sourceVideoURL: URL? = nil, onExported: @escaping (URL) -> Void = { _ in }) {
        self.sourceVideoURL = sourceVideoURL
        self.onExported = onExported
    }

    var body: some View {
        ZStack {
            IOS26Theme.editorBackground
                .ignoresSafeArea()
            IOS26Theme.editorGlow
                .ignoresSafeArea()

            GeometryReader { proxy in
                VStack(spacing: 14) {
                    headerView
                    PlayerHolderView(isFullScreen: $isFullScreen, editorVM: editorVM, videoPlayer: videoPlayer, textEditor: textEditor)
                        .frame(height: proxy.size.height / (isFullScreen ? 1.25 : 1.85))
                        .padding(.horizontal, 16)
                    PlayerControl(isFullScreen: $isFullScreen, recorderManager: audioRecorder, editorVM: editorVM, videoPlayer: videoPlayer, textEditor: textEditor)
                        .padding(.horizontal, 16)
                    ToolsSectionView(videoPlayer: videoPlayer, editorVM: editorVM, textEditor: textEditor)
                        .opacity(isFullScreen ? 0 : 1)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
                .onAppear {
                    setVideoIfNeeded(proxy)
                }
            }

            if showVideoQualitySheet, let video = editorVM.currentVideo{
                VideoExporterBottomSheetView(isPresented: $showVideoQualitySheet, video: video) { exportedURL in
                    videoPlayer.pause()
                    onExported(exportedURL)
                    dismiss()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.all, edges: .top)
        .fullScreenCover(isPresented: $showRecordView) {
            RecordVideoView{ url in
                videoPlayer.loadState = .loaded(url)
            }
        }
        .statusBar(hidden: true)
        .onDisappear {
            cancelDeferredTasks()
        }
        .blur(radius: textEditor.showEditor ? 10 : 0)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay {
            if textEditor.showEditor{
                TextEditorView(viewModel: textEditor, onSave: editorVM.setText)
            }
        }
    }
}

extension MainEditorView{
    private var headerView: some View{
        HStack {
            Button {
                videoPlayer.pause()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(width: 46, height: 46)
                    .foregroundStyle(.white)
                    .ios26CircleControl()
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                presentExporter()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .ios26CapsuleControl(prominent: true, tint: IOS26Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .overlay {
            Text("Editor")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(.white.opacity(0.95))
                .ios26CapsuleControl(tint: IOS26Theme.accentSecondary)
        }
        .padding(.horizontal, 16)
    }

    private func setVideoIfNeeded(_ proxy: GeometryProxy){
        guard !hasLoadedSourceVideo, let sourceVideoURL else { return }
        hasLoadedSourceVideo = true
        videoPlayer.loadState = .loaded(sourceVideoURL)
        editorVM.setNewVideo(sourceVideoURL, containerSize: proxy.size)
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
    MainEditorView()
        .preferredColorScheme(.dark)
}
