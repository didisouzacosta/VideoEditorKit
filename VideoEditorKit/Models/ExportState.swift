import Foundation

enum ExportState: Equatable {
    case idle
    case exporting(progress: Double)
    case completed(URL)
    case failed(VideoEditorError)
}
