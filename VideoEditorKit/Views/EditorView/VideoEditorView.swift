//
//  VideoEditorView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import PhotosUI
import SwiftUI

@MainActor
struct VideoEditorView: View {

    struct SaveState: Equatable, Sendable {

        // MARK: - Public Properties

        let editingConfiguration: VideoEditingConfiguration
        let thumbnailData: Data?

        var continuousSaveFingerprint: VideoEditingConfiguration {
            editingConfiguration.continuousSaveFingerprint
        }

        // MARK: - Initializer

        init(
            editingConfiguration: VideoEditingConfiguration,
            thumbnailData: Data? = nil
        ) {
            self.editingConfiguration = editingConfiguration
            self.thumbnailData = thumbnailData
        }

    }

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - States

    @State private var editorViewModel = EditorViewModel()
    @State private var audioRecorder = AudioRecorderManager()
    @State private var bootstrapAttempt = 0
    @State private var bootstrapState = VideoEditorSessionBootstrapCoordinator.BootstrapState.idle
    @State private var saveEmissionCoordinator = VideoEditorSaveEmissionCoordinator()
    @State private var videoPlayer = VideoPlayerManager()

    // MARK: - Private Properties

    private let title: String?
    private let callbacks: Callbacks
    private let configuration: Configuration
    private let session: Session

    // MARK: - Body

