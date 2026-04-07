import AVFoundation
import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("VideoEditorTests")
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
    func resolvedOutputRenderSizeUsesExactCanvasSizeForFacebookPostPresetExports() {
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

        #expect(renderSize == CGSize(width: 1080, height: 1350))
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
    func resolvedOutputRenderSizeUsesCanvasPresetDimensionsWhenPersisted() {
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

        #expect(renderSize == CGSize(width: 1080, height: 1350))
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
            appliesVideoComposition: true,
            isSimulatorEnvironment: true
        )

        #expect(presetName == AVAssetExportPresetHighestQuality)
    }

    @Test
    func resolvedExportPresetNameKeepsPassthroughAvailableOnlyWithoutRenderingStages() {
        let presetName = VideoEditor.resolvedExportPresetName(
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
    func resolvedTranscriptRenderSegmentsFallBackToBlockRenderingWhenEditedTextNoLongerMatchesWords() {
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
        #expect(renderSegments.first?.words.isEmpty == true)
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

}
