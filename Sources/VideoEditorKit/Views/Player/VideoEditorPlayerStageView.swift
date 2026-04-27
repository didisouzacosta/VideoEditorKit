import SwiftUI

@available(iOS 17.0, *)
public enum VideoEditorPlayerStageState: Equatable, Sendable {

    // MARK: - Public Properties

    case unknown
    case loading
    case loaded
    case failed

}

@available(iOS 17.0, *)
@MainActor
public struct VideoEditorPlayerStageView<Content: View, Overlay: View, TrailingControls: View>: View {

    // MARK: - States

    @State private var isLoadingBorderHighlighted = false

    // MARK: - Public Properties

    public let presentationState: VideoEditorPlayerStageState
    public let canvasEditorState: VideoCanvasEditorState?
    public let source: VideoCanvasSourceDescriptor?
    public let isCanvasInteractive: Bool
    public let cornerRadius: CGFloat

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                switch presentationState {
                case .loading:
                    loadingStageView
                case .unknown:
                    statusView(VideoEditorStrings.playerUnknownState)
                case .failed:
                    statusView(VideoEditorStrings.playerFailedState)
                case .loaded:
                    loadedStageView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Private Properties

    private let layoutTaskID: String?
    private let onInteractionStarted: @MainActor () -> Void
    private let onInteractionEnded: @MainActor (VideoCanvasSnapshot) -> Void
    private let onSnapshotChange: @MainActor (VideoCanvasSnapshot) -> Void
    private let onLayoutResolved: @MainActor (VideoCanvasLayout) -> Void
    private let content: () -> Content
    private let overlayContent: (VideoCanvasLayout) -> Overlay
    private let trailingControls: () -> TrailingControls

    // MARK: - Initializer

    public init(
        _ presentationState: VideoEditorPlayerStageState,
        canvasEditorState: VideoCanvasEditorState? = nil,
        source: VideoCanvasSourceDescriptor? = nil,
        isCanvasInteractive: Bool,
        cornerRadius: CGFloat = 16,
        layoutTaskID: String? = nil,
        onInteractionStarted: @escaping @MainActor () -> Void = {},
        onInteractionEnded: @escaping @MainActor (VideoCanvasSnapshot) -> Void = { _ in },
        onSnapshotChange: @escaping @MainActor (VideoCanvasSnapshot) -> Void = { _ in },
        onLayoutResolved: @escaping @MainActor (VideoCanvasLayout) -> Void = { _ in },
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder overlay: @escaping (_ canvasLayout: VideoCanvasLayout) -> Overlay,
        @ViewBuilder trailingControls: @escaping () -> TrailingControls
    ) {
        self.presentationState = presentationState
        self.canvasEditorState = canvasEditorState
        self.source = source
        self.isCanvasInteractive = isCanvasInteractive
        self.cornerRadius = cornerRadius
        self.layoutTaskID = layoutTaskID
        self.onInteractionStarted = onInteractionStarted
        self.onInteractionEnded = onInteractionEnded
        self.onSnapshotChange = onSnapshotChange
        self.onLayoutResolved = onLayoutResolved
        self.content = content
        self.overlayContent = overlay
        self.trailingControls = trailingControls
    }

    // MARK: - Private Methods

    private var loadingStageView: some View {
        GeometryReader { proxy in
            let presentation =
                HostedVideoEditorPlayerStageCoordinator
                .loadingPlaceholderPresentation(source: source)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black.opacity(0.08))
                .overlay {
                    ProgressView()
                        .controlSize(.regular)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            .primary.opacity(isLoadingBorderHighlighted ? 0.45 : 0.16),
                            lineWidth: 2
                        )
                }
                .aspectRatio(presentation.aspectRatio, contentMode: .fit)
                .frame(maxWidth: proxy.size.width, maxHeight: proxy.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    withAnimation(
                        .easeInOut(duration: 0.9)
                            .repeatForever(autoreverses: true)
                    ) {
                        isLoadingBorderHighlighted = true
                    }
                }
        }
    }

    @ViewBuilder
    private var loadedStageView: some View {
        if let canvasEditorState, let source {
            GeometryReader { proxy in
                let canvasLayout = canvasEditorState.previewLayout(
                    source: source,
                    availableSize: proxy.size
                )

                VideoCanvasPreviewView(
                    canvasEditorState,
                    source: source,
                    isInteractive: isCanvasInteractive,
                    cornerRadius: cornerRadius,
                    onInteractionStarted: onInteractionStarted,
                    onInteractionEnded: onInteractionEnded,
                    onSnapshotChange: onSnapshotChange
                ) {
                    content()
                } overlay: {
                    ZStack(alignment: .bottomTrailing) {
                        overlayContent(canvasLayout)
                            .allowsHitTesting(false)

                        trailingControls()
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .task(id: resolvedLayoutTaskID(for: proxy.size, canvasLayout: canvasLayout)) {
                    onLayoutResolved(canvasLayout)
                }
            }
        } else {
            statusView(VideoEditorStrings.playerFailedState)
        }
    }

    private func statusView(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    private func resolvedLayoutTaskID(
        for availableSize: CGSize,
        canvasLayout: VideoCanvasLayout
    ) -> String {
        let baseComponents = [
            String(Int(availableSize.width.rounded())),
            String(Int(availableSize.height.rounded())),
            String(Int(canvasLayout.previewCanvasSize.width.rounded())),
            String(Int(canvasLayout.previewCanvasSize.height.rounded())),
            String(Int(canvasLayout.exportCanvasSize.width.rounded())),
            String(Int(canvasLayout.exportCanvasSize.height.rounded())),
            String(Int(source?.naturalSize.width.rounded() ?? 0)),
            String(Int(source?.naturalSize.height.rounded() ?? 0)),
            String(Int(source?.userRotationDegrees.rounded() ?? 0)),
            String(source?.isMirrored == true),
        ]
        let baseIdentifier = baseComponents.joined(separator: "-")

        guard let layoutTaskID else { return baseIdentifier }
        return "\(layoutTaskID)-\(baseIdentifier)"
    }

}

#Preview("Unknown") {
    VideoEditorPlayerStageView(
        .unknown,
        isCanvasInteractive: false
    ) {
        EmptyView()
    } overlay: { _ in
        EmptyView()
    } trailingControls: {
        EmptyView()
    }
}

#Preview("Loading") {
    VideoEditorPlayerStageView(
        .loading,
        isCanvasInteractive: false
    ) {
        EmptyView()
    } overlay: { _ in
        EmptyView()
    } trailingControls: {
        EmptyView()
    }
}
