import CoreGraphics
import UIKit

struct CaptionStyle: Equatable {
    var fontName: String
    var fontSize: CGFloat
    var textColor: UIColor
    var backgroundColor: UIColor?
    var padding: CGFloat
    var cornerRadius: CGFloat
}

extension CaptionStyle {
    func resolvedFont() -> UIFont {
        UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
    }
}
