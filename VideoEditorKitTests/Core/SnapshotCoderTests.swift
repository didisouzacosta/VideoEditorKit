import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct SnapshotCoderTests {

    @Test func makeSnapshotPreservesPersistableProjectData() throws {
        let coder = SnapshotCoder()
        let project = makeProject()

        let snapshot = try coder.makeSnapshot(from: project)

        #expect(snapshot.sourceVideoPath == "/tmp/source-video.mov")
        #expect(snapshot.preset == .tiktok)
        #expect(snapshot.gravity == .fill)
        #expect(snapshot.selectedTimeRange == 3...18)
        #expect(snapshot.adjustments.playbackRate == 1.5)
        #expect(snapshot.adjustments.rotation == .degrees90)
        #expect(snapshot.adjustments.isMirrored)
        #expect(snapshot.adjustments.filterName == "CISepiaTone")
        #expect(snapshot.adjustments.colorCorrection == .init(
            brightness: 0.1,
            contrast: -0.2,
            saturation: 0.35
        ))
        #expect(snapshot.adjustments.frameStyle == .init(
            backgroundColorHex: "0000FFFF",
            scale: 0.82
        ))
        #expect(snapshot.captions.count == 2)

        let firstCaption = try #require(snapshot.captions.first)
        #expect(firstCaption.text == "Hello")
        #expect(firstCaption.position.mode == .freeform)
        #expect(firstCaption.position.normalizedX == 0.25)
        #expect(firstCaption.position.normalizedY == 0.8)
        #expect(firstCaption.style.fontName == "SFProText-Bold")
        #expect(firstCaption.style.fontSize == 18)
        #expect(firstCaption.style.textColorHex == "FFFFFFFF")
        #expect(firstCaption.style.backgroundColorHex == "000000FF")

        let secondCaption = snapshot.captions[1]
        #expect(secondCaption.position.mode == .preset(.top))
    }

    @Test func makeProjectReconstructsRuntimeProject() throws {
        let coder = SnapshotCoder()

        let project = try coder.makeProject(from: makeSnapshot())

        #expect(project.sourceVideoURL == URL(fileURLWithPath: "/tmp/source-video.mov"))
        #expect(project.preset == .instagram)
        #expect(project.gravity == .fit)
        #expect(project.selectedTimeRange == 1...9)
        #expect(project.adjustments.playbackRate == 0.75)
        #expect(project.adjustments.rotation == .degrees270)
        #expect(project.adjustments.isMirrored)
        #expect(project.adjustments.filterName == "CIPhotoEffectNoir")
        #expect(project.adjustments.colorCorrection == VideoColorCorrection(
            brightness: 0.2,
            contrast: 0.1,
            saturation: -0.25
        ))
        #expect(project.captions.count == 2)
        #expect(project.captions[0].placementMode == .freeform)
        #expect(project.captions[1].placementMode == .preset(.bottom))
        #expect(project.captions[0].position == CGPoint(x: 0.4, y: 0.6))
        #expect(project.captions[0].style.fontName == "SFProText-Regular")
        #expect(project.captions[0].style.fontSize == 16)
        assertColor(project.captions[0].style.textColor, equals: .white)
        assertColor(project.captions[0].style.backgroundColor, equals: .black)
        assertColor(project.adjustments.frameStyle?.backgroundColor, equals: .blue)
        #expect(project.adjustments.frameStyle?.scale == 0.7)
    }

    @Test func encodeAndDecodeProjectRoundTripsThroughData() throws {
        let coder = SnapshotCoder()
        let project = makeProject()

        let data = try coder.encode(project)
        let restoredProject = try coder.decodeProject(from: data)

        #expect(restoredProject.sourceVideoURL == project.sourceVideoURL)
        #expect(restoredProject.preset == project.preset)
        #expect(restoredProject.gravity == project.gravity)
        #expect(restoredProject.selectedTimeRange == project.selectedTimeRange)
        #expect(restoredProject.adjustments == project.adjustments)
        #expect(restoredProject.captions.count == project.captions.count)
        #expect(restoredProject.captions[0].placementMode == project.captions[0].placementMode)
        #expect(restoredProject.captions[1].placementMode == project.captions[1].placementMode)
        #expect(restoredProject.captions[0].position == project.captions[0].position)
        assertColor(restoredProject.captions[0].style.textColor, equals: project.captions[0].style.textColor)
        assertColor(restoredProject.captions[0].style.backgroundColor, equals: project.captions[0].style.backgroundColor)
    }

    @Test func makeSnapshotFailsForNonFileURL() {
        let coder = SnapshotCoder()
        let project = VideoProject(
            sourceVideoURL: URL(string: "https://example.com/video.mov")!,
            captions: [],
            preset: .original,
            gravity: .fit,
            selectedTimeRange: 0...10
        )

        #expect(throws: VideoEditorError.snapshotEncodingFailed) {
            try coder.makeSnapshot(from: project)
        }
    }

    @Test func decodeProjectFailsForEmptySourceVideoPath() throws {
        let coder = SnapshotCoder()
        var snapshot = makeSnapshot()
        snapshot.sourceVideoPath = ""

        let data = try coder.encode(snapshot: snapshot)

        #expect(throws: VideoEditorError.snapshotDecodingFailed) {
            try coder.decodeProject(from: data)
        }
    }

    @Test func decodeProjectFailsForInvalidColorHex() throws {
        let coder = SnapshotCoder()
        var snapshot = makeSnapshot()
        snapshot.captions[0].style.textColorHex = "ZZZZZZZZ"

        let data = try coder.encode(snapshot: snapshot)

        #expect(throws: VideoEditorError.snapshotDecodingFailed) {
            try coder.decodeProject(from: data)
        }
    }

    @Test func decodeProjectFailsForOutOfBoundsNormalizedPosition() throws {
        let coder = SnapshotCoder()
        var snapshot = makeSnapshot()
        snapshot.captions[0].position.normalizedY = 1.5

        let data = try coder.encode(snapshot: snapshot)

        #expect(throws: VideoEditorError.snapshotDecodingFailed) {
            try coder.decodeProject(from: data)
        }
    }

    @Test func decodeProjectFailsForInvalidSelectedTimeRange() throws {
        let coder = SnapshotCoder()
        let data = Data(
            """
            {
              "sourceVideoPath": "/tmp/source-video.mov",
              "captions": [],
              "preset": "instagram",
              "gravity": "fit",
              "selectedTimeRange": [9, 1],
              "adjustments": {
                "playbackRate": 1,
                "rotation": "degrees0",
                "isMirrored": false,
                "filterName": null,
                "colorCorrection": {
                  "brightness": 0,
                  "contrast": 0,
                  "saturation": 0
                },
                "frameStyle": null
              }
            }
            """.utf8
        )

        #expect(throws: VideoEditorError.snapshotDecodingFailed) {
            try coder.decodeProject(from: data)
        }
    }

    @Test func decodeProjectDefaultsMissingAdjustmentsToNeutralValues() throws {
        let coder = SnapshotCoder()
        let data = Data(
            """
            {
              "sourceVideoPath": "/tmp/source-video.mov",
              "captions": [],
              "preset": "instagram",
              "gravity": "fit",
              "selectedTimeRange": [1, 9]
            }
            """.utf8
        )

        let project = try coder.decodeProject(from: data)

        #expect(project.adjustments == .init())
    }
}

