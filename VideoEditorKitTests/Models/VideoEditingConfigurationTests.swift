import Foundation
import SwiftUI
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("VideoEditingConfigurationTests")
struct VideoEditingConfigurationTests {

    // MARK: - Public Methods

    @Test
    func configurationCodableRoundTripPreservesSerializableEditingState() throws {
        let configuration = VideoEditingConfiguration(
            trim: .init(lowerBound: 4, upperBound: 22),
            playback: .init(
                rate: 1.75,
                videoVolume: 0.45,
                currentTimelineTime: 12
            ),
            crop: .init(
                rotationDegrees: 180,
                isMirrored: true,
                freeformRect: .init(
                    x: 0.1,
                    y: 0.2,
                    width: 0.6,
                    height: 0.4
                )
            ),
            filter: .init(
                filterName: "CIPhotoEffectNoir",
                brightness: 0.2,
                contrast: 1.1,
                saturation: 0.8
            ),
            frame: .init(
                scaleValue: 0.3,
                colorToken: "palette:teal"
            ),
            audio: .init(
                recordedClip: .init(
                    url: URL(fileURLWithPath: "/tmp/test-audio.m4a"),
                    duration: 3,
                    volume: 0.8
                ),
                selectedTrack: .recorded
            ),
            textOverlays: [
                .init(
                    id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
                    text: "Overlay",
                    fontSize: 24,
                    backgroundColorToken: "palette:blue",
                    fontColorToken: "palette:label",
                    timeRange: .init(lowerBound: 2, upperBound: 5),
                    offset: .init(x: 0.12, y: -0.08)
                )
            ],
            presentation: .init(
                selectedTool: .filters,
                cropTab: .rotate
            )
        )

        let data = try JSONEncoder().encode(configuration)
        let decodedConfiguration = try JSONDecoder().decode(VideoEditingConfiguration.self, from: data)

        #expect(decodedConfiguration.version == VideoEditingConfiguration.currentSchemaVersion.rawValue)
        #expect(decodedConfiguration.schemaVersion == .normalizedTextOverlayOffsets)
        #expect(decodedConfiguration == configuration)
    }

    @Test
    func decodeMigratesLegacySnapshotWithoutVersionToCurrentSchemaVersion() throws {
        let legacyJSON = """
            {
              "trim": {
                "lowerBound": 2,
                "upperBound": 8
              },
              "playback": {
                "rate": 1.25,
                "videoVolume": 0.5,
                "currentTimelineTime": 3
              },
              "textOverlays": [
                {
                  "id": "11111111-2222-3333-4444-555555555555",
                  "text": "Legacy",
                  "fontSize": 22,
                  "backgroundColorToken": "palette:background",
                  "fontColorToken": "palette:label",
                  "timeRange": {
                    "lowerBound": 1,
                    "upperBound": 4
                  },
                  "offset": {
                    "x": 18,
                    "y": -12
                  }
                }
              ]
            }
            """
            .data(using: .utf8)

        let data = try #require(legacyJSON)
        let configuration = try JSONDecoder().decode(VideoEditingConfiguration.self, from: data)

        #expect(configuration.version == VideoEditingConfiguration.currentSchemaVersion.rawValue)
        #expect(configuration.schemaVersion == .normalizedTextOverlayOffsets)
        #expect(configuration.trim == .init(lowerBound: 2, upperBound: 8))
        #expect(abs(Double(configuration.playback.rate) - 1.25) < 0.0001)
        #expect(configuration.textOverlays.count == 1)
        #expect(configuration.textOverlays[0].offset == .init(x: 18, y: -12))
    }

