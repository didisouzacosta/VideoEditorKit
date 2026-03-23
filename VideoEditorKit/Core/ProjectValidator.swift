import Foundation
import UIKit

struct ProjectValidator {
    nonisolated static func validateProject(
        project: VideoProject,
        videoDuration: Double,
        timeRange: TimeRangeResult
    ) -> ValidationResult {
        var warnings: [String] = []
        var errors: [String] = []

        if project.sourceVideoURL.isFileURL == false || project.sourceVideoURL.path.isEmpty {
            errors.append(Messages.invalidSourceVideo)
        }

        if videoDuration.isFinite == false || videoDuration < 0 {
            errors.append(Messages.invalidVideoDuration)
        }

        if timeRange.isVideoTooShort {
            errors.append("Video is too short for preset \(project.preset.title).")
        }

        if isValidSelectedTimeRange(project.selectedTimeRange) == false || project.selectedTimeRange != timeRange.selectedRange {
            errors.append(Messages.invalidSelectedTimeRange)
        }

        if timeRange.exceedsMaximum {
            warnings.append(Messages.videoWillBeTruncated)
        }

        let normalizedCaptions = CaptionEngine.normalizeCaptions(
            project.captions,
            to: project.selectedTimeRange
        )
        if normalizedCaptions != project.captions {
            warnings.append(Messages.captionsWereSanitized)
        }

        if project.captions.contains(where: usesUnavailableFont) {
            warnings.append(Messages.missingFontFallback)
        }

        return ValidationResult(warnings: warnings, errors: errors)
    }
}

private extension ProjectValidator {
    enum Messages {
        nonisolated static let invalidSourceVideo = "Source video URL is invalid."
        nonisolated static let invalidVideoDuration = "Video duration is invalid."
        nonisolated static let invalidSelectedTimeRange = "Selected time range is invalid for the current preset."
        nonisolated static let videoWillBeTruncated = "Video duration exceeds the preset maximum and will be truncated."
        nonisolated static let captionsWereSanitized = "Some captions were sanitized to fit the selected time range."
        nonisolated static let missingFontFallback = "Some caption fonts are unavailable and will fall back to the system font."
    }

    nonisolated static func isValidSelectedTimeRange(
        _ selectedTimeRange: ClosedRange<Double>
    ) -> Bool {
        selectedTimeRange.lowerBound.isFinite &&
        selectedTimeRange.upperBound.isFinite &&
        selectedTimeRange.lowerBound <= selectedTimeRange.upperBound
    }

    nonisolated static func usesUnavailableFont(_ caption: Caption) -> Bool {
        UIFont(name: caption.style.fontName, size: caption.style.fontSize) == nil
    }
}
