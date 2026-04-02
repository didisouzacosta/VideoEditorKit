//
//  EditorToolbarLayoutResolver.swift
//  VideoEditorKit
//
//  Created by Codex on 02.04.2026.
//

import CoreGraphics
import Foundation

struct EditorToolbarLayoutMetrics: Equatable, Sendable {

    // MARK: - Public Properties

    let itemsPerPage: Int
    let pageWidth: CGFloat
    let itemSize: CGFloat
    let itemSpacing: CGFloat
    let pageSpacing: CGFloat
    let rowHeight: CGFloat

    // MARK: - Public Methods

    func pageContentWidth(
        for itemCount: Int
    ) -> CGFloat {
        guard itemCount > 0 else { return 0 }

        return (itemSize * CGFloat(itemCount))
            + (itemSpacing * CGFloat(max(itemCount - 1, 0)))
    }

    func shouldCenterRowContent(
        for itemCount: Int,
        availableWidth: CGFloat
    ) -> Bool {
        guard itemCount > 0 else { return false }
        guard itemCount <= itemsPerPage else { return false }

        return pageContentWidth(for: itemCount) < availableWidth
    }

}

struct EditorToolbarLayoutResolver {

    // MARK: - Public Properties

    static let itemsPerPage = Constants.itemsPerPage

    // MARK: - Private Properties

    private enum Constants {
        static let itemsPerPage = 4
        static let itemSpacing: CGFloat = 10
        static let pageSpacing: CGFloat = 10
        static let previewWidth: CGFloat = 28
        static let horizontalInset: CGFloat = 0
    }

    // MARK: - Public Methods

    static func resolvedMetrics(
        for availableWidth: CGFloat
    ) -> EditorToolbarLayoutMetrics {
        let visibleWidth = max(availableWidth - (Constants.horizontalInset * 2), 0)
        let pageWidth = max(
            visibleWidth - Constants.previewWidth - Constants.pageSpacing,
            0
        )
        let itemSize = max(
            (pageWidth
                - (Constants.itemSpacing
                    * CGFloat(Constants.itemsPerPage - 1)))
                / CGFloat(Constants.itemsPerPage),
            0
        )

        return .init(
            itemsPerPage: Constants.itemsPerPage,
            pageWidth: pageWidth,
            itemSize: itemSize,
            itemSpacing: Constants.itemSpacing,
            pageSpacing: Constants.pageSpacing,
            rowHeight: itemSize
        )
    }

}
