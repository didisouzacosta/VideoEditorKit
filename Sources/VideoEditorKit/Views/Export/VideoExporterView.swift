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

    public var isExporting: Bool {
        shouldShowLoadingView
    }

    public var shouldShowCancelAction: Bool {
        isExporting && canCancelExport
    }

    public var exportButtonTitle: String {
        isExporting ? VideoEditorStrings.exportButtonTitle(progressText: progressText) : actionTitle
    }

    public var exportButtonProgress: Double {
        min(max(exportProgress, 0), 1)
    }

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
                VideoEditorStrings.exportAlertTitle,
                isPresented: $isAlertPresented
            ) {
                Button(VideoEditorStrings.tryAgain, action: onRetry)
                Button(VideoEditorStrings.ok, role: .cancel) {}
            } message: {
                Text(state.errorMessage)
            }
    }

    // MARK: - Private Properties

    private var navigationContent: some View {
        content
            .navigationTitle(VideoEditorStrings.exportVideoTitle)
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut, value: state)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(VideoEditorStrings.cancel, role: .cancel, action: onClose)
                        .disabled(state.isInteractionDisabled)
                }
            }
    }

    private var content: some View {
        ExportQualitySelectionSection(
            qualities: qualities,
            selectedQuality: state.selectedQuality,
            state: state,
            onSelectQuality: onSelectQuality,
            onBlockedQualityTap: onBlockedQualityTap,
            onExport: onExport,
            onCancelExport: onCancelExport
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaPadding(.horizontal)
    }

    // MARK: - Initializer

    public init(
        isAlertPresented: Binding<Bool>,
        state: VideoExportPresentationState,
        qualities: [ExportQualityAvailability] = ExportQualityAvailability.allEnabled,
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
    let state: VideoExportPresentationState
    let onSelectQuality: (VideoQuality) -> Void
    let onBlockedQualityTap: (VideoQuality) -> Void
    let onExport: () -> Void
    let onCancelExport: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 16) {
                Text(VideoEditorStrings.exportChooseQualityMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                VStack(spacing: 8) {
                    ForEach(qualities) { availability in
                        ExportQualityOptionRow(
                            quality: availability.quality,
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
                .disabled(state.isInteractionDisabled)

                if state.shouldShowFailureMessage {
                    ExportFailureMessageCard(message: state.errorMessage)
                }
            }

            VStack(spacing: 12) {
                ExportActionButton(
                    title: state.exportButtonTitle,
                    progress: state.exportButtonProgress,
                    isExporting: state.isExporting,
                    action: onExport
                )
                .disabled(!state.canExportVideo && !state.isExporting)
                .allowsHitTesting(state.canExportVideo)

                if state.shouldShowCancelAction {
                    Button(VideoEditorStrings.cancel, role: .cancel, action: onCancelExport)
                        .buttonStyle(.bordered)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: state.shouldShowCancelAction)
        }
    }

}

private struct ExportQualityOptionRow: View {

    // MARK: - Public Properties

    let quality: VideoQuality
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

                Image(systemName: trailingSymbolName)
                    .font(.headline)
                    .foregroundStyle(trailingSymbolTint)
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
        VideoEditorStrings.exportQualityAccessibilityLabel(
            title: quality.title,
            isBlocked: isBlocked
        )
    }

    private var accessibilityValue: String {
        if isBlocked {
            VideoEditorStrings.locked
        } else if isSelected {
            VideoEditorStrings.selected
        } else {
            VideoEditorStrings.available
        }
    }

    private var accessibilityHint: String {
        isBlocked
            ? VideoEditorStrings.exportQualityPremiumHint
            : VideoEditorStrings.exportQualitySelectHint
    }

    private var accessibilityIdentifier: String {
        "export-quality-\(quality.rawValue)"
    }

}

private struct PremiumQualityBadge: View {

    // MARK: - Body

    var body: some View {
        Text(VideoEditorStrings.premium)
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

private struct ExportActionButton: View {

    // MARK: - Public Properties

    let title: String
    let progress: Double
    let isExporting: Bool
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(labelColor)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(buttonBackground)
                .overlay {
                    buttonBorder
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            VideoEditorStrings.exportButtonAccessibilityValue(
                progress: progress,
                isExporting: isExporting
            )
        )
        .accessibilityHint(
            isExporting
                ? VideoEditorStrings.exportButtonInProgressHint
                : VideoEditorStrings.exportButtonReadyHint
        )
    }

    // MARK: - Private Properties

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(backgroundColor)
    }

    private var buttonBorder: some View {
        ZStack {
            if isExporting == false {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(baseBorderColor, lineWidth: 1)
            }

            if isExporting {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .trim(from: 0, to: progress.clamped(to: 0...1))
                    .stroke(
                        progressBorderColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .animation(.easeInOut(duration: 0.2), value: progress)
            }
        }
    }

    private var labelColor: Color {
        isExporting ? .accentColor : .white
    }

    private var backgroundColor: Color {
        if isExporting {
            return Color.accentColor.opacity(0.14)
        }

        return .accentColor
    }

    private var baseBorderColor: Color {
        Color.white.opacity(0.18)
    }

    private var progressBorderColor: Color {
        .red
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
                actionTitle: VideoEditorStrings.export,
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
