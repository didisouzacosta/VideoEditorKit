//
//  VideoEditingConfiguration.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 27.03.2026.
//

import Foundation

struct VideoEditingConfiguration: Codable, Equatable, Sendable {

    // MARK: - Public Properties

    static let initial = Self()

    var trim = Trim()
    var playback = Playback()
    var crop = Crop()
    var filter = Filter()
    var frame = Frame()
    var audio = Audio()
    var textOverlays: [TextOverlay] = []
    var presentation = Presentation()

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

    struct Filter: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var filterName: String?
        var brightness: Double = 0
        var contrast: Double = 0
        var saturation: Double = 0

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

    struct TextOverlay: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var id: UUID
        var text: String
        var fontSize: Double
        var backgroundColorToken: String
        var fontColorToken: String
        var timeRange: Trim
        var offset: Offset

    }

    struct Offset: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var x: Double
        var y: Double

    }

    struct Presentation: Codable, Equatable, Sendable {

        // MARK: - Public Properties

        var selectedTool: ToolEnum?
        var cropTab: CropTab = .rotate

    }

    enum SelectedTrack: String, Codable, Equatable, Sendable {
        case video
        case recorded
    }

    enum CropTab: String, Codable, Equatable, Sendable {
        case format
        case rotate
    }

}
