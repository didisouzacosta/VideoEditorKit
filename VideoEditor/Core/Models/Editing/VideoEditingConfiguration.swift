//
//  VideoEditingConfiguration.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 27.03.2026.
//

import Foundation

struct VideoEditingConfiguration: Codable, Equatable, Sendable {

    // MARK: - Public Properties

    static let currentSchemaVersion: SchemaVersion = .current
    static let initial = Self()

    var version = Self.currentSchemaVersion.rawValue
    var trim = Trim()
    var playback = Playback()
    var crop = Crop()
    var canvas = Canvas()
    var adjusts = Adjusts()
    var frame = Frame()
    var audio = Audio()
    var transcript = Transcript()
    var presentation = Presentation()

    // MARK: - Private Properties

    private var opaquePayload: OpaquePayload?

    private enum CodingKeys: String, CodingKey {
        case version
        case trim
        case playback
        case crop
        case canvas
        case adjusts
        case frame
        case audio
        case transcript
        case presentation
    }

    enum SchemaVersion: Int, Codable, Equatable, Sendable {
        case v1 = 1
        case current = 2
    }

    var schemaVersion: SchemaVersion? {
        SchemaVersion(rawValue: version)
    }

    // MARK: - Initializer

    init(
        version: Int = Self.currentSchemaVersion.rawValue,
        trim: Trim = .init(),
        playback: Playback = .init(),
        crop: Crop = .init(),
        canvas: Canvas = .init(),
        adjusts: Adjusts = .init(),
        frame: Frame = .init(),
        audio: Audio = .init(),
        transcript: Transcript = .init(),
        presentation: Presentation = .init()
    ) {
        self.version = version
        self.trim = trim
        self.playback = playback
        self.crop = crop
        self.canvas = canvas
        self.adjusts = adjusts
        self.frame = frame
        self.audio = audio
        self.transcript = transcript
        self.presentation = presentation
    }

    init(from decoder: any Decoder) throws {
        let opaquePayload = try OpaquePayload(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version)

        self = try Self(
            decodedFrom: container,
            version: decodedVersion ?? SchemaVersion.current.rawValue
        )
        self.opaquePayload = opaquePayload
        self = self.migratedToCurrentSchema()
    }

    func encode(to encoder: any Encoder) throws {
        if schemaVersion == nil, let opaquePayload {
            try opaquePayload.encode(to: encoder)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion.rawValue, forKey: .version)
        try container.encode(trim, forKey: .trim)
        try container.encode(playback, forKey: .playback)
        try container.encode(crop, forKey: .crop)
        try container.encode(canvas, forKey: .canvas)
        try container.encode(adjusts, forKey: .adjusts)
        try container.encode(frame, forKey: .frame)
        try container.encode(audio, forKey: .audio)
        try container.encode(transcript, forKey: .transcript)
        try container.encode(presentation, forKey: .presentation)
    }

    // MARK: - Private Initializer

    private init(
        decodedFrom container: KeyedDecodingContainer<CodingKeys>,
        version: Int
    ) throws {
        let decodedAdjusts = try container.decodeIfPresent(Adjusts.self, forKey: .adjusts) ?? .init()

        self.init(
            version: version,
            trim: try container.decodeIfPresent(Trim.self, forKey: .trim) ?? .init(),
            playback: try container.decodeIfPresent(Playback.self, forKey: .playback) ?? .init(),
            crop: try container.decodeIfPresent(Crop.self, forKey: .crop) ?? .init(),
            canvas: try container.decodeIfPresent(Canvas.self, forKey: .canvas) ?? .init(),
            adjusts: decodedAdjusts,
            frame: try container.decodeIfPresent(Frame.self, forKey: .frame) ?? .init(),
            audio: try container.decodeIfPresent(Audio.self, forKey: .audio) ?? .init(),
            transcript: try container.decodeIfPresent(Transcript.self, forKey: .transcript) ?? .init(),
            presentation: try container.decodeIfPresent(Presentation.self, forKey: .presentation) ?? .init()
        )
    }

    // MARK: - Private Methods

    private func migratedToCurrentSchema() -> Self {
        guard let schemaVersion else {
            return preservingVersion(version)
        }

        switch schemaVersion {
        case .v1:
            return preservingVersion(Self.currentSchemaVersion.rawValue)
                .clearingOpaquePayload()
        case .current:
            return preservingVersion(Self.currentSchemaVersion.rawValue)
                .clearingOpaquePayload()
        }
    }

    private func preservingVersion(_ version: Int) -> Self {
        var configuration = self
        configuration.version = version
        return configuration
    }

