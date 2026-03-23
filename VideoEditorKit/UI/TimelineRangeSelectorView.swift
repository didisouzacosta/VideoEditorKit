import SwiftUI

struct TimelineRangeSelectorView: View {
    let snapshot: VideoEditorTimelineSnapshot
    let trackSize: CGSize
    let onRangeChange: (ClosedRange<Double>) -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.5)
                }
                .frame(width: selectedWidth, height: selectionHeight)
                .position(x: selectedMidX, y: trackSize.height / 2)

            handle(at: selectedMinX, isLeading: true)
            handle(at: selectedMaxX, isLeading: false)
        }
    }
}

private extension TimelineRangeSelectorView {
    var selectedMinX: CGFloat {
        trackSize.width * snapshot.selectionStartProgress
    }

    var selectedMaxX: CGFloat {
        trackSize.width * snapshot.selectionEndProgress
    }

    var selectedMidX: CGFloat {
        (selectedMinX + selectedMaxX) / 2
    }

    var selectedWidth: CGFloat {
        max(selectedMaxX - selectedMinX, handleSize.width)
    }

    var selectionHeight: CGFloat {
        max(trackSize.height - 18, 28)
    }

    var handleSize: CGSize {
        CGSize(width: 18, height: max(trackSize.height - 6, 30))
    }

    var accessibilityStep: Double {
        let validDuration = snapshot.validRange.upperBound - snapshot.validRange.lowerBound
        guard validDuration > 0 else {
            return 1
        }

        return 1 / validDuration
    }

    func handle(at xPosition: CGFloat, isLeading: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.92))
            .frame(width: handleSize.width, height: handleSize.height)
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
            }
            .position(x: xPosition, y: trackSize.height / 2)
            .contentShape(.rect)
            .highPriorityGesture(handleDragGesture(isLeading: isLeading))
            .accessibilityElement()
            .accessibilityLabel(isLeading ? "Range start" : "Range end")
            .accessibilityValue(timeText(isLeading ? snapshot.selectedRange.lowerBound : snapshot.selectedRange.upperBound))
            .accessibilityAdjustableAction { direction in
                let baseProgress = isLeading ? snapshot.selectionStartProgress : snapshot.selectionEndProgress
                let nextProgress = baseProgress + delta(for: direction)
                applyProgress(nextProgress, isLeading: isLeading)
            }
    }

    func handleDragGesture(isLeading: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard trackSize.width > 0 else {
                    return
                }

                let progress = Double(min(max(value.location.x / trackSize.width, 0), 1))
                applyProgress(progress, isLeading: isLeading)
            }
    }

    func applyProgress(_ progress: Double, isLeading: Bool) {
        let nextSelection = if isLeading {
            TimelineInteractionEngine.selectionByUpdatingLowerBound(
                progress: progress,
                currentSelection: snapshot.selectedRange,
                validRange: snapshot.validRange
            )
        } else {
            TimelineInteractionEngine.selectionByUpdatingUpperBound(
                progress: progress,
                currentSelection: snapshot.selectedRange,
                validRange: snapshot.validRange
            )
        }

        if nextSelection != snapshot.selectedRange {
            onRangeChange(nextSelection)
        }
    }

    func delta(for direction: AccessibilityAdjustmentDirection) -> Double {
        switch direction {
        case .increment:
            accessibilityStep
        case .decrement:
            -accessibilityStep
        @unknown default:
            0
        }
    }

    func timeText(_ value: Double) -> String {
        let duration = Duration.seconds(value)
        return duration.formatted(.time(pattern: .minuteSecond))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TimelineRangeSelectorView(
            snapshot: TimelineRangeSelectorPreviewData.snapshot,
            trackSize: CGSize(width: 320, height: 78),
            onRangeChange: { _ in }
        )
        .frame(width: 320, height: 78)
        .padding()
    }
}

private enum TimelineRangeSelectorPreviewData {
    static let snapshot = VideoEditorTimelineSnapshot(
        validRange: 0...60,
        selectedRange: 12...42,
        currentTime: 24,
        selectionStartProgress: 0.2,
        selectionEndProgress: 0.7,
        playheadProgress: 0.4,
        captions: [],
        validation: .init()
    )
}
