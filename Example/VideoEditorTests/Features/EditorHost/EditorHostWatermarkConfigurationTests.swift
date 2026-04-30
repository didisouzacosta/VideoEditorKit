import SwiftUI
import Testing
import VideoEditorKit

@testable import VideoEditor

@MainActor
@Suite("EditorHostWatermarkConfigurationTests")
struct EditorHostWatermarkConfigurationTests {

    // MARK: - Public Methods

    @Test
    func editorConfigurationUsesWatermarkAsset() throws {
        let configuration = EditorHostScreen.editorConfiguration()
        let watermark = try #require(configuration.watermark)

        #expect(watermark.position == .bottomTrailing)
        #expect(watermark.image.size.width > 0)
        #expect(watermark.image.size.height > 0)
    }

    @Test
    func editorConfigurationUsesProvidedWatermarkImage() throws {
        let image = TestFixtures.makeSolidImage(size: CGSize(width: 36, height: 18))
        let configuration = EditorHostScreen.editorConfiguration(watermarkImage: image)
        let watermark = try #require(configuration.watermark)

        #expect(watermark.position == .bottomTrailing)
        #expect(watermark.image.size == CGSize(width: 36, height: 18))
    }

    @Test
    func rootShareExportConfigurationUsesWatermark() throws {
        let configuration = RootView.shareExportConfiguration
        let watermark = try #require(configuration.watermark)

        #expect(watermark.position == .bottomTrailing)
        #expect(watermark.image.size.width > 0)
        #expect(watermark.image.size.height > 0)
    }

    @Test
    func rootShareExportRequestIncludesSourceMetadata() {
        let project = makeProject(
            duration: 8,
            width: 1920,
            height: 1080
        )

        let request = RootView.exportRequest(for: project)

        #expect(
            request.sourceMetadata
                == VideoExportSheetSourceMetadata(
                    width: 1920,
                    height: 1080,
                    duration: 8
                )
        )
    }

    // MARK: - Private Methods

    private func makeProject(
        duration: Double,
        width: Double,
        height: Double
    ) -> EditedVideoProject {
        let configurationData = (try? JSONEncoder().encode(VideoEditingConfiguration.initial)) ?? Data()

        return EditedVideoProject(
            createdAt: .now,
            updatedAt: .now,
            displayName: "Project",
            originalVideoFileName: "original.mp4",
            savedEditedVideoFileName: "saved.mp4",
            exportedVideoFileName: "",
            editingConfigurationData: configurationData,
            thumbnailData: nil,
            duration: duration,
            width: width,
            height: height,
            fileSize: 1024
        )
    }

}
