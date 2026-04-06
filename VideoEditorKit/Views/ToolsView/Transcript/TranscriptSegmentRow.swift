//
//  TranscriptSegmentRow.swift
//  VideoEditorKit
//
//  Created by Codex on 06.04.2026.
//

import SwiftUI

struct TranscriptSegmentRow: View {

    // MARK: - Public Properties

    let segment: EditableTranscriptSegment

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(segmentTimeLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondary)

            Text(segment.editedText)
                .font(.subheadline)
                .lineLimit(2)

            if segment.originalText != segment.editedText {
                Text("Edited")
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
            }
        }
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
