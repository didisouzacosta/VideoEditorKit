import CoreGraphics

enum ExportPreset: CaseIterable {
    case original
    case instagram
    case youtube
    case tiktok
}

extension ExportPreset {
    var title: String {
        switch self {
        case .original:
            "Original"
        case .instagram:
            "Instagram"
        case .youtube:
            "YouTube"
        case .tiktok:
            "TikTok"
        }
    }

    var minDuration: Double {
        switch self {
        case .original:
            0
        case .instagram:
            3
        case .youtube:
            1
        case .tiktok:
            3
        }
    }

    var maxDuration: Double {
        switch self {
        case .original:
            .infinity
        case .instagram:
            90
        case .youtube:
            60
        case .tiktok:
            180
        }
    }

    var durationRange: ClosedRange<Double> {
        minDuration...maxDuration
    }

    func resolve(videoSize: CGSize) -> CGSize {
        switch self {
        case .original:
            videoSize
        case .instagram, .youtube, .tiktok:
            CGSize(width: 1080, height: 1920)
        }
    }

    var aspectRatio: CGFloat? {
        switch self {
        case .original:
            nil
        case .instagram, .youtube, .tiktok:
            9.0 / 16.0
        }
    }

    var captionSafeArea: CaptionSafeArea {
        switch self {
        case .original:
            CaptionSafeArea(topInset: 24, leftInset: 24, bottomInset: 24, rightInset: 24)
        case .instagram:
            CaptionSafeArea(topInset: 120, leftInset: 32, bottomInset: 260, rightInset: 32)
        case .youtube:
            CaptionSafeArea(topInset: 100, leftInset: 32, bottomInset: 220, rightInset: 32)
        case .tiktok:
            CaptionSafeArea(topInset: 100, leftInset: 32, bottomInset: 300, rightInset: 80)
        }
    }
}
