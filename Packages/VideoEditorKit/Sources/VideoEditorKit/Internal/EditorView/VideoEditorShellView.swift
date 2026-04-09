import SwiftUI

@MainActor
struct VideoEditorShellView: View {

    // MARK: - States

    @State private var bootstrapAttempt = 0
    @State private var bootstrapState = VideoEditorSessionBootstrapCoordinator.BootstrapState.idle

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                content(for: proxy.size)
                    .navigationTitle(title ?? "")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel", action: onCancel)
                        }

                        ToolbarItem(placement: .primaryAction) {
                            primaryAction()
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task(id: bootstrapTaskID) {
            await resolveSessionSource()
        }
    }

    // MARK: - Private Properties

    private let title: String?
    private let session: VideoEditorSession
    private let callbacks: VideoEditorCallbacks
    private let onCancel: () -> Void
    private let onBootstrapStateChanged: (VideoEditorSessionBootstrapCoordinator.BootstrapState) -> Void
    private let primaryAction: () -> AnyView
    private let loadedContent: (CGSize, URL) -> AnyView

    private var bootstrapTaskID: String {
        "\(session.bootstrapTaskIdentifier)-\(bootstrapAttempt)"
    }

    // MARK: - Initializer

    init<PrimaryAction: View, LoadedContent: View>(
        _ title: String? = nil,
        session: VideoEditorSession,
        callbacks: VideoEditorCallbacks = .init(),
        onCancel: @escaping () -> Void,
        onBootstrapStateChanged: @escaping (VideoEditorSessionBootstrapCoordinator.BootstrapState) -> Void = { _ in },
        @ViewBuilder primaryAction: @escaping () -> PrimaryAction = { EmptyView() },
        @ViewBuilder loadedContent: @escaping (_ availableSize: CGSize, _ resolvedSourceVideoURL: URL) -> LoadedContent
    ) {
        self.title = title
        self.session = session
        self.callbacks = callbacks
        self.onCancel = onCancel
        self.onBootstrapStateChanged = onBootstrapStateChanged
        self.primaryAction = {
            AnyView(primaryAction())
        }
        self.loadedContent = { availableSize, resolvedSourceVideoURL in
            AnyView(
                loadedContent(
                    availableSize,
                    resolvedSourceVideoURL
                )
            )
        }
    }

    // MARK: - Private Methods

    @ViewBuilder
    private func content(for availableSize: CGSize) -> some View {
        switch bootstrapState {
        case .idle:
            bootstrapStatusView(
                title: "Add a video to start editing",
                message: "Choose a clip to begin a new editing session."
            )
        case .loading:
            bootstrapLoadingView
        case .loaded(let resolvedSourceVideoURL):
            loadedContent(
                availableSize,
                resolvedSourceVideoURL
            )
        case .failed(let message):
            bootstrapFailureView(message: message)
        }
    }

    private var bootstrapLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()

            Text("Importing video...")
                .font(.headline)

            Text("The editor will open as soon as the selected clip is ready.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bootstrapFailureView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.secondary)

            Text("Unable to open the selected video")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Close") {
                    onCancel()
                }

                Button("Retry") {
                    bootstrapAttempt += 1
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bootstrapStatusView(
        title: String,
        message: String
    ) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func resolveSessionSource() async {
        let initialState = VideoEditorSessionBootstrapCoordinator.initialState(
            for: session.source
        )
        publishBootstrapState(initialState)

        guard case .loading = initialState else { return }

        let resolvedState = await VideoEditorSessionBootstrapCoordinator.resolveState(
            for: session.source
        )

        guard !Task.isCancelled else { return }
        publishBootstrapState(resolvedState)
    }

    private func publishBootstrapState(
        _ state: VideoEditorSessionBootstrapCoordinator.BootstrapState
    ) {
        bootstrapState = state
        onBootstrapStateChanged(state)

        if case .loaded(let resolvedSourceVideoURL) = state {
            callbacks.onSourceVideoResolved(resolvedSourceVideoURL)
        }
    }

}
