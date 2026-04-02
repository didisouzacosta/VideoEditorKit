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
            adjusts: .init(
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
            presentation: .init(
                .adjusts,
                socialVideoDestination: .tikTok,
                showsSafeAreaGuides: true
            )
        )

        let data = try JSONEncoder().encode(configuration)
        let decodedConfiguration = try JSONDecoder().decode(VideoEditingConfiguration.self, from: data)

        #expect(decodedConfiguration.version == VideoEditingConfiguration.currentSchemaVersion.rawValue)
        #expect(decodedConfiguration.schemaVersion == .current)
        #expect(decodedConfiguration == configuration)
        #expect(decodedConfiguration.presentation.showsSafeAreaGuides)
    }

    @Test
    func decodeCurrentAdjustsSnapshotWithoutVersionToCurrentSchemaVersion() throws {
        let currentJSON = """
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
              "adjusts": {
                "brightness": 0.15,
                "contrast": 0.35,
                "saturation": 0.6
              }
            }
            """
            .data(using: .utf8)

        let data = try #require(currentJSON)
        let configuration = try JSONDecoder().decode(VideoEditingConfiguration.self, from: data)

        #expect(configuration.version == VideoEditingConfiguration.currentSchemaVersion.rawValue)
        #expect(configuration.schemaVersion == .current)
        #expect(configuration.trim == .init(lowerBound: 2, upperBound: 8))
        #expect(abs(Double(configuration.playback.rate) - 1.25) < 0.0001)
        #expect(abs(configuration.adjusts.brightness - 0.15) < 0.0001)
        #expect(abs(configuration.adjusts.contrast - 0.35) < 0.0001)
        #expect(abs(configuration.adjusts.saturation - 0.6) < 0.0001)
    }

    @Test
    func removedSelectedToolDecodesAsNilInsteadOfFailing() throws {
        let json = """
            {
              "version": 1,
              "presentation": {
                "selectedTool": 5,
                "cropTab": "format"
              }
            }
            """
            .data(using: .utf8)

        let data = try #require(json)
        let configuration = try JSONDecoder().decode(VideoEditingConfiguration.self, from: data)

        #expect(configuration.presentation.selectedTool == nil)
        #expect(configuration.presentation.socialVideoDestination == nil)
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
        video.colorAdjusts = ColorAdjusts(
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

        let configuration = VideoEditingConfigurationMapper.makeConfiguration(
            from: video,
            freeformRect: .init(
                x: 0.2,
                y: 0.1,
                width: 0.55,
                height: 0.7
            ),
            canvasSnapshot: .init(
                preset: .social(platform: .youtubeShorts),
                transform: .init(
                    normalizedOffset: CGPoint(x: 0.12, y: -0.08),
                    zoom: 1.4,
                    rotationRadians: 0.33
                ),
                showsSafeAreaOverlay: true
            ),
            selectedAudioTrack: .recorded,
            selectedTool: .adjusts,
            socialVideoDestination: .youtubeShorts,
            showsSafeAreaGuides: true,
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
        #expect(abs(configuration.adjusts.brightness - 0.15) < 0.0001)
        #expect(abs(configuration.adjusts.contrast - 1.25) < 0.0001)
        #expect(abs(configuration.adjusts.saturation - 0.75) < 0.0001)
        #expect(abs(configuration.frame.scaleValue - 0.3) < 0.0001)
        #expect(configuration.frame.colorToken == "palette:teal")
        #expect(configuration.audio.recordedClip?.url == audioURL)
        #expect(abs(Double(configuration.audio.recordedClip?.volume ?? 0) - 0.4) < 0.0001)
        #expect(configuration.audio.selectedTrack == .recorded)
        #expect(configuration.presentation.selectedTool == .adjusts)
        #expect(configuration.presentation.socialVideoDestination == .youtubeShorts)
        #expect(configuration.presentation.showsSafeAreaGuides)
        #expect(configuration.canvas.snapshot.preset == .social(platform: .youtubeShorts))
        #expect(abs(configuration.canvas.snapshot.transform.normalizedOffset.x - 0.12) < 0.0001)
        #expect(abs(configuration.canvas.snapshot.transform.normalizedOffset.y + 0.08) < 0.0001)
        #expect(abs(configuration.canvas.snapshot.transform.zoom - 1.4) < 0.0001)
        #expect(abs(configuration.canvas.snapshot.transform.rotationRadians - 0.33) < 0.0001)
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
            adjusts: .init(
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
            presentation: .init(
                .adjusts,
                socialVideoDestination: .instagramReels,
                showsSafeAreaGuides: true
            )
        )

        var video = Video.mock

        VideoEditingConfigurationMapper.apply(configuration, to: &video)

        #expect(video.rangeDuration == 6...18)
        #expect(abs(Double(video.rate) - 2) < 0.0001)
        #expect(abs(Double(video.volume) - 0.35) < 0.0001)
        #expect(video.rotation == 270)
        #expect(video.isMirror)
        #expect(abs(video.colorAdjusts.brightness - 0.1) < 0.0001)
        #expect(abs(video.colorAdjusts.contrast - 1.2) < 0.0001)
        #expect(abs(video.colorAdjusts.saturation - 0.5) < 0.0001)
        #expect(abs((video.videoFrames?.scaleValue ?? 0) - 0.25) < 0.0001)
        #expect(SystemColorPalette.matches(video.videoFrames?.frameColor ?? .clear, Color(uiColor: .systemOrange)))
        #expect(video.audio?.url == audioURL)
        #expect(abs(Double(video.audio?.volume ?? 0) - 0.7) < 0.0001)
        #expect(video.isAppliedTool(for: .cut))
        #expect(video.isAppliedTool(for: .speed))
        #expect(video.isAppliedTool(for: .presets))
        #expect(video.isAppliedTool(for: .audio))
        #expect(video.isAppliedTool(for: .adjusts))
        #expect(VideoEditingConfigurationMapper.selectedAudioTrack(from: configuration) == .recorded)
    }

    @Test
    func decodeMissingSafeAreaGuidesDefaultsToVisibleForSavedSocialDestinations() throws {
        let json = """
            {
              "version": 3,
              "presentation": {
                "cropTab": "format",
                "socialVideoDestination": "tikTok"
              }
            }
            """
            .data(using: .utf8)

        let data = try #require(json)
        let configuration = try JSONDecoder().decode(VideoEditingConfiguration.self, from: data)

        #expect(configuration.presentation.socialVideoDestination == .tikTok)
        #expect(configuration.presentation.showsSafeAreaGuides)
    }

    @Test
    func configurationCodableRoundTripPreservesCanvasSnapshot() throws {
        let configuration = VideoEditingConfiguration(
            canvas: .init(
                snapshot: .init(
                    preset: .facebookPost,
                    freeCanvasSize: CGSize(width: 1080, height: 1350),
                    transform: .init(
                        normalizedOffset: CGPoint(x: -0.22, y: 0.14),
                        zoom: 1.8,
                        rotationRadians: 0.42
                    ),
                    showsSafeAreaOverlay: false
                )
            )
        )

        let data = try JSONEncoder().encode(configuration)
        let decodedConfiguration = try JSONDecoder().decode(VideoEditingConfiguration.self, from: data)

        #expect(decodedConfiguration.canvas.snapshot == configuration.canvas.snapshot)
    }

}
