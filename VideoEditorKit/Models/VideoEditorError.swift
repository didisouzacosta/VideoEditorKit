import Foundation

enum VideoEditorError: Error, Equatable {
    case invalidAsset
    case invalidVideoDuration
    case invalidTimeRange
    case videoTooShortForPreset(minimum: Double, preset: String)
    case exportAlreadyInProgress
    case exportFailed(reason: String)
    case captionGenerationInProgress
    case captionProviderUnavailable
    case captionProviderFailed(reason: String)
    case snapshotEncodingFailed
    case snapshotDecodingFailed
}
