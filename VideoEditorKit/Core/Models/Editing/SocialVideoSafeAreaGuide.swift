//
//  SocialVideoSafeAreaGuide.swift
//  VideoEditorKit
//
//  Created by Codex on 30.03.2026.
//

import CoreGraphics
import Foundation

struct SocialVideoSafeAreaGuide: Equatable, Sendable {

    // MARK: - Public Properties

    struct Region: Equatable, Identifiable, Sendable {

        // MARK: - Public Properties

        enum Role: String, Sendable {
            case top
            case bottom
            case trailing
        }

        let role: Role
        let title: String
        let rect: CGRect

        var id: Role {
            role
        }

    }

    static let instagramReels = Self(
        topInsetRatio: 0.12,
        bottomInsetRatio: 0.20,
        leadingInsetRatio: 0.06,
        trailingInsetRatio: 0.20
    )
    static let tikTok = Self(
        topInsetRatio: 0.13,
        bottomInsetRatio: 0.24,
        leadingInsetRatio: 0.06,
        trailingInsetRatio: 0.18
    )
    static let youtubeShorts = Self(
        topInsetRatio: 0.10,
        bottomInsetRatio: 0.16,
        leadingInsetRatio: 0.05,
        trailingInsetRatio: 0.14
    )

    let topInsetRatio: CGFloat
    let bottomInsetRatio: CGFloat
    let leadingInsetRatio: CGFloat
    let trailingInsetRatio: CGFloat

    // MARK: - Public Methods

    func safeRect(in canvasRect: CGRect) -> CGRect {
        guard canvasRect.width > 0, canvasRect.height > 0 else { return .zero }

        let topInset = boundedInset(topInsetRatio, dimension: canvasRect.height)
        let bottomInset = boundedInset(bottomInsetRatio, dimension: canvasRect.height)
        let leadingInset = boundedInset(leadingInsetRatio, dimension: canvasRect.width)
        let trailingInset = boundedInset(trailingInsetRatio, dimension: canvasRect.width)
        let width = max(canvasRect.width - leadingInset - trailingInset, 0)
        let height = max(canvasRect.height - topInset - bottomInset, 0)

        return CGRect(
            x: canvasRect.minX + leadingInset,
            y: canvasRect.minY + topInset,
            width: width,
            height: height
        )
    }

    func overlayRegions(in canvasRect: CGRect) -> [Region] {
        let safeRect = safeRect(in: canvasRect)
        guard safeRect.width > 0, safeRect.height > 0 else { return [] }

        return [
            Region(
                role: .top,
                title: "Top UI",
                rect: CGRect(
                    x: canvasRect.minX,
                    y: canvasRect.minY,
                    width: canvasRect.width,
                    height: max(safeRect.minY - canvasRect.minY, 0)
                )
            ),
            Region(
                role: .bottom,
                title: "Bottom UI",
                rect: CGRect(
                    x: canvasRect.minX,
                    y: safeRect.maxY,
                    width: canvasRect.width,
                    height: max(canvasRect.maxY - safeRect.maxY, 0)
                )
            ),
            Region(
                role: .trailing,
                title: "Actions",
                rect: CGRect(
                    x: safeRect.maxX,
                    y: safeRect.minY,
                    width: max(canvasRect.maxX - safeRect.maxX, 0),
                    height: safeRect.height
                )
            ),
        ]
        .filter { !$0.rect.isEmpty }
    }

    // MARK: - Private Methods

    private func boundedInset(_ ratio: CGFloat, dimension: CGFloat) -> CGFloat {
        max(min(ratio, 0.45), 0) * dimension
    }

}

extension VideoEditingConfiguration.SocialVideoDestination {

    // MARK: - Public Properties

    var safeAreaGuide: SocialVideoSafeAreaGuide {
        switch self {
        case .instagramReels:
            .instagramReels
        case .tikTok:
            .tikTok
        case .youtubeShorts:
            .youtubeShorts
        }
    }

}
