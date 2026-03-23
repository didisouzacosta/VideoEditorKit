import Foundation

struct CaptionMergeEngine {
    nonisolated static func apply(
        incoming: [Caption],
        to existing: [Caption],
        strategy: CaptionApplyStrategy
    ) -> [Caption] {
        switch strategy {
        case .replaceAll:
            return incoming
        case .append:
            return existing + incoming
        case .replaceIntersecting:
            let preservedCaptions = existing.filter { existingCaption in
                incoming.contains { incomingCaption in
                    intersects(existingCaption, incomingCaption)
                } == false
            }

            return preservedCaptions + incoming
        }
    }
}

private extension CaptionMergeEngine {
    nonisolated static func intersects(
        _ lhs: Caption,
        _ rhs: Caption
    ) -> Bool {
        lhs.startTime < rhs.endTime && rhs.startTime < lhs.endTime
    }
}
