import CoreGraphics

struct VideoEditorPreviewBuilder {
    nonisolated static func build(
        project: VideoProject,
        currentTime: Double,
        videoSize: CGSize,
        containerSize: CGSize,
        preferredTransform: CGAffineTransform = .identity
    ) -> VideoEditorPreviewSnapshot {
        let layout = LayoutEngine.computeLayout(
            videoSize: videoSize,
            containerSize: containerSize,
            preset: project.preset,
            gravity: project.gravity,
            preferredTransform: preferredTransform
        )
        let safeFrame = CaptionSafeFrameResolver.resolve(
            renderSize: layout.renderSize,
            safeArea: project.preset.captionSafeArea
        )
        let captions = CaptionEngine.activeCaptions(
            from: project.captions,
            at: currentTime,
            in: project.selectedTimeRange
        ).map { caption in
            VideoEditorPreviewCaption(
                id: caption.id,
                text: caption.text,
                center: CaptionPositionResolver.resolve(
                    caption: caption,
                    renderSize: layout.renderSize,
                    safeFrame: safeFrame
                ),
                style: caption.style
            )
        }

        return VideoEditorPreviewSnapshot(
            layout: layout,
            safeFrame: safeFrame,
            captions: captions
        )
    }
}
