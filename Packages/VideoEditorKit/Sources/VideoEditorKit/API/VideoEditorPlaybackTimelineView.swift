import SwiftUI

@available(iOS 16.0, *)
@MainActor
public struct VideoEditorPlaybackTimelineView<
    PlayButton: View,
    Badge: View,
    Track: View,
    Footer: View
>: View {

    // MARK: - Body

    public var body: some View {
        VideoEditorPlaybackTimelineContainerView {
            playButton()
        } timeline: {
            VideoEditorPlaybackTimelineTrackSectionView(
                badgeHeight: badgeHeight,
                trackHeight: trackHeight
            ) { size, badgeWidth in
                badge(size, badgeWidth)
            } track: { size in
                track(size)
            }
        } footer: {
            footer()
        }
    }

    // MARK: - Private Properties

    private let badgeHeight: CGFloat
    private let trackHeight: CGFloat
    private let playButton: () -> PlayButton
    private let badge: (_ size: CGSize, _ badgeWidth: CGFloat) -> Badge
    private let track: (_ size: CGSize) -> Track
    private let footer: () -> Footer

    // MARK: - Initializer

    public init(
        badgeHeight: CGFloat = 28,
        trackHeight: CGFloat = 60,
        @ViewBuilder playButton: @escaping () -> PlayButton,
        @ViewBuilder badge: @escaping (_ size: CGSize, _ badgeWidth: CGFloat) -> Badge,
        @ViewBuilder track: @escaping (_ size: CGSize) -> Track,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.badgeHeight = badgeHeight
        self.trackHeight = trackHeight
        self.playButton = playButton
        self.badge = badge
        self.track = track
        self.footer = footer
    }

}
