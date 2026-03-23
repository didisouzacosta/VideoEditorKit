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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    selectVideoCard
                    resultSection
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .navigationDestination(item: $editorDestination) { destination in
                MainEditorView(sourceVideoURL: destination.url) { exportedURL in
                    replaceEditedVideo(with: exportedURL)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Example Mode")
                        .font(.title2.bold())
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
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 10) {
                        Text("Loading video")
                        ProgressView()
                    }
                    .padding()
                    .frame(height: 100)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

extension RootView {
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a video from your gallery, edit it, and get the rendered result back on this screen.")
                .font(.title3.bold())
            Text("This screen now works as an example mode. It starts a temporary editing session and shows the exported output.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectVideoCard: some View {
        PhotosPicker(selection: $item, matching: .videos) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 24, weight: .semibold))
                Text("Choose a Video")
                    .font(.headline)
                Text("Import a clip from Photos and open it directly in the editor.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.systemGray6), in: .rect(cornerRadius: 20))
            .foregroundStyle(.primary)
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
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No edited video yet.")
                        .font(.headline)
                    Text("After exporting from the editor, the rendered video will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.systemGray6), in: .rect(cornerRadius: 20))
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
                print("Failed to load video: \(error.localizedDescription)")
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
        FileManager.default.removefileExists(for: url)
    }
}

#Preview {
    RootView()
}
