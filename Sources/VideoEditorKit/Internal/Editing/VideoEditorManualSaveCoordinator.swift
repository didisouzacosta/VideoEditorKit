//
//  VideoEditorManualSaveCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 25.04.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class VideoEditorManualSaveCoordinator {

    // MARK: - Public Properties

    private(set) var hasUnsavedChanges = false

    // MARK: - Private Properties

    private var baselineFingerprint: VideoEditingConfiguration?

    // MARK: - Public Methods

    func resetBaseline(to editingConfiguration: VideoEditingConfiguration?) {
        baselineFingerprint = editingConfiguration?.continuousSaveFingerprint
        hasUnsavedChanges = false
    }

    func resetBaselineIfNeeded(to editingConfiguration: VideoEditingConfiguration?) {
        guard baselineFingerprint == nil else { return }
        resetBaseline(to: editingConfiguration)
    }

    func updateCurrentEditingConfiguration(_ editingConfiguration: VideoEditingConfiguration?) {
        guard let baselineFingerprint,
            let currentFingerprint = editingConfiguration?.continuousSaveFingerprint
        else {
            hasUnsavedChanges = false
            return
        }

        hasUnsavedChanges = currentFingerprint != baselineFingerprint
    }

    func markSaved(_ editingConfiguration: VideoEditingConfiguration) {
        resetBaseline(to: editingConfiguration)
    }

    func reset() {
        resetBaseline(to: nil)
    }

}
