import Foundation
import VideoEditorKit

enum VideoEditingThumbnailTimestampResolver {

    // MARK: - Public Methods

    static func exportedAssetTimestamp(
        for editingConfiguration: VideoEditingConfiguration,
        exportedDuration: Double
    ) -> Double {
        _ = editingConfiguration
        _ = exportedDuration
        return 0
    }

}
