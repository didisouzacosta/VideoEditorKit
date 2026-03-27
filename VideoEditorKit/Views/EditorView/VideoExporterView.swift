//
//  VideoExporterView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Observation
import SwiftUI

@MainActor
struct VideoExporterView: View {

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - States

    @State private var viewModel: ExporterViewModel

    // MARK: - Private Properties

    private let onExported: (URL) -> Void

    // MARK: - Body

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        navigationContent
            .alert("Unable to export video", isPresented: $bindableViewModel.showAlert) {}
    }

    // MARK: - Initializer

    init(video: Video, onExported: @escaping (URL) -> Void) {
        _viewModel = State(initialValue: ExporterViewModel(video))

        self.onExported = onExported
    }

}

extension VideoExporterView {

    // MARK: - Private Properties

    private var navigationContent: some View {
        sheetContent
            .navigationTitle("Export Video")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut, value: viewModel.renderState)
            .disabled(viewModel.isInteractionDisabled)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .disabled(viewModel.isInteractionDisabled)
                }
            }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading) {
            if viewModel.shouldShowLoadingView {
                loadingView
            } else {
                list
            }
        }
        .padding()
    }

    private var list: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose the output quality for the rendered file.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal)

                qualityListSection

                if viewModel.shouldShowFailureMessage {
                    Text("The video could not be exported. Check the current edit state and try again.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }
            }

            Button {
                viewModel.exportVideo(handleExportedVideo)
            } label: {
                Text("Exportar")
                    .font(.headline.weight(.bold))
                    .padding()
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
            .disabled(!viewModel.canExportVideo)
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
        .frame(maxWidth: .infinity)
    }

    private var qualityListSection: some View {
        VStack(spacing: 8) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .contentShape(.rect(cornerRadius: 16))
                    .card(
                        cornerRadius: 16,
                        prominent: viewModel.isSelectedQuality(type),
                        tint: viewModel.isSelectedQuality(type) ? Theme.accent : Theme.secondary
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Private Methods

    private func handleExportedVideo(_ url: URL) {
        dismiss()
        onExported(url)
    }

}

#Preview {
    NavigationStack {
        VideoExporterView(video: Video.mock) { _ in }
    }
}
