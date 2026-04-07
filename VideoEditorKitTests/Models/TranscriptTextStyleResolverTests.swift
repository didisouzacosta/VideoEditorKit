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
                fontWeight: .heavy,
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

        #expect(attributes[.strokeWidth] as? CGFloat == -4)
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
                fontWeight: .semibold
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

    @Test
    func attributedStringCanRenderFillOnlyTextWithAColorOverride() {
        let attributedString = TranscriptTextStyleResolver.attributedString(
            text: "Caption",
            style: .init(
                id: UUID(),
                name: "Outlined",
                fontWeight: .heavy,
                hasStroke: true,
                textAlignment: .center,
                textColor: .white,
                strokeColor: .black
            ),
            fontSize: 32,
            textColorOverride: .black,
            includesStroke: false
        )

        let attributes = attributedString.attributes(
            at: 0,
            effectiveRange: nil
        )
        let foregroundColorComponents = (attributes[.foregroundColor] as? UIColor)?.rgbaComponents

        #expect(attributes[.strokeWidth] == nil)
        #expect(attributes[.strokeColor] == nil)
        #expect(foregroundColorComponents?.red == 0)
        #expect(foregroundColorComponents?.green == 0)
        #expect(foregroundColorComponents?.blue == 0)
        #expect(foregroundColorComponents?.alpha == 1)
    }

    @Test
    func transcriptStyleDecodesLegacyFontFieldsIntoAStableFontWeight() throws {
        let data = try #require(
            """
            {
              "id": "11111111-2222-3333-4444-555555555555",
              "name": "Legacy",
              "fontFamily": "Avenir Next",
              "isItalic": true,
              "hasStroke": false,
              "textAlignment": "center",
              "textColor": {
                "red": 1,
                "green": 1,
                "blue": 1,
                "alpha": 1
              }
            }
            """.data(using: .utf8)
        )

        let style = try JSONDecoder().decode(TranscriptStyle.self, from: data)

        #expect(style.fontWeight == .heavy)
    }

    @Test
    func resolvedStrokeOffsetsUseAnEightPointOutlineAtFourPixels() {
        let offsets = TranscriptTextStyleResolver.resolvedStrokeOffsets()

        #expect(TranscriptTextStyleResolver.strokeWidth == 4)
        #expect(TranscriptTextStyleResolver.strokeOffset == 2)
        #expect(offsets.count == 8)
        #expect(offsets.contains(CGSize(width: -2, height: 0)))
        #expect(offsets.contains(CGSize(width: 2, height: 2)))
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
