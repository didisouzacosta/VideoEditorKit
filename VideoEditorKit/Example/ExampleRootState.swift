import Observation
import PhotosUI
import SwiftUI

enum ExampleRootPhase {
    case idle
    case importing
    case ready(ExampleEditorSession)
    case failed(String)
}

@MainActor
@Observable
final class ExampleRootState {
    private(set) var phase: ExampleRootPhase

    @ObservationIgnored
    private let pickerItemLoader: any ExamplePickedVideoItemLoading

    @ObservationIgnored
    private let importCoordinator: any ExampleVideoImportCoordinating

    init(
        phase: ExampleRootPhase = .idle,
        pickerItemLoader: any ExamplePickedVideoItemLoading = PhotosPickerVideoItemLoader(),
        importCoordinator: any ExampleVideoImportCoordinating = ExampleVideoImportCoordinator()
    ) {
        self.phase = phase
        self.pickerItemLoader = pickerItemLoader
        self.importCoordinator = importCoordinator
    }

    var session: ExampleEditorSession? {
        guard case .ready(let session) = phase else {
            return nil
        }

        return session
    }

    var errorMessage: String? {
        guard case .failed(let message) = phase else {
            return nil
        }

        return message
    }

    var isImporting: Bool {
        if case .importing = phase {
            return true
        }

        return false
    }

    func importVideo(from item: PhotosPickerItem) async {
        phase = .importing

        do {
            let pickedVideoURL = try await pickerItemLoader.loadURL(from: item)
            let session = try await importCoordinator.prepareEditorSession(
                fromPickedVideoAt: pickedVideoURL
            )
            phase = .ready(session)
        } catch {
            phase = .failed(message(for: error))
        }
    }

    func reset() {
        phase = .idle
    }
}

@MainActor
extension ExampleRootState {
    static func previewReady() -> ExampleRootState {
        ExampleRootState(phase: .ready(.preview()))
    }
}

private extension ExampleRootState {
    func message(for error: Error) -> String {
        if let importError = error as? ExampleVideoImportError {
            return importError.errorDescription ?? "The selected video could not be imported."
        }

        if let editorError = error as? VideoEditorError {
            switch editorError {
            case .invalidAsset:
                return "The selected video could not be loaded by AVFoundation."
            case .invalidVideoDuration:
                return "The selected video has an invalid duration."
            default:
                return "The editor could not be prepared for the selected video."
            }
        }

        return "The selected video could not be imported."
    }
}
