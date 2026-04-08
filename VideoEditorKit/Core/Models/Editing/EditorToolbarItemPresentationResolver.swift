//
//  EditorToolbarItemPresentationResolver.swift
//  VideoEditorKit
//
//  Created by Codex on 07.04.2026.
//

import Foundation

struct EditorToolbarItemPresentation: Equatable, Sendable {

    // MARK: - Public Properties

    let title: String
    let image: String
    let subtitle: String?
    let isApplied: Bool

}

struct EditorToolbarItemPresentationResolver {

    // MARK: - Public Methods

    static func resolve(
        for tool: ToolEnum,
        video: Video?,
        cropPresentationSummary: EditorCropPresentationSummary?,
        transcriptDocument: TranscriptDocument?
    ) -> EditorToolbarItemPresentation {
        let isApplied = video?.isAppliedTool(for: tool) ?? false

        return .init(
            title: tool.title,
            image: tool.image,
            subtitle: isApplied
                ? subtitle(
                    for: tool,
                    video: video,
                    cropPresentationSummary: cropPresentationSummary,
                    transcriptDocument: transcriptDocument
                )
                : nil,
            isApplied: isApplied
        )
    }

    // MARK: - Private Methods

    private static func subtitle(
        for tool: ToolEnum,
        video: Video?,
        cropPresentationSummary: EditorCropPresentationSummary?,
        transcriptDocument: TranscriptDocument?
    ) -> String? {
        switch tool {
        case .speed:
            speedSubtitle(video)
        case .presets:
            presetsSubtitle(cropPresentationSummary)
        case .audio:
            audioSubtitle(video)
        case .adjusts:
            adjustsSubtitle(video)
        case .transcript:
            transcriptSubtitle(transcriptDocument)
        case .cut:
            nil
        }
    }

    private static func speedSubtitle(
        _ video: Video?
    ) -> String? {
        guard let rate = video?.rate else { return nil }
        return "\(rate.formatted(.number.precision(.fractionLength(1))))x"
    }

    private static func presetsSubtitle(
        _ cropPresentationSummary: EditorCropPresentationSummary?
    ) -> String? {
        guard let cropPresentationSummary else { return nil }

        if cropPresentationSummary.selectedPreset == .original {
            return "Custom crop"
        }

        return "\(cropPresentationSummary.badgeTitle) \(cropPresentationSummary.badgeDimension)"
    }

    private static func audioSubtitle(
        _ video: Video?
    ) -> String? {
        guard let video else { return nil }

        if let recordedAudio = video.audio {
            return percentageString(for: recordedAudio.volume)
        }

        return percentageString(for: video.volume)
    }

    private static func adjustsSubtitle(
        _ video: Video?
    ) -> String? {
        guard let appliedAdjustmentsCount = video?.colorAdjusts.appliedAdjustmentsCount else {
            return nil
        }

        guard appliedAdjustmentsCount > 0 else { return nil }

        let suffix = appliedAdjustmentsCount == 1 ? "" : "s"
        return "\(appliedAdjustmentsCount) adjustment\(suffix)"
    }

    private static func transcriptSubtitle(
        _ transcriptDocument: TranscriptDocument?
    ) -> String? {
        guard let transcriptDocument else { return nil }

        return
            "\(transcriptDocument.overlayPosition.abbreviation)/\(transcriptDocument.overlaySize.abbreviation)"
    }

    private static func percentageString(
        for value: Float
    ) -> String {
        "\(Int((Double(value) * 100).rounded()))%"
    }

}
