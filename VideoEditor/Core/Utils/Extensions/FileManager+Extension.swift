import Foundation
import SwiftUI

extension FileManager {

    // MARK: - Private Properties

    private var documentsDirectory: URL? {
        urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // MARK: - Public Methods

    func createImagePath(with id: String) -> URL? {
        documentsDirectory?.appendingPathComponent("\(id).jpg")
    }

    func createVideoPath(with name: String) -> URL? {
        documentsDirectory?.appendingPathComponent(name)
    }

    func retrieveImage(with id: String) -> UIImage? {
        guard let url = createImagePath(with: id) else { return nil }

        do {
            let imageData = try Data(contentsOf: url)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }

    func saveImage(with id: String, image: UIImage) {
        guard let url = createImagePath(with: id),
            let data = image.jpegData(compressionQuality: 0.9)
        else { return }

        do {
            try data.write(to: url)
        } catch {
            assertionFailure("Failed to save image at \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    func deleteImage(with id: String) {
        guard let url = createImagePath(with: id) else { return }
        removeIfExists(for: url)
    }

    func deleteVideo(with name: String) {
        guard let url = createVideoPath(with: name) else { return }
        removeIfExists(for: url)
    }

    func removeIfExists(for url: URL) {
        guard fileExists(atPath: url.path) else { return }

        do {
            try removeItem(at: url)
        } catch {
            assertionFailure("Failed to remove item at \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

}
