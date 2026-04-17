import SwiftUI

private enum AdaptativeGlassShape {

    // MARK: - Public Properties

    case roundedRectangle(cornerRadius: CGFloat)
    case circle
    case capsule

}

extension View {

    // MARK: - Public Methods

    nonisolated func adaptativeGlass(
        _ shape: AdaptativeGlassShape,
        prominent: Bool = false,
        tint: Color? = nil,
        isInteractive: Bool = false
    ) -> some View {
        modifier(
            AdaptativeGlassModifier(
                shape: shape,
                prominent: prominent,
                tint: tint,
                isInteractive: isInteractive
            )
        )
    }

}

private struct AdaptativeGlassModifier: ViewModifier {

    // MARK: - Private Properties

    private let shape: AdaptativeGlassShape
    private let prominent: Bool
    private let tint: Color?
    private let isInteractive: Bool

    // MARK: - Initializer

    init(
        shape: AdaptativeGlassShape,
        prominent: Bool,
        tint: Color?,
        isInteractive: Bool
    ) {
        self.shape = shape
        self.prominent = prominent
        self.tint = tint
        self.isInteractive = isInteractive
    }

    // MARK: - Public Methods

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            glassContent(content)
        } else {
            fallbackContent(content)
        }
    }

    // MARK: - Private Methods

    @ViewBuilder
    private func glassContent(_ content: Content) -> some View {
        switch shape {
        case .roundedRectangle(let cornerRadius):
            if let tint {
                content.glassEffect(
                    resolvedGlassEffect(tint: tint),
                    in: .rect(cornerRadius: cornerRadius)
                )
            } else {
                content.glassEffect(
                    resolvedGlassEffect(),
                    in: .rect(cornerRadius: cornerRadius)
                )
            }
        case .circle:
            if let tint {
                content.glassEffect(
                    resolvedGlassEffect(tint: tint),
                    in: .circle
                )
            } else {
                content.glassEffect(
                    resolvedGlassEffect(),
                    in: .circle
                )
            }
        case .capsule:
            if let tint {
                content.glassEffect(
                    resolvedGlassEffect(tint: tint),
                    in: .capsule
                )
            } else {
                content.glassEffect(
                    resolvedGlassEffect(),
                    in: .capsule
                )
            }
        }
    }

    @ViewBuilder
    private func fallbackContent(_ content: Content) -> some View {
        switch shape {
        case .roundedRectangle(let cornerRadius):
            content.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        case .circle:
            content.background(.ultraThinMaterial, in: Circle())
        case .capsule:
            content.background(.ultraThinMaterial, in: Capsule(style: .continuous))
        }
    }

    @available(iOS 26, *)
    private func resolvedGlassEffect(tint: Color? = nil) -> Glass {
        let tintOpacity = prominent ? 0.30 : 0.18

        if let tint {
            let glass = Glass.regular.tint(tint.opacity(tintOpacity))
            return isInteractive ? glass.interactive() : glass
        }

        return isInteractive ? .regular.interactive() : .regular
    }

}
