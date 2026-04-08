//
//  PagedToolsRow.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 27.03.2026.
//

import SwiftUI
import VideoEditorKit

struct PagedToolsRow: View {

    // MARK: - States

    @State private var currentPageID: Int?
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
                                            minWidth: metrics.minimumItemWidth,
                                            minHeight: metrics.itemHeight,
                                            maxHeight: metrics.itemHeight
                                        )
                                    }
                                }
                                .frame(
                                    minWidth: metrics.pageContentWidth(for: page.count),
                                    alignment: .leading
                                )
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
                .scrollClipDisabled()
                .scrollIndicators(.hidden)
                .scrollPosition(id: $currentPageID)
                .scrollTargetBehavior(.viewAligned)
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

    // MARK: - Private Methods

    private func updateRowHeight(for availableWidth: CGFloat) {
        let resolvedRowHeight = EditorToolbarLayoutResolver.resolvedMetrics(
            for: availableWidth
        ).rowHeight

        guard abs(rowHeight - resolvedRowHeight) > 0.0001 else { return }
        rowHeight = resolvedRowHeight
    }

}

extension PagedToolsRow {

    fileprivate enum Layout {

        // MARK: - Public Properties

        static let defaultRowHeight: CGFloat = 104
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
