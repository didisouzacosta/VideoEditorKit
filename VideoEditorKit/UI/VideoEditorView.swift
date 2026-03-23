import Foundation
import CoreGraphics
import SwiftUI
import UIKit

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
        ScrollView {
            VStack(spacing: 20) {
                previewCard
                PresetToolbarView(selectedPreset: controller.project.preset) { preset in
                    controller.selectPreset(preset)
                }
                TimelineView(
                    snapshot: timelineSnapshot,
                    isPlaying: controller.editorState.isPlaying,
                    onSeek: controller.seek(to:),
                    onTogglePlayback: controller.togglePlayback,
                    onSelectedRangeChange: controller.updateSelectedTimeRange(_:)
                )
                CaptionActionBar(
                    controller: controller,
                    videoDuration: controller.playerEngine.duration
                )
                EditorNoticeList(
                    validation: timelineSnapshot.validation,
                    captionState: controller.editorState.captionState,
                    exportState: controller.editorState.exportState
                )
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.11, blue: 0.13), Color(red: 0.03, green: 0.03, blue: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

private extension VideoEditorView {
    var timelineSnapshot: VideoEditorTimelineSnapshot {
        VideoEditorTimelineBuilder.build(
            project: controller.project,
            videoDuration: controller.playerEngine.duration,
            currentTime: controller.playerEngine.currentTime
        )
    }

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
                    displaySize: geometry.size,
                    selectedCaptionID: controller.editorState.selectedCaptionID,
                    onSelect: controller.selectCaption(_:),
                    onMove: { captionID, point in
                        controller.moveCaption(
                            captionID,
                            to: point,
                            displaySize: geometry.size,
                            renderSize: snapshot.layout.renderSize,
                            safeFrame: snapshot.safeFrame
                        )
                    }
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

private struct CaptionActionBar: View {
    let controller: VideoEditorController
    let videoDuration: Double

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                generateButton
                translateButton
            }

            VStack(spacing: 12) {
                generateButton
                translateButton
            }
        }
    }
}

private extension CaptionActionBar {
    var isLoading: Bool {
        controller.editorState.captionState == .loading
    }

    var actionsDisabled: Bool {
        videoDuration <= 0 || isLoading
    }

    var generateButton: some View {
        CaptionActionButtonView(
            title: "Generate Captions",
            loadingTitle: "Generating",
            systemImage: "captions.bubble.fill",
            isLoading: isLoading,
            isDisabled: actionsDisabled
        ) {
            run(.generate)
        }
    }

    var translateButton: some View {
        CaptionActionButtonView(
            title: "Translate Captions",
            loadingTitle: "Translating",
            systemImage: "globe",
            isLoading: isLoading,
            isDisabled: actionsDisabled
        ) {
            run(.translate)
        }
    }

    func run(_ action: CaptionAction) {
        guard actionsDisabled == false else {
            return
        }

        Task {
            try? await controller.performCaptionAction(
                action,
                videoDuration: videoDuration
            )
        }
    }
}

private struct EditorNoticeList: View {
    let validation: ValidationResult
    let captionState: CaptionState
    let exportState: ExportState

    var body: some View {
        VStack(spacing: 12) {
            ForEach(validation.errors, id: \.self) { message in
                EditorNoticeCard(
                    title: "Blocking Issue",
                    message: message,
                    tint: Color(red: 0.74, green: 0.28, blue: 0.24)
                )
            }

            ForEach(validation.warnings, id: \.self) { message in
                EditorNoticeCard(
                    title: "Warning",
                    message: message,
                    tint: Color(red: 0.9, green: 0.62, blue: 0.25)
                )
            }

            switch captionState {
            case .idle:
                EmptyView()
            case .loading:
                EditorNoticeCard(
                    title: "Captions",
                    message: "Caption request in progress.",
                    tint: Color(red: 0.24, green: 0.5, blue: 0.84)
                )
            case .failed(let message):
                EditorNoticeCard(
                    title: "Caption Error",
                    message: message,
                    tint: Color(red: 0.78, green: 0.25, blue: 0.24)
                )
            }

            switch exportState {
            case .idle:
                EmptyView()
            case .exporting(let progress):
                EditorNoticeCard(
                    title: "Exporting",
                    message: "Progress \(Int((progress * 100).rounded()))%",
                    tint: Color(red: 0.24, green: 0.5, blue: 0.84)
                )
            case .completed(let url):
                EditorNoticeCard(
                    title: "Export Complete",
                    message: url.lastPathComponent,
                    tint: Color(red: 0.22, green: 0.56, blue: 0.34)
                )
            case .failed(let error):
                EditorNoticeCard(
                    title: "Export Error",
                    message: error.localizedDescription,
                    tint: Color(red: 0.78, green: 0.25, blue: 0.24)
                )
            }
        }
    }
}