    var body: some View {
        @Bindable var bindablePresentationState = editorViewModel.presentationState

        NavigationStack {
            GeometryReader { proxy in
                content(for: proxy.size)
                    .navigationTitle(title ?? "")
                    .navigationBarTitleDisplayMode(.inline)
                    .animation(.default, value: videoPlayer.isPlaybackFocusActive)
                    .safeAreaPadding()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .cancel) {
                                dismissEditor()
                            }
                        }

                        ToolbarItem(placement: .primaryAction) {
                            if editorViewModel.currentVideo != nil {
                                Button(role: .confirm) {
                                    editorViewModel.presentExporter()
                                } label: {
                                    Text("Export")
                                }
                                .disabled(isEditingLocked)
                            }
                        }
                    }
            }
        }
        .task(id: bootstrapTaskID) {
            await resolveSessionSource()
        }
        .onDisappear(perform: handleDisappear)
        .dynamicHeightSheet(
            isPresented: $bindablePresentationState.showVideoQualitySheet,
            initialHeight: 420
        ) {
            if let video = editorViewModel.currentVideo {
                let editingConfiguration =
                    editorViewModel.currentEditingConfiguration(
                        currentTimelineTime: videoPlayer.currentTime
                    ) ?? .initial

                VideoExporterView(
                    video: video,
                    editingConfiguration: editingConfiguration
                ) { exportedVideo in
                    videoPlayer.pause()
                    callbacks.onExportedVideoURL(exportedVideo.url)
                }
            }
        }
        .fullScreenCover(isPresented: $bindablePresentationState.showRecordView) {
            RecordVideoView { url in
                editorViewModel.handleRecordedVideo(url, videoPlayer: videoPlayer)
            }
        }
        .onChange(of: videoPlayer.isPlaybackFocusActive) { _, isPlaybackFocusActive in
            handlePlaybackLockChange(isPlaybackFocusActive)
        }
        .onChange(of: editorViewModel.presentationState.editingConfigurationRevision) { _, _ in
            publishEditingConfigurationIfNeeded()
        }
        .onChange(of: configuration.tools) { _, newValue in
            editorViewModel.setToolAvailability(newValue)
        }
    }

    // MARK: - Private Properties

    private var isEditingLocked: Bool {
        videoPlayer.isPlaybackFocusActive
    }

    private var bootstrapTaskID: String {
        "\(session.bootstrapTaskIdentifier)-\(bootstrapAttempt)"
    }

    private var resolvedSourceVideoURL: URL? {
        guard case .loaded(let url) = bootstrapState else { return nil }
        return url
    }

    // MARK: - Initializer

    init(
        _ title: String? = nil,
        session: Session,
        configuration: Configuration = .init(),
        callbacks: Callbacks = .init()
    ) {
        self.title = title
        self.callbacks = callbacks
        self.configuration = configuration
        self.session = session
    }

    init(
        _ title: String? = nil,
        source: Session.Source? = nil,
        editingConfiguration: VideoEditingConfiguration? = nil,
        configuration: Configuration = .init(),
        onSaveStateChanged: @escaping (SaveState) -> Void = { _ in },
        onSourceVideoResolved: @escaping (URL) -> Void = { _ in },
        onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
        onExportedVideoURL: @escaping (URL) -> Void = { _ in }
    ) {
        self.init(
            title,
            session: .init(
                source: source,
                editingConfiguration: editingConfiguration
            ),
            configuration: configuration,
            callbacks: .init(
                onSaveStateChanged: onSaveStateChanged,
                onSourceVideoResolved: onSourceVideoResolved,
                onDismissed: onDismissed,
                onExportedVideoURL: onExportedVideoURL
            )
        )
    }

    init(
        _ title: String? = nil,
        sourceVideoURL: URL?,
        editingConfiguration: VideoEditingConfiguration? = nil,
        configuration: Configuration = .init(),
        onSaveStateChanged: @escaping (SaveState) -> Void = { _ in },
        onSourceVideoResolved: @escaping (URL) -> Void = { _ in },
        onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
        onExportedVideoURL: @escaping (URL) -> Void = { _ in }
    ) {
        self.init(
            title,
            source: sourceVideoURL.map { .fileURL($0) },
            editingConfiguration: editingConfiguration,
            configuration: configuration,
            onSaveStateChanged: onSaveStateChanged,
            onSourceVideoResolved: onSourceVideoResolved,
            onDismissed: onDismissed,
            onExportedVideoURL: onExportedVideoURL
        )
    }

    // MARK: - Private Methods

    private func handlePlaybackLockChange(_ isPlaybackFocusActive: Bool) {
        guard isPlaybackFocusActive else { return }
        editorViewModel.closeSelectedTool()
    }

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
        case .loaded:
            editorContent(for: availableSize)
        case .failed(let message):
            bootstrapFailureView(message: message)
        }
    }

    private func editorContent(for availableSize: CGSize) -> some View {
        VStack(spacing: 32) {
            PlayerHolderView(
                editorViewModel,
                videoPlayer: videoPlayer
            )
            .layoutPriority(1)

            PlayerControl(
                editorViewModel,
                videoPlayer: videoPlayer,
                recorderManager: audioRecorder
            )

            if !videoPlayer.isPlaybackFocusActive {
                ToolsSectionView(
                    videoPlayer,
                    editorVM: editorViewModel,
                    configuration: configuration
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(
            id: editorContentTaskID(for: availableSize)
        ) {
            bootstrapEditorContent(for: availableSize)
        }
    }

    private var bootstrapLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()

            Text("Importing video...")
                .font(.headline)

            Text("The editor will open as soon as the selected clip is ready.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bootstrapFailureView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.secondary)

            Text("Unable to open the selected video")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Close", role: .cancel) {
                    dismissEditor()
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
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func editorContentTaskID(for availableSize: CGSize) -> String {
        let width = Int(availableSize.width.rounded())
        let height = Int(availableSize.height.rounded())
        let resolvedURL = resolvedSourceVideoURL?.absoluteString ?? "unresolved"

        return "\(resolvedURL)-\(width)x\(height)"
    }

    private func bootstrapEditorContent(for availableSize: CGSize) {
        guard let resolvedSourceVideoURL else { return }

        editorViewModel.setToolAvailability(configuration.tools)
        editorViewModel.setSourceVideoIfNeeded(
            resolvedSourceVideoURL,
            editingConfiguration: session.editingConfiguration,
            availableSize: availableSize,
            videoPlayer: videoPlayer
        )
    }

    private func resolveSessionSource() async {
        let initialState = VideoEditorSessionBootstrapCoordinator.initialState(
            for: session.source
        )
        bootstrapState = initialState
        syncPlayerLoadState(for: initialState)

        guard case .loading = initialState else {
            if case .loaded(let resolvedSourceVideoURL) = initialState {
                callbacks.onSourceVideoResolved(resolvedSourceVideoURL)
            }
            return
        }

        let resolvedState = await VideoEditorSessionBootstrapCoordinator.resolveState(
            for: session.source,
            using: .init()
        )

        guard !Task.isCancelled else { return }

        bootstrapState = resolvedState
        syncPlayerLoadState(for: resolvedState)

        if case .loaded(let resolvedSourceVideoURL) = resolvedState {
            callbacks.onSourceVideoResolved(resolvedSourceVideoURL)
        }
    }

    private func syncPlayerLoadState(
        for bootstrapState: VideoEditorSessionBootstrapCoordinator.BootstrapState
    ) {
        switch bootstrapState {
        case .idle:
            videoPlayer.loadState = .unknown
        case .loading:
            videoPlayer.loadState = .loading
        case .loaded(let resolvedSourceVideoURL):
            if editorViewModel.currentVideo?.url == resolvedSourceVideoURL {
                videoPlayer.loadState = .loaded(resolvedSourceVideoURL)
            } else {
                videoPlayer.loadState = .loading
            }
        case .failed:
            videoPlayer.loadState = .failed
        }
    }

    private func dismissEditor() {
        let currentEditingConfiguration =
            editorViewModel.currentEditingConfiguration(
                currentTimelineTime: videoPlayer.currentTime
            ) ?? session.editingConfiguration

        callbacks.onDismissed(currentEditingConfiguration)
        dismiss()
    }

    private func publishEditingConfigurationIfNeeded() {
        guard
            let currentEditingConfiguration = editorViewModel.currentEditingConfiguration(
                currentTimelineTime: videoPlayer.currentTime
            )
        else {
            return
        }

        let sourceVideoURL = editorViewModel.currentVideo?.url ?? resolvedSourceVideoURL

        saveEmissionCoordinator.scheduleSave(
            editingConfiguration: currentEditingConfiguration,
            sourceVideoURL: sourceVideoURL
        ) { publishedSave in
            callbacks.onSaveStateChanged(
                .init(
                    editingConfiguration: publishedSave.editingConfiguration,
                    thumbnailData: publishedSave.thumbnailData
                )
            )
        }
    }

    private func handleDisappear() {
        saveEmissionCoordinator.reset()
        editorViewModel.cancelDeferredTasks()
    }

}

extension VideoEditorView {

    struct Session: Equatable {

        enum Source {
            case fileURL(URL)
            case photosPickerItem(PhotosPickerItem)
        }

        // MARK: - Public Properties

        let source: Source?
        let editingConfiguration: VideoEditingConfiguration?

        var sourceVideoURL: URL? {
            source?.fileURL
        }

        var bootstrapTaskIdentifier: String {
            source?.taskIdentifier ?? "none"
        }

        // MARK: - Initializer

        init(
            source: Source? = nil,
            editingConfiguration: VideoEditingConfiguration? = nil
        ) {
            self.source = source
            self.editingConfiguration = editingConfiguration
        }

        init(
            sourceVideoURL: URL? = nil,
            editingConfiguration: VideoEditingConfiguration? = nil
        ) {
            self.init(
                source: sourceVideoURL.map { .fileURL($0) },
                editingConfiguration: editingConfiguration
            )
        }

        // MARK: - Public Methods

        static func == (lhs: Session, rhs: Session) -> Bool {
            lhs.source == rhs.source
                && lhs.editingConfiguration == rhs.editingConfiguration
        }

    }

}

extension VideoEditorView.Session.Source: Equatable {

    // MARK: - Public Methods

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.fileURL(let lhsURL), .fileURL(let rhsURL)):
            return lhsURL == rhsURL
        case (.photosPickerItem(let lhsItem), .photosPickerItem(let rhsItem)):
            return lhsItem.itemIdentifier == rhsItem.itemIdentifier
                && lhsItem.supportedContentTypes == rhsItem.supportedContentTypes
        default:
            return false
        }

    }

}

