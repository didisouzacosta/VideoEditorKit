//
//  TranscriptToolView.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import SwiftUI

struct TranscriptToolView: View {

    // MARK: - States

    @State private var selectedSegment: EditableTranscriptSegment?

    // MARK: - Public Properties

    let isTranscriptionAvailable: Bool
    let transcriptState: TranscriptFeatureState
    let document: TranscriptDocument?
    let onTranscribe: () -> Void
    let onRetry: () -> Void
    let onCopyTranscript: (String) -> Void
    let onUpdateSegmentText: (UUID, String) -> Void
    let onRevertSegmentText: (UUID) -> Void
    let onUpdatePosition: (TranscriptOverlayPosition) -> Void
    let onUpdateSize: (TranscriptOverlaySize) -> Void

    // MARK: - Body

    var body: some View {
        content
            .navigationDestination(item: $selectedSegment) { segment in
                segmentEditorDestination(segment)
            }
            .onChange(of: document?.segments.map(\.id)) { _, segmentIDs in
                guard let selectedSegment else { return }
                guard segmentIDs?.contains(selectedSegment.id) != true else { return }

                self.selectedSegment = nil
            }
    }

    // MARK: - Private Properties

    @ViewBuilder
    private var content: some View {
        switch transcriptState {
        case .idle:
            idleView
                .safeAreaPadding(.horizontal, 32)
        case .loading:
            loadingView
                .safeAreaPadding(.horizontal, 32)
        case .loaded:
            loadedView
        case .failed(let error):
            failureView(for: error)
                .safeAreaPadding(.horizontal, 32)
        }
    }

    private var idleView: some View {
        if isTranscriptionAvailable {
            statusView(
                title: VideoEditorStrings.transcriptCreateTitle,
                message: VideoEditorStrings.transcriptCreateMessage,
                actionTitle: VideoEditorStrings.transcriptRetry,
                action: onTranscribe
            )
        } else {
            statusView(
                title: VideoEditorStrings.transcriptUnavailableTitle,
                message: VideoEditorStrings.transcriptUnavailableMessage
            )
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()

            Text(VideoEditorStrings.transcriptLoadingTitle)
                .font(.headline)

            Text(VideoEditorStrings.transcriptLoadingMessage)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private var loadedView: some View {
        if let document, !document.segments.isEmpty {
            List {
                Section(VideoEditorStrings.transcriptLayoutSection) {
                    styleSection
                }

                Section {
                    ForEach(document.segments) { segment in
                        Button {
                            selectedSegment = segment
                        } label: {
                            TranscriptSegmentRow(segment: segment)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    transcriptionSectionHeader(document)
                }
            }
            .listRowSpacing(8)
        } else {
            statusView(
                title: VideoEditorStrings.transcriptNoneTitle,
                message: VideoEditorStrings.transcriptNoneMessage,
                actionTitle: VideoEditorStrings.transcriptRetry,
                action: onTranscribe
            )
        }
    }

    // MARK: - Private Methods

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            positionPicker
            sizePicker
        }
    }

    private var positionPicker: some View {
        HStack {
            Text(VideoEditorStrings.transcriptPosition)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)

            Spacer()

            Picker(VideoEditorStrings.transcriptPosition, selection: positionSelection) {
                Text(VideoEditorStrings.transcriptPositionTop).tag(TranscriptOverlayPosition.top)
                Text(VideoEditorStrings.transcriptPositionCenter).tag(TranscriptOverlayPosition.center)
                Text(VideoEditorStrings.transcriptPositionBottom).tag(TranscriptOverlayPosition.bottom)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }

    private var sizePicker: some View {
        HStack {
            Text(VideoEditorStrings.transcriptSize)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)

            Spacer()

            Picker(VideoEditorStrings.transcriptSize, selection: sizeSelection) {
                Text(VideoEditorStrings.transcriptSizeSmall).tag(TranscriptOverlaySize.small)
                Text(VideoEditorStrings.transcriptSizeMedium).tag(TranscriptOverlaySize.medium)
                Text(VideoEditorStrings.transcriptSizeLarge).tag(TranscriptOverlaySize.large)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }

    private func transcriptionSectionHeader(
        _ document: TranscriptDocument
    ) -> some View {
        HStack {
            Text(VideoEditorStrings.transcriptSectionTitle)

            Spacer()

            Button {
                onCopyTranscript(document.plainText)
            } label: {
                Label(VideoEditorStrings.copy, systemImage: "doc.on.doc")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
            .disabled(document.hasCopyableText == false)
        }
    }

    private var positionSelection: Binding<TranscriptOverlayPosition> {
        Binding(
            get: { document?.overlayPosition ?? .bottom },
            set: { onUpdatePosition($0) }
        )
    }

    private var sizeSelection: Binding<TranscriptOverlaySize> {
        Binding(
            get: { document?.overlaySize ?? .medium },
            set: { onUpdateSize($0) }
        )
    }

    private func failureView(for error: TranscriptError) -> some View {
        if isNonRetryable(error) {
            statusView(
                title: VideoEditorStrings.transcriptUnavailableTitle,
                message: errorMessage(for: error)
            )
        } else {
            statusView(
                title: VideoEditorStrings.transcriptUnableToTranscribeTitle,
                message: errorMessage(for: error),
                actionTitle: VideoEditorStrings.transcriptRetryFailure,
                action: onRetry
            )
        }
    }

    private func segmentEditorDestination(
        _ segment: EditableTranscriptSegment
    ) -> some View {
        TranscriptSegmentEditView(
            segment,
            onUpdateText: { newText in
                onUpdateSegmentText(segment.id, newText)
            },
            onRevertText: {
                onRevertSegmentText(segment.id)
            }
        )
    }

    private func statusView(
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    private func errorMessage(for error: TranscriptError) -> String {
        switch error {
        case .providerNotConfigured:
            VideoEditorStrings.transcriptUnavailableMessage
        case .unavailable(let message):
            message
        case .invalidVideoSource:
            VideoEditorStrings.transcriptProviderInvalidSource
        case .emptyResult:
            VideoEditorStrings.transcriptProviderEmptyResult
        case .cancelled:
            VideoEditorStrings.transcriptProviderCancelled
        case .providerFailure(let message):
            message
        }
    }

    private func isNonRetryable(_ error: TranscriptError) -> Bool {
        switch error {
        case .providerNotConfigured, .unavailable:
            true
        case .invalidVideoSource, .emptyResult, .cancelled, .providerFailure:
            false
        }
    }

}

#Preview("Idle") {
    NavigationStack {
        TranscriptToolView(
            isTranscriptionAvailable: true,
            transcriptState: .idle,
            document: nil,
            onTranscribe: {},
            onRetry: {},
            onCopyTranscript: { _ in },
            onUpdateSegmentText: { _, _ in },
            onRevertSegmentText: { _ in },
            onUpdatePosition: { _ in },
            onUpdateSize: { _ in }
        )
    }
}

#Preview("Loading") {
    NavigationStack {
        TranscriptToolView(
            isTranscriptionAvailable: true,
            transcriptState: .loading,
            document: nil,
            onTranscribe: {},
            onRetry: {},
            onCopyTranscript: { _ in },
            onUpdateSegmentText: { _, _ in },
            onRevertSegmentText: { _ in },
            onUpdatePosition: { _ in },
            onUpdateSize: { _ in }
        )
    }
}
