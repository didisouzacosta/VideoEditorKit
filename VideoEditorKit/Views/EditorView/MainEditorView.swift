//
//  MainEditorView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//
import AVKit
import SwiftUI
import PhotosUI
import Observation

@MainActor
struct MainEditorView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    let project: ProjectEntity?
    let selectedVideoURl: URL?
    @State private var isFullScreen = false
    @State private var showVideoQualitySheet = false
    @State private var showRecordView = false
    @State private var exportSheetTask: Task<Void, Never>?
    @State private var filterRestoreTask: Task<Void, Never>?
    @State private var editorVM = EditorViewModel()
    @State private var audioRecorder = AudioRecorderManager()
    @State private var videoPlayer = VideoPlayerManager()
    @State private var textEditor = TextEditorViewModel()

    init(project: ProjectEntity? = nil, selectedVideoURl: URL? = nil) {
        self.project = project
        self.selectedVideoURl = selectedVideoURl
    }

    var body: some View {
        ZStack{
            GeometryReader { proxy in
                VStack(spacing: 0){
                    headerView
                    PlayerHolderView(isFullScreen: $isFullScreen, editorVM: editorVM, videoPlayer: videoPlayer, textEditor: textEditor)
                        .frame(height: proxy.size.height / (isFullScreen ?  1.25 : 1.8))
                    PlayerControl(isFullScreen: $isFullScreen, recorderManager: audioRecorder, editorVM: editorVM, videoPlayer: videoPlayer, textEditor: textEditor)
                    ToolsSectionView(videoPlayer: videoPlayer, editorVM: editorVM, textEditor: textEditor)
                        .opacity(isFullScreen ? 0 : 1)
                        .padding(.top, 5)
                }
                .onAppear{
                    setVideo(proxy)
                }
            }
            
            if showVideoQualitySheet, let video = editorVM.currentVideo{
                VideoExporterBottomSheetView(isPresented: $showVideoQualitySheet, video: video)
            }
        }
        .background(.black)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.all, edges: .top)
        .fullScreenCover(isPresented: $showRecordView) {
            RecordVideoView{ url in
                videoPlayer.loadState = .loaded(url)
            }
        }
        .statusBar(hidden: true)
        .onChange(of: scenePhase) { _, phase in
            saveProject(phase)
        }
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
        HStack{
            Button {
                editorVM.updateProject()
                dismiss()
            } label: {
                Image(systemName: "folder.fill")
            }

            Spacer()
            
            Button {
                presentExporter()
            } label: {
                Image(systemName: "square.and.arrow.up.fill")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(height: 50)
        .padding(.bottom)
    }
    
    private func saveProject(_ phase: ScenePhase){
        switch phase{
        case .background, .inactive:
            editorVM.updateProject()
        default:
            break
        }
    }
    
    private func setVideo(_ proxy: GeometryProxy){
        if let selectedVideoURl{
            videoPlayer.loadState = .loaded(selectedVideoURl)
            editorVM.setNewVideo(selectedVideoURl, containerSize: proxy.size)
        }
        
        if let project, let url = project.videoURL{
            videoPlayer.loadState = .loaded(url)
            editorVM.setProject(project, containerSize: proxy.size)
            scheduleFilterRestore(project)
        }
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

    private func scheduleFilterRestore(_ project: ProjectEntity) {
        filterRestoreTask?.cancel()
        filterRestoreTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            videoPlayer.setFilters(
                mainFilter: project.filterName.flatMap(CIFilter.init(name:)),
                colorCorrection: editorVM.currentVideo?.colorCorrection
            )
        }
    }

    private func cancelDeferredTasks() {
        exportSheetTask?.cancel()
        filterRestoreTask?.cancel()
        exportSheetTask = nil
        filterRestoreTask = nil
    }
}

#Preview {
    MainEditorView(project: nil, selectedVideoURl: nil)
        .preferredColorScheme(.dark)
}
