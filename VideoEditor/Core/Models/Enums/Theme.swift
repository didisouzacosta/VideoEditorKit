import SwiftUI

enum Theme {

    // MARK: - Public Properties

    static let accent = Color.accentColor
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let outline = Color(uiColor: .separator).opacity(0.35)
    static let rootBackground = LinearGradient(
        colors: [
            Color(uiColor: .systemBackground),
            Color(uiColor: .secondarySystemBackground),
            Color(uiColor: .tertiarySystemBackground),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

}
