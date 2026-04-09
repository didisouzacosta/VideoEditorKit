//
//  VideoExporterContainerView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Observation
import SwiftUI

@MainActor
struct VideoExporterContainerView: View {

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - States

    @State private var viewModel: ExporterViewModel

    // MARK: - Private Properties

    private let exportQualities: [ExportQualityAvailability]
    private let onBlockedQualityTap: (VideoQuality) -> Void
    private let onExported: (ExportedVideo) -> Void

    // MARK: - Body

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        VideoExporterView(
            isAlertPresented: $bindableViewModel.showAlert,
            state: exportPresentationState,
            qualities: exportQualities,
            estimatedVideoSizeText: viewModel.estimatedVideoSizeText(for:),
            onSelectQuality: viewModel.selectQuality(_:),
            onBlockedQualityTap: onBlockedQualityTap,
            onExport: exportVideo,
            onRetry: retryExport,
            onCancelExport: viewModel.cancelExport,
            onClose: dismissView
        )
    }

    // MARK: - Initializer

    init(
        video: Video,
        editingConfiguration: VideoEditingConfiguration,
        exportQualities: [ExportQualityAvailability] = ExportQualityAvailability.allEnabled,
        onBlockedQualityTap: @escaping (VideoQuality) -> Void = { _ in },
        onExported: @escaping (ExportedVideo) -> Void
    ) {
        _viewModel = State(
            initialValue: ExporterViewModel(
                video,
                editingConfiguration: editingConfiguration,
                exportQualities: exportQualities
            )
        )

        self.exportQualities = exportQualities.sorted {
            if $0.order == $1.order {
                return $0.quality.rawValue < $1.quality.rawValue
            }

            return $0.order < $1.order
        }
        self.onBlockedQualityTap = onBlockedQualityTap
        self.onExported = onExported
    }

    // MARK: - Private Properties

    private var exportPresentationState: VideoExportPresentationState {
        .init(
            selectedQuality: viewModel.selectedQuality,
            exportProgress: viewModel.exportProgress,
            progressText: viewModel.progressText,
            errorMessage: viewModel.errorMessage,
            actionTitle: viewModel.exportActionTitle,
            isInteractionDisabled: viewModel.isInteractionDisabled,
            canExportVideo: viewModel.canExportVideo,
            canCancelExport: viewModel.canCancelExport,
            shouldShowLoadingView: viewModel.shouldShowLoadingView,
            shouldShowFailureMessage: viewModel.shouldShowFailureMessage
        )
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

#Preview {
    NavigationStack {
        VideoExporterContainerView(
            video: Video.mock,
            editingConfiguration: .initial
        ) { _ in }
    }
}
