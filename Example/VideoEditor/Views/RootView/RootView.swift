//
//  RootView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import PhotosUI
import SwiftData
import SwiftUI

struct RootView: View {

    // MARK: - Environments

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - States

    @State private var selectedItem: PhotosPickerItem?
    @State private var editorDraft: EditorSessionDraft?
    @State private var persistenceAlert: RootAlertPresentation?
    @State private var sharedVideo: ProjectVideoAction?

    // MARK: - Private Properties

    @Query(sort: \EditedVideoProject.updatedAt, order: .reverse)
    private var persistedProjects: [EditedVideoProject]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            HomeScreen(
                selectedItem: $selectedItem,
                projects: availableProjects,
                usesCompactGridLayout: horizontalSizeClass == .compact,
                onOpenProject: openProject,
                onShareSavedVideo: shareSavedVideo,
                onDeleteProject: deleteProject
            )
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                editorDraft = .imported(photoVideoImporter.makeSource(from: newItem))
                selectedItem = nil
            }
            .alert(
                item: $persistenceAlert
            ) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .cancel(Text(ExampleStrings.ok))
                )
            }
            .fullScreenCover(
                item: $editorDraft,
                onDismiss: handleEditorDismiss
            ) { draft in
                EditorHostScreen(
                    draft: draft,
                    repository: projectsRepository
                )
            }
            .sheet(item: $sharedVideo) { videoAction in
                VideoShareSheet(
                    activityItems: [videoAction.url],
                    onCompletion: handleShareCompletion
                )
            }
        }
    }

}

extension RootView {

    private struct RootAlertPresentation: Identifiable {

        // MARK: - Public Properties

        let title: String
        let message: String

        var id: String {
            "\(title)-\(message)"
        }

    }

    private struct ProjectVideoAction: Identifiable {

        // MARK: - Public Properties

        let id: UUID
        let url: URL

    }

    private var availableProjects: [EditedVideoProject] {
        persistedProjects.filter(\.hasOriginalVideo)
    }

    private var projectsRepository: ProjectsRepository {
        ProjectsRepository(modelContext: modelContext)
    }

    private var photoVideoImporter: PhotoVideoImporter {
        PhotoVideoImporter()
    }

    private func openProject(_ project: EditedVideoProject) {
        guard project.hasOriginalVideo else {
            showPersistenceError(ExampleStrings.missingProjectOriginalVideo)
            return
        }

        editorDraft = .project(project)
    }

    private func shareSavedVideo(_ project: EditedVideoProject) {
        guard let url = project.savedPlaybackVideoURL else {
            showPersistenceError(ExampleStrings.missingSavedVideo)
            return
        }

        sharedVideo = .init(id: project.id, url: url)
    }

    private func deleteProject(_ project: EditedVideoProject) {
        do {
            try projectsRepository.deleteProject(project)
        } catch {
            showPersistenceError(error.localizedDescription)
        }
    }

    private func handleEditorDismiss() {
        editorDraft = nil
    }

    private func showPersistenceError(_ message: String) {
        persistenceAlert = .init(
            title: ExampleStrings.persistenceErrorTitle,
            message: message
        )
    }

    private func handleShareCompletion(_ result: VideoShareCompletionResult) {
        guard case .failed(let message) = result else { return }
        showPersistenceError(message)
    }

}

#Preview {
    RootView()
        .modelContainer(for: EditedVideoProject.self, inMemory: true)
}
