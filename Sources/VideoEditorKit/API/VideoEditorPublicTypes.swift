import Foundation

/// The payload emitted by continuous-save callbacks while the user edits a video.
public struct VideoEditorSaveState: Equatable, Sendable {

    // MARK: - Public Properties

    /// The latest serializable editing snapshot.
    public let editingConfiguration: VideoEditingConfiguration
    /// An optional thumbnail image generated for the current project state.
    public let thumbnailData: Data?

    /// A normalized version of the save payload suitable for change detection during autosave.
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

/// Describes a single editor session, including its source video and optional restore state.
public struct VideoEditorSession: Equatable, Sendable {

    /// The supported source type for a session.
    public typealias Source = VideoEditorSessionSource

    // MARK: - Public Properties

    /// The source video descriptor used to bootstrap the editor.
    public let source: Source?
    /// An optional editing snapshot used to resume an existing project.
    public let editingConfiguration: VideoEditingConfiguration?

    /// A convenient accessor when the source is already available as a local file URL.
    public var sourceVideoURL: URL? {
        source?.fileURL
    }

    /// A stable identifier used to detect session-source changes.
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

/// Host callbacks invoked as the editor resolves, saves, dismisses, and exports content.
public struct VideoEditorCallbacks {

    // MARK: - Public Properties

    /// Called whenever the editor emits a new continuous-save snapshot.
    public let onSaveStateChanged: (VideoEditorSaveState) -> Void
    /// Called when an asynchronous source resolver finishes and yields a local file URL.
    public let onSourceVideoResolved: (URL) -> Void
    /// Called when the editor is dismissed, with the last known editing snapshot if available.
    public let onDismissed: (VideoEditingConfiguration?) -> Void
    /// Called after a successful export with the exported file URL.
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

/// Host-facing runtime configuration for the editor UI and feature set.
public struct VideoEditorConfiguration {

    /// Configuration used to inject optional transcript generation behavior.
    public struct TranscriptionConfiguration {

        // MARK: - Public Properties

        /// Preferred locale passed through to the active transcription provider.
        public let preferredLocale: String?

        /// Indicates whether a transcription provider is currently configured.
        public var isConfigured: Bool {
            explicitProvider != nil
        }

        /// The effective provider used by the editor for transcript generation.
        public var provider: (any VideoTranscriptionProvider)? {
            explicitProvider
        }

        // MARK: - Private Properties

        private let explicitProvider: (any VideoTranscriptionProvider)?

        // MARK: - Initializer

        /// Creates a transcription configuration with an optional custom provider.
        public init(
            provider: (any VideoTranscriptionProvider)? = nil,
            preferredLocale: String? = nil
        ) {
            explicitProvider = provider
            self.preferredLocale = preferredLocale
        }

        // MARK: - Public Methods

        /// Creates an Apple Speech-backed transcription configuration for on-device or
        /// system-provided speech recognition.
        public static func appleSpeech(
            preferredLocale: String? = nil
        ) -> Self {
            .init(
                provider: AppleSpeechTranscriptionComponent(),
                preferredLocale: preferredLocale
            )
        }

        /// Creates an OpenAI Whisper-backed transcription configuration when an API key is
        /// available.
        public static func openAIWhisper(
            apiKey: String,
            preferredLocale: String? = nil
        ) -> Self {
            let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmedAPIKey.isEmpty == false else {
                return .init(preferredLocale: preferredLocale)
            }

            return .init(
                provider: OpenAIWhisperTranscriptionComponent(trimmedAPIKey),
                preferredLocale: preferredLocale
            )
        }

    }

    // MARK: - Public Properties

    /// A convenience configuration with every currently public tool and export quality enabled.
    public static var allToolsEnabled: Self {
        Self(
            transcription: .init()
        )
    }

