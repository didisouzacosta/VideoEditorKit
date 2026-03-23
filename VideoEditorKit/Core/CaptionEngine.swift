import Foundation

struct CaptionEngine {
    nonisolated static func activeCaptions(
        from captions: [Caption],
        at time: Double,
        in selectedRange: ClosedRange<Double>
    ) -> [Caption] {
        guard selectedRange.contains(time), time < selectedRange.upperBound else {
            return []
        }

        return normalizeCaptions(captions, to: selectedRange).filter { caption in
            caption.startTime <= time && time < caption.endTime
        }
    }

    nonisolated static func normalizeCaptions(
        _ captions: [Caption],
        to selectedRange: ClosedRange<Double>
    ) -> [Caption] {
        captions.compactMap { caption in
            let trimmedText = caption.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedText.isEmpty == false else {
                return nil
            }

            guard caption.endTime > selectedRange.lowerBound else {
                return nil
            }

            guard caption.startTime < selectedRange.upperBound else {
                return nil
            }

            var normalizedCaption = caption
            normalizedCaption.startTime = max(caption.startTime, selectedRange.lowerBound)
            normalizedCaption.endTime = min(caption.endTime, selectedRange.upperBound)

            guard normalizedCaption.startTime < normalizedCaption.endTime else {
                return nil
            }

            return normalizedCaption
        }
    }
}