private extension SnapshotCoderTests {
    func makeProject() -> VideoProject {
        VideoProject(
            sourceVideoURL: URL(fileURLWithPath: "/tmp/source-video.mov"),
            captions: [
                Caption(
                    id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                    text: "Hello",
                    startTime: 3,
                    endTime: 8,
                    position: CGPoint(x: 0.25, y: 0.8),
                    placementMode: .freeform,
                    style: CaptionStyle(
                        fontName: "SFProText-Bold",
                        fontSize: 18,
                        textColor: .white,
                        backgroundColor: .black,
                        padding: 12,
                        cornerRadius: 10
                    )
                ),
                Caption(
                    id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                    text: "Preset",
                    startTime: 9,
                    endTime: 15,
                    position: CGPoint(x: 0.5, y: 0.15),
                    placementMode: .preset(.top),
                    style: CaptionStyle(
                        fontName: "SFProText-Regular",
                        fontSize: 20,
                        textColor: .yellow,
                        backgroundColor: nil,
                        padding: 10,
                        cornerRadius: 6
                    )
                )
            ],
            preset: .tiktok,
            gravity: .fill,
            selectedTimeRange: 3...18,
            adjustments: VideoAdjustmentSettings(
                playbackRate: 1.5,
                rotation: .degrees90,
                isMirrored: true,
                filterName: "CISepiaTone",
                colorCorrection: VideoColorCorrection(
                    brightness: 0.1,
                    contrast: -0.2,
                    saturation: 0.35
                ),
                frameStyle: VideoFrameStyle(
                    backgroundColor: .blue,
                    scale: 0.82
                )
            )
        )
    }

