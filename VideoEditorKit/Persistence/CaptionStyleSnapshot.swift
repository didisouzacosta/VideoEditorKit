import Foundation

struct CaptionStyleSnapshot: Codable, Equatable {
    var fontName: String
    var fontSize: Double
    var textColorHex: String
    var backgroundColorHex: String?
    var padding: Double
    var cornerRadius: Double
}
