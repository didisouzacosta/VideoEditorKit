import SwiftUI

enum VideoEditorPlaybackFocusTransitionPolicy {

    // MARK: - Public Properties

    static let animationDuration = 0.24

    static var animation: Animation {
        .easeInOut(duration: animationDuration)
    }

    static var toolsTransition: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

}
