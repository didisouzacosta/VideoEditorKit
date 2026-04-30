import AVFoundation
import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("VideoEditorTests", .serialized)
struct VideoEditorTests {

    // MARK: - Public Methods

    @Test
    func resolvedCropRectConvertsNormalizedGeometryIntoRenderCoordinates() {
        let cropRect = VideoEditor.resolvedCropRect(
            for: .init(
                x: 0.1,
                y: 0.2,
                width: 0.5,
                height: 0.4
            ),
            in: CGSize(width: 1000, height: 500)
        )

        #expect(cropRect == CGRect(x: 100, y: 100, width: 500, height: 200))
    }

    @Test
    func resolvedCropRectClampsOutOfBoundsValuesToTheVisibleFrame() {
        let cropRect = VideoEditor.resolvedCropRect(
            for: .init(
                x: -0.2,
                y: 0.85,
                width: 1.4,
                height: 0.5
            ),
            in: CGSize(width: 1000, height: 500)
        )

        #expect(cropRect == CGRect(x: 0, y: 424, width: 1000, height: 76))
    }

    @Test
    func watermarkLayoutUsesExactImageSizeAndTopLeadingPadding() {
        let frame = VideoWatermarkLayout.frame(
            renderSize: CGSize(width: 1920, height: 1080),
            imageSize: CGSize(width: 120, height: 48),
            position: .topLeading
        )

        #expect(frame == CGRect(x: 16, y: 16, width: 120, height: 48))
    }

    @Test
    func watermarkLayoutUsesTopTrailingPadding() {
        let frame = VideoWatermarkLayout.frame(
            renderSize: CGSize(width: 1920, height: 1080),
            imageSize: CGSize(width: 120, height: 48),
            position: .topTrailing
        )

        #expect(frame == CGRect(x: 1784, y: 16, width: 120, height: 48))
    }

    @Test
    func watermarkLayoutUsesBottomLeadingPadding() {
        let frame = VideoWatermarkLayout.frame(
            renderSize: CGSize(width: 1920, height: 1080),
            imageSize: CGSize(width: 120, height: 48),
            position: .bottomLeading
        )

        #expect(frame == CGRect(x: 16, y: 1016, width: 120, height: 48))
    }

    @Test
    func watermarkLayoutUsesBottomTrailingPadding() {
        let frame = VideoWatermarkLayout.frame(
            renderSize: CGSize(width: 1920, height: 1080),
            imageSize: CGSize(width: 120, height: 48),
            position: .bottomTrailing
        )

        #expect(frame == CGRect(x: 1784, y: 1016, width: 120, height: 48))
    }

