import Testing

@testable import VideoEditor

@Suite("VideoEditorKitPackageSmokeTests")
struct VideoEditorKitPackageSmokeTests {

    // MARK: - Public Methods

    @Test
    func hostAppCanResolveTheLinkedPackageSurface() {
        #expect(VideoEditorKitPackageSmoke.packageName == "VideoEditorKit")
        #expect(VideoEditorKitPackageSmoke.currentSchemaVersion == 2)
        #expect(VideoEditorKitPackageSmoke.initialConfiguration.version == 2)
    }

}
