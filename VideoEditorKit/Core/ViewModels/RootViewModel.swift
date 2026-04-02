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
    private(set) var latestEditorSaveState: VideoEditorView.SaveState?
    private var lastPersistedSaveFingerprint: VideoEditingConfiguration?
    private var pendingSaveFingerprint: VideoEditingConfiguration?

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
        latestEditorSaveState = editingConfiguration.map {
            .init(editingConfiguration: $0)
        }
        lastPersistedSaveFingerprint = editingConfiguration?.continuousSaveFingerprint
        pendingSaveFingerprint = nil
        editorDestination = .init(
            session: .init(
                sourceVideoURL: url,
                editingConfiguration: editingConfiguration
            )
        )
    }

    func handleEditorSaveStateChange(
        _ saveState: VideoEditorView.SaveState
    ) -> Bool {
        latestEditorSaveState = saveState

        let fingerprint = saveState.continuousSaveFingerprint
        guard
            fingerprint != lastPersistedSaveFingerprint,
            fingerprint != pendingSaveFingerprint
        else {
            return false
        }

        pendingSaveFingerprint = fingerprint
        return true
    }

    func handlePersistedProjectSave(
        projectID: UUID,
        originalVideoURL: URL
    ) {
        currentProjectID = projectID
        currentSourceVideoURL = originalVideoURL

        if let latestEditorSaveState {
            lastPersistedSaveFingerprint = latestEditorSaveState.continuousSaveFingerprint
        }

        pendingSaveFingerprint = nil
    }

    func handlePersistedEditingStateSave(
        projectID: UUID,
        originalVideoURL: URL,
        saveState: VideoEditorView.SaveState
    ) {
        currentProjectID = projectID
        currentSourceVideoURL = originalVideoURL
        latestEditorSaveState = saveState
        let fingerprint = saveState.continuousSaveFingerprint
        lastPersistedSaveFingerprint = fingerprint

        if pendingSaveFingerprint == fingerprint {
            pendingSaveFingerprint = nil
        }
    }

    func clearPendingEditingStateSave(
        for saveState: VideoEditorView.SaveState
    ) {
        let fingerprint = saveState.continuousSaveFingerprint

        if pendingSaveFingerprint == fingerprint {
            pendingSaveFingerprint = nil
        }
    }
}
