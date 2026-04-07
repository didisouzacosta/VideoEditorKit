//
//  TranscriptModels.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

struct TranscriptDocument: Codable, Hashable, Sendable {

    enum CodingKeys: String, CodingKey {
        case segments
        case overlayPosition
        case overlaySize
        case availableStyles
        case selectedStyleID
    }

    // MARK: - Public Properties

    var segments: [EditableTranscriptSegment] = []
    var overlayPosition: TranscriptOverlayPosition = .bottom
    var overlaySize: TranscriptOverlaySize = .medium

    // MARK: - Initializer

    init(
        segments: [EditableTranscriptSegment] = [],
        overlayPosition: TranscriptOverlayPosition = .bottom,
        overlaySize: TranscriptOverlaySize = .medium
    ) {
        self.segments = segments
        self.overlayPosition = overlayPosition
        self.overlaySize = overlaySize
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        segments = try container.decodeIfPresent([EditableTranscriptSegment].self, forKey: .segments) ?? []
        overlayPosition =
            try container.decodeIfPresent(TranscriptOverlayPosition.self, forKey: .overlayPosition)
            ?? .bottom
        overlaySize =
            try container.decodeIfPresent(TranscriptOverlaySize.self, forKey: .overlaySize)
            ?? .medium

        // Ignore legacy style fields while remaining backward compatible with persisted snapshots.
        _ = try container.decodeIfPresent([TranscriptStyle].self, forKey: .availableStyles)
        _ = try container.decodeIfPresent(TranscriptStyle.StyleIdentifier.self, forKey: .selectedStyleID)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(segments, forKey: .segments)
        try container.encode(overlayPosition, forKey: .overlayPosition)
        try container.encode(overlaySize, forKey: .overlaySize)
    }

}

struct EditableTranscriptSegment: Identifiable, Codable, Hashable, Sendable {

    enum CodingKeys: String, CodingKey {
        case id
        case timeMapping
        case originalText
        case editedText
        case words
        case styleID
    }

    // MARK: - Public Properties

    let id: UUID
    var timeMapping: TranscriptTimeMapping
    var originalText: String
    var editedText: String
    var words: [EditableTranscriptWord] = []

    // MARK: - Initializer

    init(
        id: UUID,
        timeMapping: TranscriptTimeMapping,
        originalText: String,
        editedText: String,
        words: [EditableTranscriptWord] = []
    ) {
        self.id = id
        self.timeMapping = timeMapping
        self.originalText = originalText
        self.editedText = editedText
        self.words = words
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timeMapping = try container.decode(TranscriptTimeMapping.self, forKey: .timeMapping)
        originalText = try container.decode(String.self, forKey: .originalText)
        editedText = try container.decode(String.self, forKey: .editedText)
        words = try container.decodeIfPresent([EditableTranscriptWord].self, forKey: .words) ?? []

        // Ignore legacy per-segment style overrides from older snapshots.
        _ = try container.decodeIfPresent(TranscriptStyle.StyleIdentifier.self, forKey: .styleID)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timeMapping, forKey: .timeMapping)
        try container.encode(originalText, forKey: .originalText)
        try container.encode(editedText, forKey: .editedText)
        try container.encode(words, forKey: .words)
    }

}

struct EditableTranscriptWord: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Public Properties

    let id: UUID
    var timeMapping: TranscriptTimeMapping
    let originalText: String
    var editedText: String

}

struct TranscriptTimeMapping: Codable, Hashable, Sendable {

    // MARK: - Public Properties

    var sourceStartTime: Double
    var sourceEndTime: Double
    var timelineStartTime: Double?
    var timelineEndTime: Double?

    var sourceRange: ClosedRange<Double> {
        sourceStartTime...sourceEndTime
    }

    var timelineRange: ClosedRange<Double>? {
        guard let timelineStartTime, let timelineEndTime else { return nil }
        return timelineStartTime...timelineEndTime
    }

}

