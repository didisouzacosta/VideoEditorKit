import CoreGraphics
import Testing
import UIKit

@testable import VideoEditorKit

@Suite("VideoEditorExportCharacterizationTests")
struct VideoEditorExportCharacterizationTests {

    // MARK: - Public Methods

    @Test
    func startRenderScalesBaseExportResolutionAcrossQualities() async throws {
        let sourceVideoURL = try await makeFixtureVideo()
        let video = await Video.load(from: sourceVideoURL)

        let snapshots = try await exportSnapshots(
            for: video,
            editingConfiguration: .initial
        )

        defer {
            cleanup(urls: [sourceVideoURL] + snapshots.map(\.exportedVideo.url))
        }

        let low = try snapshot(for: .low, in: snapshots)
        let medium = try snapshot(for: .medium, in: snapshots)
        let high = try snapshot(for: .high, in: snapshots)

        #expect(low.renderSize == VideoQuality.low.size)
        #expect(medium.renderSize == VideoQuality.medium.size)
        #expect(high.renderSize == VideoQuality.high.size)

        #expect(low.exportedVideo.fileSize > 0)
        #expect(medium.exportedVideo.fileSize > low.exportedVideo.fileSize)
        #expect(high.exportedVideo.fileSize > medium.exportedVideo.fileSize)
    }

    @Test
    func startRenderScalesCanvasPresetExportsAcrossQualities() async throws {
        let sourceVideoURL = try await makeFixtureVideo()
        let video = await Video.load(from: sourceVideoURL)
        let editingConfiguration = VideoEditingConfiguration(
            canvas: .init(
                snapshot: .init(
                    preset: .facebookPost,
                    freeCanvasSize: CGSize(width: 1080, height: 1350)
                )
            )
        )

        let snapshots = try await exportSnapshots(
            for: video,
            editingConfiguration: editingConfiguration
        )

        defer {
            cleanup(urls: [sourceVideoURL] + snapshots.map(\.exportedVideo.url))
        }

        let low = try snapshot(for: .low, in: snapshots)
        let medium = try snapshot(for: .medium, in: snapshots)
        let high = try snapshot(for: .high, in: snapshots)

        #expect(low.renderSize == CGSize(width: 480, height: 600))
        #expect(medium.renderSize == CGSize(width: 720, height: 900))
        #expect(high.renderSize == CGSize(width: 1080, height: 1350))

        #expect(low.exportedVideo.fileSize > 0)
        #expect(medium.exportedVideo.fileSize > low.exportedVideo.fileSize)
        #expect(high.exportedVideo.fileSize > medium.exportedVideo.fileSize)
    }

    // MARK: - Private Methods

    private func makeFixtureVideo() async throws -> URL {
        try await TestFixtures.createTemporaryVideo(
            size: CGSize(width: 640, height: 360),
            frameCount: 90,
            framesPerSecond: 30,
            drawFrame: drawFrame
        )
    }

    private func exportSnapshots(
        for video: Video,
        editingConfiguration: VideoEditingConfiguration
    ) async throws -> [ExportSnapshot] {
        try await withThrowingTaskGroup(of: ExportSnapshot.self) { group in
            for quality in VideoQuality.allCases {
                group.addTask {
                    let outputURL = try await VideoEditor.startRender(
                        video: video,
                        editingConfiguration: editingConfiguration,
                        videoQuality: quality
                    )
                    let exportedVideo = await ExportedVideo.load(from: outputURL)
                    return ExportSnapshot(
                        quality: quality,
                        exportedVideo: exportedVideo
                    )
                }
            }

            var snapshots = [ExportSnapshot]()
            for try await snapshot in group {
                snapshots.append(snapshot)
            }

            return snapshots.sorted { $0.quality.order > $1.quality.order }
        }
    }

    private func snapshot(
        for quality: VideoQuality,
        in snapshots: [ExportSnapshot]
    ) throws -> ExportSnapshot {
        guard let snapshot = snapshots.first(where: { $0.quality == quality }) else {
            throw SnapshotLookupError.missingQuality(quality)
        }

        return snapshot
    }

    private func cleanup(urls: [URL]) {
        for url in urls {
            FileManager.default.removeIfExists(for: url)
        }
    }

    private func drawFrame(
        _ context: CGContext,
        _ size: CGSize,
        _ frameIndex: Int
    ) {
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let columns = 10
        let rows = 6
        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = size.height / CGFloat(rows)

        for row in 0..<rows {
            for column in 0..<columns {
                let hueValue =
                    (Double(frameIndex * 13)
                    + Double(row * 29)
                    + Double(column * 37)).truncatingRemainder(dividingBy: 360)
                let hue = CGFloat(hueValue / 360)
                let color = UIColor(
                    hue: hue,
                    saturation: 0.9,
                    brightness: 0.95,
                    alpha: 1
                )
                let rect = CGRect(
                    x: CGFloat(column) * cellWidth,
                    y: CGFloat(row) * cellHeight,
                    width: cellWidth + 1,
                    height: cellHeight + 1
                )

                context.setFillColor(color.cgColor)
                context.fill(rect)
            }
        }

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(6)
        context.strokeEllipse(
            in: CGRect(
                x: CGFloat((frameIndex * 11) % max(Int(size.width) - 60, 1)),
                y: CGFloat((frameIndex * 7) % max(Int(size.height) - 60, 1)),
                width: 60,
                height: 60
            )
        )
    }

}

private struct ExportSnapshot: Sendable {

    // MARK: - Public Properties

    let quality: VideoQuality
    let exportedVideo: ExportedVideo

    var renderSize: CGSize {
        CGSize(
            width: exportedVideo.width,
            height: exportedVideo.height
        )
    }

}

private enum SnapshotLookupError: Error {

    // MARK: - Public Properties

    case missingQuality(VideoQuality)

}
