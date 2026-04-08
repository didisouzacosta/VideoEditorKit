import VideoEditorKit

enum VideoEditorKitPackageSmoke {

    // MARK: - Public Properties

    static let packageName = VideoEditorKitPackage.packageName
    static let currentSchemaVersion = VideoEditorKit.VideoEditingConfiguration
        .currentSchemaVersion
        .rawValue
    static let initialConfiguration = VideoEditorKit.VideoEditingConfiguration.initial

}
