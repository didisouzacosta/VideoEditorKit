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
        VStack(alignment: .leading, spacing: 18) {
            Text("Export Video")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("Choose the output quality for the rendered file.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))

            qualityListSection

            if case .failed = viewModel.renderState {
                Text("The video could not be exported. Check the current edit state and try again.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
            }

            exportButton.padding(.top, 4)
        }
    }
    
    private var loadingView: some View{
        VStack(spacing: 22){
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text(viewModel.progressTimer.formatted())
                .font(.title.monospacedDigit())
                .foregroundStyle(.white)
            Text("Video export in progress")
                .font(.headline)
                .foregroundStyle(.white)
            Text("The edited video will be returned to the example screen.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var qualityListSection: some View{
        VStack(spacing: 12) {
            ForEach(VideoQuality.allCases.reversed(), id: \.self) { type in
                Button {
                    viewModel.selectedQuality = type
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.title)
                                .font(.headline)
                            Text(type.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            if let value = type.calculateVideoSize(duration: viewModel.video.totalDuration){
                                Text("\(value.formatted(.number.precision(.fractionLength(1))))Mb")
                                    .font(.subheadline.weight(.semibold))
                            }

                            Image(systemName: viewModel.selectedQuality == type ? "checkmark.circle.fill" : "circle")
                                .font(.headline)
                                .foregroundStyle(viewModel.selectedQuality == type ? .white : .white.opacity(0.5))
                        }
                    }
                    .padding(14)
                    .foregroundStyle(.white)
                    .ios26Card(
                        cornerRadius: 22,
                        prominent: viewModel.selectedQuality == type,
                        tint: viewModel.selectedQuality == type ? IOS26Theme.accent : IOS26Theme.accentSecondary
                    )
                }
                .buttonStyle(.plain)
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
            Text(label)
                .font(.headline.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .foregroundStyle(.white)
        .ios26CapsuleControl(prominent: true, tint: IOS26Theme.accent)
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
