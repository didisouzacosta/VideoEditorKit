import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("EditorToolbarLayoutResolverTests")
struct EditorToolbarLayoutResolverTests {

    // MARK: - Public Methods

    @Test
    func resolvedMetricsKeepFourSquareItemsAcrossCommonViewportWidths() {
        let viewportWidths: [CGFloat] = [320, 375, 393, 430, 768, 1024]

        for viewportWidth in viewportWidths {
            let metrics = EditorToolbarLayoutResolver.resolvedMetrics(
                for: viewportWidth
            )
            let occupiedPageWidth =
                (metrics.itemSize * CGFloat(metrics.itemsPerPage))
                + (metrics.itemSpacing
                    * CGFloat(metrics.itemsPerPage - 1))

            #expect(metrics.itemsPerPage == 4)
            #expect(metrics.itemSize > 0)
            #expect(abs(metrics.rowHeight - metrics.itemSize) < 0.0001)
            #expect(abs(occupiedPageWidth - metrics.pageWidth) < 0.0001)
        }
    }

    @Test
    func resolvedMetricsClampToZeroForCollapsedWidths() {
        let metrics = EditorToolbarLayoutResolver.resolvedMetrics(for: 0)

        #expect(metrics.itemsPerPage == 4)
        #expect(metrics.pageWidth == 0)
        #expect(metrics.itemSize == 0)
        #expect(metrics.rowHeight == 0)
    }

    @Test
    func metricsCenterRowsThatFitTheVisibleWidth() {
        let metrics = EditorToolbarLayoutResolver.resolvedMetrics(for: 393)

        #expect(
            metrics.shouldCenterRowContent(
                for: 1,
                availableWidth: 393
            )
        )
        #expect(
            metrics.shouldCenterRowContent(
                for: 2,
                availableWidth: 393
            )
        )
        #expect(
            metrics.shouldCenterRowContent(
                for: 3,
                availableWidth: 393
            )
        )
        #expect(
            metrics.shouldCenterRowContent(
                for: 4,
                availableWidth: 393
            )
        )
        #expect(
            metrics.shouldCenterRowContent(
                for: 5,
                availableWidth: 393
            ) == false
        )
    }

    @Test
    func pageContentWidthMatchesTheVisibleItemsOnThePage() {
        let metrics = EditorToolbarLayoutResolver.resolvedMetrics(for: 393)
        let threeItemsWidth = metrics.pageContentWidth(for: 3)
        let fourItemsWidth = metrics.pageContentWidth(for: 4)

        #expect(threeItemsWidth > 0)
        #expect(fourItemsWidth > threeItemsWidth)
        #expect(abs(fourItemsWidth - metrics.pageWidth) < 0.0001)
    }

}
