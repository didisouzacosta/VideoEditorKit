import SwiftUI
import Testing

@testable import VideoEditorKit

@Suite("TranscriptTextStyleResolverTests")
struct TranscriptTextStyleResolverTests {

    // MARK: - Public Methods

    @Test
    func attributedStringIncludesStrokeAttributesWhenStyleRequestsStroke() throws {
        let attributedString = TranscriptTextStyleResolver.attributedString(
            text: "Caption",
            style: .init(
                id: UUID(),
                name: "Outlined",
                fontFamily: "SF Pro Rounded",
                hasStroke: true,
                textAlignment: .trailing,
                textColor: .white,
                strokeColor: .black
            ),
            fontSize: 32
        )

        let attributes = attributedString.attributes(
            at: 0,
            effectiveRange: nil
        )

        #expect(attributes[.strokeWidth] as? CGFloat == -3)
        let strokeColorComponents = (attributes[.strokeColor] as? UIColor)?.rgbaComponents

        #expect(strokeColorComponents?.red == 0)
        #expect(strokeColorComponents?.green == 0)
        #expect(strokeColorComponents?.blue == 0)
        #expect(strokeColorComponents?.alpha == 1)
        #expect(
            (attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment == .right
        )
    }

    @Test
    func attributedStringOmitsStrokeAttributesWhenStyleDoesNotUseStroke() {
        let attributedString = TranscriptTextStyleResolver.attributedString(
            text: "Caption",
            style: .init(
                id: UUID(),
                name: "Plain",
                fontFamily: "SF Pro Rounded"
            ),
            fontSize: 32
        )

        let attributes = attributedString.attributes(
            at: 0,
            effectiveRange: nil
        )

        #expect(attributes[.strokeWidth] == nil)
        #expect(attributes[.strokeColor] == nil)
    }

}

extension UIColor {

    fileprivate var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }

        return (red, green, blue, alpha)
    }

}
