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

    private let exportQualities: [ExportQualityAvailability]
    private let onBlockedQualityTap: (VideoQuality) -> Void
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
                    qualities: exportQualities,
                    selectedQuality: viewModel.selectedQuality,
                    estimatedVideoSizeText: viewModel.estimatedVideoSizeText(for:),
                    showsFailureMessage: viewModel.shouldShowFailureMessage,
                    errorMessage: viewModel.errorMessage,
                    actionTitle: viewModel.exportActionTitle,
                    canExportVideo: viewModel.canExportVideo,
                    onSelectQuality: viewModel.selectQuality(_:),
                    onBlockedQualityTap: onBlockedQualityTap,
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

    let qualities: [ExportQualityAvailability]
    let selectedQuality: VideoQuality
    let estimatedVideoSizeText: (VideoQuality) -> String?
    let showsFailureMessage: Bool
    let errorMessage: String
    let actionTitle: String
    let canExportVideo: Bool
    let onSelectQuality: (VideoQuality) -> Void
    let onBlockedQualityTap: (VideoQuality) -> Void
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
                    ForEach(qualities) { availability in
                        ExportQualityOptionRow(
                            quality: availability.quality,
                            estimatedSizeText: estimatedVideoSizeText(availability.quality),
                            isSelected: availability.quality == selectedQuality,
                            isBlocked: availability.isBlocked,
                            onTap: {
                                if availability.isBlocked {
                                    onBlockedQualityTap(availability.quality)
                                } else {
                                    onSelectQuality(availability.quality)
                                }
                            }
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
    let isBlocked: Bool
    let onTap: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(quality.title)
                            .font(.headline)

                        if isBlocked {
                            PremiumQualityBadge()
                        }
                    }

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

                    Image(systemName: trailingSymbolName)
                        .font(.headline)
                        .foregroundStyle(trailingSymbolTint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .opacity(isBlocked ? 0.55 : 1)
            .contentShape(.rect(cornerRadius: 16))
            .card(
                cornerRadius: 16,
                prominent: isSelected && !isBlocked,
                tint: rowTint
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    // MARK: - Private Properties

    private var trailingSymbolName: String {
        if isBlocked {
            "lock.fill"
        } else if isSelected {
            "checkmark.circle.fill"
        } else {
            "circle"
        }
    }

    private var trailingSymbolTint: Color {
        if isBlocked {
            Theme.secondary
        } else if isSelected {
            Theme.primary
        } else {
            Theme.secondary
        }
    }

    private var rowTint: Color {
        isBlocked ? Theme.secondary : (isSelected ? Theme.accent : Theme.secondary)
    }

    private var accessibilityLabel: String {
        isBlocked ? "\(quality.title), premium" : quality.title
    }

    private var accessibilityValue: String {
        if isBlocked {
            "Locked"
        } else if isSelected {
            "Selected"
        } else {
            "Available"
        }
    }

    private var accessibilityHint: String {
        isBlocked
            ? "Double-tap to learn how to unlock this export quality."
            : "Double-tap to select this export quality."
    }

    private var accessibilityIdentifier: String {
        "export-quality-\(quality.rawValue)"
    }

}

private struct PremiumQualityBadge: View {

    // MARK: - Body

    var body: some View {
        Text("Premium")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.rootBackground.opacity(0.95))
            )
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
