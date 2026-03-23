import CoreGraphics
import SwiftUI

struct VideoEditorView: View {
    let controller: VideoEditorController
    let videoSize: CGSize
    let preferredTransform: CGAffineTransform

    init(
        controller: VideoEditorController,
        videoSize: CGSize,
        preferredTransform: CGAffineTransform = .identity
    ) {
        self.controller = controller
        self.videoSize = videoSize
        self.preferredTransform = preferredTransform
    }

    var body: some View {
        VStack(spacing: 20) {
            previewCard
            PresetToolbarView(selectedPreset: controller.project.preset) { preset in
                controller.selectPreset(preset)
            }
            timelineSummary
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.11, blue: 0.13), Color(red: 0.03, green: 0.03, blue: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private extension VideoEditorView {
    var previewCard: some View {
        GeometryReader { geometry in
            let snapshot = VideoEditorPreviewBuilder.build(
                project: controller.project,
                currentTime: controller.playerEngine.currentTime,
                videoSize: videoSize,
                containerSize: geometry.size,
                preferredTransform: preferredTransform
            )

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black)

                SafeFrameOverlay(
                    safeFrame: snapshot.safeFrame,
                    renderSize: snapshot.layout.renderSize,
                    displaySize: geometry.size
                )

                CaptionOverlayView(
                    captions: snapshot.captions,
                    renderSize: snapshot.layout.renderSize,
                    displaySize: geometry.size
                )

                VStack(alignment: .leading, spacing: 8) {
                    previewPill(title: controller.project.preset.title)
                    previewPill(title: timeText)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .clipShape(.rect(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .aspectRatio(previewAspectRatio, contentMode: .fit)
    }

    var timelineSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Range")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(rangeText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var rangeText: String {
        let range = controller.project.selectedTimeRange
        return "\(formatted(range.lowerBound))s - \(formatted(range.upperBound))s"
    }

    var timeText: String {
        "Time \(formatted(controller.playerEngine.currentTime))s"
    }

    var previewAspectRatio: CGFloat {
        let orientedSize = CGRect(origin: .zero, size: videoSize)
            .applying(preferredTransform)
            .standardized
            .size
        let baseSize = controller.project.preset.resolve(videoSize: orientedSize)

        guard baseSize.height > 0 else {
            return 9.0 / 16.0
        }

        return baseSize.width / baseSize.height
    }

    func previewPill(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1), in: .rect(cornerRadius: 12))
    }

    func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}

private struct SafeFrameOverlay: View {
    let safeFrame: CGRect
    let renderSize: CGSize
    let displaySize: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [10, 8]))
            .foregroundStyle(Color.white.opacity(0.12))
            .frame(width: displayFrame.width, height: displayFrame.height)
            .position(x: displayFrame.midX, y: displayFrame.midY)
    }
}

private extension SafeFrameOverlay {
    var displayFrame: CGRect {
        CGRect(
            x: scaledAxis(safeFrame.minX, renderDimension: renderSize.width, displayDimension: displaySize.width),
            y: scaledAxis(safeFrame.minY, renderDimension: renderSize.height, displayDimension: displaySize.height),
            width: scaledAxis(safeFrame.width, renderDimension: renderSize.width, displayDimension: displaySize.width),
            height: scaledAxis(safeFrame.height, renderDimension: renderSize.height, displayDimension: displaySize.height)
        )
    }

    func scaledAxis(
        _ value: CGFloat,
        renderDimension: CGFloat,
        displayDimension: CGFloat
    ) -> CGFloat {
        guard renderDimension > 0 else {
            return 0
        }

        return (value / renderDimension) * displayDimension
    }
}
