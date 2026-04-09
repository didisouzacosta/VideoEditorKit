import SwiftUI

extension View {

    // MARK: - Public Methods

    @ViewBuilder
    nonisolated func card(
        cornerRadius: CGFloat = 28,
        prominent: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                self.glassEffect(
                    .regular.tint(tint.opacity(prominent ? 0.30 : 0.18)),
                    in: .rect(cornerRadius: cornerRadius)
                )
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }

    @ViewBuilder
    nonisolated func circleControl(
        prominent: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                self.glassEffect(
                    .regular.tint(tint.opacity(prominent ? 0.30 : 0.18)).interactive(),
                    in: .circle
                )
            } else {
                self.glassEffect(.regular.interactive(), in: .circle)
            }
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }

}
