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

    struct EditorDestination: Identifiable {

        // MARK: - Public Properties

        let id = UUID()
        let session: VideoEditorView.Session

    }

    struct ShareDestination: Identifiable, Equatable {

        // MARK: - Public Properties

        let videoURL: URL

        var id: URL {
            videoURL
        }

    }

    // MARK: - Public Properties

    var editorDestination: EditorDestination?
    var shareDestination: ShareDestination?

    private(set) var currentProjectID: UUID?
    private(set) var currentSourceVideoURL: URL?
    private(set) var latestEditorSaveState: VideoEditorView.SaveState?

    // MARK: - Private Properties

    private var lastPersistedSaveFingerprint: VideoEditingConfiguration?
    private var pendingSaveFingerprint: VideoEditingConfiguration?

    // MARK: - Public Methods

    func handleViewDisappear() {
        shareDestination = nil
    }

    func handleEditorDismiss() {
        editorDestination = nil
        shareDestination = nil
    }

    func startEditorSession(
        with source: VideoEditorView.Session.Source,
        projectID: UUID? = nil,
        editingConfiguration: VideoEditingConfiguration? = nil
    ) {
        currentProjectID = projectID
        currentSourceVideoURL = source.fileURL
        latestEditorSaveState = editingConfiguration.map {
            .init(editingConfiguration: $0)
        }
        lastPersistedSaveFingerprint = editingConfiguration?.continuousSaveFingerprint
        pendingSaveFingerprint = nil
        shareDestination = nil
        editorDestination = .init(
            session: .init(
                source: source,
                editingConfiguration: editingConfiguration
            )
        )
    }

    func startEditorSession(
        with url: URL,
        projectID: UUID? = nil,
        editingConfiguration: VideoEditingConfiguration? = nil
    ) {
        startEditorSession(
            with: .fileURL(url),
            projectID: projectID,
            editingConfiguration: editingConfiguration
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
        completePersistedProjectSave(
            projectID: projectID,
            originalVideoURL: originalVideoURL
        )
    }

    func handlePersistedExportedVideo(
        projectID: UUID,
        originalVideoURL: URL,
        exportedVideoURL: URL
    ) {
        completePersistedProjectSave(
            projectID: projectID,
            originalVideoURL: originalVideoURL
        )
        shareDestination = .init(videoURL: exportedVideoURL)
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

    func handleSourceVideoResolved(_ url: URL) {
        currentSourceVideoURL = url
    }

    func dismissShareDestination() {
        shareDestination = nil
    }

    // MARK: - Private Methods

    private func completePersistedProjectSave(
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

}
