import Observation

@MainActor
@Observable
final class EditorState {
    var currentTime: Double = 0
    var isPlaying = false
    var selectedCaptionID: Caption.ID?
    var captionState: CaptionState = .idle
    var exportState: ExportState = .idle

    init() {}
}
