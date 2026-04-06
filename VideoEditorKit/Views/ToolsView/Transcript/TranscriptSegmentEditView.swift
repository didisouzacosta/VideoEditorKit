//
//  TranscriptSegmentEditView.swift
//  VideoEditorKit
//
//  Created by Codex on 06.04.2026.
//

import SwiftUI

@MainActor
struct TranscriptSegmentEditView: View {

    // MARK: - States

    @State private var editedText: String

    // MARK: - Public Properties

    let segment: EditableTranscriptSegment
    let onUpdateText: (String) -> Void

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(segmentTimeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondary)

                TextField(
                    "Transcript segment",
                    text: $editedText,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...10)
                .onChange(of: editedText) { _, newValue in
                    onUpdateText(newValue)
                }

                if segment.originalText != editedText {
                    Text("Original: \(segment.originalText)")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Edit Segment")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Initializer

    init(
        _ segment: EditableTranscriptSegment,
        onUpdateText: @escaping (String) -> Void
    ) {
        self.segment = segment
        self.onUpdateText = onUpdateText

        _editedText = State(initialValue: segment.editedText)
    }

    // MARK: - Private Properties

    private var segmentTimeLabel: String {
        "\(formattedTime(segment.timeMapping.sourceStartTime)) - \(formattedTime(segment.timeMapping.sourceEndTime))"
    }

    // MARK: - Private Methods

    private func formattedTime(_ value: Double) -> String {
        value.formatterTimeString()
    }

}
