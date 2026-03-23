import Foundation

@MainActor
final class ExportEngine {
    private let assetLoader: any VideoAssetLoading
    private let renderer: any VideoExportRendering
    private var isExporting = false

    init(
        assetLoader: any VideoAssetLoading = AVFoundationVideoAssetLoader(),
        renderer: any VideoExportRendering = AVFoundationExportRenderer()
    ) {
        self.assetLoader = assetLoader
        self.renderer = renderer
    }

    func export(
        project: VideoProject,
        destinationURL: URL,
        progressHandler: ExportProgressHandler? = nil
    ) async throws -> URL {
        guard isExporting == false else {
            throw VideoEditorError.exportAlreadyInProgress
        }

        guard destinationURL.isFileURL, destinationURL.path.isEmpty == false else {
            throw VideoEditorError.exportFailed(reason: "Destination URL is invalid.")
        }

        isExporting = true
        defer {
            isExporting = false
        }

        let asset = try await assetLoader.loadAsset(from: project.sourceVideoURL)
        let timeRange = TimeRangeEngine.resolve(
            videoDuration: asset.duration,
            currentSelection: project.selectedTimeRange,
            preset: project.preset
        )
        let validationResult = ProjectValidator.validateProject(
            project: project,
            videoDuration: asset.duration,
            timeRange: timeRange
        )

        try throwIfNeeded(
            validationResult: validationResult,
            project: project,
            timeRange: timeRange
        )

        let snapshot = FrozenExportProject(
            sourceVideoURL: project.sourceVideoURL,
            captions: CaptionEngine.normalizeCaptions(
                project.captions,
                to: timeRange.selectedRange
            ),
            preset: project.preset,
            gravity: project.gravity,
            selectedTimeRange: timeRange.selectedRange
        )
        let layout = LayoutEngine.computeLayout(
            videoSize: asset.naturalSize,
            containerSize: snapshot.preset.resolve(videoSize: asset.presentationSize),
            preset: snapshot.preset,
            gravity: snapshot.gravity,
            preferredTransform: asset.preferredTransform
        )
        let request = ExportRenderRequest(
            snapshot: snapshot,
            asset: asset,
            layout: layout,
            timeRange: timeRange,
            destinationURL: destinationURL
        )

        progressHandler?(0)

        return try await renderer.export(
            request: request,
            progressHandler: progressHandler
        )
    }
}

private extension ExportEngine {
    func throwIfNeeded(
        validationResult: ValidationResult,
        project: VideoProject,
        timeRange: TimeRangeResult
    ) throws {
        guard validationResult.canExport == false else {
            return
        }

        if timeRange.isVideoTooShort {
            throw VideoEditorError.videoTooShortForPreset(
                minimum: project.preset.minDuration,
                preset: project.preset.title
            )
        }

        if project.selectedTimeRange != timeRange.selectedRange {
            throw VideoEditorError.invalidTimeRange
        }

        if let firstError = validationResult.errors.first {
            throw VideoEditorError.exportFailed(reason: firstError)
        }

        throw VideoEditorError.exportFailed(reason: "Export failed.")
    }
}
