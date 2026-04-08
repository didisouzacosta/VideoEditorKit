import Foundation

public struct VideoEditorSaveState: Equatable, Sendable {

    // MARK: - Public Properties

    public let editingConfiguration: VideoEditingConfiguration
    public let thumbnailData: Data?

    public var continuousSaveFingerprint: VideoEditingConfiguration {
        editingConfiguration.continuousSaveFingerprint
    }

    // MARK: - Initializer

    public init(
        editingConfiguration: VideoEditingConfiguration,
        thumbnailData: Data? = nil
    ) {
        self.editingConfiguration = editingConfiguration
        self.thumbnailData = thumbnailData
    }

}

public struct VideoEditorSession: Equatable, Sendable {

    public typealias Source = VideoEditorSessionSource

    // MARK: - Public Properties

    public let source: Source?
    public let editingConfiguration: VideoEditingConfiguration?

    public var sourceVideoURL: URL? {
        source?.fileURL
    }

    public var bootstrapTaskIdentifier: String {
        source?.taskIdentifier ?? "none"
    }

    // MARK: - Initializer

    public init(
        source: Source? = nil,
        editingConfiguration: VideoEditingConfiguration? = nil
    ) {
        self.source = source
        self.editingConfiguration = editingConfiguration
    }

    public init(
        sourceVideoURL: URL? = nil,
        editingConfiguration: VideoEditingConfiguration? = nil
    ) {
        self.init(
            source: sourceVideoURL.map { .fileURL($0) },
            editingConfiguration: editingConfiguration
        )
    }
}

public struct VideoEditorCallbacks {

    // MARK: - Public Properties

    public let onSaveStateChanged: (VideoEditorSaveState) -> Void
    public let onSourceVideoResolved: (URL) -> Void
    public let onDismissed: (VideoEditingConfiguration?) -> Void
    public let onExportedVideoURL: (URL) -> Void

    // MARK: - Initializer

    public init(
        onSaveStateChanged: @escaping (VideoEditorSaveState) -> Void = { _ in },
        onSourceVideoResolved: @escaping (URL) -> Void = { _ in },
        onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
        onExportedVideoURL: @escaping (URL) -> Void = { _ in }
    ) {
        self.onSaveStateChanged = onSaveStateChanged
        self.onSourceVideoResolved = onSourceVideoResolved
        self.onDismissed = onDismissed
        self.onExportedVideoURL = onExportedVideoURL
    }

}

public struct VideoEditorConfiguration {

    public struct TranscriptionConfiguration {

        // MARK: - Public Properties

        public let preferredLocale: String?

        public var isConfigured: Bool {
            explicitProvider != nil
        }

        public var provider: (any VideoTranscriptionProvider)? {
            explicitProvider
        }

        // MARK: - Private Properties

        private let explicitProvider: (any VideoTranscriptionProvider)?

        // MARK: - Initializer

        public init(
            provider: (any VideoTranscriptionProvider)? = nil,
            preferredLocale: String? = nil
        ) {
            explicitProvider = provider
            self.preferredLocale = preferredLocale
        }

    }

    // MARK: - Public Properties

    public static var allToolsEnabled: Self {
        Self()
    }

    public let tools: [ToolAvailability]
    public let exportQualities: [ExportQualityAvailability]
    public let transcription: TranscriptionConfiguration

    // MARK: - Private Properties

    private let onBlockedToolTap: ((ToolEnum) -> Void)?
    private let onBlockedExportQualityTap: ((VideoQuality) -> Void)?

    public var visibleTools: [ToolEnum] {
        tools.map(\.tool)
    }

    // MARK: - Initializer

    public init(
        tools: [ToolAvailability] = ToolAvailability.enabled(ToolEnum.all),
        exportQualities: [ExportQualityAvailability] = ExportQualityAvailability.allEnabled,
        transcription: TranscriptionConfiguration = .init(),
        onBlockedToolTap: ((ToolEnum) -> Void)? = nil,
        onBlockedExportQualityTap: ((VideoQuality) -> Void)? = nil
    ) {
        self.tools = tools.sorted {
            if $0.order == $1.order {
                return $0.tool.rawValue < $1.tool.rawValue
            }

            return $0.order < $1.order
        }
        self.exportQualities = exportQualities.sorted {
            if $0.order == $1.order {
                return $0.quality.rawValue < $1.quality.rawValue
            }

            return $0.order < $1.order
        }
        self.transcription = transcription
        self.onBlockedToolTap = onBlockedToolTap
        self.onBlockedExportQualityTap = onBlockedExportQualityTap
    }

    // MARK: - Public Methods

    public func availability(for tool: ToolEnum) -> ToolAvailability? {
        tools.first(where: { $0.tool == tool })
    }

    public func availability(for quality: VideoQuality) -> ExportQualityAvailability? {
        exportQualities.first(where: { $0.quality == quality })
    }

    public func isVisible(_ tool: ToolEnum) -> Bool {
        availability(for: tool) != nil
    }

    public func isBlocked(_ tool: ToolEnum) -> Bool {
        availability(for: tool)?.isBlocked == true
    }

    public func isEnabled(_ tool: ToolEnum) -> Bool {
        availability(for: tool)?.isEnabled == true
    }

    public func notifyBlockedToolTap(for tool: ToolEnum) {
        onBlockedToolTap?(tool)
    }

    public func isBlocked(_ quality: VideoQuality) -> Bool {
        availability(for: quality)?.isBlocked == true
    }

    public func isEnabled(_ quality: VideoQuality) -> Bool {
        availability(for: quality)?.isEnabled == true
    }

    public func notifyBlockedExportQualityTap(for quality: VideoQuality) {
        onBlockedExportQualityTap?(quality)
    }

}