    /// Ordered tool availability definitions displayed by the editor.
    public let tools: [ToolAvailability]
    /// Ordered export-quality availability definitions displayed during export.
    public let exportQualities: [ExportQualityAvailability]
    /// Optional transcript generation integration settings.
    public let transcription: TranscriptionConfiguration?
    /// Optional upper bound, in seconds, for accepted source video duration.
    public let maximumVideoDuration: TimeInterval?

    // MARK: - Private Properties

    private let onBlockedToolTap: ((ToolEnum) -> Void)?
    private let onBlockedExportQualityTap: ((VideoQuality) -> Void)?

    /// The tools that are visible in the current configuration.
    public var visibleTools: [ToolEnum] {
        tools.map(\.tool)
    }

    // MARK: - Initializer

    public init(
        tools: [ToolAvailability] = ToolAvailability.enabled(ToolEnum.all),
        exportQualities: [ExportQualityAvailability] = ExportQualityAvailability.allEnabled,
        transcription: TranscriptionConfiguration? = nil,
        maximumVideoDuration: TimeInterval? = nil,
        onBlockedToolTap: ((ToolEnum) -> Void)? = nil,
        onBlockedExportQualityTap: ((VideoQuality) -> Void)? = nil
    ) {
        self.tools = Self.normalizedTools(
            tools,
            transcription: transcription
        ).sorted {
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
        self.maximumVideoDuration = Self.normalizedMaximumVideoDuration(
            maximumVideoDuration
        )
        self.onBlockedToolTap = onBlockedToolTap
        self.onBlockedExportQualityTap = onBlockedExportQualityTap
    }

    // MARK: - Public Methods

    /// Returns the availability metadata for a tool if the tool is part of the current config.
    public func availability(for tool: ToolEnum) -> ToolAvailability? {
        tools.first(where: { $0.tool == tool })
    }

    /// Returns the availability metadata for an export quality if it is part of the current config.
    public func availability(for quality: VideoQuality) -> ExportQualityAvailability? {
        exportQualities.first(where: { $0.quality == quality })
    }

    /// Returns `true` when the tool should be shown in the editor.
    public func isVisible(_ tool: ToolEnum) -> Bool {
        availability(for: tool) != nil
    }

    /// Returns `true` when the tool is visible but intentionally blocked.
    public func isBlocked(_ tool: ToolEnum) -> Bool {
        availability(for: tool)?.isBlocked == true
    }

    /// Returns `true` when the tool is visible and enabled for interaction.
    public func isEnabled(_ tool: ToolEnum) -> Bool {
        availability(for: tool)?.isEnabled == true
    }

    /// Triggers the host callback associated with blocked tool taps.
    public func notifyBlockedToolTap(for tool: ToolEnum) {
        onBlockedToolTap?(tool)
    }

    /// Returns `true` when an export quality is visible but intentionally blocked.
    public func isBlocked(_ quality: VideoQuality) -> Bool {
        availability(for: quality)?.isBlocked == true
    }

    /// Returns `true` when an export quality is visible and enabled for interaction.
    public func isEnabled(_ quality: VideoQuality) -> Bool {
        availability(for: quality)?.isEnabled == true
    }

    /// Triggers the host callback associated with blocked export-quality taps.
    public func notifyBlockedExportQualityTap(for quality: VideoQuality) {
        onBlockedExportQualityTap?(quality)
    }

    // MARK: - Private Methods

    private static func normalizedMaximumVideoDuration(
        _ maximumVideoDuration: TimeInterval?
    ) -> TimeInterval? {
        guard let maximumVideoDuration else { return nil }
        guard maximumVideoDuration.isFinite, maximumVideoDuration > 0 else {
            return nil
        }

        return maximumVideoDuration
    }

    private static func normalizedTools(
        _ tools: [ToolAvailability],
        transcription: TranscriptionConfiguration?
    ) -> [ToolAvailability] {
        guard transcription != nil else {
            return tools.filter { $0.tool != .transcript }
        }

        return tools
    }

}
