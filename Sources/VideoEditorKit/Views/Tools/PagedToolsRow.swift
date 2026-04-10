//
//  PagedToolsRow.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 27.03.2026.
//

import SwiftUI

struct PagedToolsRow: View {

    // MARK: - States

    @State private var currentPageID = 0
    @State private var rowHeight = Layout.defaultRowHeight

    // MARK: - Private Properties

    private let toolAvailability: [ToolAvailability]
    private let presentation: (ToolEnum) -> EditorToolbarItemPresentation
    private let action: (ToolAvailability) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let metrics = EditorToolbarLayoutResolver.resolvedMetrics(
                    for: proxy.size.width
                )

                let shouldCenterRow = metrics.shouldCenterRowContent(
                    for: toolAvailability.count,
                    availableWidth: proxy.size.width
                )

                ScrollView(.horizontal) {
                    GlassEffectContainer(spacing: metrics.itemSpacing) {
                        LazyHStack(spacing: metrics.pageSpacing) {
                            ForEach(Array(toolPages.enumerated()), id: \.offset) { index, page in
                                HStack(spacing: metrics.itemSpacing) {
                                    ForEach(page) { item in
                                        let itemPresentation = presentation(item.tool)

                                        ToolButtonView(
                                            itemPresentation.title,
                                            image: itemPresentation.image,
                                            subtitle: itemPresentation.subtitle,
                                            isChange: itemPresentation.isApplied,
                                            isBlocked: item.isBlocked,
                                            horizontalPadding: metrics.itemHorizontalPadding
                                        ) {
                                            action(item)
                                        }
                                        .frame(
                                            width: metrics.minimumItemWidth,
                                            height: metrics.itemHeight
                                        )
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(
                                    minWidth: metrics.pageWidth(for: page.count),
                                    alignment: .leading
                                )
                                .background(pageOffsetReader(for: index))
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .frame(
                        minWidth: proxy.size.width,
                        alignment: shouldCenterRow ? .center : .leading
                    )
                }
                .coordinateSpace(name: Layout.scrollCoordinateSpaceName)
                .scrollClipDisabled()
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .onPreferenceChange(ToolPageMinXPreferenceKey.self) { pageOffsets in
                    guard
                        let resolvedPageID = PagedToolsRowPageSelectionResolver.selectedPageID(
                            from: pageOffsets
                        ),
                        resolvedPageID != currentPageID
                    else {
                        return
                    }

                    currentPageID = resolvedPageID
                }
                .onAppear {
                    updateRowHeight(for: proxy.size.width)
                }
                .onChange(of: proxy.size.width) { _, newWidth in
                    updateRowHeight(for: newWidth)
                }
            }
            .frame(height: rowHeight)

            if shouldShowPagination {
                pagination
            }
        }
    }

    // MARK: - Initializer

    init(
        _ tools: [ToolAvailability],
        presentation: @escaping (ToolEnum) -> EditorToolbarItemPresentation,
        action: @escaping (ToolAvailability) -> Void
    ) {
        self.toolAvailability = tools
        self.presentation = presentation
        self.action = action
    }

    // MARK: - Private Properties

    private var toolPages: [[ToolAvailability]] {
        toolAvailability.chunked(
            into: EditorToolbarLayoutResolver.itemsPerPage
        )
    }

    private var shouldShowPagination: Bool {
        toolPages.count > 1
    }

    private var pagination: some View {
        HStack(spacing: 8) {
            ForEach(Array(toolPages.indices), id: \.self) { index in
                Capsule()
                    .fill(index == currentPageID ? Theme.primary : Theme.secondary.opacity(0.4))
                    .frame(
                        width: index == currentPageID ? Layout.activeIndicatorWidth : Layout.indicatorSize,
                        height: Layout.indicatorSize
                    )
                    .animation(.snappy(duration: 0.18), value: currentPageID)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Private Methods

    private func updateRowHeight(for availableWidth: CGFloat) {
        let resolvedRowHeight = EditorToolbarLayoutResolver.resolvedMetrics(
            for: availableWidth
        ).rowHeight

        guard abs(rowHeight - resolvedRowHeight) > 0.0001 else { return }
        rowHeight = resolvedRowHeight
    }

    private func pageOffsetReader(for pageID: Int) -> some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ToolPageMinXPreferenceKey.self,
                    value: [
                        pageID: geometry.frame(in: .named(Layout.scrollCoordinateSpaceName)).minX
                    ]
                )
        }
    }

}

extension PagedToolsRow {

    fileprivate enum Layout {

        // MARK: - Public Properties

        static let defaultRowHeight: CGFloat = 104
        static let indicatorSize: CGFloat = 6
        static let activeIndicatorWidth: CGFloat = 18
        static let scrollCoordinateSpaceName = "PagedToolsRowScrollView"

    }

}

struct PagedToolsRowPageSelectionResolver {

    // MARK: - Public Methods

    static func selectedPageID(
        from pageOffsets: [Int: CGFloat]
    ) -> Int? {
        pageOffsets.min { leftPage, rightPage in
            let leftDistance = abs(leftPage.value)
            let rightDistance = abs(rightPage.value)

            guard abs(leftDistance - rightDistance) > 0.0001 else {
                return leftPage.key < rightPage.key
            }

            return leftDistance < rightDistance
        }?.key
    }

}

private struct ToolPageMinXPreferenceKey: PreferenceKey {

    static let defaultValue: [Int: CGFloat] = [:]

    static func reduce(
        value: inout [Int: CGFloat],
        nextValue: () -> [Int: CGFloat]
    ) {
        value.merge(
            nextValue(),
            uniquingKeysWith: { _, next in next }
        )
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
    PagedToolsRow(
        ToolEnum.all.map { ToolAvailability($0) }
    ) { tool in
        .init(
            title: tool.title,
            image: tool.image,
            subtitle: tool == .presets ? "Social 9:16" : nil,
            isApplied: tool == .presets
        )
    } action: { _ in
    }
}
