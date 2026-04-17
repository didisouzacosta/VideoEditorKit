import SwiftUI

extension View {

    // MARK: - Public Methods

    @ViewBuilder
    nonisolated func card(
        cornerRadius: CGFloat = 28,
        prominent: Bool = false,
        tint: Color? = nil
    ) -> some View {
        adaptativeGlass(
            .roundedRectangle(cornerRadius: cornerRadius),
            prominent: prominent,
            tint: tint
        )
    }

    @ViewBuilder
    nonisolated func circleControl(
        prominent: Bool = false,
        tint: Color? = nil
    ) -> some View {
        adaptativeGlass(
            .circle,
            prominent: prominent,
            tint: tint,
            isInteractive: true
        )
    }

}
