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

    private let onExported: (ExportedVideo) -> Void

    // MARK: - Body

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        navigationContent
            .interactiveDismissDisabled(viewModel.isInteractionDisabled)
            .alert(
                "Unable to export video",
                isPresented: $bindableViewModel.showAlert
            ) {
                Button("Try Again", action: retryExport)
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
    }

    // MARK: - Initializer

    init(
        video: Video,
        editingConfiguration: VideoEditingConfiguration,
        onExported: @escaping (ExportedVideo) -> Void
    ) {
        _viewModel = State(
            initialValue: ExporterViewModel(
                video,
                editingConfiguration: editingConfiguration
            )
        )

        self.onExported = onExported
    }

    // MARK: - Private Properties

    private var navigationContent: some View {
        content
            .navigationTitle("Export Video")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut, value: viewModel.renderState)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: dismissView)
                        .disabled(viewModel.isInteractionDisabled)
                }
            }
    }

    private var content: some View {
        VStack(alignment: .leading) {
            if viewModel.shouldShowLoadingView {
                ExportProgressSection(
                    progress: viewModel.exportProgress,
                    progressText: viewModel.progressText,
                    canCancelExport: viewModel.canCancelExport,
                    onCancel: viewModel.cancelExport
                )
            } else {
                ExportQualitySelectionSection(
                    selectedQuality: viewModel.selectedQuality,
                    estimatedVideoSizeText: viewModel.estimatedVideoSizeText(for:),
                    showsFailureMessage: viewModel.shouldShowFailureMessage,
                    errorMessage: viewModel.errorMessage,
                    actionTitle: viewModel.exportActionTitle,
                    canExportVideo: viewModel.canExportVideo,
                    onSelectQuality: viewModel.selectQuality(_:),
                    onExport: exportVideo
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    // MARK: - Private Methods

    private func exportVideo() {
        viewModel.exportVideo(handleExportedVideo)
    }

    private func retryExport() {
        viewModel.retryExport(handleExportedVideo)
    }

    private func dismissView() {
        guard !viewModel.isInteractionDisabled else { return }
        dismiss()
    }

    private func handleExportedVideo(_ video: ExportedVideo) {
        dismiss()
        onExported(video)
    }

}

private struct ExportQualitySelectionSection: View {

    // MARK: - Public Properties

    let selectedQuality: VideoQuality
    let estimatedVideoSizeText: (VideoQuality) -> String?
    let showsFailureMessage: Bool
    let errorMessage: String
    let actionTitle: String
    let canExportVideo: Bool
    let onSelectQuality: (VideoQuality) -> Void
    let onExport: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose the output quality for the rendered file.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal)

                VStack(spacing: 8) {
                    ForEach(VideoQuality.allCases.reversed(), id: \.self) { quality in
                        ExportQualityOptionRow(
                            quality: quality,
                            estimatedSizeText: estimatedVideoSizeText(quality),
                            isSelected: quality == selectedQuality,
                            onTap: { onSelectQuality(quality) }
                        )
                    }
                }

                if showsFailureMessage {
                    ExportFailureMessageCard(message: errorMessage)
                }
            }

            Button(action: onExport) {
                Text(actionTitle)
                    .font(.headline.weight(.bold))
                    .padding()
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
            .disabled(!canExportVideo)
        }
    }

}

private struct ExportQualityOptionRow: View {

    // MARK: - Public Properties

    let quality: VideoQuality
    let estimatedSizeText: String?
    let isSelected: Bool
    let onTap: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quality.title)
                        .font(.headline)
                    Text(quality.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let estimatedSizeText {
                        Text(estimatedSizeText)
                            .font(.subheadline.weight(.semibold))
                    }

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.headline)
                        .foregroundStyle(isSelected ? Theme.primary : Theme.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .contentShape(.rect(cornerRadius: 16))
            .card(
                cornerRadius: 16,
                prominent: isSelected,
                tint: isSelected ? Theme.accent : Theme.secondary
            )
        }
        .buttonStyle(.plain)
    }

}

private struct ExportFailureMessageCard: View {

    // MARK: - Public Properties

    let message: String

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card(cornerRadius: 16, prominent: false, tint: .yellow)
    }

}

private struct ExportProgressSection: View {

    // MARK: - Public Properties

    let progress: Double
    let progressText: String
    let canCancelExport: Bool
    let onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: progress, total: 1)
                .tint(Theme.accent)

            Text(progressText)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .contentTransition(.numericText())

            Text("Video export in progress")
                .font(.headline)

            Text("Keep this sheet open while we prepare the final video.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)

            Button("Cancel", role: .cancel, action: onCancel)
                .buttonStyle(.glass)
                .disabled(!canCancelExport)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

}

#Preview {
    NavigationStack {
        VideoExporterView(
            video: Video.mock,
            editingConfiguration: .initial
        ) { _ in }
    }
}