    func makeSnapshot() -> VideoProjectSnapshot {
        VideoProjectSnapshot(
            sourceVideoPath: "/tmp/source-video.mov",
            captions: [
                CaptionSnapshot(
                    id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                    text: "Hello",
                    startTime: 1,
                    endTime: 4,
                    position: CaptionPositionSnapshot(
                        mode: .freeform,
                        normalizedX: 0.4,
                        normalizedY: 0.6
                    ),
                    style: CaptionStyleSnapshot(
                        fontName: "SFProText-Regular",
                        fontSize: 16,
                        textColorHex: "FFFFFFFF",
                        backgroundColorHex: "000000FF",
                        padding: 12,
                        cornerRadius: 8
                    )
                ),
                CaptionSnapshot(
                    id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                    text: "Preset",
                    startTime: 5,
                    endTime: 8,
                    position: CaptionPositionSnapshot(
                        mode: .preset(.bottom),
                        normalizedX: 0.5,
                        normalizedY: 0.85
                    ),
                    style: CaptionStyleSnapshot(
                        fontName: "SFProText-Bold",
                        fontSize: 22,
                        textColorHex: "FFFF00FF",
                        backgroundColorHex: nil,
                        padding: 14,
                        cornerRadius: 12
                    )
                )
            ],
            preset: .instagram,
            gravity: .fit,
            selectedTimeRange: 1...9,
            adjustments: VideoAdjustmentSettingsSnapshot(
                playbackRate: 0.75,
                rotation: .degrees270,
                isMirrored: true,
                filterName: "CIPhotoEffectNoir",
                colorCorrection: .init(
                    brightness: 0.2,
                    contrast: 0.1,
                    saturation: -0.25
                ),
                frameStyle: .init(
                    backgroundColorHex: "0000FFFF",
                    scale: 0.7
                )
            )
        )
    }

    func assertColor(
        _ actual: UIColor?,
        equals expected: UIColor?,
        tolerance: CGFloat = 0.0001
    ) {
        switch (actual, expected) {
        case (nil, nil):
            return
        case let (.some(actualColor), .some(expectedColor)):
            let actualComponents = rgbaComponents(from: actualColor)
            let expectedComponents = rgbaComponents(from: expectedColor)

            #expect(abs(actualComponents.red - expectedComponents.red) <= tolerance)
            #expect(abs(actualComponents.green - expectedComponents.green) <= tolerance)
            #expect(abs(actualComponents.blue - expectedComponents.blue) <= tolerance)
            #expect(abs(actualComponents.alpha - expectedComponents.alpha) <= tolerance)
        default:
            Issue.record("Expected both colors to be nil or non-nil")
        }
    }

    func rgbaComponents(from color: UIColor) -> (
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat
    ) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        let resolvedColor = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        guard resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            Issue.record("Unable to extract RGBA components from color")
            return (0, 0, 0, 0)
        }

        return (red, green, blue, alpha)
    }
}
