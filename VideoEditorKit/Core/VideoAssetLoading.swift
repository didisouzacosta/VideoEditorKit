import Foundation

protocol VideoAssetLoading {
    func loadAsset(from sourceVideoURL: URL) async throws -> LoadedVideoAsset
}