    @Test
    func encodeAlwaysWritesTheCurrentSchemaVersion() throws {
        let configuration = VideoEditingConfiguration(version: 1)

        let data = try JSONEncoder().encode(configuration)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"version\":\(VideoEditingConfiguration.currentSchemaVersion.rawValue)"))
    }

    @Test
    func unknownFutureVersionIsPreservedForTheDecodedValue() throws {
        let futureJSON = """
            {
              "version": 99,
              "trim": {
                "lowerBound": 1,
                "upperBound": 2
              }
            }
            """
            .data(using: .utf8)

        let data = try #require(futureJSON)
        let configuration = try JSONDecoder().decode(VideoEditingConfiguration.self, from: data)

        #expect(configuration.version == 99)
        #expect(configuration.schemaVersion == nil)
    }

    @Test
    func unknownFutureVersionRoundTripsWithoutDowngradingOrDroppingUnknownFields() throws {
        let futureJSON = """
            {
              "version": 99,
              "trim": {
                "lowerBound": 1,
                "upperBound": 2
              },
              "futureField": {
                "mode": "cinematic",
                "passes": [
                  1,
                  2,
                  3
                ]
              }
            }
            """
            .data(using: .utf8)

        let data = try #require(futureJSON)
        let configuration = try JSONDecoder().decode(VideoEditingConfiguration.self, from: data)
        let reencodedData = try JSONEncoder().encode(configuration)

        let originalObject = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let reencodedObject = try #require(JSONSerialization.jsonObject(with: reencodedData) as? NSDictionary)

        #expect(configuration.version == 99)
        #expect(configuration.schemaVersion == nil)
        #expect(reencodedObject == originalObject)
    }

    @Test
    func makeConfigurationCapturesCurrentEditableVideoState() throws {
        let audioURL = try TestFixtures.createTemporaryAudio()
        defer { FileManager.default.removeIfExists(for: audioURL) }

        var video = Video.mock
        video.rangeDuration = 5...15
        video.updateRate(1.5)
        video.rotation = 90
        video.isMirror = true
        video.setFilter("CIPhotoEffectNoir")
        video.colorCorrection = ColorCorrection(
            brightness: 0.15,
            contrast: 1.25,
            saturation: 0.75
        )
        video.videoFrames = VideoFrames(
            scaleValue: 0.3,
            frameColor: Color(uiColor: .systemTeal)
        )
        video.audio = Audio(
            url: audioURL,
            duration: 3,
            volume: 0.4
        )
        video.setVolume(0.65)
        video.geometrySize = CGSize(width: 240, height: 120)
        video.textBoxes = [
            TextBox(
                text: "Hello",
                fontSize: 32,
                bgColor: Color(uiColor: .systemBlue),
                fontColor: Color(uiColor: .label),
                timeRange: 1...4,
                offset: CGSize(width: 24, height: -10)
            )
        ]

        let configuration = VideoEditingConfigurationMapper.makeConfiguration(
            from: video,
            freeformRect: .init(
                x: 0.2,
                y: 0.1,
                width: 0.55,
                height: 0.7
            ),
            selectedAudioTrack: .recorded,
            selectedTool: .filters,
            cropTab: .rotate,
            currentTimelineTime: 7
        )

        #expect(configuration.trim.lowerBound == 5)
        #expect(configuration.trim.upperBound == 15)
        #expect(abs(Double(configuration.playback.rate) - 1.5) < 0.0001)
        #expect(abs(Double(configuration.playback.videoVolume) - 0.65) < 0.0001)
        #expect(configuration.playback.currentTimelineTime == 7)
        #expect(configuration.crop.rotationDegrees == 90)
        #expect(configuration.crop.isMirrored)
        #expect(
            configuration.crop.freeformRect
                == .init(
                    x: 0.2,
                    y: 0.1,
                    width: 0.55,
                    height: 0.7
                )
        )
        #expect(configuration.filter.filterName == "CIPhotoEffectNoir")
        #expect(abs(configuration.filter.brightness - 0.15) < 0.0001)
        #expect(abs(configuration.filter.contrast - 1.25) < 0.0001)
        #expect(abs(configuration.filter.saturation - 0.75) < 0.0001)
        #expect(abs(configuration.frame.scaleValue - 0.3) < 0.0001)
        #expect(configuration.frame.colorToken == "palette:teal")
        #expect(configuration.audio.recordedClip?.url == audioURL)
        #expect(abs(Double(configuration.audio.recordedClip?.volume ?? 0) - 0.4) < 0.0001)
        #expect(configuration.audio.selectedTrack == .recorded)
        #expect(configuration.presentation.selectedTool == .filters)
        #expect(configuration.presentation.cropTab == .rotate)
        #expect(configuration.textOverlays.count == 1)
        #expect(configuration.textOverlays[0].backgroundColorToken == "palette:blue")
        #expect(configuration.textOverlays[0].fontColorToken == "palette:label")
        #expect(abs(configuration.textOverlays[0].offset.x - 0.1) < 0.0001)
        #expect(abs(configuration.textOverlays[0].offset.y + 0.0833333333) < 0.0001)
    }

    @Test
    func applyRestoresSerializableEditingStateIntoRuntimeVideo() throws {
        let audioURL = try TestFixtures.createTemporaryAudio()
        defer { FileManager.default.removeIfExists(for: audioURL) }

        let configuration = VideoEditingConfiguration(
            trim: .init(lowerBound: 6, upperBound: 18),
            playback: .init(
                rate: 2,
                videoVolume: 0.35,
                currentTimelineTime: 4
            ),
            crop: .init(
                rotationDegrees: 270,
                isMirrored: true,
                freeformRect: nil
            ),
            filter: .init(
                filterName: "CIPhotoEffectMono",
                brightness: 0.1,
                contrast: 1.2,
                saturation: 0.5
            ),
            frame: .init(
                scaleValue: 0.25,
                colorToken: "palette:orange"
            ),
            audio: .init(
                recordedClip: .init(
                    url: audioURL,
                    duration: 5,
                    volume: 0.7
                ),
                selectedTrack: .recorded
            ),
            textOverlays: [
                .init(
                    id: UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID(),
                    text: "Restored",
                    fontSize: 28,
                    backgroundColorToken: "palette:red",
                    fontColorToken: "palette:background",
                    timeRange: .init(lowerBound: 3, upperBound: 6),
                    offset: .init(x: 0.05, y: -0.0428571429)
                )
            ],
            presentation: .init(
                selectedTool: .text,
                cropTab: .format
            )
        )

        var video = Video.mock
        video.geometrySize = CGSize(width: 280, height: 140)

        VideoEditingConfigurationMapper.apply(configuration, to: &video)

        #expect(video.rangeDuration == 6...18)
        #expect(abs(Double(video.rate) - 2) < 0.0001)
        #expect(abs(Double(video.volume) - 0.35) < 0.0001)
        #expect(video.rotation == 270)
        #expect(video.isMirror)
        #expect(video.filterName == "CIPhotoEffectMono")
        #expect(abs(video.colorCorrection.brightness - 0.1) < 0.0001)
        #expect(abs(video.colorCorrection.contrast - 1.2) < 0.0001)
        #expect(abs(video.colorCorrection.saturation - 0.5) < 0.0001)
        #expect(abs((video.videoFrames?.scaleValue ?? 0) - 0.25) < 0.0001)
        #expect(SystemColorPalette.matches(video.videoFrames?.frameColor ?? .clear, Color(uiColor: .systemOrange)))
        #expect(video.audio?.url == audioURL)
        #expect(abs(Double(video.audio?.volume ?? 0) - 0.7) < 0.0001)
        #expect(video.textBoxes.count == 1)
        #expect(video.textBoxes[0].text == "Restored")
        #expect(SystemColorPalette.matches(video.textBoxes[0].bgColor, Color(uiColor: .systemRed)))
        #expect(SystemColorPalette.matches(video.textBoxes[0].fontColor, Color(uiColor: .systemBackground)))
        #expect(video.textBoxes[0].timeRange == 3...6)
        #expect(abs(video.textBoxes[0].offset.width - 14) < 0.0001)
        #expect(abs(video.textBoxes[0].offset.height + 6) < 0.0001)
        #expect(abs(video.textBoxes[0].lastOffset.width - 14) < 0.0001)
        #expect(abs(video.textBoxes[0].lastOffset.height + 6) < 0.0001)
        #expect(video.isAppliedTool(for: .cut))
        #expect(video.isAppliedTool(for: .speed))
        #expect(video.isAppliedTool(for: .crop))
        #expect(video.isAppliedTool(for: .audio))
        #expect(video.isAppliedTool(for: .text))
        #expect(video.isAppliedTool(for: .filters))
        #expect(video.isAppliedTool(for: .corrections))
        #expect(video.isAppliedTool(for: .frames))
        #expect(VideoEditingConfigurationMapper.selectedAudioTrack(from: configuration) == .recorded)
        #expect(VideoEditingConfigurationMapper.cropTab(from: configuration) == .format)
    }

    @Test
    func applySupportsLegacyRawTextOverlayOffsetsForBackwardCompatibility() {
        let configuration = VideoEditingConfiguration(
            textOverlays: [
                .init(
                    id: UUID(),
                    text: "Legacy",
                    fontSize: 20,
                    backgroundColorToken: "palette:background",
                    fontColorToken: "palette:label",
                    timeRange: .init(lowerBound: 1, upperBound: 3),
                    offset: .init(x: 18, y: -12)
                )
            ]
        )

        var video = Video.mock
        video.geometrySize = CGSize(width: 300, height: 150)

        VideoEditingConfigurationMapper.apply(configuration, to: &video)

        #expect(video.textBoxes.count == 1)
        #expect(abs(video.textBoxes[0].offset.width - 18) < 0.0001)
        #expect(abs(video.textBoxes[0].offset.height + 12) < 0.0001)
    }

}
