//
//  RootView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import PhotosUI
import SwiftUI

@MainActor
struct RootView: View {
    private struct EditorDestination: Hashable, Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var item: PhotosPickerItem?
    @State private var showLoader = false
    @State private var editorDestination: EditorDestination?
    @State private var editedVideoURL: URL?
    @State private var resultPlayer = AVPlayer()
    @State private var sessionSourceURL: URL?
    @State private var itemLoadTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.rootBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroSection
                        selectVideoCard
                        resultSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .navigationTitle("Example Mode")
                .scrollIndicators(.hidden)
                .sheet(item: $editorDestination) { destination in
                    MainEditorView(sourceVideoURL: destination.url) { exportedURL in
                        replaceEditedVideo(with: exportedURL)
                    }
                }
                .onChange(of: item) { _, newItem in
                    loadPhotosItem(newItem)
                }
                .onDisappear {
                    itemLoadTask?.cancel()
                    resultPlayer.pause()
                }
                .overlay {
                    if showLoader {
                        Theme.scrim.ignoresSafeArea()
                        VStack(spacing: 12) {
                            Text("Loading video")
                                .font(.headline)
                            ProgressView()
                                .tint(Theme.accent)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 22)
                    }
                }
            }
        }
    }
}

extension RootView {
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Temporary Editing Session", systemImage: "sparkles.rectangle.stack.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Text("Edit a clip with the iOS 26 visual language.")
                .font(.largeTitle.bold())

            Text(
                "Pick a video from your gallery, edit it, and get the rendered result back on this screen."
            )
            .font(.title3.weight(.semibold))
            Text(
                "This screen now works as an example mode. It starts a temporary editing session and shows the exported output."
            )
            .font(.subheadline)
            .foregroundStyle(Theme.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var selectVideoCard: some View {
        PhotosPicker(selection: $item, matching: .videos) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .foregroundStyle(Theme.primary)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .card(prominent: true, tint: Theme.accent)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edited Result")
                .font(.headline)

            if let editedVideoURL {
                VStack(alignment: .leading, spacing: 12) {
                    PlayerView(player: resultPlayer)
                        .frame(height: 260)
                        .clipShape(.rect(cornerRadius: 24))

                    Text(editedVideoURL.lastPathComponent)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                }
                .padding(18)
                .card(tint: Theme.accent)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No edited video yet.")
                        .font(.headline)
                    Text("After exporting from the editor, the rendered video will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .card(tint: Theme.accent)
            }
        }
    }

    private func loadPhotosItem(_ newItem: PhotosPickerItem?) {
        itemLoadTask?.cancel()

        guard let newItem else {
            showLoader = false
            return
        }

        itemLoadTask = Task {
            showLoader = true
            defer { showLoader = false }

            do {
                if let video = try await newItem.loadTransferable(type: VideoItem.self), !Task.isCancelled {
                    prepareEditorSession(with: video.url)
                }
            } catch {
                assertionFailure("Failed to load selected video: \(error.localizedDescription)")
            }
        }
    }

    private func prepareEditorSession(with url: URL) {
        resultPlayer.pause()
        resultPlayer.replaceCurrentItem(with: nil)
        cleanupFileIfNeeded(sessionSourceURL)
        cleanupFileIfNeeded(editedVideoURL)
        editedVideoURL = nil
        sessionSourceURL = url
        editorDestination = .init(url: url)
    }

    private func replaceEditedVideo(with url: URL) {
        cleanupFileIfNeeded(editedVideoURL)
        editedVideoURL = url
        resultPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
        resultPlayer.seek(to: .zero)
    }

    private func cleanupFileIfNeeded(_ url: URL?) {
        guard let url else { return }
        FileManager.default.removeIfExists(for: url)
    }
}

#Preview {
    RootView()
}
