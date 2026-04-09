#if os(iOS)
    import Foundation
    import Testing

    @testable import VideoEditorKit

    @MainActor
    @Suite("HostedVideoEditorRuntimeCoordinatorTests")
    struct HostedVideoEditorRuntimeCoordinatorTests {

        // MARK: - Public Methods

        @Test
        func resolvedPlayerLoadStateKeepsBootstrapLoadingUntilTheHostVideoMatches() throws {
            let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

            defer { FileManager.default.removeIfExists(for: sourceURL) }

            #expect(
                HostedVideoEditorRuntimeCoordinator.resolvedPlayerLoadState(
                    for: .loaded(sourceURL),
                    currentVideoURL: nil
                ) == .loading
            )
            #expect(
                HostedVideoEditorRuntimeCoordinator.resolvedPlayerLoadState(
                    for: .loaded(sourceURL),
                    currentVideoURL: sourceURL
                ) == .loaded(sourceURL)
            )
        }

        @Test
        func dismissedEditingConfigurationFallsBackToTheSessionStateWhenTheEditorHasNoLoadedVideo() {
            let fallbackConfiguration = VideoEditingConfiguration(
                trim: .init(
                    lowerBound: 1,
                    upperBound: 4
                )
            )
            let editorViewModel = EditorViewModel()

            #expect(
                HostedVideoEditorRuntimeCoordinator.dismissedEditingConfiguration(
                    editorViewModel: editorViewModel,
                    currentTimelineTime: 2,
                    fallbackEditingConfiguration: fallbackConfiguration
                ) == fallbackConfiguration
            )
        }

        @Test
        func scheduleSaveUsesTheLoadedVideoURLBeforeTheSessionFallbackURL() async throws {
            let currentVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
            let fallbackSourceVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
            let sourceURLRecorder = SourceURLRecorder()
            let publishedSaveRecorder = PublishedSaveRecorder()
            let saveEmissionCoordinator = VideoEditorSaveEmissionCoordinator(
                .init(
                    sleep: { _ in },
                    makeThumbnailData: { sourceVideoURL, _ in
                        await sourceURLRecorder.record(sourceVideoURL)
                        return nil
                    }
                )
            )
            let editorViewModel = EditorViewModel()
            var video = Video.mock
            video.url = currentVideoURL
            editorViewModel.currentVideo = video

            HostedVideoEditorRuntimeCoordinator.scheduleSaveIfNeeded(
                editorViewModel: editorViewModel,
                currentTimelineTime: 3,
                fallbackSourceVideoURL: fallbackSourceVideoURL,
                saveEmissionCoordinator: saveEmissionCoordinator
            ) { publishedSave in
                Task {
                    await publishedSaveRecorder.record(publishedSave)
                }
            }

            await publishedSaveRecorder.waitUntilCount(is: 1)

            #expect(await sourceURLRecorder.sourceURLs == [currentVideoURL])
        }

        @Test
        func handlePlaybackFocusChangeClosesTheSelectedToolOnlyWhenPlaybackLocks() {
            let editorViewModel = EditorViewModel()
            editorViewModel.presentationState.selectedTool = .speed

            HostedVideoEditorRuntimeCoordinator.handlePlaybackFocusChange(
                false,
                editorViewModel: editorViewModel
            )
            #expect(editorViewModel.presentationState.selectedTool == .speed)

            HostedVideoEditorRuntimeCoordinator.handlePlaybackFocusChange(
                true,
                editorViewModel: editorViewModel
            )
            #expect(editorViewModel.presentationState.selectedTool == nil)
        }

    }

    private actor SourceURLRecorder {

        // MARK: - Private Properties

        private(set) var sourceURLs = [URL]()

        // MARK: - Public Methods

        func record(_ sourceURL: URL) {
            sourceURLs.append(sourceURL)
        }

    }

    private actor PublishedSaveRecorder {

        // MARK: - Private Properties

        private(set) var saves = [VideoEditorSaveEmissionCoordinator.PublishedSave]()

        // MARK: - Public Methods

        func record(_ save: VideoEditorSaveEmissionCoordinator.PublishedSave) {
            saves.append(save)
        }

        func waitUntilCount(is expectedCount: Int) async {
            while saves.count < expectedCount {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }

    }

#endif
