//
//  RootViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 26.03.2026.
//

import AVKit
import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class RootViewModel {

    // MARK: - Public Properties

    var selectedItem: PhotosPickerItem?
    var showLoader = false
    var editorDestination: EditorDestination?
    var editedVideoURL: URL?
    private(set) var resultPlayer = AVPlayer()

    struct EditorDestination: Hashable, Identifiable {

        let id = UUID()
        let url: URL

    }

    // MARK: - Private Properties

    @ObservationIgnored private var itemLoadTask: Task<Void, Never>?

    private var sessionSourceURL: URL?

    // MARK: - Public Methods

    func loadSelectedItem(_ newItem: PhotosPickerItem?) {
        itemLoadTask?.cancel()

        guard let newItem else {
            showLoader = false
            return
        }

        itemLoadTask = Task { [weak self] in
            guard let self else { return }
            showLoader = true

            defer {
                showLoader = false
                itemLoadTask = nil
            }

            do {
                if let video = try await newItem.loadTransferable(type: VideoItem.self), !Task.isCancelled {
                    prepareEditorSession(with: video.url)
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

    func handleEditorDismiss() {
        resetPickerSelection()
    }

    func handleExportedVideo(_ url: URL) {
        cleanupFileIfNeeded(editedVideoURL)
        editedVideoURL = url
        resultPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
        resultPlayer.seek(to: .zero)
    }

    // MARK: - Private Methods

    private func prepareEditorSession(with url: URL) {
        resultPlayer.pause()
        resultPlayer.replaceCurrentItem(with: nil)
        cleanupFileIfNeeded(sessionSourceURL)
        cleanupFileIfNeeded(editedVideoURL)
        editedVideoURL = nil
        sessionSourceURL = url
        resetPickerSelection()
        editorDestination = .init(url: url)
    }

    private func resetPickerSelection() {
        selectedItem = nil
    }

    private func cleanupFileIfNeeded(_ url: URL?) {
        guard let url else { return }
        FileManager.default.removeIfExists(for: url)
    }

}
