import Foundation

struct VideoEditorConfig {
    var onCaptionAction: ((CaptionAction, CaptionRequestContext) async throws -> [Caption])?
    var captionApplyStrategy: CaptionApplyStrategy
    var onExportProgress: ((Double) -> Void)?

    init(
        onCaptionAction: ((CaptionAction, CaptionRequestContext) async throws -> [Caption])? = nil,
        captionApplyStrategy: CaptionApplyStrategy = .replaceAll,
        onExportProgress: ((Double) -> Void)? = nil
    ) {
        self.onCaptionAction = onCaptionAction
        self.captionApplyStrategy = captionApplyStrategy
        self.onExportProgress = onExportProgress
    }
}
