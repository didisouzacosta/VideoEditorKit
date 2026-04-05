import Foundation
import Testing

@testable import VideoEditorKit

@Suite("TranscriptionModelStoreTests")
struct TranscriptionModelStoreTests {

    // MARK: - Public Methods

    @Test
    func localModelURLUsesTheDedicatedModelsDirectory() throws {
        let rootDirectoryURL = makeTemporaryDirectoryURL()
        let store = TranscriptionModelStore(
            rootDirectoryURL: rootDirectoryURL
        )
        let descriptor = makeDescriptor()

        let localURL = try store.localModelURL(for: descriptor)

        #expect(
            localURL
                == rootDirectoryURL
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent("base.bin")
        )
    }

    @Test
    func cachedModelStateIsMissingWhenTheModelDoesNotExist() throws {
        let rootDirectoryURL = makeTemporaryDirectoryURL()
        let store = TranscriptionModelStore(
            rootDirectoryURL: rootDirectoryURL
        )

        let state = try store.cachedModelState(
            for: makeDescriptor()
        )

        #expect(state == .missing)
    }

    @Test
    func cachedModelStateRecognizesAValidModelByExpectedSize() throws {
        let rootDirectoryURL = makeTemporaryDirectoryURL()
        let store = TranscriptionModelStore(
            rootDirectoryURL: rootDirectoryURL
        )
        let descriptor = makeDescriptor(expectedSizeInBytes: 4)
        let modelURL = try store.localModelURL(for: descriptor)

        try FileManager.default.createDirectory(
            at: modelURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3, 4]).write(
            to: modelURL,
            options: .atomic
        )

        let state = try store.cachedModelState(
            for: descriptor
        )

        #expect(state == .valid(modelURL))
    }

    @Test
    func cachedModelStateRejectsAModelWithUnexpectedSize() throws {
        let rootDirectoryURL = makeTemporaryDirectoryURL()
        let store = TranscriptionModelStore(
            rootDirectoryURL: rootDirectoryURL
        )
        let descriptor = makeDescriptor(expectedSizeInBytes: 8)
        let modelURL = try store.localModelURL(for: descriptor)

        try FileManager.default.createDirectory(
            at: modelURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3, 4]).write(
            to: modelURL,
            options: .atomic
        )

        let state = try store.cachedModelState(
            for: descriptor
        )

        #expect(
            state
                == .invalid(
                    modelURL,
                    issue: .unexpectedFileSize(
                        expected: 8,
                        actual: 4
                    )
                )
        )
    }

    @Test
    func installDownloadedModelMovesTheTemporaryFileIntoTheCache() throws {
        let rootDirectoryURL = makeTemporaryDirectoryURL()
        let store = TranscriptionModelStore(
            rootDirectoryURL: rootDirectoryURL
        )
        let descriptor = makeDescriptor(expectedSizeInBytes: 4)
        let temporaryURL = try store.temporaryDownloadURL(
            for: descriptor
        )

        try FileManager.default.createDirectory(
            at: temporaryURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3, 4]).write(
            to: temporaryURL,
            options: .atomic
        )

        let installedURL = try store.installDownloadedModel(
            from: temporaryURL,
            for: descriptor
        )

        #expect(FileManager.default.fileExists(atPath: installedURL.path()))
        #expect(FileManager.default.fileExists(atPath: temporaryURL.path()) == false)
    }

    // MARK: - Private Methods

    private func makeDescriptor(
        expectedSizeInBytes: Int64? = nil
    ) -> RemoteModelDescriptor {
        RemoteModelDescriptor(
            id: "base",
            remoteURL: URL(filePath: "/tmp/base.bin"),
            localFileName: "base.bin",
            expectedSizeInBytes: expectedSizeInBytes
        )
    }

    private func makeTemporaryDirectoryURL() -> URL {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        return directoryURL
    }

}
