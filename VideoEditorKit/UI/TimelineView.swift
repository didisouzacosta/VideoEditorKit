import SwiftUI

struct TimelineView: View {
    let snapshot: VideoEditorTimelineSnapshot
    let isPlaying: Bool
    let onSeek: (Double) -> Void
    let onTogglePlayback: () -> Void
    let onSelectedRangeChange: (ClosedRange<Double>) -> Void

    var body: some View {
        VStack(spacing: 14) {
            TimelineHeader(
                snapshot: snapshot,
                isPlaying: isPlaying,
                onTogglePlayback: onTogglePlayback
            )

            TimelineTrack(
                snapshot: snapshot,
                onSeek: onSeek,
                onSelectedRangeChange: onSelectedRangeChange
            )
            .frame(height: 82)
        }
    }
}

private struct TimelineHeader: View {
    let snapshot: VideoEditorTimelineSnapshot
    let isPlaying: Bool
    let onTogglePlayback: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Timeline")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Range \(timeText(snapshot.selectedRange.lowerBound)) - \(timeText(snapshot.selectedRange.upperBound))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Playhead \(timeText(snapshot.currentTime))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill", action: onTogglePlayback)
                .buttonStyle(.borderedProminent)
                .tint(Color.white.opacity(0.14))
                .foregroundStyle(.white)
        }
    }

    private func timeText(_ value: Double) -> String {
        Duration.seconds(value).formatted(.time(pattern: .minuteSecond))
    }
}

private struct TimelineTrack: View {
    let snapshot: VideoEditorTimelineSnapshot
    let onSeek: (Double) -> Void
    let onSelectedRangeChange: (ClosedRange<Double>) -> Void

    var body: some View {
        GeometryReader { geometry in
            let trackSize = geometry.size

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(trackBackground)

                selectionMask(trackSize: trackSize)
                    .clipShape(.rect(cornerRadius: 24))
                    .allowsHitTesting(false)

                captionSegments(trackSize: trackSize)
                    .clipShape(.rect(cornerRadius: 24))
                    .allowsHitTesting(false)

                TimelineRangeSelectorView(
                    snapshot: snapshot,
                    trackSize: trackSize,
                    onRangeChange: onSelectedRangeChange
                )

                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: trackSize.height - 12)
                    .position(x: playheadX(trackSize: trackSize), y: trackSize.height / 2)
                    .shadow(color: .white.opacity(0.3), radius: 6)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .contentShape(.rect)
            .gesture(scrubGesture(trackSize: trackSize))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Timeline")
            .accessibilityValue("Selected range \(timeText(snapshot.selectedRange.lowerBound)) to \(timeText(snapshot.selectedRange.upperBound)), playhead at \(timeText(snapshot.currentTime))")
            .accessibilityAdjustableAction { direction in
                let step = 1.0
                switch direction {
                case .increment:
                    onSeek(snapshot.currentTime + step)
                case .decrement:
                    onSeek(snapshot.currentTime - step)
                @unknown default:
                    break
                }
            }
        }
    }
}

private extension TimelineTrack {
    var trackBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.13, green: 0.14, blue: 0.17),
                Color(red: 0.08, green: 0.09, blue: 0.11)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func selectionMask(trackSize: CGSize) -> some View {
        let leadingWidth = trackSize.width * snapshot.selectionStartProgress
        let trailingWidth = trackSize.width * (1 - snapshot.selectionEndProgress)

        return HStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.36))
                .frame(width: leadingWidth)

            Color.clear

            Rectangle()
                .fill(Color.black.opacity(0.36))
                .frame(width: trailingWidth)
        }
    }

    func captionSegments(trackSize: CGSize) -> some View {
        ZStack(alignment: .leading) {
            ForEach(snapshot.captions) { caption in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(captionGradient)
                    .frame(
                        width: max((caption.endProgress - caption.startProgress) * trackSize.width, 8),
                        height: 16
                    )
                    .position(
                        x: ((caption.startProgress + caption.endProgress) / 2) * trackSize.width,
                        y: trackSize.height - 16
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    var captionGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.72, blue: 0.3),
                Color(red: 0.88, green: 0.52, blue: 0.24)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    func playheadX(trackSize: CGSize) -> CGFloat {
        trackSize.width * snapshot.playheadProgress
    }

    func scrubGesture(trackSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard trackSize.width > 0 else {
                    return
                }

                let progress = Double(min(max(value.location.x / trackSize.width, 0), 1))
                let time = TimelineInteractionEngine.time(
                    for: progress,
                    in: snapshot.validRange
                )
                onSeek(time)
            }
    }

    func timeText(_ value: Double) -> String {
        Duration.seconds(value).formatted(.time(pattern: .minuteSecond))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TimelineView(
            snapshot: TimelinePreviewData.snapshot,
            isPlaying: false,
            onSeek: { _ in },
            onTogglePlayback: {},
            onSelectedRangeChange: { _ in }
        )
        .padding()
    }
}

private enum TimelinePreviewData {
    static let snapshot = VideoEditorTimelineSnapshot(
        validRange: 0...60,
        selectedRange: 12...46,
        currentTime: 28,
        selectionStartProgress: 0.2,
        selectionEndProgress: 46.0 / 60.0,
        playheadProgress: 28.0 / 60.0,
        captions: [
            .init(id: UUID(), text: "Intro", startProgress: 0.05, endProgress: 0.2),
            .init(id: UUID(), text: "Middle", startProgress: 0.36, endProgress: 0.56)
        ],
        validation: .init(warnings: ["Video duration exceeds the preset maximum and will be truncated."])
    )
}
