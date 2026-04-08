//
//  RootView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import PhotosUI
import SwiftData
import SwiftUI

@MainActor
struct RootView: View {

    // MARK: - Environments

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - States

    @State private var viewModel = RootViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var saveStateTask: Task<Void, Never>?
    @State private var premiumPresentation: PremiumPresentation?
    @State private var persistenceErrorMessage: String?

    // MARK: - Private Properties

    @Query(sort: \EditedVideoProject.updatedAt, order: .reverse)
    private var persistedProjects: [EditedVideoProject]

    private enum Constants {
        static let editingStateSaveDebounceInNanoseconds: UInt64 = 250_000_000
        static let openAIAPIKeyEnvironmentName = "OPENAI_API_KEY"
        static let openAIAPIKeyInfoDictionaryName = "OPENAI_API_KEY"
        static let openAIAPIKeyUserDefaultsName = "OPENAI_API_KEY"
    }

    // MARK: - Body

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationStack {
            ZStack {
                Theme.rootBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroSection

                        selectVideoCard($selectedItem)

                        editedProjectsSection
                    }
                }
                .scrollIndicators(.hidden)
                .contentMargins(16)
            }
            .onDisappear(perform: handleViewDisappear)
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                viewModel.startEditorSession(with: .photosPickerItem(newItem))
                selectedItem = nil
            }
            .alert(
                "Unable to Save Project",
                isPresented: persistenceAlertBinding
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(persistenceErrorMessage ?? "")
            }
            .fullScreenCover(
                item: $bindableViewModel.editorDestination,
                onDismiss: viewModel.handleEditorDismiss
            ) { destination in
                VideoEditorView(
                    "Editor",
                    session: destination.session,
                    configuration: editorConfiguration,
                    callbacks: editorCallbacks
                )
                .sheet(
                    item: $bindableViewModel.shareDestination,
                    onDismiss: viewModel.dismissShareDestination
                ) { shareDestination in
                    VideoShareSheet(activityItems: [shareDestination.videoURL])
                }
                .alert(
                    premiumAlertTitle,
                    isPresented: premiumAlertBinding,
                    presenting: premiumPresentation
                ) { _ in
                    Button("OK", role: .cancel) {}
                } message: { presentation in
                    Text(premiumAlertMessage(for: presentation))
                }
            }
        }
    }

}

extension RootView {

    // MARK: - Private Properties

    static var defaultTranscriptionConfiguration: VideoEditorView.Configuration.TranscriptionConfiguration {
        .init(
            provider: defaultTranscriptionProvider,
            preferredLocale: nil
        )
    }

    private static var defaultTranscriptionProvider: (any VideoTranscriptionProvider)? {
        guard let apiKey = resolvedOpenAIAPIKey() else { return nil }

        return OpenAIWhisperTranscriptionComponent(apiKey)
    }

    private static func resolvedOpenAIAPIKey() -> String? {
        let candidates = [
            ProcessInfo.processInfo.environment[Constants.openAIAPIKeyEnvironmentName],
            Bundle.main.object(forInfoDictionaryKey: Constants.openAIAPIKeyInfoDictionaryName) as? String,
            UserDefaults.standard.string(forKey: Constants.openAIAPIKeyUserDefaultsName),
        ]

        return
            candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private enum PremiumPresentation: Identifiable {

        // MARK: - Public Properties

        case tool(ToolEnum)
        case exportQuality(VideoQuality)

        var id: String {
            switch self {
            case .tool(let tool):
                "tool-\(tool.rawValue)"
            case .exportQuality(let quality):
                "quality-\(quality.rawValue)"
            }
        }

        var alertTitle: String {
            switch self {
            case .tool:
                "Premium Tool"
            case .exportQuality:
                "Premium Export"
            }
        }

    }

    private var premiumAlertBinding: Binding<Bool> {
        Binding(
            get: { premiumPresentation != nil },
            set: { isPresented in
                if !isPresented {
                    premiumPresentation = nil
                }
            }
        )
    }

    private var premiumAlertTitle: String {
        premiumPresentation?.alertTitle ?? "Premium Feature"
    }

    private var editorConfiguration: VideoEditorView.Configuration {
        .init(
            tools: ToolAvailability.enabled(ToolEnum.all),
            exportQualities: ExportQualityAvailability.allEnabled,
            transcription: Self.defaultTranscriptionConfiguration,
            onBlockedToolTap: { tool in
                premiumPresentation = .tool(tool)
            },
            onBlockedExportQualityTap: { quality in
                premiumPresentation = .exportQuality(quality)
            }
        )
    }

    private var persistenceAlertBinding: Binding<Bool> {
        Binding(
            get: { persistenceErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    persistenceErrorMessage = nil
                }
            }
        )
    }

    private var editorCallbacks: VideoEditorView.Callbacks {
        .init(
            onSaveStateChanged: { saveState in
                if viewModel.handleEditorSaveStateChange(saveState) {
                    scheduleEditingStateSave(saveState)
                }
            },
            onSourceVideoResolved: { sourceVideoURL in
                viewModel.handleSourceVideoResolved(sourceVideoURL)
            },
            onDismissed: { _ in },
            onExportedVideoURL: { exportedVideoURL in
                Task {
                    await persistExportedVideo(at: exportedVideoURL)
                }
            }
        )
    }

    private var availableProjects: [EditedVideoProject] {
        persistedProjects.filter(\.hasOriginalVideo)
    }

    private var projectsStore: EditedVideoProjectsStore {
        EditedVideoProjectsStore(modelContext: modelContext)
    }

    private var editedProjectsGridColumnCount: Int {
        horizontalSizeClass == .compact ? 3 : 4
    }

    private var editedProjectsGridSpacing: CGFloat {
        12
    }