    private func clearingOpaquePayload() -> Self {
        var configuration = self
        configuration.opaquePayload = nil
        return configuration
    }

}

extension VideoEditingConfiguration {

    struct Trim: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var lowerBound: Double = 0
        var upperBound: Double = 0

    }

    struct Playback: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var rate: Float = 1
        var videoVolume: Float = 1
        var currentTimelineTime: Double?

    }

    struct Crop: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var rotationDegrees: Double = 0
        var isMirrored = false
        var freeformRect: FreeformRect?

    }

    struct FreeformRect: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var x: Double
        var y: Double
        var width: Double
        var height: Double

    }

    struct Adjusts: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var brightness: Double = 0
        var contrast: Double = 0
        var saturation: Double = 0

    }

    struct Canvas: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var snapshot: VideoCanvasSnapshot = .initial

    }

    struct Frame: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var scaleValue: Double = 0
        var colorToken: String?

    }

    struct Audio: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var recordedClip: RecordedClip?
        var selectedTrack: SelectedTrack = .video

    }

    struct RecordedClip: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var url: URL
        var duration: Double
        var volume: Float = 1

    }

    struct Transcript: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var featureState: TranscriptFeaturePersistenceState = .idle
        var document: TranscriptDocument?

    }

    struct Presentation: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var selectedTool: ToolEnum?
        var socialVideoDestination: SocialVideoDestination?
        var showsSafeAreaGuides = false

        // MARK: - Private Properties

        private enum CodingKeys: String, CodingKey {
            case selectedTool
            case socialVideoDestination
            case showsSafeAreaGuides
        }

        // MARK: - Initializer

        init(
            _ selectedTool: ToolEnum? = nil,
            socialVideoDestination: SocialVideoDestination? = nil,
            showsSafeAreaGuides: Bool = false
        ) {
            self.selectedTool = selectedTool
            self.socialVideoDestination = socialVideoDestination
            self.showsSafeAreaGuides = showsSafeAreaGuides
        }

        // MARK: - Public Methods

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let selectedToolRawValue = try container.decodeIfPresent(Int.self, forKey: .selectedTool) {
                selectedTool = ToolEnum(rawValue: selectedToolRawValue)
            } else {
                selectedTool = nil
            }

            socialVideoDestination = try container.decodeIfPresent(
                SocialVideoDestination.self,
                forKey: .socialVideoDestination
            )
            showsSafeAreaGuides =
                try container.decodeIfPresent(Bool.self, forKey: .showsSafeAreaGuides)
                ?? false
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(selectedTool?.rawValue, forKey: .selectedTool)
            try container.encodeIfPresent(socialVideoDestination, forKey: .socialVideoDestination)
            try container.encode(showsSafeAreaGuides, forKey: .showsSafeAreaGuides)
        }

    }

    enum SelectedTrack: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
        case video
        case recorded

        // MARK: - Public Properties

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .video:
                "Video"
            case .recorded:
                "Recorded"
            }
        }
    }

    enum SocialVideoDestination: String, Codable, CaseIterable, Equatable, Sendable {
        case instagramReels
        case tikTok
        case youtubeShorts

        // MARK: - Public Properties

        var title: String {
            switch self {
            case .instagramReels:
                "Instagram Reels"
            case .tikTok:
                "TikTok"
            case .youtubeShorts:
                "YouTube Shorts"
            }
        }

        var shortTitle: String {
            switch self {
            case .instagramReels:
                "Instagram"
            case .tikTok:
                "TikTok"
            case .youtubeShorts:
                "Shorts"
            }
        }
    }

}

extension VideoEditingConfiguration {

    // MARK: - Public Properties

    var continuousSaveFingerprint: Self {
        var configuration = self
        configuration.playback.currentTimelineTime = nil
        configuration.audio.selectedTrack = .video
        configuration.presentation.selectedTool = nil
        configuration.presentation.showsSafeAreaGuides = false
        configuration.canvas.snapshot.showsSafeAreaOverlay = false
        return configuration
    }

}

private enum OpaquePayload: Codable, Equatable, Sendable {

    // MARK: - Cases

    case object([String: Self])
    case array([Self])
    case string(String)
    case integer(Int64)
    case number(Double)
    case bool(Bool)
    case null

    // MARK: - Initializer

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let integer = try? container.decode(Int64.self) {
            self = .integer(integer)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([Self].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: Self].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported opaque JSON payload."
            )
        }
    }

    // MARK: - Public Methods

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .object(let object):
            try container.encode(object)
        case .array(let array):
            try container.encode(array)
        case .string(let string):
            try container.encode(string)
        case .integer(let integer):
            try container.encode(integer)
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        }
    }

}
