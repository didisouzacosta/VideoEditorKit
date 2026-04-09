#if os(iOS)
    //
    //  VideoEditorSaveEmissionCoordinator.swift
    //  VideoEditorKit
    //
    //  Created by Codex on 02.04.2026.
    //

    import Foundation

    @MainActor
    final class VideoEditorSaveEmissionCoordinator {

        struct PublishedSave: Equatable, Sendable {

            // MARK: - Public Properties

            let editingConfiguration: VideoEditingConfiguration
            let thumbnailData: Data?

            var continuousSaveFingerprint: VideoEditingConfiguration {
                editingConfiguration.continuousSaveFingerprint
            }

        }

        struct Dependencies {

            // MARK: - Public Properties

            static let live = Self(
                sleep: { try await Task.sleep(for: $0) },
                makeThumbnailData: { sourceVideoURL, editingConfiguration in
                    await VideoEditingThumbnailRenderer.makeThumbnailData(
                        sourceVideoURL: sourceVideoURL,
                        editingConfiguration: editingConfiguration
                    )
                }
            )

            let sleep: @Sendable (Duration) async throws -> Void
            let makeThumbnailData: @Sendable (URL, VideoEditingConfiguration) async -> Data?

        }

        // MARK: - Private Properties

        private let debounceDuration: Duration
        private let dependencies: Dependencies

        private var lastPublishedSaveFingerprint: VideoEditingConfiguration?
        private var saveTask: Task<Void, Never>?

        // MARK: - Initializer

        init(
            _ dependencies: Dependencies = .live,
            debounceDuration: Duration = .milliseconds(150)
        ) {
            self.debounceDuration = debounceDuration
            self.dependencies = dependencies
        }

        // MARK: - Public Methods

        func scheduleSave(
            editingConfiguration: VideoEditingConfiguration,
            sourceVideoURL: URL?,
            onPublish: @escaping @MainActor (PublishedSave) -> Void
        ) {
            let save = PublishedSave(
                editingConfiguration: editingConfiguration,
                thumbnailData: nil
            )

            guard save.continuousSaveFingerprint != lastPublishedSaveFingerprint else {
                return
            }

            lastPublishedSaveFingerprint = save.continuousSaveFingerprint
            saveTask?.cancel()

            saveTask = Task { [debounceDuration, dependencies] in
                try? await dependencies.sleep(debounceDuration)
                guard Task.isCancelled == false else { return }

                let thumbnailData: Data?

                if let sourceVideoURL {
                    thumbnailData = await dependencies.makeThumbnailData(
                        sourceVideoURL,
                        editingConfiguration
                    )
                } else {
                    thumbnailData = nil
                }

                guard Task.isCancelled == false else { return }

                await MainActor.run {
                    onPublish(
                        .init(
                            editingConfiguration: editingConfiguration,
                            thumbnailData: thumbnailData
                        )
                    )
                }
            }
        }

        func reset() {
            saveTask?.cancel()
            saveTask = nil
            lastPublishedSaveFingerprint = nil
        }

    }

#endif