    private var editedProjectsGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: editedProjectsGridSpacing),
            count: editedProjectsGridColumnCount
        )
    }

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit, export, and revisit your clips.")
                .font(.largeTitle.bold())

            Text(
                "Choose a video from Photos, export it, and keep both the original media and the rendered output saved for future edits."
            )
            .font(.title3.weight(.semibold))

            Text(
                "The home screen now behaves like the host app shell: it owns persistence, shows your exported projects in a grid, and reopens the editor with the original file plus the last saved editing configuration."
            )
            .font(.subheadline)
            .foregroundStyle(Theme.secondary)
        }
        .padding(32)
        .card()
    }

    private func premiumAlertMessage(for presentation: PremiumPresentation) -> String {
        switch presentation {
        case .tool(let tool):
            "\(tool.title) is locked in this demo. Connect `onBlockedToolTap` to your paywall or upgrade flow in the host app."
        case .exportQuality(let quality):
            "\(quality.title) export is locked in this demo. Connect `onBlockedExportQualityTap` to your paywall or upgrade flow in the host app."
        }
    }

    private func selectVideoCard(
        _ selectedItem: Binding<PhotosPickerItem?>
    ) -> some View {
        PhotosPicker(selection: selectedItem, matching: .videos) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .circleControl(prominent: true, tint: Theme.accent)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose a Video")
                        .font(.headline)
                    Text("Import a clip from Photos and open it directly in the editor.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(32)
            .card(prominent: true, tint: Theme.accent)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var editedProjectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edited Videos")
                .font(.headline)
                .padding(.horizontal)

            if availableProjects.isEmpty {
                emptyProjectsCard
            } else {
                LazyVGrid(
                    columns: editedProjectsGridColumns,
                    alignment: .leading,
                    spacing: editedProjectsGridSpacing
                ) {
                    ForEach(availableProjects) { project in
                        EditedVideoProjectCard(
                            project: project,
                            onOpen: {
                                openProject(project)
                            },
                            onEdit: {
                                openProject(project)
                            },
                            onDelete: {
                                deleteProject(project)
                            }
                        )
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    private var emptyProjectsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No saved videos yet")
                .font(.headline)

            Text(
                "Choose a video, make your edits, and it will appear here with the latest saved configuration even before export."
            )
            .font(.subheadline)
            .foregroundStyle(Theme.secondary)
        }
        .padding(24)
        .card()
    }

    private func openProject(_ project: EditedVideoProject) {
        guard project.hasOriginalVideo else {
            persistenceErrorMessage = "The original video for this project is no longer available."
            return
        }

        viewModel.startEditorSession(
            with: project.originalVideoURL,
            projectID: project.id,
            editingConfiguration: project.editingConfiguration
        )
    }

    private func deleteProject(_ project: EditedVideoProject) {
        do {
            try projectsStore.deleteProject(project)
        } catch {
            persistenceErrorMessage = error.localizedDescription
        }
    }

    private func handleViewDisappear() {
        saveStateTask?.cancel()
        saveStateTask = nil
        viewModel.handleViewDisappear()
    }

    private func scheduleEditingStateSave(
        _ saveState: VideoEditorView.SaveState
    ) {
        saveStateTask?.cancel()
        saveStateTask = Task {
            try? await Task.sleep(nanoseconds: Constants.editingStateSaveDebounceInNanoseconds)
            guard Task.isCancelled == false else {
                viewModel.clearPendingEditingStateSave(for: saveState)
                return
            }

            await persistEditingState(saveState)
        }
    }

    private func persistEditingState(
        _ saveState: VideoEditorView.SaveState
    ) async {
        guard let originalVideoURL = viewModel.currentSourceVideoURL else {
            persistenceErrorMessage = "The original video for this editing session could not be resolved."
            return
        }

        do {
            let persistedState = try await projectsStore.saveEditingState(
                projectID: viewModel.currentProjectID,
                originalVideoURL: originalVideoURL,
                saveState: saveState
            )

            guard Task.isCancelled == false else {
                viewModel.clearPendingEditingStateSave(for: saveState)
                return
            }

            viewModel.handlePersistedEditingStateSave(
                projectID: persistedState.project.id,
                originalVideoURL: persistedState.project.originalVideoURL,
                saveState: persistedState.saveState
            )
        } catch {
            guard Task.isCancelled == false else {
                viewModel.clearPendingEditingStateSave(for: saveState)
                return
            }
            viewModel.clearPendingEditingStateSave(for: saveState)
            persistenceErrorMessage = error.localizedDescription
        }
    }

    private func persistExportedVideo(
        at exportedVideoURL: URL
    ) async {
        saveStateTask?.cancel()
        saveStateTask = nil

        guard let originalVideoURL = viewModel.currentSourceVideoURL else {
            persistenceErrorMessage = "The original video for this editing session could not be resolved."
            return
        }

        let editingConfiguration =
            viewModel.latestEditorSaveState?.editingConfiguration
            ?? viewModel.editorDestination?.session.editingConfiguration
            ?? .initial
        let exportedVideo = await ExportedVideo.load(from: exportedVideoURL)

        do {
            let project = try await projectsStore.saveExportedVideo(
                projectID: viewModel.currentProjectID,
                originalVideoURL: originalVideoURL,
                exportedVideo: exportedVideo,
                editingConfiguration: editingConfiguration
            )

            viewModel.handlePersistedExportedVideo(
                projectID: project.id,
                originalVideoURL: project.originalVideoURL,
                exportedVideoURL: project.exportedVideoURL
            )
            selectedItem = nil
        } catch {
            persistenceErrorMessage = error.localizedDescription
        }
    }

}

#Preview {
    RootView()
        .modelContainer(for: EditedVideoProject.self, inMemory: true)
}
