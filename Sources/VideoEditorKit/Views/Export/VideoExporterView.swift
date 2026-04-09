#if os(iOS)
    import SwiftUI

    public struct VideoExportPresentationState: Equatable, Sendable {

        // MARK: - Public Properties

        public let selectedQuality: VideoQuality
        public let exportProgress: Double
        public let progressText: String
        public let errorMessage: String
        public let actionTitle: String
        public let isInteractionDisabled: Bool
        public let canExportVideo: Bool
        public let canCancelExport: Bool
        public let shouldShowLoadingView: Bool
        public let shouldShowFailureMessage: Bool

        // MARK: - Initializer

        public init(
            selectedQuality: VideoQuality,
            exportProgress: Double,
            progressText: String,
            errorMessage: String,
            actionTitle: String,
            isInteractionDisabled: Bool,
            canExportVideo: Bool,
            canCancelExport: Bool,
            shouldShowLoadingView: Bool,
            shouldShowFailureMessage: Bool
        ) {
            self.selectedQuality = selectedQuality
            self.exportProgress = exportProgress
            self.progressText = progressText
            self.errorMessage = errorMessage
            self.actionTitle = actionTitle
            self.isInteractionDisabled = isInteractionDisabled
            self.canExportVideo = canExportVideo
            self.canCancelExport = canCancelExport
            self.shouldShowLoadingView = shouldShowLoadingView
            self.shouldShowFailureMessage = shouldShowFailureMessage
        }

    }

    public struct VideoExporterView: View {

        // MARK: - Bindings

        @Binding private var isAlertPresented: Bool

        // MARK: - Private Properties

        private let state: VideoExportPresentationState
        private let qualities: [ExportQualityAvailability]
        private let estimatedVideoSizeText: (VideoQuality) -> String?
        private let onSelectQuality: (VideoQuality) -> Void
        private let onBlockedQualityTap: (VideoQuality) -> Void
        private let onExport: () -> Void
        private let onRetry: () -> Void
        private let onCancelExport: () -> Void
        private let onClose: () -> Void

        // MARK: - Body

        public var body: some View {
            navigationContent
                .interactiveDismissDisabled(state.isInteractionDisabled)
                .alert(
                    "Unable to export video",
                    isPresented: $isAlertPresented
                ) {
                    Button("Try Again", action: onRetry)
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(state.errorMessage)
                }
        }

        // MARK: - Private Properties

        private var navigationContent: some View {
            content
                .navigationTitle("Export Video")
                .navigationBarTitleDisplayMode(.inline)
                .animation(.easeInOut, value: state)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel, action: onClose)
                            .disabled(state.isInteractionDisabled)
                    }
                }
        }

        private var content: some View {
            VStack(alignment: .leading) {
                if state.shouldShowLoadingView {
                    ExportProgressSection(
                        progress: state.exportProgress,
                        progressText: state.progressText,
                        canCancelExport: state.canCancelExport,
                        onCancel: onCancelExport
                    )
                } else {
                    ExportQualitySelectionSection(
                        qualities: qualities,
                        selectedQuality: state.selectedQuality,
                        estimatedVideoSizeText: estimatedVideoSizeText,
                        showsFailureMessage: state.shouldShowFailureMessage,
                        errorMessage: state.errorMessage,
                        actionTitle: state.actionTitle,
                        canExportVideo: state.canExportVideo,
                        onSelectQuality: onSelectQuality,
                        onBlockedQualityTap: onBlockedQualityTap,
                        onExport: onExport
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }

        // MARK: - Initializer

        public init(
            isAlertPresented: Binding<Bool>,
            state: VideoExportPresentationState,
            qualities: [ExportQualityAvailability] = ExportQualityAvailability.allEnabled,
            estimatedVideoSizeText: @escaping (VideoQuality) -> String? = { _ in nil },
            onSelectQuality: @escaping (VideoQuality) -> Void,
            onBlockedQualityTap: @escaping (VideoQuality) -> Void = { _ in },
            onExport: @escaping () -> Void,
            onRetry: @escaping () -> Void,
            onCancelExport: @escaping () -> Void,
            onClose: @escaping () -> Void
        ) {
            _isAlertPresented = isAlertPresented

            self.state = state
            self.qualities = qualities.sorted {
                if $0.order == $1.order {
                    return $0.quality.rawValue < $1.quality.rawValue
                }

                return $0.order < $1.order
            }
            self.estimatedVideoSizeText = estimatedVideoSizeText
            self.onSelectQuality = onSelectQuality
            self.onBlockedQualityTap = onBlockedQualityTap
            self.onExport = onExport
            self.onRetry = onRetry
            self.onCancelExport = onCancelExport
            self.onClose = onClose
        }

    }

    private struct ExportQualitySelectionSection: View {

        // MARK: - Public Properties

        let qualities: [ExportQualityAvailability]
        let selectedQuality: VideoQuality
        let estimatedVideoSizeText: (VideoQuality) -> String?
        let showsFailureMessage: Bool
        let errorMessage: String
        let actionTitle: String
        let canExportVideo: Bool
        let onSelectQuality: (VideoQuality) -> Void
        let onBlockedQualityTap: (VideoQuality) -> Void
        let onExport: () -> Void

        // MARK: - Body

        var body: some View {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose the output quality for the rendered file.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(spacing: 8) {
                        ForEach(qualities) { availability in
                            ExportQualityOptionRow(
                                quality: availability.quality,
                                estimatedSizeText: estimatedVideoSizeText(availability.quality),
                                isSelected: availability.quality == selectedQuality,
                                isBlocked: availability.isBlocked,
                                onTap: {
                                    if availability.isBlocked {
                                        onBlockedQualityTap(availability.quality)
                                    } else {
                                        onSelectQuality(availability.quality)
                                    }
                                }
                            )
                        }
                    }

                    if showsFailureMessage {
                        ExportFailureMessageCard(message: errorMessage)
                    }
                }

                Button(action: onExport) {
                    Text(actionTitle)
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canExportVideo)
            }
        }

    }

    private struct ExportQualityOptionRow: View {

        // MARK: - Public Properties

        let quality: VideoQuality
        let estimatedSizeText: String?
        let isSelected: Bool
        let isBlocked: Bool
        let onTap: () -> Void

        // MARK: - Body

        var body: some View {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(quality.title)
                                .font(.headline)

                            if isBlocked {
                                PremiumQualityBadge()
                            }
                        }

                        Text(quality.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if let estimatedSizeText {
                            Text(estimatedSizeText)
                                .font(.subheadline.weight(.semibold))
                        }

                        Image(systemName: trailingSymbolName)
                            .font(.headline)
                            .foregroundStyle(trailingSymbolTint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .opacity(isBlocked ? 0.55 : 1)
                .background(rowBackground)
                .contentShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(accessibilityHint)
            .accessibilityIdentifier(accessibilityIdentifier)
        }

        // MARK: - Private Properties

        private var trailingSymbolName: String {
            if isBlocked {
                "lock.fill"
            } else if isSelected {
                "checkmark.circle.fill"
            } else {
                "circle"
            }
        }

        private var trailingSymbolTint: Color {
            if isBlocked {
                .secondary
            } else if isSelected {
                .accentColor
            } else {
                .secondary
            }
        }

        private var rowBackground: some View {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected && !isBlocked ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isSelected && !isBlocked ? Color.accentColor : Color.secondary.opacity(0.18),
                            lineWidth: isSelected && !isBlocked ? 1.5 : 1
                        )
                }
        }

        private var accessibilityLabel: String {
            isBlocked ? "\(quality.title), premium" : quality.title
        }

        private var accessibilityValue: String {
            if isBlocked {
                "Locked"
            } else if isSelected {
                "Selected"
            } else {
                "Available"
            }
        }

        private var accessibilityHint: String {
            isBlocked
                ? "Double-tap to learn how to unlock this export quality."
                : "Double-tap to select this export quality."
        }

        private var accessibilityIdentifier: String {
            "export-quality-\(quality.rawValue)"
        }

    }

    private struct PremiumQualityBadge: View {

        // MARK: - Body

        var body: some View {
            Text("Premium")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                )
        }

    }

    private struct ExportFailureMessageCard: View {

        // MARK: - Public Properties

        let message: String

        // MARK: - Body

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.yellow.opacity(0.12))
            )
        }

    }

    private struct ExportProgressSection: View {

        // MARK: - Public Properties

        let progress: Double
        let progressText: String
        let canCancelExport: Bool
        let onCancel: () -> Void

        // MARK: - Body

        var body: some View {
            VStack(spacing: 24) {
                ProgressView(value: progress, total: 1)
                    .tint(.accentColor)

                Text(progressText)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .contentTransition(.numericText())

                Text("Video export in progress")
                    .font(.headline)

                Text("Keep this sheet open while we prepare the final video.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .disabled(!canCancelExport)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        }

    }

    #Preview {
        @Previewable @State var isAlertPresented = false
        NavigationStack {
            VideoExporterView(
                isAlertPresented: $isAlertPresented,
                state: VideoExportPresentationState(
                    selectedQuality: .medium,
                    exportProgress: 0,
                    progressText: "",
                    errorMessage: "",
                    actionTitle: "Export",
                    isInteractionDisabled: false,
                    canExportVideo: true,
                    canCancelExport: false,
                    shouldShowLoadingView: false,
                    shouldShowFailureMessage: false
                ),
                onSelectQuality: { _ in },
                onExport: {},
                onRetry: {},
                onCancelExport: {},
                onClose: {}
            )
        }
    }

#endif
