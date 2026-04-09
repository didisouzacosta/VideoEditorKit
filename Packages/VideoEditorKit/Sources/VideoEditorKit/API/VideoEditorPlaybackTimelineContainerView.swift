import SwiftUI

@available(iOS 16.0, *)
@MainActor
public struct VideoEditorPlaybackTimelineContainerView<PlayButton: View, Timeline: View, Footer: View>: View {

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 32) {
            playButton()
                .padding(.top, 8)

            VStack(spacing: 8) {
                timeline()
                footer()
            }
            .padding(.trailing, 8)
        }
    }

    // MARK: - Private Properties

    private let playButton: () -> PlayButton
    private let timeline: () -> Timeline
    private let footer: () -> Footer

    // MARK: - Initializer

    public init(
        @ViewBuilder playButton: @escaping () -> PlayButton,
        @ViewBuilder timeline: @escaping () -> Timeline,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.playButton = playButton
        self.timeline = timeline
        self.footer = footer
    }

}
