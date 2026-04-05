//
//  TranscriptModels.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

struct TranscriptDocument: Codable, Hashable, Sendable {

    // MARK: - Public Properties

    var segments: [EditableTranscriptSegment] = []
    var availableStyles: [TranscriptStyle] = []
    var overlayPosition: TranscriptOverlayPosition = .bottom
    var overlaySize: TranscriptOverlaySize = .medium

}

struct EditableTranscriptSegment: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Public Properties

    let id: UUID
    var timeMapping: TranscriptTimeMapping
    var originalText: String
    var editedText: String
    var words: [EditableTranscriptWord] = []
    var styleID: TranscriptStyle.ID?

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

    typealias ID = UUID

    // MARK: - Public Properties

    let id: ID
    var name: String
    var fontFamily: String
    var isItalic = false
    var hasStroke = false
    var textAlignment: TranscriptTextAlignment = .center
    var textColor: RGBAColor = .white
    var strokeColor: RGBAColor?

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

enum TranscriptOverlayPosition: String, Codable, Hashable, Sendable {
    case top
    case center
    case bottom
}

enum TranscriptOverlaySize: String, Codable, Hashable, Sendable {
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
