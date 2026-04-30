import SwiftUI

@MainActor
public struct VideoExportSheet: View {

    // MARK: - Environments

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - States

    @State private var exportLifecycleState: ExportLifecycleState = .active
    @State private var loadedVideo: Video?
    @State private var loadedOriginalVideo: ExportedVideo?

    // MARK: - Public Properties

    public typealias PrepareForExport = (VideoQuality) async -> VideoExportPreparationResult

    // MARK: - Body

    public var body: some View {
        Group {
            if let loadedVideo {
                VideoExporterContainerView(
                    lifecycleState: $exportLifecycleState,
                    video: loadedVideo,
                    editingConfiguration: request.editingConfiguration,
                    exportQualities: configuration.exportQualities,
                    watermark: configuration.watermark,
                    prepareForExport: resolvedPrepareForExport,
                    onBlockedQualityTap: configuration.notifyBlockedExportQualityTap(for:),
                    onExported: onExported
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .task(id: request.id) {
            await loadVideo()
        }
        .onChange(of: scenePhase) { _, newScenePhase in
            exportLifecycleState = .init(scenePhase: newScenePhase)
        }
        .task(id: scenePhase) {
            exportLifecycleState = .init(scenePhase: scenePhase)
        }
    }

    // MARK: - Private Properties

    private let request: VideoExportSheetRequest
    private let configuration: VideoEditorConfiguration
    private let prepareForExport: PrepareForExport?
    private let onExported: (ExportedVideo) -> Void

    private var resolvedPrepareForExport: PrepareForExport {
        if let prepareForExport {
            return prepareForExport
        }

        return { quality in
            VideoExportSheetPreparationResolver.preparationResult(
                selectedQuality: quality,
                request: request,
                loadedOriginalVideo: loadedOriginalVideo,
                hasWatermark: configuration.watermark != nil
            )
        }
    }

    // MARK: - Initializer

    public init(
        request: VideoExportSheetRequest,
        configuration: VideoEditorConfiguration = .init(),
        prepareForExport: PrepareForExport? = nil,
        onExported: @escaping (ExportedVideo) -> Void
    ) {
        self.request = request
        self.configuration = configuration
        self.prepareForExport = prepareForExport
        self.onExported = onExported
    }

    // MARK: - Private Methods

    private func loadVideo() async {
        loadedVideo = nil
        loadedOriginalVideo = nil

        let video = await Video.load(from: request.sourceVideoURL)
        loadedVideo = video
        loadedOriginalVideo = Self.loadedOriginalExportVideo(from: video)
    }

    private static func loadedOriginalExportVideo(from video: Video) -> ExportedVideo {
        ExportedVideo(
            video.url,
            width: max(video.presentationSize.width, 0),
            height: max(video.presentationSize.height, 0),
            duration: max(video.originalDuration, 0),
            fileSize: resolvedFileSize(for: video.url)
        )
    }

    private static func resolvedFileSize(for url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path())
        let sizeValue = attributes?[.size] as? NSNumber
        return max(sizeValue?.int64Value ?? 0, 0)
    }

}

enum VideoExportSheetPreparationResolver {

    // MARK: - Public Methods

    static func preparationResult(
        selectedQuality: VideoQuality,
        request: VideoExportSheetRequest,
        loadedOriginalVideo: ExportedVideo?,
        hasWatermark: Bool = false
    ) -> VideoExportPreparationResult {
        guard hasWatermark == false else {
            return .render
        }

        if selectedQuality == .original,
            let preparedOriginalExportVideo = request.preparedOriginalExportVideo,
            request.preparedOriginalExportEditingConfiguration?.continuousSaveFingerprint
                == request.editingConfiguration.continuousSaveFingerprint
        {
            return .usePreparedVideo(preparedOriginalExportVideo)
        }

        if selectedQuality == .original,
            request.editingConfiguration.continuousSaveFingerprint
                == VideoEditingConfiguration.initial.continuousSaveFingerprint,
            let loadedOriginalVideo
        {
            return .usePreparedVideo(loadedOriginalVideo)
        }

        return .render
    }

}
