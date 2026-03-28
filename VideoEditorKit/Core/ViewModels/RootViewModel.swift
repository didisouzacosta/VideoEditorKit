//
//  RootViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 26.03.2026.
//

import AVKit
import CoreGraphics
import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class RootViewModel {

    // MARK: - Public Properties

    var selectedItem: PhotosPickerItem?
    var isLoading = false
    var editorDestination: EditorDestination?
    var editedVideo: ExportedVideo?
    var latestEditingConfiguration: VideoEditingConfiguration?
    var latestExportedEditingConfiguration: VideoEditingConfiguration?

    var shouldShowVideoPicker: Bool {
        editedVideo == nil
    }

    var canReopenEditor: Bool {
        sessionSourceURL != nil && latestEditingConfiguration != nil
    }

    var editedVideoAspectRatio: CGFloat {
        let fallbackAspectRatio = CGFloat(16.0 / 9.0)
        return max(editedVideo?.aspectRatio ?? fallbackAspectRatio, 0.1)
    }

    var hasUnrenderedChanges: Bool {
        guard editedVideo != nil else { return false }
        return latestEditingConfiguration != latestExportedEditingConfiguration
    }

    private(set) var resultPlayer = AVPlayer()

    struct EditorDestination: Identifiable {
        let id = UUID()
        let session: VideoEditorView.Session
    }

    // MARK: - Private Properties

    @ObservationIgnored private var itemLoadTask: Task<Void, Never>?

    private var sessionSourceURL: URL?

    // MARK: - Public Methods

    func loadSelectedItem(_ newItem: PhotosPickerItem?) {
        itemLoadTask?.cancel()

        guard let newItem else {
            isLoading = false
            return
        }

        itemLoadTask = Task { [weak self] in
            guard let self else { return }

            isLoading = true

            defer {
                isLoading = false
                itemLoadTask = nil
            }

            do {
                if let video = try await newItem.loadTransferable(type: VideoItem.self), !Task.isCancelled {
                    startEditorSession(with: video.url)
                }
            } catch {
                assertionFailure("Failed to load selected video: \(error.localizedDescription)")
                resetPickerSelection()
            }
        }
    }

    func handleViewDisappear() {
        itemLoadTask?.cancel()
        resultPlayer.pause()
    }

    func handleEditorDismiss(editingConfiguration: VideoEditingConfiguration? = nil) {
        if let editingConfiguration {
            latestEditingConfiguration = editingConfiguration
        }

        resetPickerSelection()
    }

    func handleEditingConfigurationChanged(_ editingConfiguration: VideoEditingConfiguration) {
        latestEditingConfiguration = editingConfiguration
    }

    func startEditorSession(with url: URL) {
        resultPlayer.pause()
        resultPlayer.replaceCurrentItem(with: nil)
        cleanupFileIfNeeded(sessionSourceURL)
        cleanupFileIfNeeded(editedVideo?.url)
        editedVideo = nil
        latestEditingConfiguration = nil
        latestExportedEditingConfiguration = nil
        sessionSourceURL = url
        resetPickerSelection()
        editorDestination = .init(
            session: .init(sourceVideoURL: url)
        )
    }

    func handleExportedVideo(
        _ video: ExportedVideo,
        editingConfiguration: VideoEditingConfiguration
    ) {
        cleanupFileIfNeeded(editedVideo?.url)
        editedVideo = video
        latestEditingConfiguration = editingConfiguration
        latestExportedEditingConfiguration = editingConfiguration
        resultPlayer.replaceCurrentItem(with: AVPlayerItem(url: video.url))
        resultPlayer.seek(to: .zero)
    }

    func reopenEditor() {
        guard let sessionSourceURL else { return }
        editorDestination = .init(
            session: .init(
                sourceVideoURL: sessionSourceURL,
                editingConfiguration: latestEditingConfiguration
            )
        )
    }

    func clearEditedVideo() {
        resultPlayer.pause()
        resultPlayer.replaceCurrentItem(with: nil)
        cleanupFileIfNeeded(editedVideo?.url)
        editedVideo = nil
        latestEditingConfiguration = nil
        latestExportedEditingConfiguration = nil
    }

    // MARK: - Private Methods

    private func resetPickerSelection() {
        selectedItem = nil
    }

    private func cleanupFileIfNeeded(_ url: URL?) {
        guard let url else { return }
        FileManager.default.removeIfExists(for: url)
    }

}
