import Foundation
import Testing

@testable import VideoEditorKit

@Suite("VideoEditorPublicTypesTests")
struct VideoEditorPublicTypesTests {

    @Test
    func sessionResolvesTheExpectedConvenienceValues() {
        let url = URL(fileURLWithPath: "/tmp/video.mp4")
        let session = VideoEditorSession(
            source: .fileURL(url),
            editingConfiguration: .initial
        )

        #expect(session.sourceVideoURL == url)
        #expect(session.bootstrapTaskIdentifier == "file:\(url.absoluteString)")
    }

    @Test
    func configurationSortsToolsAndExportQualitiesByOrder() {
        let configuration = VideoEditorConfiguration(
            tools: [
                .enabled(.speed, order: 4),
                .enabled(.audio, order: 2),
                .enabled(.presets, order: 1),
            ],
            exportQualities: [
                .enabled(.low, order: 2),
                .enabled(.high, order: 0),
                .enabled(.medium, order: 1),
            ]
        )

        #expect(configuration.tools.map(\.tool) == [.presets, .audio, .speed])
        #expect(configuration.exportQualities.map(\.quality) == [.high, .medium, .low])
    }

    @Test
    func saveStateExposesTheContinuousSaveFingerprint() {
        let configuration = VideoEditingConfiguration(
            presentation: .init(.audio)
        )
        let saveState = VideoEditorSaveState(
            editingConfiguration: configuration,
            thumbnailData: Data([1, 2, 3])
        )

        #expect(saveState.continuousSaveFingerprint == configuration.continuousSaveFingerprint)
    }

}
