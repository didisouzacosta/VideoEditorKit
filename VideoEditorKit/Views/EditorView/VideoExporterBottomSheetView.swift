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

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - States

    @State private var selectedDetent: PresentationDetent = .height(420)
    @State private var viewModel: ExporterViewModel

    // MARK: - Private Properties

    private let onExported: (URL) -> Void

    // MARK: - Body

    var body: some View {
        @Bindable var bindableViewModel = viewModel
        VStack(alignment: .leading) {
            if viewModel.shouldShowLoadingView {
                loadingView
            } else {
                list
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 28)
        .disabled(viewModel.isInteractionDisabled)
        .animation(.easeInOut, value: viewModel.renderState)
        .presentationDetents(detents, selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .presentationCornerRadius(32)
        .onChange(of: viewModel.renderState) { _, newValue in
            updateSelectedDetent(for: newValue)
        }
        .alert("Unable to export video", isPresented: $bindableViewModel.showAlert) {}
    }

    // MARK: - Initializer

    init(video: Video, onExported: @escaping (URL) -> Void) {
        _selectedDetent = State(initialValue: .height(420))
        _viewModel = State(initialValue: ExporterViewModel(video))

        self.onExported = onExported
    }

}

extension VideoExporterBottomSheetView {

    // MARK: - Private Properties

    private var detents: Set<PresentationDetent> {
        if viewModel.shouldShowLoadingView {
            [.medium, .large]
        } else {
            [.height(420), .medium]
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Export Video")
                .font(.title3.bold())

            Text("Choose the output quality for the rendered file.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)

            qualityListSection

            if viewModel.shouldShowFailureMessage {
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
                    viewModel.selectQuality(type)
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
                            if let value = viewModel.estimatedVideoSizeText(for: type) {
                                Text(value)
                                    .font(.subheadline.weight(.semibold))
                            }

                            Image(
                                systemName: viewModel.isSelectedQuality(type) ? "checkmark.circle.fill" : "circle"
                            )
                            .font(.headline)
                            .foregroundStyle(
                                viewModel.isSelectedQuality(type)
                                    ? Theme.primary : Theme.secondary
                            )
                        }
                    }
                    .padding(14)
                    .card(
                        cornerRadius: 22,
                        prominent: viewModel.isSelectedQuality(type),
                        tint: viewModel.isSelectedQuality(type) ? Theme.accent : Theme.secondary
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var exportButton: some View {
        Button {
            viewModel.exportVideo(handleExportedVideo)
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

    private func handleExportedVideo(_ url: URL) {
        dismiss()
        onExported(url)
    }

    private func updateSelectedDetent(for state: ExporterViewModel.ExportState) {
        switch state {
        case .loading, .loaded:
            selectedDetent = .medium
        case .unknown, .failed:
            selectedDetent = .height(420)
        }
    }

}

#Preview {
    NavigationStack {
        VideoExporterBottomSheetView(video: Video.mock) { _ in }
    }
}
