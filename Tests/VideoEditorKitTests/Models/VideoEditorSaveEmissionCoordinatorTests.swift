import Foundation
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("VideoEditorSaveEmissionCoordinatorTests")
struct VideoEditorSaveEmissionCoordinatorTests {

    // MARK: - Public Methods

    @Test
    func scheduleSavePublishesDistinctMeaningfulConfigurationsWithoutManualSaveGate() async {
        let recorder = SaveEmissionRecorder()
        let coordinator = VideoEditorSaveEmissionCoordinator(
            .init(
                sleep: { _ in },
                makeThumbnailData: { _, _ in nil }
            )
        )
        let initialConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 0, upperBound: 8)
        )
        let editedConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 2, upperBound: 6)
        )

        coordinator.scheduleSave(
            editingConfiguration: initialConfiguration,
            sourceVideoURL: nil
        ) { publishedSave in
            Task {
                await recorder.record(publishedSave)
            }
        }
        await recorder.waitUntilCount(is: 1)

        coordinator.scheduleSave(
            editingConfiguration: editedConfiguration,
            sourceVideoURL: nil
        ) { publishedSave in
            Task {
                await recorder.record(publishedSave)
            }
        }
        await recorder.waitUntilCount(is: 2)

        #expect(
            await recorder.saves.map(\.editingConfiguration)
                == [
                    initialConfiguration,
                    editedConfiguration,
                ]
        )
    }

    @Test
    func scheduleSavePublishesOnlyTheLatestMeaningfulConfiguration() async {
        let sleepProbe = SaveEmissionSleepProbe()
        let recorder = SaveEmissionRecorder()
        let coordinator = VideoEditorSaveEmissionCoordinator(
            .init(
                sleep: { _ in
                    await sleepProbe.sleep()
                },
                makeThumbnailData: { _, _ in nil }
            )
        )
        let firstConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 4)
        )
        let secondConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 2, upperBound: 5)
        )

        coordinator.scheduleSave(
            editingConfiguration: firstConfiguration,
            sourceVideoURL: nil
        ) { publishedSave in
            Task {
                await recorder.record(publishedSave)
            }
        }
        await sleepProbe.waitUntilCount(is: 1)

        coordinator.scheduleSave(
            editingConfiguration: secondConfiguration,
            sourceVideoURL: nil
        ) { publishedSave in
            Task {
                await recorder.record(publishedSave)
            }
        }
        await sleepProbe.waitUntilCount(is: 2)

        await sleepProbe.resumeNext()
        try? await Task.sleep(for: .milliseconds(20))
        #expect(await recorder.saves.isEmpty)

        await sleepProbe.resumeNext()
        await recorder.waitUntilCount(is: 1)

        #expect(
            await recorder.saves.map(\.editingConfiguration)
                == [secondConfiguration]
        )
    }

    @Test
    func scheduleSaveSkipsTransientOnlyChangesWhileKeepingThePendingMeaningfulSave() async {
        let sleepProbe = SaveEmissionSleepProbe()
        let recorder = SaveEmissionRecorder()
        let coordinator = VideoEditorSaveEmissionCoordinator(
            .init(
                sleep: { _ in
                    await sleepProbe.sleep()
                },
                makeThumbnailData: { _, _ in nil }
            )
        )
        let baseConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 4),
            playback: .init(
                rate: 1.25,
                videoVolume: 0.8,
                currentTimelineTime: 3
            ),
            audio: .init(selectedTrack: .recorded),
            presentation: .init(
                .adjusts,
                socialVideoDestination: .tikTok,
                showsSafeAreaGuides: true
            )
        )
        var transientOnlyChange = baseConfiguration
        transientOnlyChange.playback.currentTimelineTime = 9
        transientOnlyChange.audio.selectedTrack = .video
        transientOnlyChange.presentation.selectedTool = nil
        transientOnlyChange.presentation.showsSafeAreaGuides = false

        coordinator.scheduleSave(
            editingConfiguration: baseConfiguration,
            sourceVideoURL: nil
        ) { publishedSave in
            Task {
                await recorder.record(publishedSave)
            }
        }
        await sleepProbe.waitUntilCount(is: 1)

        coordinator.scheduleSave(
            editingConfiguration: transientOnlyChange,
            sourceVideoURL: nil
        ) { publishedSave in
            Task {
                await recorder.record(publishedSave)
            }
        }

        try? await Task.sleep(for: .milliseconds(20))
        #expect(await sleepProbe.count == 1)

        await sleepProbe.resumeNext()
        await recorder.waitUntilCount(is: 1)

        #expect(
            await recorder.saves.map(\.editingConfiguration)
                == [baseConfiguration]
        )
    }

    @Test
    func resetCancelsPendingWorkAndAllowsTheSameFingerprintToBeScheduledAgain() async {
        let sleepProbe = SaveEmissionSleepProbe()
        let recorder = SaveEmissionRecorder()
        let coordinator = VideoEditorSaveEmissionCoordinator(
            .init(
                sleep: { _ in
                    await sleepProbe.sleep()
                },
                makeThumbnailData: { _, _ in nil }
            )
        )
        let configuration = VideoEditingConfiguration(
            trim: .init(lowerBound: 1, upperBound: 4)
        )

        coordinator.scheduleSave(
            editingConfiguration: configuration,
            sourceVideoURL: nil
        ) { publishedSave in
            Task {
                await recorder.record(publishedSave)
            }
        }
        await sleepProbe.waitUntilCount(is: 1)

        coordinator.reset()
        await sleepProbe.resumeNext()
        try? await Task.sleep(for: .milliseconds(20))
        #expect(await recorder.saves.isEmpty)

        coordinator.scheduleSave(
            editingConfiguration: configuration,
            sourceVideoURL: nil
        ) { publishedSave in
            Task {
                await recorder.record(publishedSave)
            }
        }
        await sleepProbe.waitUntilCount(is: 2)

        await sleepProbe.resumeNext()
        await recorder.waitUntilCount(is: 1)

        #expect(
            await recorder.saves.map(\.editingConfiguration)
                == [configuration]
        )
    }

}

private actor SaveEmissionSleepProbe {

    // MARK: - Private Properties

    private var sleepCount = 0
    private var continuations = [CheckedContinuation<Void, Never>]()

    // MARK: - Public Properties

    var count: Int {
        sleepCount
    }

    // MARK: - Public Methods

    func sleep() async {
        sleepCount += 1
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitUntilCount(is expectedCount: Int) async {
        while sleepCount < expectedCount {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func resumeNext() {
        guard continuations.isEmpty == false else { return }
        continuations.removeFirst().resume()
    }

}

private actor SaveEmissionRecorder {

    // MARK: - Private Properties

    private(set) var saves = [VideoEditorSaveEmissionCoordinator.PublishedSave]()

    // MARK: - Public Methods

    func record(
        _ save: VideoEditorSaveEmissionCoordinator.PublishedSave
    ) {
        saves.append(save)
    }

    func waitUntilCount(is expectedCount: Int) async {
        while saves.count < expectedCount {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

}
