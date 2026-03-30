//
//  RootViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 26.03.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class RootViewModel {

    // MARK: - Public Properties

    var isLoading = false
    var editorDestination: EditorDestination?
    private(set) var currentProjectID: UUID?
    private(set) var currentSourceVideoURL: URL?

    struct EditorDestination: Identifiable {
        let id = UUID()
        let session: VideoEditorView.Session
    }

    // MARK: - Public Methods

    func handleViewDisappear() {
        isLoading = false
    }

    func handleEditorDismiss() {
        isLoading = false
    }

    func startEditorSession(
        with url: URL,
        projectID: UUID? = nil,
        editingConfiguration: VideoEditingConfiguration? = nil
    ) {
        currentProjectID = projectID
        currentSourceVideoURL = url
        editorDestination = .init(
            session: .init(
                sourceVideoURL: url,
                editingConfiguration: editingConfiguration
            )
        )
    }

    func handlePersistedProjectSave(
        projectID: UUID,
        originalVideoURL: URL
    ) {
        currentProjectID = projectID
        currentSourceVideoURL = originalVideoURL
    }
}