extension VideoEditorView.Session.Source {

    // MARK: - Public Properties

    var fileURL: URL? {
        switch self {
        case .fileURL(let url):
            return url
        case .photosPickerItem:
            return nil
        }
    }

    // MARK: - Private Properties

    fileprivate var taskIdentifier: String {
        switch self {
        case .fileURL(let url):
            return "file:\(url.absoluteString)"
        case .photosPickerItem(let item):
            let itemIdentifier = item.itemIdentifier ?? "unknown"
            let supportedContentTypes = String(describing: item.supportedContentTypes)

            return "picker:\(itemIdentifier)-\(supportedContentTypes)"
        }
    }

}

extension VideoEditorView {

    struct Callbacks {

        // MARK: - Public Properties

        let onSaveStateChanged: (SaveState) -> Void
        let onSourceVideoResolved: (URL) -> Void
        let onDismissed: (VideoEditingConfiguration?) -> Void
        let onExportedVideoURL: (URL) -> Void

        // MARK: - Initializer

        init(
            onSaveStateChanged: @escaping (SaveState) -> Void = { _ in },
            onSourceVideoResolved: @escaping (URL) -> Void = { _ in },
            onDismissed: @escaping (VideoEditingConfiguration?) -> Void = { _ in },
            onExportedVideoURL: @escaping (URL) -> Void = { _ in }
        ) {
            self.onSaveStateChanged = onSaveStateChanged
            self.onSourceVideoResolved = onSourceVideoResolved
            self.onDismissed = onDismissed
            self.onExportedVideoURL = onExportedVideoURL
        }

    }

    struct Configuration {

        // MARK: - Public Properties

        static var allToolsEnabled: Self {
            Self()
        }

        let tools: [ToolAvailability]

        // MARK: - Private Properties

        private let onBlockedToolTap: ((ToolEnum) -> Void)?

        var visibleTools: [ToolEnum] {
            tools.map(\.tool)
        }

        // MARK: - Initializer

        init(
            tools: [ToolAvailability] = ToolAvailability.enabled(ToolEnum.all),
            onBlockedToolTap: ((ToolEnum) -> Void)? = nil
        ) {
            self.tools = tools.sorted {
                if $0.order == $1.order {
                    return $0.tool.rawValue < $1.tool.rawValue
                }

                return $0.order < $1.order
            }
            self.onBlockedToolTap = onBlockedToolTap
        }

        // MARK: - Public Methods

        func availability(for tool: ToolEnum) -> ToolAvailability? {
            tools.first(where: { $0.tool == tool })
        }

        func isVisible(_ tool: ToolEnum) -> Bool {
            availability(for: tool) != nil
        }

        func isBlocked(_ tool: ToolEnum) -> Bool {
            availability(for: tool)?.isBlocked == true
        }

        func isEnabled(_ tool: ToolEnum) -> Bool {
            availability(for: tool)?.isEnabled == true
        }

        func notifyBlockedToolTap(for tool: ToolEnum) {
            onBlockedToolTap?(tool)
        }

    }

}
