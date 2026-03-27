import Foundation
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("EditorViewModelTests")
struct EditorViewModelTests {

    // MARK: - Public Methods

    @Test
    func selectedTrackVolumeUsesRecordedTrackWhenSelected() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.audio = Audio(
            url: URL(fileURLWithPath: "/tmp/recorded-audio.m4a"),
            duration: 12,
            volume: 0.35
        )
        viewModel.currentVideo = video

        viewModel.selectAudioTrack(.recorded)

        #expect(abs(Double(viewModel.selectedTrackVolume()) - 0.35) < 0.0001)
    }

    @Test
    func updateSelectedTrackVolumeUpdatesRecordedTrackVolume() {
        let viewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock
        video.audio = Audio(
            url: URL(fileURLWithPath: "/tmp/recorded-audio.m4a"),
            duration: 12,
            volume: 0.35
        )
        viewModel.currentVideo = video
        viewModel.selectAudioTrack(.recorded)

        viewModel.updateSelectedTrackVolume(0.8, videoPlayer: videoPlayer)

        #expect(abs(Double(viewModel.currentVideo?.audio?.volume ?? 0) - 0.8) < 0.0001)
        #expect(abs(Double(viewModel.currentVideo?.volume ?? 0) - 1.0) < 0.0001)
    }

    @Test
    func resetSpeedPreservesTimelineIndicatorPosition() {
        let viewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock
        video.rangeDuration = 20...80
        viewModel.currentVideo = video
        videoPlayer.syncPlaybackState(with: video)
        videoPlayer.currentTime = 50

        viewModel.handleRateChange(2, videoPlayer: videoPlayer)

        viewModel.reset(.speed, textEditor: TextEditorViewModel(), videoPlayer: videoPlayer)

        #expect(abs(Double(viewModel.currentVideo?.rate ?? 0) - 1.0) < 0.0001)
        #expect(abs(videoPlayer.currentTime - 50) < 0.0001)
    }

    @Test
    func exportVideoOnlyExistsWhileTheQualitySheetIsPresented() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock

        #expect(viewModel.exportVideo == nil)

        viewModel.showVideoQualitySheet = true

        #expect(viewModel.exportVideo?.id == viewModel.currentVideo?.id)
    }

    @Test
    func setFilterAppliesAndRemovesTheSelectedTool() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        viewModel.selectTool(.filters)

        viewModel.setFilter("CIPhotoEffectNoir")

        #expect(viewModel.currentVideo?.filterName == "CIPhotoEffectNoir")
        #expect(viewModel.currentVideo?.isAppliedTool(for: .filters) == true)

        viewModel.setFilter(nil)

        #expect(viewModel.currentVideo?.filterName == nil)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .filters) == false)
    }

    @Test
    func setCutTracksWhetherTheVideoIsCurrentlyTrimmed() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.rangeDuration = 10...80
        viewModel.currentVideo = video

        viewModel.setCut()

        #expect(viewModel.currentVideo?.isAppliedTool(for: .cut) == true)

        viewModel.currentVideo?.rangeDuration = 0...250
        viewModel.setCut()

        #expect(viewModel.currentVideo?.isAppliedTool(for: .cut) == false)
    }

    @Test
    func resetCutRestoresTheFullRangeAndClearsTheCutTool() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.rangeDuration = 15...40
        video.appliedTool(for: .cut)
        viewModel.currentVideo = video

        viewModel.resetCut()

        #expect(viewModel.currentVideo?.rangeDuration == 0...250)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .cut) == false)
    }

    @Test
    func cropRotationAndMirrorProxyTheCurrentVideoState() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock

        viewModel.cropRotation = 180
        viewModel.toggleMirror()

        #expect(viewModel.cropRotation == 180)
        #expect(viewModel.isMirrorEnabled)
    }

    @Test
    func setAudioSwitchesToRecordedTrackAndMarksAudioTool() throws {
        let viewModel = EditorViewModel()
        let audioURL = try TestFixtures.createTemporaryAudio()
        defer { FileManager.default.removeIfExists(for: audioURL) }

        viewModel.currentVideo = Video.mock
        viewModel.selectTool(.audio)

        viewModel.setAudio(Audio(url: audioURL, duration: 3, volume: 0.5))

        #expect(viewModel.currentVideo?.audio?.url == audioURL)
        #expect(viewModel.selectedAudioTrack == .recorded)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == true)
    }

    @Test
    func removeAudioDeletesTheRecordedFileAndRestoresTheVideoTrackSelection() throws {
        let viewModel = EditorViewModel()
        let audioURL = try TestFixtures.createTemporaryAudio()
        var video = Video.mock
        video.audio = Audio(url: audioURL, duration: 4, volume: 0.7)
        video.appliedTool(for: .audio)
        viewModel.currentVideo = video
        viewModel.selectTool(.audio)
        viewModel.selectedAudioTrack = .recorded

        viewModel.removeAudio()

        #expect(FileManager.default.fileExists(atPath: audioURL.path()) == false)
        #expect(viewModel.currentVideo?.audio == nil)
        #expect(viewModel.selectedAudioTrack == .video)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == false)
    }

    @Test
    func selectingRecordedTrackFallsBackToVideoWhenNoRecordedAudioExists() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock

        viewModel.selectAudioTrack(.recorded)

        #expect(viewModel.selectedAudioTrack == .video)
    }

    @Test
    func updateSelectedTrackVolumeRemovesTheAudioToolWhenBackAtDefaults() {
        let viewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock
        video.appliedTool(for: .audio)
        viewModel.currentVideo = video
        viewModel.selectedAudioTrack = .video

        viewModel.updateSelectedTrackVolume(1.0, videoPlayer: videoPlayer)

        #expect(abs(Double(viewModel.currentVideo?.volume ?? 0) - 1.0) < 0.0001)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == false)
    }

    @Test
    func handleSelectedTextBoxChangeKeepsTheTextToolInSyncWithSelection() {
        let viewModel = EditorViewModel()

        viewModel.handleSelectedTextBoxChange(TextBox(text: "Hello"))
        #expect(viewModel.selectedTools == .text)

        viewModel.handleSelectedTextBoxChange(nil)
        #expect(viewModel.selectedTools == nil)
    }

    @Test
    func handleSelectedToolChangePreparesTheTextEditorAndPersistsItsTextBoxesOnDismiss() {
        let viewModel = EditorViewModel()
        let textEditor = TextEditorViewModel()
        let existingText = TextBox(text: "Overlay")
        viewModel.currentVideo = Video.mock
        viewModel.currentVideo?.rangeDuration = 3...9

        viewModel.handleSelectedToolChange(.text, textEditor: textEditor)

        #expect(textEditor.showEditor)
        #expect(textEditor.currentTextBox.timeRange == 3...9)

        textEditor.load(textBoxes: [existingText])
        viewModel.handleSelectedToolChange(nil, textEditor: textEditor)

        #expect(viewModel.currentVideo?.textBoxes == [existingText])
    }

    @Test
    func selectToolIgnoresBlockedAndHiddenToolsFromAvailability() {
        let viewModel = EditorViewModel()
        viewModel.setToolAvailability([
            .init(.filters),
            .init(.speed, access: .blocked),
        ])

        viewModel.selectTool(.filters)
        #expect(viewModel.selectedTools == .filters)

        viewModel.selectTool(.speed)
        #expect(viewModel.selectedTools == .filters)

        viewModel.selectTool(.audio)
        #expect(viewModel.selectedTools == .filters)
    }

    @Test
    func changingAvailabilityClearsTheCurrentSelectionWhenItBecomesUnavailable() {
        let viewModel = EditorViewModel()
        viewModel.selectTool(.text)

        viewModel.setToolAvailability([
            .init(.filters),
            .init(.speed),
        ])

        #expect(viewModel.selectedTools == nil)
    }

    @Test
    func handleSelectedTextBoxChangeDoesNotOpenTextWhenTheToolIsUnavailable() {
        let viewModel = EditorViewModel()
        viewModel.setToolAvailability([
            .init(.filters),
            .init(.speed),
        ])

        viewModel.handleSelectedTextBoxChange(TextBox(text: "Hello"))

        #expect(viewModel.selectedTools == nil)
    }

    @Test
    func frameBindingsMutateTheSharedFramesState() {
        let viewModel = EditorViewModel()
        let colorBinding = viewModel.frameColorBinding()
        let scaleBinding = viewModel.frameScaleBinding()

        colorBinding.wrappedValue = .red
        scaleBinding.wrappedValue = 0.35

        #expect(SystemColorPalette.matches(viewModel.frames.frameColor, .red))
        #expect(abs(viewModel.frames.scaleValue - 0.35) < 0.0001)
    }

    @Test
    func playerContainerSizeUsesWidthInsetAndMinimumHeight() {
        let viewModel = EditorViewModel()

        let compactSize = viewModel.playerContainerSize(in: CGSize(width: 300, height: 400))
        let tallSize = viewModel.playerContainerSize(in: CGSize(width: 300, height: 900))

        #expect(abs(compactSize.width - 268) < 0.0001)
        #expect(abs(compactSize.height - 220) < 0.0001)
        #expect(abs(tallSize.height - 360) < 0.0001)
    }

    @Test
    func presentExporterShowsTheQualitySheetAfterTheDeferredDelay() async {
        let viewModel = EditorViewModel()
        viewModel.selectTool(.text)

        viewModel.presentExporter()

        #expect(viewModel.selectedTools == nil)
        #expect(viewModel.showVideoQualitySheet == false)

        for _ in 0..<10 where !viewModel.showVideoQualitySheet {
            try? await Task.sleep(for: .milliseconds(100))
        }

        #expect(viewModel.showVideoQualitySheet)
    }

}
