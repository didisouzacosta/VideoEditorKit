//
//  VideoExporterBottomSheetView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Observation
import SwiftUI

@MainActor
struct VideoExporterBottomSheetView: View {

    // MARK: - Bindings

    @Binding private var isPresented: Bool

    // MARK: - States

    @State private var viewModel: ExporterViewModel

    // MARK: - Private Properties

    private let onExported: (URL) -> Void

    // MARK: - Body

    var body: some View {
        @Bindable var bindableViewModel = viewModel
        GeometryReader { proxy in
            SheetView($isPresented, bgOpacity: 0.1) {
                VStack(alignment: .leading) {
                    switch viewModel.renderState {
                    case .unknown, .failed:
                        list
                    case .loading, .loaded:
                        loadingView
                    }
                }
            }
            .safeAreaPadding()
            .disabled(viewModel.renderState == .loading)
            .animation(.easeInOut, value: viewModel.renderState)
            .alert("Unable to export video", isPresented: $bindableViewModel.showAlert) {}
        }
    }

    // MARK: - Initializer

    init(_ isPresented: Binding<Bool>, video: Video, onExported: @escaping (URL) -> Void) {
        _isPresented = isPresented
        _viewModel = State(initialValue: ExporterViewModel(video))

        self.onExported = onExported
    }

}

extension VideoExporterBottomSheetView {

    // MARK: - Private Properties

    private var list: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Export Video")
                .font(.title3.bold())

            Text("Choose the output quality for the rendered file.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)

            qualityListSection

            if case .failed = viewModel.renderState {
                Text("The video could not be exported. Check the current edit state and try again.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
            }

            exportButton.padding(.top, 4)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 22) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.accent)
            Text(viewModel.progressTimer.formatted())
                .font(.title.monospacedDigit())
            Text("Video export in progress")
                .font(.headline)
            Text("The edited video will be returned to the example screen.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var qualityListSection: some View {
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
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            if let value = type.calculateVideoSize(duration: viewModel.video.totalDuration) {
                                Text("\(value.formatted(.number.precision(.fractionLength(1))))Mb")
                                    .font(.subheadline.weight(.semibold))
                            }

                            Image(
                                systemName: viewModel.selectedQuality == type ? "checkmark.circle.fill" : "circle"
                            )
                            .font(.headline)
                            .foregroundStyle(
                                viewModel.selectedQuality == type
                                    ? Theme.primary : Theme.secondary
                            )
                        }
                    }
                    .padding(14)
                    .card(
                        cornerRadius: 22,
                        prominent: viewModel.selectedQuality == type,
                        tint: viewModel.selectedQuality == type ? Theme.accent : Theme.secondary
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var exportButton: some View {
        Button {
            mainAction()
        } label: {
            buttonLabel("Export Video", icon: "wand.and.stars")
        }
        .hCenter()
    }

    // MARK: - Private Methods

    private func buttonLabel(_ label: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
            Text(label)
                .font(.headline.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .capsuleControl(prominent: true, tint: Theme.accent)
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
            .ignoresSafeArea()
        VideoExporterBottomSheetView(.constant(true), video: Video.mock) { _ in }
    }
}
