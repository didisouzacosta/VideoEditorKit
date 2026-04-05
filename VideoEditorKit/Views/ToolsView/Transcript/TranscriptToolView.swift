//
//  TranscriptToolView.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import SwiftUI

@MainActor
struct TranscriptToolView: View {

    // MARK: - Public Properties

    let isTranscriptionAvailable: Bool
    let transcriptState: TranscriptFeatureState
    let document: TranscriptDocument?
    let onTranscribe: () -> Void
    let onRetry: () -> Void
    let onUpdateSegmentText: (UUID, String) -> Void
    let onUpdateSegmentStyle: (UUID, TranscriptStyle.StyleIdentifier?) -> Void

    // MARK: - Body

    var body: some View {
        content
    }

    // MARK: - Private Properties

    @ViewBuilder
    private var content: some View {
        switch transcriptState {
        case .idle:
            idleView
        case .loading:
            loadingView
        case .loaded:
            loadedView
        case .failed(let error):
            failureView(for: error)
        }
    }

    private var idleView: some View {
        if isTranscriptionAvailable {
            statusView(
                title: "Create a transcript",
                message: "Generate timed text from the current source video and edit it segment by segment.",
                actionTitle: "Transcribe",
                action: onTranscribe
            )
        } else {
            statusView(
                title: "Transcription unavailable",
                message: "No transcription provider is configured for this editor session."
            )
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()

            Text("Transcribing audio...")
                .font(.headline)

            Text("The transcript will appear here as soon as the provider returns the timed segments.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private var loadedView: some View {
        if let document, !document.segments.isEmpty {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(document.segments) { segment in
                        TranscriptSegmentCard(
                            segment: segment,
                            availableStyles: document.availableStyles,
                            onUpdateText: { onUpdateSegmentText(segment.id, $0) },
                            onUpdateStyle: { onUpdateSegmentStyle(segment.id, $0) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        } else {
            statusView(
                title: "No transcript yet",
                message: "Run the transcription provider to populate timed segments for this video.",
                actionTitle: "Transcribe",
                action: onTranscribe
            )
        }
    }

    private func failureView(for error: TranscriptError) -> some View {
        if error == .providerNotConfigured {
            statusView(
                title: "Transcription unavailable",
                message: errorMessage(for: error)
            )
        } else {
            statusView(
                title: "Unable to transcribe",
                message: errorMessage(for: error),
                actionTitle: "Try again",
                action: onRetry
            )
        }
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
            "No transcription provider is configured for this editor session."
        case .invalidVideoSource:
            "The current video source could not be used for transcription."
        case .emptyResult:
            "The transcription provider returned no timed segments."
        case .cancelled:
            "The transcription request was cancelled before it finished."
        case .providerFailure(let message):
            message
        }
    }

}

private struct TranscriptSegmentCard: View {

    // MARK: - Public Properties

    let segment: EditableTranscriptSegment
    let availableStyles: [TranscriptStyle]
    let onUpdateText: (String) -> Void
    let onUpdateStyle: (TranscriptStyle.StyleIdentifier?) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(segmentTimeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondary)

                Spacer(minLength: 0)

                if !availableStyles.isEmpty {
                    Picker("Style", selection: styleSelection) {
                        Text("Default").tag(nil as TranscriptStyle.StyleIdentifier?)

                        ForEach(availableStyles) { style in
                            Text(style.name)
                                .tag(style.id as TranscriptStyle.StyleIdentifier?)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            TextField(
                "Transcript segment",
                text: Binding(
                    get: { segment.editedText },
                    set: onUpdateText
                ),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...6)

            if segment.originalText != segment.editedText {
                Text("Original: \(segment.originalText)")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    // MARK: - Private Properties

    private var styleSelection: Binding<TranscriptStyle.StyleIdentifier?> {
        Binding(
            get: { segment.styleID },
            set: onUpdateStyle
        )
    }

    private var segmentTimeLabel: String {
        "\(formattedTime(segment.timeMapping.sourceStartTime)) - \(formattedTime(segment.timeMapping.sourceEndTime))"
    }

    // MARK: - Private Methods

    private func formattedTime(_ value: Double) -> String {
        value.formatterTimeString()
    }

}
