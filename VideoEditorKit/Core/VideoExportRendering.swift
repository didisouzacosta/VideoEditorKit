import Foundation

typealias ExportProgressHandler = @MainActor @Sendable (Double) -> Void

protocol VideoExportRendering {
    func export(
        request: ExportRenderRequest,
        progressHandler: ExportProgressHandler?
    ) async throws -> URL
}