struct TranscriptStyle: Identifiable, Codable, Hashable, Sendable {

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fontWeight
        case hasStroke
        case textAlignment
        case textColor
        case strokeColor
        case fontFamily
        case isItalic
    }

    typealias StyleIdentifier = UUID

    // MARK: - Public Properties

    let id: StyleIdentifier
    var name: String
    var fontWeight: TranscriptFontWeight = .bold
    var hasStroke = false
    var textAlignment: TranscriptTextAlignment = .center
    var textColor: RGBAColor = .white
    var strokeColor: RGBAColor?

    // MARK: - Initializer

    init(
        id: StyleIdentifier,
        name: String,
        fontWeight: TranscriptFontWeight = .bold,
        hasStroke: Bool = false,
        textAlignment: TranscriptTextAlignment = .center,
        textColor: RGBAColor = .white,
        strokeColor: RGBAColor? = nil
    ) {
        self.id = id
        self.name = name
        self.fontWeight = fontWeight
        self.hasStroke = hasStroke
        self.textAlignment = textAlignment
        self.textColor = textColor
        self.strokeColor = strokeColor
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyFontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily)
        let legacyIsItalic = try container.decodeIfPresent(Bool.self, forKey: .isItalic) ?? false

        id = try container.decode(StyleIdentifier.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        fontWeight =
            try container.decodeIfPresent(TranscriptFontWeight.self, forKey: .fontWeight)
            ?? Self.fallbackFontWeight(
                legacyFontFamily: legacyFontFamily,
                legacyIsItalic: legacyIsItalic
            )
        hasStroke = try container.decodeIfPresent(Bool.self, forKey: .hasStroke) ?? false
        textAlignment =
            try container.decodeIfPresent(TranscriptTextAlignment.self, forKey: .textAlignment)
            ?? .center
        textColor = try container.decodeIfPresent(RGBAColor.self, forKey: .textColor) ?? .white
        strokeColor = try container.decodeIfPresent(RGBAColor.self, forKey: .strokeColor)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(fontWeight, forKey: .fontWeight)
        try container.encode(hasStroke, forKey: .hasStroke)
        try container.encode(textAlignment, forKey: .textAlignment)
        try container.encode(textColor, forKey: .textColor)
        try container.encodeIfPresent(strokeColor, forKey: .strokeColor)
    }

    // MARK: - Private Methods

    private static func fallbackFontWeight(
        legacyFontFamily _: String?,
        legacyIsItalic: Bool
    ) -> TranscriptFontWeight {
        legacyIsItalic ? .heavy : .bold
    }

}

extension TranscriptStyle {

    // MARK: - Public Properties

    static let defaultCaptionStyle = Self(
        id: UUID(uuidString: "E5A04D11-329A-4C8E-B266-1E6A60A6F9F9") ?? UUID(),
        name: "Default",
        fontWeight: .semibold,
        hasStroke: true,
        textAlignment: .center,
        textColor: .white,
        strokeColor: .init(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )
    )

}

struct RGBAColor: Codable, Hashable, Sendable {

    // MARK: - Public Properties

    static let white = Self(red: 1, green: 1, blue: 1, alpha: 1)
    static let black = Self(red: 0, green: 0, blue: 0, alpha: 1)

    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

}

enum TranscriptTextAlignment: String, Codable, Hashable, Sendable {
    case leading
    case center
    case trailing
}

enum TranscriptFontWeight: String, Codable, Hashable, Sendable, CaseIterable {
    case regular
    case semibold
    case bold
    case heavy
}

enum TranscriptOverlayPosition: String, Codable, Hashable, Sendable, CaseIterable {
    case top
    case center
    case bottom
}

enum TranscriptOverlaySize: String, Codable, Hashable, Sendable, CaseIterable {
    case small
    case medium
    case large
}

enum TranscriptFeaturePersistenceState: String, Codable, Equatable, Sendable {
    case idle
    case loaded
    case failed
}

enum TranscriptFeatureState: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case failed(TranscriptError)
}

enum TranscriptError: Error, Sendable, Equatable {
    case providerNotConfigured
    case invalidVideoSource
    case emptyResult
    case cancelled
    case providerFailure(message: String)
}