private struct EditorNoticeCard: View {
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.14), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.34), lineWidth: 1)
        }
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

#Preview("Instagram") {
    VideoEditorView(
        controller: VideoEditorViewPreviewData.makeController(preset: .instagram, time: 12),
        videoSize: CGSize(width: 1920, height: 1080)
    )
}

#Preview("Original") {
    VideoEditorView(
        controller: VideoEditorViewPreviewData.makeController(preset: .original, time: 26),
        videoSize: CGSize(width: 1920, height: 1080)
    )
}

private enum VideoEditorViewPreviewData {
    @MainActor static func makeController(
        preset: ExportPreset,
        time: Double
    ) -> VideoEditorController {
        let style = previewStyle
        let controller = VideoEditorController(
            project: VideoProject(
                sourceVideoURL: URL(fileURLWithPath: "/tmp/demo.mov"),
                captions: previewCaptions(style: style),
                preset: preset,
                gravity: .fit,
                selectedTimeRange: 0...35
            ),
            config: VideoEditorConfig(
                onCaptionAction: { action, context in
                    try await Task.sleep(for: .milliseconds(250))
                    return mockCaptions(
                        for: action,
                        context: context,
                        style: style
                    )
                }
            )
        )

        try? controller.loadVideo(duration: 45)
        controller.seek(to: time)
        return controller
    }

    static var previewStyle: CaptionStyle {
        CaptionStyle(
            fontName: UIFont.boldSystemFont(ofSize: 24).fontName,
            fontSize: 24,
            textColor: .white,
            backgroundColor: UIColor.black.withAlphaComponent(0.72),
            padding: 12,
            cornerRadius: 14
        )
    }

    static func previewCaptions(style: CaptionStyle) -> [Caption] {
        [
            Caption(
                id: UUID(),
                text: "Preview = Export",
                startTime: 0,
                endTime: 20,
                position: CGPoint(x: 0.5, y: 0.5),
                placementMode: .preset(.bottom),
                style: style
            ),
            Caption(
                id: UUID(),
                text: "Legenda livre na safe area",
                startTime: 20,
                endTime: 40,
                position: CGPoint(x: 0.5, y: 0.34),
                placementMode: .freeform,
                style: style
            )
        ]
    }

    static func mockCaptions(
        for action: CaptionAction,
        context: CaptionRequestContext,
        style: CaptionStyle
    ) -> [Caption] {
        let range = context.selectedTimeRange
        let duration = max(range.upperBound - range.lowerBound, 1)
        let segmentDuration = duration / 3
        let texts = switch action {
        case .generate:
            ["Generated intro", "Generated body", "Generated outro"]
        case .translate:
            ["Legenda traduzida 1", "Legenda traduzida 2", "Legenda traduzida 3"]
        }

        return texts.enumerated().map { index, text in
            let startTime = range.lowerBound + (segmentDuration * Double(index))
            let endTime = min(startTime + segmentDuration, range.upperBound)

            return Caption(
                id: UUID(),
                text: text,
                startTime: startTime,
                endTime: endTime,
                position: CGPoint(x: 0.5, y: 0.68 - (Double(index) * 0.1)),
                placementMode: .freeform,
                style: style
            )
        }
    }
}
