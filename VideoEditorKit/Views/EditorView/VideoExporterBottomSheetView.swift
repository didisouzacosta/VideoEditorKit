//
//  VideoExporterBottomSheetView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import Observation

@MainActor
struct VideoExporterBottomSheetView: View {
    @Binding var isPresented: Bool
    @State private var viewModel: ExporterViewModel
    let onExported: (URL) -> Void
    
    init(isPresented: Binding<Bool>, video: Video, onExported: @escaping (URL) -> Void) {
        self._isPresented = isPresented
        self._viewModel = State(initialValue: ExporterViewModel(video: video))
        self.onExported = onExported
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel
        GeometryReader { proxy in
            SheetView(isPresented: $isPresented, bgOpacity: 0.1) {
                VStack(alignment: .leading) {
                    switch viewModel.renderState {
                    case .unknown, .failed:
                        list
                    case .loading, .loaded:
                        loadingView
                    }
                }
                .hCenter()
                .frame(height: proxy.size.height / 2.8)
            }
            .ignoresSafeArea()
            .alert("Unable to export video", isPresented: $bindableViewModel.showAlert) {}
            .disabled(viewModel.renderState == .loading)
            .animation(.easeInOut, value: viewModel.renderState)
        }
    }
}

extension VideoExporterBottomSheetView{
    
    
    private var list: some View{
        Group{
            qualityListSection

            if case .failed = viewModel.renderState {
                Text("The video could not be exported. Check the current edit state and try again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            exportButton
                .padding(.top, 14)
        }
    }
    
    private var loadingView: some View{
        VStack(spacing: 30){
            ProgressView()
                .scaleEffect(2)
            Text(viewModel.progressTimer.formatted())
            Text("Video export in progress")
                .font(.headline)
            Text("The edited video will be returned to the example screen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var qualityListSection: some View{
        ForEach(VideoQuality.allCases.reversed(), id: \.self) { type in
            
            HStack{
                VStack(alignment: .leading) {
                    Text(type.title)
                        .font(.headline)
                    Text(type.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let value = type.calculateVideoSize(duration: viewModel.video.totalDuration){
                    Text("\(value.formatted(.number.precision(.fractionLength(1))))Mb")
                }
            }
            .padding(10)
            .hLeading()
            .background{
                if viewModel.selectedQuality == type{
                    RoundedRectangle(cornerRadius: 10)
                        .fill( Color(.systemGray5))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectedQuality = type
            }
        }
    }
    
    
    private var exportButton: some View{
        Button {
            mainAction()
        } label: {
            buttonLabel("Export Video", icon: "wand.and.stars")
        }
        .hCenter()
    }
    
    private func buttonLabel(_ label: String, icon: String) -> some View{
        
        HStack(spacing: 12){
            Image(systemName: icon)
                .imageScale(.large)
                .padding(10)
                .background(Color(.systemGray), in: Circle())
            Text(label)
                .font(.headline)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color(.systemGray6), in: .rect(cornerRadius: 16))
        .foregroundStyle(.primary)
    }
    
    
    private func mainAction() {
        Task {
            guard let url = await viewModel.export() else { return }
            isPresented = false
            onExported(url)
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.secondary.opacity(0.5)
        VideoExporterBottomSheetView(isPresented: .constant(true), video: Video.mock) { _ in }
    }
}
