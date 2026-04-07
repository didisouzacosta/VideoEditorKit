//
//  TranscriptToolView.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import SwiftUI

struct TranscriptToolView: View {

    // MARK: - States

    @State private var selectedSegmentID: UUID?

    // MARK: - Public Properties

    let isTranscriptionAvailable: Bool
    let transcriptState: TranscriptFeatureState
    let document: TranscriptDocument?
    let onTranscribe: () -> Void
    let onRetry: () -> Void
    let onUpdateSegmentText: (UUID, String) -> Void
    let onUpdatePosition: (TranscriptOverlayPosition) -> Void
    let onUpdateSize: (TranscriptOverlaySize) -> Void

    // MARK: - Body

    var body: some View {
        content
            .navigationDestination(isPresented: isShowingSegmentEditor) {
                segmentEditorDestination
            }
            .onChange(of: document?.segments.map(\.id)) { _, segmentIDs in
                guard let selectedSegmentID else { return }
                guard segmentIDs?.contains(selectedSegmentID) != true else { return }

                self.selectedSegmentID = nil
            }
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
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private var loadedView: some View {
        if let document, !document.segments.isEmpty {
            List {
                Section("Layout") {
                    styleSection(document)
                }

                Section("Transcription") {
                    ForEach(document.segments) { segment in
                        Button {
                            selectedSegmentID = segment.id
                        } label: {
                            TranscriptSegmentRow(segment: segment)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowSpacing(8)
        } else {
            statusView(
                title: "No transcript yet",
                message: "Run the transcription provider to populate timed segments for this video.",
                actionTitle: "Transcribe",
                action: onTranscribe
            )
        }
    }

    // MARK: - Private Methods

    private func styleSection(_ document: TranscriptDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            positionPicker(document)
            sizePicker(document)
        }
    }

    private func positionPicker(_ document: TranscriptDocument) -> some View {
        HStack {
            Text("Position")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)

            Spacer()

            Picker("Position", selection: positionSelection) {
                Text("Top").tag(TranscriptOverlayPosition.top)
                Text("Center").tag(TranscriptOverlayPosition.center)
                Text("Bottom").tag(TranscriptOverlayPosition.bottom)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }

    private func sizePicker(_ document: TranscriptDocument) -> some View {
        HStack {
            Text("Size")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)

            Spacer()

            Picker("Size", selection: sizeSelection) {
                Text("S").tag(TranscriptOverlaySize.small)
                Text("M").tag(TranscriptOverlaySize.medium)
                Text("L").tag(TranscriptOverlaySize.large)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 200)
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

    private var isShowingSegmentEditor: Binding<Bool> {
        Binding(
            get: { selectedSegmentID != nil },
            set: { isPresented in
                if !isPresented {
                    selectedSegmentID = nil
                }
            }
        )
    }

    @ViewBuilder
    private var segmentEditorDestination: some View {
        if let selectedSegmentID,
            let document,
            let segment = document.segments.first(where: { $0.id == selectedSegmentID })
        {
            TranscriptSegmentEditView(segment) { newText in
                onUpdateSegmentText(selectedSegmentID, newText)
            }
        } else {
            statusView(
                title: "Segment unavailable",
                message: "This transcript segment is no longer available."
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
