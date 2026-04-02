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
