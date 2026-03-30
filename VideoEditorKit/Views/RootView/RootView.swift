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
    @State private var itemLoadTask: Task<Void, Never>?
    @State private var blockedTool: ToolEnum?
    @State private var persistenceErrorMessage: String?

    // MARK: - Private Properties

    @Query(sort: \EditedVideoProject.updatedAt, order: .reverse)
    private var persistedProjects: [EditedVideoProject]

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

                        selectVideoCard(
                            $selectedItem,
                            isLoading: viewModel.isLoading
                        )

                        editedProjectsSection
                    }
                }
                .scrollIndicators(.hidden)
                .contentMargins(16)
            }
            .onDisappear(perform: handleViewDisappear)
            .onChange(of: selectedItem) { _, newItem in
                itemLoadTask?.cancel()
                itemLoadTask = Task {
                    await loadSelectedItem(newItem)
                }
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
                onDismiss: {
                    viewModel.handleEditorDismiss()
                }
            ) { destination in
                VideoEditorView(
                    destination.session,
                    configuration: editorConfiguration,
                    callbacks: editorCallbacks
                )
                .alert(
                    "Premium Tool",
                    isPresented: blockedToolAlertBinding,
                    presenting: blockedTool
                ) { _ in
                    Button("OK", role: .cancel) {}
                } message: { tool in
                    Text(blockedToolAlertMessage(for: tool))
                }
            }
        }
    }

}

extension RootView {

    // MARK: - Private Properties

    private var blockedToolAlertBinding: Binding<Bool> {
        Binding(
            get: { blockedTool != nil },
            set: { isPresented in
                if !isPresented {
                    blockedTool = nil
                }
            }
        )
    }

    private var editorConfiguration: VideoEditorView.Configuration {
        .init(
            tools: [
                .enabled(.speed),
                .blocked(.audio),
                .blocked(.filters),
            ],
            onBlockedToolTap: { tool in
                blockedTool = tool
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
            onEditingConfigurationChanged: { _ in },
            onDismissed: { _ in },
            onExported: { exportedVideo, editingConfiguration in
                Task {
                    await persistProject(
                        exportedVideo,
                        editingConfiguration: editingConfiguration
                    )
                }
            }
        )
    }

    private var availableProjects: [EditedVideoProject] {
        persistedProjects.filter(\.hasRequiredMedia)
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

    private func blockedToolAlertMessage(for tool: ToolEnum) -> String {
        "\(tool.title) is locked in this demo. Connect `onBlockedToolTap` to your paywall or upgrade flow in the host app."
    }

    private func selectVideoCard(
        _ selectedItem: Binding<PhotosPickerItem?>,
        isLoading: Bool
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

                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.secondary)
                }
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
                GeometryReader { geometry in
                    let itemSide = editedProjectsGridItemSide(for: geometry.size.width)

                    LazyVGrid(
                        columns: editedProjectsGridColumns(with: itemSide),
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
                            .frame(width: itemSide, height: itemSide)
                        }
                    }
                }
                .frame(height: editedProjectsGridHeight)
            }
        }
    }

    private var emptyProjectsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No exported videos yet")
                .font(.headline)

            Text(
                "Export your first clip and it will appear here with its thumbnail, duration tag, and saved editing configuration."
            )
            .font(.subheadline)
            .foregroundStyle(Theme.secondary)
        }
        .padding(24)
        .card()
    }

    private var editedProjectsGridHeight: CGFloat {
        let rowCount = ceil(CGFloat(availableProjects.count) / CGFloat(editedProjectsGridColumnCount))
        let itemSide = editedProjectsGridItemSide(for: UIScreen.main.bounds.width - 32)

        return (rowCount * itemSide) + (max(0, rowCount - 1) * editedProjectsGridSpacing)
    }

    private func editedProjectsGridColumns(with itemSide: CGFloat) -> [GridItem] {
        Array(
            repeating: GridItem(.fixed(itemSide), spacing: editedProjectsGridSpacing),
            count: editedProjectsGridColumnCount
        )
    }

    private func editedProjectsGridItemSide(for availableWidth: CGFloat) -> CGFloat {
        let totalSpacing = CGFloat(editedProjectsGridColumnCount - 1) * editedProjectsGridSpacing
        return floor((availableWidth - totalSpacing) / CGFloat(editedProjectsGridColumnCount))
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
        itemLoadTask?.cancel()
        itemLoadTask = nil
        viewModel.handleViewDisappear()
    }

    private func loadSelectedItem(_ newItem: PhotosPickerItem?) async {
        guard let newItem else {
            viewModel.isLoading = false
            return
        }

        viewModel.isLoading = true

        defer {
            viewModel.isLoading = false
            itemLoadTask = nil
        }

        do {
            if let video = try await newItem.loadTransferable(type: VideoItem.self), !Task.isCancelled {
                viewModel.startEditorSession(with: video.url)
                selectedItem = nil
            }
        } catch {
            assertionFailure("Failed to load selected video: \(error.localizedDescription)")
            selectedItem = nil
        }
    }

    private func persistProject(
        _ exportedVideo: ExportedVideo,
        editingConfiguration: VideoEditingConfiguration
    ) async {
        guard let originalVideoURL = viewModel.currentSourceVideoURL else {
            persistenceErrorMessage = "The original video for this editing session could not be resolved."
            return
        }

        do {
            let project = try await projectsStore.saveProject(
                projectID: viewModel.currentProjectID,
                originalVideoURL: originalVideoURL,
                exportedVideo: exportedVideo,
                editingConfiguration: editingConfiguration
            )

            viewModel.handlePersistedProjectSave(
                projectID: project.id,
                originalVideoURL: project.originalVideoURL
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
