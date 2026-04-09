import Foundation

public protocol VideoTranscriptionProvider: Sendable {
    func transcribeVideo(input: VideoTranscriptionInput) async throws -> VideoTranscriptionResult
}

public protocol VideoTranscriptionComponentProtocol: VideoTranscriptionProvider {
    var state: TranscriptFeatureState { get async }
    func cancelCurrentTranscription() async
    func availabilityError(
        preferredLocale: String?
    ) async -> TranscriptError?
}

extension VideoTranscriptionComponentProtocol {

    public func availabilityError(
        preferredLocale: String?
    ) async -> TranscriptError? {
        nil
    }
}

public struct VideoTranscriptionInput: Hashable, Sendable {

    // MARK: - Public Properties

    public let assetIdentifier: String
    public let source: VideoTranscriptionSource
    public let preferredLocale: String?

    // MARK: - Initializer

    public init(
        assetIdentifier: String,
        source: VideoTranscriptionSource,
        preferredLocale: String?
    ) {
        self.assetIdentifier = assetIdentifier
        self.source = source
        self.preferredLocale = preferredLocale
    }

}

public enum VideoTranscriptionSource: Hashable, Sendable {
    case fileURL(URL)
}

public struct VideoTranscriptionResult: Hashable, Sendable {

    // MARK: - Public Properties

    public var segments: [TranscriptionSegment] = []

    // MARK: - Initializer

    public init(segments: [TranscriptionSegment] = []) {
        self.segments = segments
    }

}

public struct TranscriptionSegment: Identifiable, Hashable, Sendable {

    // MARK: - Public Properties

    public let id: UUID
    public let startTime: Double
    public let endTime: Double
    public let text: String
    public var words: [TranscriptionWord] = []

    // MARK: - Initializer

    public init(
        id: UUID,
        startTime: Double,
        endTime: Double,
        text: String,
        words: [TranscriptionWord] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.words = words
    }

}

public struct TranscriptionWord: Identifiable, Hashable, Sendable {

    // MARK: - Public Properties

    public let id: UUID
    public let startTime: Double
    public let endTime: Double
    public let text: String

    // MARK: - Initializer

    public init(
        id: UUID,
        startTime: Double,
        endTime: Double,
        text: String
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }

}
