import Foundation
import SwiftUI
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
    func selectingVerticalCropFormatCreatesACentered9x16Rect() throws {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.crop)

        viewModel.selectCropFormat(.vertical9x16)

        let cropRect = try #require(viewModel.cropFreeformRect)
        #expect(viewModel.cropTab == .format)
        #expect(abs(cropRect.x - 0.341796875) < 0.0001)
        #expect(abs(cropRect.width - 0.31640625) < 0.0001)
        #expect(abs(cropRect.y - 0) < 0.0001)
        #expect(abs(cropRect.height - 1) < 0.0001)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .crop) == true)
        #expect(viewModel.shouldShowCropOverlay)
        #expect(viewModel.isCropFormatSelected(.vertical9x16))
    }

    @Test
    func selectingOriginalCropFormatClearsThePresetRect() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.crop)
        viewModel.selectCropFormat(.vertical9x16)

        viewModel.selectCropFormat(.original)

        #expect(viewModel.cropFreeformRect == nil)
        #expect(viewModel.shouldShowCropOverlay == false)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .crop) == false)
        #expect(viewModel.isCropFormatSelected(.original))
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
    func editingConfigurationChangeCounterAdvancesWhenEditingStateMutates() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        let initialCounter = viewModel.editingConfigurationChangeCounter

        viewModel.selectTool(.filters)
        viewModel.setFilter("CIPhotoEffectNoir")

        #expect(viewModel.editingConfigurationChangeCounter > initialCounter)
    }

    @Test
    func frameBindingsAdvanceTheEditingConfigurationChangeCounter() {
        let viewModel = EditorViewModel()
        let initialCounter = viewModel.editingConfigurationChangeCounter
        let colorBinding = viewModel.frameColorBinding()
        let scaleBinding = viewModel.frameScaleBinding()

        colorBinding.wrappedValue = .red
        scaleBinding.wrappedValue = 0.35

        #expect(viewModel.editingConfigurationChangeCounter >= initialCounter + 2)
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
        #expect(textEditor.showEditor == false)
        #expect(textEditor.selectedTextBox == nil)
    }

    @Test
    func handleSelectedToolChangeDismissesTextPresentationWhenSwitchingToAnotherTool() {
        let viewModel = EditorViewModel()
        let textEditor = TextEditorViewModel()
        let textBox = TextBox(text: "Overlay")
        viewModel.currentVideo = Video.mock
        textEditor.load(textBoxes: [textBox])
        textEditor.selectTextBox(textBox)
        textEditor.openTextEditor(isEdit: true, textBox)

        viewModel.handleSelectedToolChange(.speed, textEditor: textEditor)

        #expect(textEditor.showEditor == false)
        #expect(textEditor.selectedTextBox == nil)
    }

    @Test
    func removingTextToolAvailabilityClosesAnOpenTextEditorFlow() {
        let viewModel = EditorViewModel()
        let textEditor = TextEditorViewModel()
        let textBox = TextBox(text: "Overlay")
        viewModel.currentVideo = Video.mock
        textEditor.load(textBoxes: [textBox])
        textEditor.selectTextBox(textBox)
        textEditor.openTextEditor(isEdit: true, textBox)
        viewModel.selectTool(.text)

        viewModel.setToolAvailability([
            .init(.filters),
            .init(.speed),
        ])
        viewModel.handleSelectedToolChange(viewModel.selectedTools, textEditor: textEditor)

        #expect(viewModel.selectedTools == nil)
        #expect(textEditor.showEditor == false)
        #expect(textEditor.selectedTextBox == nil)
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

    @Test
    func prepareEditingConfigurationForInitialLoadSeedsPlayerAndRestoresPresentationState() throws {
        let viewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        let audioURL = try TestFixtures.createTemporaryAudio()
        defer { FileManager.default.removeIfExists(for: audioURL) }

        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 8, upperBound: 24),
            playback: .init(
                rate: 1.5,
                videoVolume: 0.55,
                currentTimelineTime: 11
            ),
            crop: .init(
                rotationDegrees: 90,
                isMirrored: true,
                freeformRect: .init(
                    x: 0.15,
                    y: 0.1,
                    width: 0.7,
                    height: 0.65
                )
            ),
            filter: .init(
                filterName: "CIPhotoEffectMono",
                brightness: 0.1,
                contrast: 1.2,
                saturation: 0.7
            ),
            frame: .init(
                scaleValue: 0.2,
                colorToken: "palette:blue"
            ),
            audio: .init(
                recordedClip: .init(
                    url: audioURL,
                    duration: 2,
                    volume: 0.4
                ),
                selectedTrack: .recorded
            ),
            textOverlays: [
                .init(
                    id: UUID(),
                    text: "Resume",
                    fontSize: 24,
                    backgroundColorToken: "palette:orange",
                    fontColorToken: "palette:background",
                    timeRange: .init(lowerBound: 2, upperBound: 4),
                    offset: .init(x: 0.05, y: -0.02)
                )
            ],
            presentation: .init(
                selectedTool: .filters,
                cropTab: .format
            )
        )

        viewModel.prepareEditingConfigurationForInitialLoad(
            editingConfiguration,
            videoPlayer: videoPlayer
        )

        var video = Video.mock
        viewModel.applyPendingEditingConfiguration(
            to: &video,
            containerSize: CGSize(width: 320, height: 240)
        )
        viewModel.currentVideo = video
        viewModel.restorePendingEditingPresentationState()

        #expect(abs(videoPlayer.currentTime - 11) < 0.0001)
        #expect(viewModel.currentVideo?.rangeDuration == 8...24)
        #expect(abs(Double(viewModel.currentVideo?.rate ?? 0) - 1.5) < 0.0001)
        #expect(abs(Double(viewModel.currentVideo?.volume ?? 0) - 0.55) < 0.0001)
        #expect(viewModel.currentVideo?.rotation == 90)
        #expect(viewModel.currentVideo?.isMirror == true)
        #expect(viewModel.currentVideo?.filterName == "CIPhotoEffectMono")
        #expect(viewModel.currentVideo?.audio?.url == audioURL)
        #expect(viewModel.selectedAudioTrack == .recorded)
        #expect(viewModel.cropFreeformRect == editingConfiguration.crop.freeformRect)
        #expect(viewModel.cropTab == .format)
        #expect(viewModel.selectedTools == .filters)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .cut) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .speed) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .crop) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .filters) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .corrections) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .frames) == true)
    }

    @Test
    func currentEditingConfigurationBuildsSnapshotFromCurrentEditorState() throws {
        let viewModel = EditorViewModel()
        let audioURL = try TestFixtures.createTemporaryAudio()
        defer { FileManager.default.removeIfExists(for: audioURL) }

        var video = Video.mock
        video.rangeDuration = 4...18
        video.updateRate(1.75)
        video.rotation = 180
        video.isMirror = true
        video.setFilter("CIPhotoEffectNoir")
        video.colorCorrection = .init(
            brightness: 0.2,
            contrast: 1.15,
            saturation: 0.65
        )
        video.geometrySize = CGSize(width: 160, height: 80)
        video.audio = Audio(
            url: audioURL,
            duration: 2.5,
            volume: 0.45
        )
        video.textBoxes = [
            TextBox(
                text: "Exported",
                fontSize: 26,
                bgColor: Color(uiColor: .systemBlue),
                fontColor: Color(uiColor: .systemBackground),
                timeRange: 3...7,
                offset: CGSize(width: 16, height: -8)
            )
        ]

        viewModel.currentVideo = video
        viewModel.frames = VideoFrames(
            scaleValue: 0.3,
            frameColor: Color(uiColor: .systemOrange)
        )
        viewModel.selectedAudioTrack = .recorded
        viewModel.cropFreeformRect = .init(
            x: 0.12,
            y: 0.08,
            width: 0.72,
            height: 0.6
        )
        viewModel.cropTab = .format
        viewModel.selectTool(.filters)

        let configuration = viewModel.currentEditingConfiguration(currentTimelineTime: 9)

        #expect(configuration?.trim.lowerBound == 4)
        #expect(configuration?.trim.upperBound == 18)
        #expect(abs(Double(configuration?.playback.rate ?? 0) - 1.75) < 0.0001)
        #expect(abs(Double(configuration?.playback.currentTimelineTime ?? 0) - 9) < 0.0001)
        #expect(configuration?.crop.rotationDegrees == 180)
        #expect(configuration?.crop.isMirrored == true)
        #expect(configuration?.crop.freeformRect == viewModel.cropFreeformRect)
        #expect(configuration?.filter.filterName == "CIPhotoEffectNoir")
        #expect(configuration?.frame.colorToken == "palette:orange")
        #expect(configuration?.audio.selectedTrack == .recorded)
        #expect(configuration?.audio.recordedClip?.url == audioURL)
        #expect(configuration?.presentation.selectedTool == .filters)
        #expect(configuration?.presentation.cropTab == .format)
        #expect(abs((configuration?.textOverlays[0].offset.x ?? 0) - 0.1) < 0.0001)
        #expect(abs((configuration?.textOverlays[0].offset.y ?? 0) + 0.1) < 0.0001)
    }

    @Test
    func updateCurrentVideoLayoutRescalesTextOffsetsAndSyncsTextEditor() {
        let viewModel = EditorViewModel()
        let textEditor = TextEditorViewModel()
        var video = Video.mock
        video.geometrySize = CGSize(width: 200, height: 100)
        video.frameSize = CGSize(width: 200, height: 100)
        video.textBoxes = [
            TextBox(
                text: "Overlay",
                offset: CGSize(width: 20, height: -10),
                lastOffset: CGSize(width: 20, height: -10)
            )
        ]
        viewModel.currentVideo = video
        textEditor.load(textBoxes: video.textBoxes)

        viewModel.updateCurrentVideoLayout(
            to: CGSize(width: 400, height: 200),
            textEditor: textEditor
        )

        #expect(viewModel.currentVideo?.geometrySize == CGSize(width: 400, height: 200))
        #expect(viewModel.currentVideo?.textBoxes[0].offset == CGSize(width: 40, height: -20))
        #expect(viewModel.currentVideo?.textBoxes[0].lastOffset == CGSize(width: 40, height: -20))
        #expect(textEditor.textBoxes[0].offset == CGSize(width: 40, height: -20))
    }

}
