//
//  SocialPlatformSafeArea.swift
//  VideoEditorKit
//
//  Created by Codex on 31.03.2026.
//

import CoreGraphics
import Foundation

struct SafeAreaInsets: Equatable, Sendable {

    // MARK: - Public Properties

    let top: CGFloat
    let bottom: CGFloat
    let left: CGFloat
    let right: CGFloat

    // MARK: - Initializer

    init(
        top: CGFloat,
        bottom: CGFloat,
        left: CGFloat,
        right: CGFloat
    ) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }

    // MARK: - Public Methods

    func safeFrame(
        in previewSize: CGSize
    ) -> CGRect {
        guard previewSize.width > 0, previewSize.height > 0 else {
            return .zero
        }

        let normalized = normalized()
        let x = previewSize.width * normalized.left
        let y = previewSize.height * normalized.top
        let width = previewSize.width * (1 - normalized.left - normalized.right)
        let height = previewSize.height * (1 - normalized.top - normalized.bottom)

        return CGRect(
            x: x,
            y: y,
            width: max(width, 0),
            height: max(height, 0)
        )
    }

    func guideLayout(
        in previewSize: CGSize
    ) -> SafeAreaGuideLayout {
        let safeFrame = safeFrame(in: previewSize)
        var unsafeRegions = [SafeAreaGuideRegion]()

        if safeFrame.minY > 0 {
            unsafeRegions.append(
                .init(
                    role: .top,
                    rect: CGRect(
                        x: 0,
                        y: 0,
                        width: previewSize.width,
                        height: safeFrame.minY
                    )
                )
            )
        }

        if safeFrame.maxY < previewSize.height {
            unsafeRegions.append(
                .init(
                    role: .bottom,
                    rect: CGRect(
                        x: 0,
                        y: safeFrame.maxY,
                        width: previewSize.width,
                        height: previewSize.height - safeFrame.maxY
                    )
                )
            )
        }

        if safeFrame.minX > 0, safeFrame.height > 0 {
            unsafeRegions.append(
                .init(
                    role: .left,
                    rect: CGRect(
                        x: 0,
                        y: safeFrame.minY,
                        width: safeFrame.minX,
                        height: safeFrame.height
                    )
                )
            )
        }

        if safeFrame.maxX < previewSize.width, safeFrame.height > 0 {
            unsafeRegions.append(
                .init(
                    role: .right,
                    rect: CGRect(
                        x: safeFrame.maxX,
                        y: safeFrame.minY,
                        width: previewSize.width - safeFrame.maxX,
                        height: safeFrame.height
                    )
                )
            )
        }

        return SafeAreaGuideLayout(
            safeFrame: safeFrame,
            unsafeRegions: unsafeRegions
        )
    }

    static func intersection(
        of insetsCollection: [Self]
    ) -> Self? {
        guard let firstInsets = insetsCollection.first else { return nil }

        return insetsCollection.dropFirst().reduce(firstInsets) { current, next in
            Self(
                top: max(current.top, next.top),
                bottom: max(current.bottom, next.bottom),
                left: max(current.left, next.left),
                right: max(current.right, next.right)
            )
        }
    }

    // MARK: - Private Methods

    private func normalized() -> Self {
        let clampedTop = top.clamped(to: 0...1)
        let clampedBottom = bottom.clamped(to: 0...1)
        let clampedLeft = left.clamped(to: 0...1)
        let clampedRight = right.clamped(to: 0...1)

        return Self(
            top: min(clampedTop, 1 - clampedBottom),
            bottom: min(clampedBottom, 1 - clampedTop),
            left: min(clampedLeft, 1 - clampedRight),
            right: min(clampedRight, 1 - clampedLeft)
        )
    }

}

enum SafeAreaGuideProfile: Equatable, Sendable {

    // MARK: - Cases

    case universalSocial
    case platform(SocialPlatform)

    // MARK: - Public Properties

    var safeAreaInsets: SafeAreaInsets? {
        switch self {
        case .universalSocial:
            SafeAreaInsets.intersection(
                of: SocialPlatform.allCases.compactMap(\.safeAreaInsets)
            )
        case .platform(let platform):
            platform.safeAreaInsets
        }
    }

}

struct SafeAreaGuideLayout: Equatable, Sendable {

    // MARK: - Public Properties

    let safeFrame: CGRect
    let unsafeRegions: [SafeAreaGuideRegion]

}

struct SafeAreaGuideRegion: Equatable, Sendable, Identifiable {

    enum Role: Equatable, Sendable, Hashable {
        case top
        case bottom
        case left
        case right
    }

    // MARK: - Public Properties

    var id: Role { role }

    let role: Role
    let rect: CGRect

}

enum SocialPlatform: String, Codable, CaseIterable, Equatable, Sendable {

    // MARK: - Cases

    case instagram
    case tiktok
    case youtubeShorts

    // MARK: - Public Properties

    var safeAreaInsets: SafeAreaInsets? {
        switch self {
        case .instagram:
            SafeAreaInsets(
                top: 250 / 1920,
                bottom: 250 / 1920,
                left: 0,
                right: 0
            )
        case .tiktok:
            SafeAreaInsets(
                top: 240 / 1920,
                bottom: 660 / 1920,
                left: 120 / 1080,
                right: 120 / 1080
            )
        case .youtubeShorts:
            SafeAreaInsets(
                top: 288 / 1920,
                bottom: 672 / 1920,
                left: 48 / 1080,
                right: 192 / 1080
            )
        }
    }

    var title: String {
        switch self {
        case .instagram:
            "Instagram Reels"
        case .tiktok:
            "TikTok"
        case .youtubeShorts:
            "YouTube Shorts"
        }
    }

}

extension VideoEditingConfiguration.SocialVideoDestination {

    // MARK: - Public Properties

    var socialPlatform: SocialPlatform {
        switch self {
        case .instagramReels:
            .instagram
        case .tikTok:
            .tiktok
        case .youtubeShorts:
            .youtubeShorts
        }
    }

}

extension CGFloat {

    // MARK: - Public Methods

    fileprivate func clamped(
        to range: ClosedRange<CGFloat>
    ) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

}