    @Test
    func resolvedOutputRenderLayoutUsesPresetAspectRatioWithoutSocialDestination() {
        let configuration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0.275,
                    y: 0,
                    width: 0.45,
                    height: 1
                )
            )
        )

        let layout = VideoEditor.resolvedOutputRenderLayout(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: configuration
        )

        #expect(layout == .portrait)
    }

    @Test
    func resolvedOutputRenderSizeScalesFacebookPostPresetExportsToTheSelectedQuality() {
        let configuration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0.275,
                    y: 0,
                    width: 0.45,
                    height: 1
                )
            )
        )

        let renderSize = VideoEditor.resolvedOutputRenderSize(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: configuration,
            videoQuality: .medium
        )

        #expect(renderSize == CGSize(width: 720, height: 900))
    }

    @Test
    func resolvedCropRectSharesTheSameVisibleGeometryAsThePreviewLayout() throws {
        let sourceSize = CGSize(width: 1000, height: 500)
        let freeformRect = VideoEditingConfiguration.FreeformRect(
            x: 0.8,
            y: 0.1,
            width: 0.4,
            height: 0.8
        )
        let previewLayout = try #require(
            VideoCropPreviewLayout(
                freeformRect: freeformRect,
                in: sourceSize
            )
        )

        let cropRect = VideoEditor.resolvedCropRect(
            for: freeformRect,
            in: sourceSize
        )

        #expect(cropRect == previewLayout.sourceRect)
    }

    @Test
    func resolvedOutputRenderLayoutUsesTheClampedPreviewGeometryWhenCropOverflowsTheSource() {
        let configuration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0.8,
                    y: 0.1,
                    width: 0.4,
                    height: 0.8
                )
            )
        )

        let layout = VideoEditor.resolvedOutputRenderLayout(
            for: CGSize(width: 1000, height: 500),
            editingConfiguration: configuration
        )

        #expect(layout == .portrait)
    }

    @Test
    func resolvedOutputRenderSizeScalesPersistedCanvasPresetDimensionsToTheSelectedQuality() {
        let configuration = VideoEditingConfiguration(
            canvas: .init(
                snapshot: .init(
                    preset: .facebookPost,
                    freeCanvasSize: CGSize(width: 1080, height: 1350)
                )
            )
        )

        let renderSize = VideoEditor.resolvedOutputRenderSize(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: configuration,
            videoQuality: .low
        )

        #expect(renderSize == CGSize(width: 480, height: 600))
    }

    @Test
    func resolvedExportProfileSharesTheCanvasRenderSizeForTheSelectedQuality() {
        let video = Video(
            url: URL(fileURLWithPath: "/tmp/export-profile.mp4"),
            asset: AVURLAsset(url: URL(fileURLWithPath: "/tmp/export-profile.mp4")),
            originalDuration: 12,
            rangeDuration: 0...12,
            presentationSize: CGSize(width: 1920, height: 1080)
        )
        let configuration = VideoEditingConfiguration(
            canvas: .init(
                snapshot: .init(
                    preset: .facebookPost,
                    freeCanvasSize: CGSize(width: 1080, height: 1350)
                )
            )
        )

        let exportProfile = VideoEditor.resolvedExportProfile(
            for: video,
            editingConfiguration: configuration,
            videoQuality: .medium
        )

        #expect(exportProfile.renderSize == CGSize(width: 720, height: 900))
    }

    @Test
    func resolvedSaveNativeRenderProfileUsesCanvasSizeWhilePreservingSourceFrameRate() {
        let profile = VideoEditor.resolvedRenderProfile(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: VideoEditingConfiguration(
                canvas: .init(
                    snapshot: .init(
                        preset: .facebookPost,
                        freeCanvasSize: CGSize(width: 1080, height: 1350)
                    )
                )
            ),
            intent: .saveNative(sourceFrameRate: 23.976),
            isSimulatorEnvironment: true
        )

        #expect(profile.intent == .saveNative(sourceFrameRate: 23.976))
        #expect(profile.renderSize == CGSize(width: 1080, height: 1350))
        #expect(abs(profile.frameDuration.seconds - (1 / 23.976)) < 0.0001)
        #expect(profile.renderPresetName == AVAssetExportPresetHighestQuality)
        #expect(profile.passthroughPresetName == AVAssetExportPresetPassthrough)
    }

    @Test
    func resolvedSaveNativeRenderProfileKeepsSourceSizeWhenCanvasIsIdentity() {
        let profile = VideoEditor.resolvedRenderProfile(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: .initial,
            intent: .saveNative(sourceFrameRate: 24),
            isSimulatorEnvironment: true
        )

        #expect(profile.renderSize == CGSize(width: 1920, height: 1080))
        #expect(abs(profile.frameDuration.seconds - (1 / 24.0)) < 0.0001)
    }

    @Test
    func startRenderSaveNativeProducesCanvasSizedVideoForPresetEdits() async throws {
        let url = try await TestFixtures.createTemporaryVideo(
            size: CGSize(width: 160, height: 90),
            frameCount: 12,
            framesPerSecond: 24
        )
        defer { FileManager.default.removeIfExists(for: url) }

        let video = await Video.load(from: url)
        let editingConfiguration = VideoEditingConfiguration(
            canvas: .init(
                snapshot: .init(
                    preset: .custom(width: 108, height: 135),
                    freeCanvasSize: CGSize(width: 108, height: 135),
                    transform: .init(
                        normalizedOffset: CGPoint(x: 0.15, y: 0),
                        zoom: 1.2,
                        rotationRadians: 0
                    )
                )
            )
        )

        let savedURL = try await VideoEditor.startRender(
            video: video,
            editingConfiguration: editingConfiguration,
            renderIntent: .saveNative(sourceFrameRate: 24)
        )
        defer { FileManager.default.removeIfExists(for: savedURL) }

        let savedAsset = AVURLAsset(url: savedURL)
        let savedSize = try #require(await savedAsset.presentationSize())

        #expect(savedSize == CGSize(width: 108, height: 136))
    }

    @Test
    func resolvedSaveNativeRenderProfileFallsBackToThirtyFPSWhenSourceFrameRateIsInvalid() {
        let profile = VideoEditor.resolvedRenderProfile(
            for: CGSize(width: 1080, height: 1920),
            editingConfiguration: .initial,
            intent: .saveNative(sourceFrameRate: 0),
            isSimulatorEnvironment: true
        )

        #expect(profile.renderSize == CGSize(width: 1080, height: 1920))
        #expect(profile.frameDuration == CMTime(seconds: 1 / 30, preferredTimescale: 600))
    }

    @Test
    func resolvedSourceFrameRateLoadsNominalFrameRateFromTheVideoAsset() async throws {
        let url = try await TestFixtures.createTemporaryVideo(
            frameCount: 48,
            framesPerSecond: 24
        )
        let asset = AVURLAsset(url: url)

        let frameRate = await VideoEditor.resolvedSourceFrameRate(for: asset)

        #expect(frameRate == 24)
    }

    @Test
    func canIntegrateAdjustsIntoBaseRenderForNativeIdentityOutput() async throws {
        let size = CGSize(width: 48, height: 24)
        let url = try await TestFixtures.createTemporaryVideo(size: size)
        let video = Video(
            url: url,
            asset: AVURLAsset(url: url),
            originalDuration: 1,
            rangeDuration: 0...1,
            presentationSize: size
        )
        let exportProfile = VideoEditor.resolvedExportProfile(
            for: video,
            editingConfiguration: .initial,
            videoQuality: .original,
            isSimulatorEnvironment: true
        )

        let canIntegrate = await VideoEditor.canIntegrateAdjustsIntoBaseRender(
            video: video,
            editingConfiguration: .initial,
            exportProfile: exportProfile
        )

        #expect(canIntegrate)
    }

    @Test
    func canIntegrateAdjustsIntoBaseRenderRejectsScaledOutputs() async throws {
        let size = CGSize(width: 48, height: 24)
        let url = try await TestFixtures.createTemporaryVideo(size: size)
        let video = Video(
            url: url,
            asset: AVURLAsset(url: url),
            originalDuration: 1,
            rangeDuration: 0...1,
            presentationSize: size
        )
        let scaledProfile = VideoEditor.ExportProfile(
            quality: .medium,
            renderSize: CGSize(width: 96, height: 48),
            frameDuration: CMTime(seconds: 1 / 30, preferredTimescale: 600),
            renderPresetName: AVAssetExportPresetHighestQuality,
            passthroughPresetName: AVAssetExportPresetPassthrough
        )

        let canIntegrate = await VideoEditor.canIntegrateAdjustsIntoBaseRender(
            video: video,
            editingConfiguration: .initial,
            exportProfile: scaledProfile
        )

        #expect(canIntegrate == false)
    }

    @Test
    func resolvedExportRenderProfileKeepsSelectedQualityRules() {
        let profile = VideoEditor.resolvedRenderProfile(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: VideoEditingConfiguration(
                canvas: .init(
                    snapshot: .init(
                        preset: .facebookPost,
                        freeCanvasSize: CGSize(width: 1080, height: 1350)
                    )
                )
            ),
            intent: .export(.medium),
            isSimulatorEnvironment: true
        )

        #expect(profile.intent == .export(.medium))
        #expect(profile.renderSize == CGSize(width: 720, height: 900))
        #expect(profile.frameDuration == CMTime(seconds: 1 / 30, preferredTimescale: 600))
    }

    @Test
    func resolvedOutputRenderLayoutUsesCanvasPresetOrientationWhenPersisted() {
        let configuration = VideoEditingConfiguration(
            canvas: .init(
                snapshot: .init(
                    preset: .custom(width: 1080, height: 1080),
                    freeCanvasSize: CGSize(width: 1080, height: 1080)
                )
            )
        )

        let layout = VideoEditor.resolvedOutputRenderLayout(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: configuration
        )

        #expect(layout == .landscape)
    }

    @Test
    func resolvedExportPresetNameUsesARealRenderPresetForVideoCompositionOnSimulator() {
        let presetName = VideoEditor.resolvedExportPresetName(
            videoQuality: .low,
            appliesVideoComposition: true,
            isSimulatorEnvironment: true
        )

        #expect(presetName == AVAssetExportPresetHighestQuality)
    }

    @Test
    func resolvedExportPresetNameKeepsPassthroughAvailableOnlyWithoutRenderingStages() {
        let presetName = VideoEditor.resolvedExportPresetName(
            videoQuality: .high,
            appliesVideoComposition: false,
            isSimulatorEnvironment: true
        )

        #expect(presetName == AVAssetExportPresetPassthrough)
    }

    @Test
    func resolvedRenderStagesAbsorbCanvasIntoTheBaseStageWhenCanvasRenderingIsActive() {
        let stages = VideoEditor.resolvedRenderStages(
            usesAdjustsStage: true,
            usesTranscriptStage: true,
            usesCropStage: true
        )

        #expect(stages == [.base, .adjusts, .transcript])
    }

    @Test
    func resolvedRenderStagesKeepsTranscriptImmediatelyAfterAdjustsWhenCanvasRenderingIsDisabled() {
        let stages = VideoEditor.resolvedRenderStages(
            usesAdjustsStage: true,
            usesTranscriptStage: true,
            usesCropStage: false
        )

        #expect(stages == [.base, .adjusts, .transcript])
    }

    @Test
    func resolvedTranscriptRenderBatchesSplitLargeWordRunsWithoutChangingOrder() {
        let firstSegment = VideoEditor.TranscriptRenderSegment(
            text: "one",
            timeRange: 0...1,
            style: .defaultCaptionStyle,
            words: (0..<20).map { index in
                VideoEditor.TranscriptRenderWord(
                    id: UUID(),
                    text: "w\(index)",
                    timeRange: Double(index)...Double(index + 1)
                )
            }
        )
        let secondSegment = VideoEditor.TranscriptRenderSegment(
            text: "two",
            timeRange: 1...2,
            style: .defaultCaptionStyle,
            words: (20..<40).map { index in
                VideoEditor.TranscriptRenderWord(
                    id: UUID(),
                    text: "w\(index)",
                    timeRange: Double(index)...Double(index + 1)
                )
            }
        )
        let thirdSegment = VideoEditor.TranscriptRenderSegment(
            text: "fallback",
            timeRange: 2...3,
            style: .defaultCaptionStyle,
            words: []
        )
        let renderUnits = VideoEditor.resolvedTranscriptRenderUnits(
            from: [firstSegment, secondSegment, thirdSegment]
        )

        let batches = VideoEditor.resolvedTranscriptRenderBatches(
            from: renderUnits
        )

        #expect(batches.count == 2)
        #expect(batches[0].count == 32)
        #expect(batches[1].count == 9)
        #expect(
            batches.flatMap { $0.map(\.text) }
                == renderUnits.map(\.text)
        )
    }

    @Test
    func requiresTranscriptStageOnlyWhenALoadedTimelineSegmentExists() {
        let loadedConfiguration = VideoEditingConfiguration(
            transcript: .init(
                featureState: .loaded,
                document: TranscriptDocument(
                    segments: [
                        EditableTranscriptSegment(
                            id: UUID(),
                            timeMapping: .init(
                                sourceStartTime: 4,
                                sourceEndTime: 8,
                                timelineStartTime: 2,
                                timelineEndTime: 6
                            ),
                            originalText: "Hello",
                            editedText: "Hello"
                        )
                    ]
                )
            )
        )
        let missingTimelineConfiguration = VideoEditingConfiguration(
            transcript: .init(
                featureState: .loaded,
                document: TranscriptDocument(
                    segments: [
                        EditableTranscriptSegment(
                            id: UUID(),
                            timeMapping: .init(
                                sourceStartTime: 4,
                                sourceEndTime: 8,
                                timelineStartTime: nil,
                                timelineEndTime: nil
                            ),
                            originalText: "Hello",
                            editedText: "Hello"
                        )
                    ]
                )
            )
        )

        #expect(VideoEditor.requiresTranscriptStage(loadedConfiguration))
        #expect(VideoEditor.requiresTranscriptStage(missingTimelineConfiguration) == false)
    }

    @Test
    func resolvedTranscriptRenderSegmentsUseTheDefaultStyleAndKeepRenderableWords() {
        let transcriptDocument = TranscriptDocument(
            segments: [
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 4,
                        sourceEndTime: 8,
                        timelineStartTime: 2,
                        timelineEndTime: 6
                    ),
                    originalText: "hello world",
                    editedText: "hello world",
                    words: [
                        EditableTranscriptWord(
                            id: UUID(),
                            timeMapping: .init(
                                sourceStartTime: 4,
                                sourceEndTime: 5,
                                timelineStartTime: 2,
                                timelineEndTime: 3
                            ),
                            originalText: "hello",
                            editedText: "hello"
                        ),
                        EditableTranscriptWord(
                            id: UUID(),
                            timeMapping: .init(
                                sourceStartTime: 5,
                                sourceEndTime: 6,
                                timelineStartTime: 3,
                                timelineEndTime: 4
                            ),
                            originalText: "world",
                            editedText: "world"
                        ),
                    ]
                )
            ]
        )

        let renderSegments = VideoEditor.resolvedTranscriptRenderSegments(
            from: transcriptDocument
        )

        #expect(renderSegments.count == 1)
        #expect(renderSegments.first?.style.name == "Default")
        #expect(renderSegments.first?.style.fontWeight == .semibold)
        #expect(renderSegments.first?.style.hasStroke == true)
        #expect(
            renderSegments.first?.style.strokeColor
                == .init(
                    red: 0,
                    green: 0,
                    blue: 0,
                    alpha: 1
                )
        )
        #expect(renderSegments.first?.words.map(\.text) == ["hello", "world"])
        #expect(renderSegments.first?.words.count == transcriptDocument.segments.first?.words.count)
    }

    @Test
    func resolvedTranscriptRenderSegmentsForExportNormalizesTrimmedTimelineToZero() throws {
        let firstWordID = UUID()
        let secondWordID = UUID()
        let transcriptDocument = TranscriptDocument(
            segments: [
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 10,
                        sourceEndTime: 12,
                        timelineStartTime: 5,
                        timelineEndTime: 6
                    ),
                    originalText: "hello world",
                    editedText: "hello world",
                    words: [
                        EditableTranscriptWord(
                            id: firstWordID,
                            timeMapping: .init(
                                sourceStartTime: 10,
                                sourceEndTime: 11,
                                timelineStartTime: 5,
                                timelineEndTime: 5.5
                            ),
                            originalText: "hello",
                            editedText: "hello"
                        ),
                        EditableTranscriptWord(
                            id: secondWordID,
                            timeMapping: .init(
                                sourceStartTime: 11,
                                sourceEndTime: 12,
                                timelineStartTime: 5.5,
                                timelineEndTime: 6
                            ),
                            originalText: "world",
                            editedText: "world"
                        ),
                    ]
                )
            ]
        )
        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(
                lowerBound: 10,
                upperBound: 12
            ),
            playback: .init(
                rate: 2
            )
        )

        let renderSegment = try #require(
            VideoEditor.resolvedTranscriptRenderSegmentsForExport(
                from: transcriptDocument,
                editingConfiguration: editingConfiguration
            ).first
        )

        #expect(renderSegment.timeRange == 0...1)
        #expect(renderSegment.words.map(\.id) == [firstWordID, secondWordID])
        #expect(renderSegment.words.map(\.timeRange) == [0...0.5, 0.5...1])
    }

    @Test
    func resolvedTranscriptVisibilityAnimationTurnsOnImmediatelyAtSegmentStart() {
        let animation = VideoEditor.resolvedTranscriptVisibilityAnimation(
            for: 2.0...3.0
        )

        #expect((animation.values as? [NSNumber])?.map(\.doubleValue) == [0, 1, 1, 0])
        #expect(animation.keyTimes?.map(\.doubleValue) == [0, 0.0001, 0.999, 1])
    }

    @Test
    func resolvedActiveWordTimelineStatesInsertHiddenStatesOnlyAcrossRealGaps() {
        let renderUnits: [VideoEditor.TranscriptRenderUnit] = [
            .init(
                text: "alpha",
                timeRange: 0...0.8,
                style: .defaultCaptionStyle,
                mode: .activeWord
            ),
            .init(
                text: "beta",
                timeRange: 0.8...1.4,
                style: .defaultCaptionStyle,
                mode: .activeWord
            ),
            .init(
                text: "gamma",
                timeRange: 2.0...2.6,
                style: .defaultCaptionStyle,
                mode: .activeWord
            ),
        ]

        let timelineStates = VideoEditor.resolvedActiveWordTimelineStates(
            from: renderUnits,
            overlayPosition: .bottom,
            overlaySize: .medium,
            renderSize: CGSize(width: 1080, height: 1920)
        )

        #expect(timelineStates.map(\.time) == [0, 0.8, 1.4, 2.0, 2.6])
        #expect(timelineStates.map(\.text) == ["alpha", "beta", nil, "gamma", nil])
    }

    @Test
    func resolvedActiveWordTimelineStatesUseTheFullAvailableCaptionWidthForSingleWords() throws {
        let renderUnits: [VideoEditor.TranscriptRenderUnit] = [
            .init(
                text: "Edmure,",
                timeRange: 0...1,
                style: .defaultCaptionStyle,
                mode: .activeWord
            )
        ]

        let timelineState = try #require(
            VideoEditor.resolvedActiveWordTimelineStates(
                from: renderUnits,
                overlayPosition: .bottom,
                overlaySize: .medium,
                renderSize: CGSize(width: 1080, height: 1920)
            ).first
        )

        #expect(timelineState.text == "Edmure,")
        #expect(abs(timelineState.frame.minX - 16) < 0.0001)
        #expect(abs((1080 - timelineState.frame.maxX) - 16) < 0.0001)
        #expect(abs(timelineState.frame.width - 1048) < 0.0001)
        #expect(abs(timelineState.textFrame.width - 984) < 0.0001)
        #expect(abs(timelineState.frame.midX - 540) < 0.0001)
        #expect(abs((1920 - timelineState.frame.maxY) - 135) < 0.0001)
    }

    @Test
    func resolvedActiveWordRasterLayoutKeepsCenteredAlignmentWhileReducingTheExportFrame() throws {
        let timelineState = VideoEditor.TranscriptActiveWordTimelineState(
            time: 0,
            text: "Edmure,",
            frame: CGRect(x: 16, y: 1733, width: 1048, height: 52),
            textFrame: CGRect(x: 48, y: 1765, width: 984, height: 20),
            fontSize: 20,
            style: .defaultCaptionStyle
        )

        let rasterLayout = try #require(
            VideoEditor.resolvedActiveWordRasterLayout(
                for: timelineState,
                text: "Edmure,"
            )
        )

        #expect(rasterLayout.frame.width < timelineState.frame.width)
        #expect(abs(rasterLayout.frame.midX - timelineState.frame.midX) < 0.0001)
        #expect(rasterLayout.textFrame.width < timelineState.textFrame.width)
        #expect(abs(rasterLayout.textFrame.midX - timelineState.textFrame.midX) < 0.0001)
    }

    @Test
    func resolvedActiveWordRasterLayoutReturnsNilForHiddenStates() {
        let timelineState = VideoEditor.TranscriptActiveWordTimelineState(
            time: 1,
            text: nil,
            frame: .zero,
            textFrame: .zero,
            fontSize: 0,
            style: .defaultCaptionStyle
        )

        let rasterLayout = VideoEditor.resolvedActiveWordRasterLayout(
            for: timelineState,
            text: "unused"
        )

        #expect(rasterLayout == nil)
    }

    @Test
    func resolvedTranscriptRenderSegmentsKeepTimedWordBlocksWhenEditedTextIsHeavilyRewritten() {
        let transcriptDocument = TranscriptDocument(
            segments: [
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 4,
                        sourceEndTime: 8,
                        timelineStartTime: 2,
                        timelineEndTime: 6
                    ),
                    originalText: "hello world",
                    editedText: "greetings brave world",
                    words: [
                        EditableTranscriptWord(
                            id: UUID(),
                            timeMapping: .init(
                                sourceStartTime: 4,
                                sourceEndTime: 5,
                                timelineStartTime: 2,
                                timelineEndTime: 3
                            ),
                            originalText: "hello",
                            editedText: "hello"
                        ),
                        EditableTranscriptWord(
                            id: UUID(),
                            timeMapping: .init(
                                sourceStartTime: 5,
                                sourceEndTime: 6,
                                timelineStartTime: 3,
                                timelineEndTime: 4
                            ),
                            originalText: "world",
                            editedText: "world"
                        ),
                    ]
                )
            ]
        )

        let renderSegments = VideoEditor.resolvedTranscriptRenderSegments(
            from: transcriptDocument
        )

        #expect(renderSegments.count == 1)
        #expect(renderSegments.first?.words.map(\.text) == ["greetings brave", "world"])
    }

    @Test
    func resolvedTranscriptRenderSegmentsReconcileStandalonePunctuationIntoRenderableWords() {
        let firstWordID = UUID()
        let secondWordID = UUID()
        let transcriptDocument = TranscriptDocument(
            segments: [
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 4,
                        sourceEndTime: 8,
                        timelineStartTime: 2,
                        timelineEndTime: 6
                    ),
                    originalText: "hello world",
                    editedText: "\" Hello , world !",
                    words: [
                        EditableTranscriptWord(
                            id: firstWordID,
                            timeMapping: .init(
                                sourceStartTime: 4,
                                sourceEndTime: 5,
                                timelineStartTime: 2,
                                timelineEndTime: 3
                            ),
                            originalText: "hello",
                            editedText: "hello"
                        ),
                        EditableTranscriptWord(
                            id: secondWordID,
                            timeMapping: .init(
                                sourceStartTime: 5,
                                sourceEndTime: 6,
                                timelineStartTime: 3,
                                timelineEndTime: 4
                            ),
                            originalText: "world",
                            editedText: "world"
                        ),
                    ]
                )
            ]
        )

        let renderSegments = VideoEditor.resolvedTranscriptRenderSegments(
            from: transcriptDocument
        )

        #expect(renderSegments.count == 1)
        #expect(renderSegments.first?.words.map(\.id) == [firstWordID, secondWordID])
        #expect(renderSegments.first?.words.map(\.text) == ["\"Hello,", "world!"])
    }

    @Test
    func resolvedTranscriptRenderSegmentsKeepRenderableWordBlocksWhenTheTextGainsAnInsertedWord() {
        let transcriptDocument = TranscriptDocument(
            segments: [
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 4,
                        sourceEndTime: 8,
                        timelineStartTime: 2,
                        timelineEndTime: 6
                    ),
                    originalText: "hello world",
                    editedText: "hello brave world",
                    words: [
                        EditableTranscriptWord(
                            id: UUID(),
                            timeMapping: .init(
                                sourceStartTime: 4,
                                sourceEndTime: 5,
                                timelineStartTime: 2,
                                timelineEndTime: 3
                            ),
                            originalText: "hello",
                            editedText: "hello"
                        ),
                        EditableTranscriptWord(
                            id: UUID(),
                            timeMapping: .init(
                                sourceStartTime: 5,
                                sourceEndTime: 6,
                                timelineStartTime: 3,
                                timelineEndTime: 4
                            ),
                            originalText: "world",
                            editedText: "world"
                        ),
                    ]
                )
            ]
        )

        let renderSegments = VideoEditor.resolvedTranscriptRenderSegments(
            from: transcriptDocument
        )

        #expect(renderSegments.count == 1)
        #expect(renderSegments.first?.words.map(\.text) == ["hello brave", "world"])
    }

    @Test
    func resolvedTranscriptRenderSegmentsCreateTimedSyntheticWordsWhenPerWordTimingIsUnavailable() {
        let transcriptDocument = TranscriptDocument(
            segments: [
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 4,
                        sourceEndTime: 8,
                        timelineStartTime: 2,
                        timelineEndTime: 6
                    ),
                    originalText: "hello world",
                    editedText: "greetings brave world"
                )
            ]
        )

        let renderSegments = VideoEditor.resolvedTranscriptRenderSegments(
            from: transcriptDocument
        )
        let timeRanges = renderSegments.first?.words.map(\.timeRange) ?? []

        #expect(renderSegments.count == 1)
        #expect(renderSegments.first?.words.map(\.text) == ["greetings", "brave", "world"])
        #expect(timeRanges.count == 3)
        #expect(abs(timeRanges[0].lowerBound - 2) < 0.0001)
        #expect(abs(timeRanges[0].upperBound - 3.3333333333333335) < 0.0001)
        #expect(abs(timeRanges[1].lowerBound - 3.3333333333333335) < 0.0001)
        #expect(abs(timeRanges[1].upperBound - 4.666666666666667) < 0.0001)
        #expect(abs(timeRanges[2].lowerBound - 4.666666666666667) < 0.0001)
        #expect(abs(timeRanges[2].upperBound - 6) < 0.0001)
    }

    @Test
    func resolvedTranscriptRenderSegmentsPreserveTimelineRangesPerWordForExportHighlighting() throws {
        let firstWordID = UUID()
        let secondWordID = UUID()
        let thirdWordID = UUID()
        let segment = EditableTranscriptSegment(
            id: UUID(),
            timeMapping: .init(
                sourceStartTime: 10,
                sourceEndTime: 13,
                timelineStartTime: 2,
                timelineEndTime: 5
            ),
            originalText: "alpha beta gamma",
            editedText: "alpha beta gamma",
            words: [
                EditableTranscriptWord(
                    id: firstWordID,
                    timeMapping: .init(
                        sourceStartTime: 10,
                        sourceEndTime: 11,
                        timelineStartTime: 2.0,
                        timelineEndTime: 2.8
                    ),
                    originalText: "alpha",
                    editedText: "alpha"
                ),
                EditableTranscriptWord(
                    id: secondWordID,
                    timeMapping: .init(
                        sourceStartTime: 11,
                        sourceEndTime: 12,
                        timelineStartTime: 2.8,
                        timelineEndTime: 3.7
                    ),
                    originalText: "beta",
                    editedText: "beta"
                ),
                EditableTranscriptWord(
                    id: thirdWordID,
                    timeMapping: .init(
                        sourceStartTime: 12,
                        sourceEndTime: 13,
                        timelineStartTime: 3.7,
                        timelineEndTime: 5.0
                    ),
                    originalText: "gamma",
                    editedText: "gamma"
                ),
            ]
        )
        let transcriptDocument = TranscriptDocument(
            segments: [segment]
        )

        let renderSegment = try #require(
            VideoEditor.resolvedTranscriptRenderSegments(
                from: transcriptDocument
            ).first
        )

        #expect(renderSegment.words.map(\.id) == [firstWordID, secondWordID, thirdWordID])
        #expect(renderSegment.words.map(\.timeRange) == [2.0...2.8, 2.8...3.7, 3.7...5.0])
    }

    @Test
    func resolvedTranscriptRenderSegmentsMatchTheEditorWordLayoutOrderForWrappedCaptions() throws {
        let segment = EditableTranscriptSegment(
            id: UUID(),
            timeMapping: .init(
                sourceStartTime: 0,
                sourceEndTime: 4,
                timelineStartTime: 0,
                timelineEndTime: 4
            ),
            originalText: "one two three four five six seven eight",
            editedText: "one two three four five six seven eight",
            words: [
                EditableTranscriptWord(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 0, sourceEndTime: 0.5, timelineStartTime: 0, timelineEndTime: 0.5
                    ),
                    originalText: "one",
                    editedText: "one"
                ),
                EditableTranscriptWord(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 0.5, sourceEndTime: 1, timelineStartTime: 0.5, timelineEndTime: 1
                    ),
                    originalText: "two",
                    editedText: "two"
                ),
                EditableTranscriptWord(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 1, sourceEndTime: 1.5, timelineStartTime: 1, timelineEndTime: 1.5
                    ),
                    originalText: "three",
                    editedText: "three"
                ),
                EditableTranscriptWord(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 1.5, sourceEndTime: 2, timelineStartTime: 1.5, timelineEndTime: 2
                    ),
                    originalText: "four",
                    editedText: "four"
                ),
                EditableTranscriptWord(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 2, sourceEndTime: 2.5, timelineStartTime: 2, timelineEndTime: 2.5
                    ),
                    originalText: "five",
                    editedText: "five"
                ),
                EditableTranscriptWord(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 2.5, sourceEndTime: 3, timelineStartTime: 2.5, timelineEndTime: 3
                    ),
                    originalText: "six",
                    editedText: "six"
                ),
                EditableTranscriptWord(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 3, sourceEndTime: 3.5, timelineStartTime: 3, timelineEndTime: 3.5
                    ),
                    originalText: "seven",
                    editedText: "seven"
                ),
                EditableTranscriptWord(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 3.5, sourceEndTime: 4, timelineStartTime: 3.5, timelineEndTime: 4
                    ),
                    originalText: "eight",
                    editedText: "eight"
                ),
            ]
        )
        let transcriptDocument = TranscriptDocument(
            segments: [segment]
        )

        let renderSegment = try #require(
            VideoEditor.resolvedTranscriptRenderSegments(
                from: transcriptDocument
            ).first
        )
        let layout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 320,
            videoHeight: 568,
            selectedPosition: .bottom,
            selectedSize: .medium,
            segment: segment
        )

        #expect(renderSegment.words.count == layout.wordLayouts.count)
        #expect(renderSegment.words.map(\.id) == layout.wordLayouts.map(\.wordID))
        #expect(renderSegment.words.map(\.text) == layout.wordLayouts.map(\.text))
    }

    @Test
    func resolvedTranscriptExportSegmentsRemainRenderableWhenTheVideoIsCropped() throws {
        let transcriptDocument = TranscriptDocument(
            segments: [
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 0,
                        sourceEndTime: 1.5,
                        timelineStartTime: 0,
                        timelineEndTime: 1.5
                    ),
                    originalText: "MMMMMMMMMMMMMMMMMMMMMMMM",
                    editedText: "MMMMMMMMMMMMMMMMMMMMMMMM"
                )
            ],
            overlayPosition: .center,
            overlaySize: .large
        )
        let croppedConfiguration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0.25,
                    y: 0,
                    width: 0.5,
                    height: 1
                )
            ),
            transcript: .init(
                featureState: .loaded,
                document: transcriptDocument
            )
        )
        let renderSegment = try #require(
            VideoEditor.resolvedTranscriptRenderSegmentsForExport(
                from: transcriptDocument,
                editingConfiguration: croppedConfiguration
            ).first
        )
        let renderSize = VideoEditor.resolvedOutputRenderSize(
            for: CGSize(width: 160, height: 90),
            editingConfiguration: croppedConfiguration,
            videoQuality: .low
        )
        let stages = VideoEditor.resolvedRenderStages(
            usesAdjustsStage: false,
            usesTranscriptStage: VideoEditor.requiresTranscriptStage(croppedConfiguration),
            usesCropStage: true
        )

        #expect(renderSegment.text == "MMMMMMMMMMMMMMMMMMMMMMMM")
        #expect(renderSegment.timeRange == 0...1.5)
        #expect(renderSegment.words.map(\.text) == ["MMMMMMMMMMMMMMMMMMMMMMMM"])
        #expect(renderSize == CGSize(width: 80, height: 90))
        #expect(stages == [.base, .transcript])
    }

    @Test
    func resolvedActiveWordTranscriptExportUnitsRemainRenderableWhenTheVideoIsCropped() throws {
        let wordID = UUID()
        let transcriptDocument = TranscriptDocument(
            segments: [
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 0,
                        sourceEndTime: 1.5,
                        timelineStartTime: 0,
                        timelineEndTime: 1.5
                    ),
                    originalText: "MMMMMMMMMMMMMMMM",
                    editedText: "MMMMMMMMMMMMMMMM",
                    words: [
                        EditableTranscriptWord(
                            id: wordID,
                            timeMapping: .init(
                                sourceStartTime: 0,
                                sourceEndTime: 1.5,
                                timelineStartTime: 0,
                                timelineEndTime: 1.5
                            ),
                            originalText: "MMMMMMMMMMMMMMMM",
                            editedText: "MMMMMMMMMMMMMMMM"
                        )
                    ]
                )
            ],
            overlayPosition: .center,
            overlaySize: .large
        )
        let croppedConfiguration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0.25,
                    y: 0,
                    width: 0.5,
                    height: 1
                )
            ),
            transcript: .init(
                featureState: .loaded,
                document: transcriptDocument
            )
        )
        let renderSegments = VideoEditor.resolvedTranscriptRenderSegmentsForExport(
            from: transcriptDocument,
            editingConfiguration: croppedConfiguration
        )
        let renderUnits = VideoEditor.resolvedTranscriptRenderUnits(
            from: renderSegments
        )
        let timelineStates = VideoEditor.resolvedActiveWordTimelineStates(
            from: renderUnits,
            overlayPosition: transcriptDocument.overlayPosition,
            overlaySize: transcriptDocument.overlaySize,
            renderSize: CGSize(width: 480, height: 540)
        )
        let renderSegment = try #require(renderSegments.first)
        let renderUnit = try #require(renderUnits.first)
        let visibleState = try #require(timelineStates.first { !$0.isHidden })

        #expect(renderSegment.words.map(\.id) == [wordID])
        #expect(renderUnit.mode == .activeWord)
        #expect(renderUnit.text == "MMMMMMMMMMMMMMMM")
        #expect(renderUnit.timeRange == 0...1.5)
        #expect(visibleState.text == "MMMMMMMMMMMMMMMM")
        #expect(visibleState.frame.width > 0)
        #expect(visibleState.frame.height > 0)
    }

    @Test
    func resolvedTranscriptExportSegmentsNormalizeTrimmedTimelineToTheExportStart() throws {
        let transcriptDocument = TranscriptDocument(
            segments: [
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 2,
                        sourceEndTime: 3,
                        timelineStartTime: 2,
                        timelineEndTime: 3
                    ),
                    originalText: "MMMMMMMMMMMMMMMMMMMMMMMM",
                    editedText: "MMMMMMMMMMMMMMMMMMMMMMMM"
                )
            ],
            overlayPosition: .center,
            overlaySize: .large
        )
        let configuration = VideoEditingConfiguration(
            trim: .init(
                lowerBound: 2,
                upperBound: 3
            ),
            transcript: .init(
                featureState: .loaded,
                document: transcriptDocument
            )
        )
        let renderSegment = try #require(
            VideoEditor.resolvedTranscriptRenderSegmentsForExport(
                from: transcriptDocument,
                editingConfiguration: configuration
            ).first
        )

        #expect(renderSegment.text == "MMMMMMMMMMMMMMMMMMMMMMMM")
        #expect(renderSegment.timeRange == 0...1)
        #expect(VideoEditor.requiresTranscriptStage(configuration))
    }

}
