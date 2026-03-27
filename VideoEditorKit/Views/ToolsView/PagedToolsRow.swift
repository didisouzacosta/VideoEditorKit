//
//  PagedToolsRow.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 27.03.2026.
//

import SwiftUI

struct PagedToolsRow: View {

    // MARK: - States

    @State private var currentPageID: Int?

    // MARK: - Private Properties

    private let tools: [ToolEnum]
    private let isApplied: (ToolEnum) -> Bool
    private let action: (ToolEnum) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let metrics = layoutMetrics(for: proxy.size.width)

                ScrollView(.horizontal) {
                    GlassEffectContainer(spacing: metrics.itemSpacing) {
                        LazyHStack(spacing: metrics.pageSpacing) {
                            ForEach(Array(toolPages.enumerated()), id: \.offset) { index, page in
                                HStack(spacing: metrics.itemSpacing) {
                                    ForEach(page) { tool in
                                        ToolButtonView(
                                            tool.title,
                                            image: tool.image,
                                            isChange: isApplied(tool)
                                        ) {
                                            action(tool)
                                        }
                                        .frame(width: metrics.itemWidth)
                                    }
                                }
                                .frame(width: metrics.pageWidth, alignment: .leading)
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .padding(.vertical, Layout.verticalContentPadding)
                }
                .contentMargins(.horizontal, Layout.horizontalInset, for: .scrollContent)
                .scrollClipDisabled()
                .scrollIndicators(.hidden)
                .scrollPosition(id: $currentPageID)
                .scrollTargetBehavior(.viewAligned)
            }
            .frame(height: Layout.rowHeight)

            if shouldShowPagination {
                pagination
            }
        }
    }

    // MARK: - Initializer

    init(
        _ tools: [ToolEnum],
        isApplied: @escaping (ToolEnum) -> Bool,
        action: @escaping (ToolEnum) -> Void
    ) {
        self.tools = tools
        self.isApplied = isApplied
        self.action = action
    }

    // MARK: - Private Methods

    private func layoutMetrics(for availableWidth: CGFloat) -> LayoutMetrics {
        let visibleWidth = max(availableWidth - (Layout.horizontalInset * 2), 0)
        let pageWidth = max(visibleWidth - Layout.previewWidth - Layout.pageSpacing, 0)
        let itemWidth = max(
            (pageWidth - (Layout.itemSpacing * CGFloat(Layout.itemsPerPage - 1))) / CGFloat(Layout.itemsPerPage),
            0
        )

        return LayoutMetrics(
            pageWidth: pageWidth,
            itemWidth: itemWidth,
            itemSpacing: Layout.itemSpacing,
            pageSpacing: Layout.pageSpacing
        )
    }

    // MARK: - Private Properties

    private var toolPages: [[ToolEnum]] {
        tools.chunked(into: Layout.itemsPerPage)
    }

    private var shouldShowPagination: Bool {
        toolPages.count > 1
    }

    private var pagination: some View {
        HStack(spacing: 8) {
            ForEach(Array(toolPages.indices), id: \.self) { index in
                Capsule()
                    .fill(index == selectedPageID ? Theme.primary : Theme.secondary.opacity(0.4))
                    .frame(
                        width: index == selectedPageID ? Layout.activeIndicatorWidth : Layout.indicatorSize,
                        height: Layout.indicatorSize
                    )
                    .animation(.snappy(duration: 0.18), value: selectedPageID)
                    .accessibilityHidden(true)
            }
        }
    }

    private var selectedPageID: Int {
        currentPageID ?? 0
    }

}

extension PagedToolsRow {

    fileprivate struct LayoutMetrics {

        // MARK: - Public Properties

        let pageWidth: CGFloat
        let itemWidth: CGFloat
        let itemSpacing: CGFloat
        let pageSpacing: CGFloat

    }

    fileprivate enum Layout {

        // MARK: - Public Properties

        static let itemsPerPage = 4
        static let itemSpacing: CGFloat = 10
        static let pageSpacing: CGFloat = 10
        static let previewWidth: CGFloat = 28
        static let horizontalInset: CGFloat = 0
        static let rowHeight: CGFloat = 97
        static let verticalContentPadding: CGFloat = 6
        static let indicatorSize: CGFloat = 6
        static let activeIndicatorWidth: CGFloat = 18

    }

}

extension Array {

    fileprivate func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { index in
            Array(self[index..<Swift.min(index + size, count)])
        }
    }

}

#Preview {
    PagedToolsRow(ToolEnum.all) { tool in
        [.speed].contains(tool)
    } action: { _ in
    }
}
