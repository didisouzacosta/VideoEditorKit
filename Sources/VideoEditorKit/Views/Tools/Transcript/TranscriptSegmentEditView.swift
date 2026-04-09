#if os(iOS)
    //
    //  TranscriptSegmentEditView.swift
    //  VideoEditorKit
    //
    //  Created by Codex on 06.04.2026.
    //

    import SwiftUI

    struct TranscriptSegmentEditView: View {

        // MARK: - States

        @State private var editedText: String

        // MARK: - Public Properties

        let segment: EditableTranscriptSegment
        let onUpdateText: (String) -> Void
        let onRevertText: () -> Void

        // MARK: - Body

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(segmentTimeLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondary)

                    TextField(
                        "Transcript segment",
                        text: editedTextBinding,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...10)

                    if isShowingRevertButton {
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
            .toolbar {
                if isShowingRevertButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Revert") {
                            revertToOriginalText()
                        }
                    }
                }
            }
        }

        // MARK: - Initializer

        init(
            _ segment: EditableTranscriptSegment,
            onUpdateText: @escaping (String) -> Void,
            onRevertText: @escaping () -> Void
        ) {
            self.segment = segment
            self.onUpdateText = onUpdateText
            self.onRevertText = onRevertText

            _editedText = State(initialValue: segment.editedText)
        }

        // MARK: - Private Properties

        private var editedTextBinding: Binding<String> {
            Binding(
                get: { editedText },
                set: { newValue in
                    editedText = newValue
                    onUpdateText(newValue)
                }
            )
        }

        private var isShowingRevertButton: Bool {
            segment.originalText != editedText
        }

        private var segmentTimeLabel: String {
            "\(formattedTime(segment.timeMapping.sourceStartTime)) - \(formattedTime(segment.timeMapping.sourceEndTime))"
        }

        // MARK: - Private Methods

        private func revertToOriginalText() {
            guard isShowingRevertButton else { return }

            editedText = segment.originalText
            onRevertText()
        }

        private func formattedTime(_ value: Double) -> String {
            value.formatterTimeString()
        }

    }

    #Preview {
        NavigationStack {
            TranscriptSegmentEditView(
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: TranscriptTimeMapping(
                        sourceStartTime: 0,
                        sourceEndTime: 3.5
                    ),
                    originalText: "Original transcript text.",
                    editedText: "Edited transcript text."
                ),
                onUpdateText: { _ in },
                onRevertText: {}
            )
        }
    }

#endif
