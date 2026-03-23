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
                IOS26Theme.rootBackground
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
                .scrollIndicators(.hidden)
                .navigationDestination(item: $editorDestination) { destination in
                    MainEditorView(sourceVideoURL: destination.url) { exportedURL in
                        replaceEditedVideo(with: exportedURL)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Example Mode")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .foregroundStyle(.white)
                            .ios26CapsuleControl(tint: IOS26Theme.accentSecondary)
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .onChange(of: item) { _, newItem in
                    loadPhotosItem(newItem)
                }
                .onDisappear {
                    itemLoadTask?.cancel()
                    resultPlayer.pause()
                }
                .overlay {
                    if showLoader {
                        IOS26Theme.scrim.ignoresSafeArea()
                        VStack(spacing: 12) {
                            Text("Loading video")
                                .font(.headline)
                                .foregroundStyle(.white)
                            ProgressView()
                                .tint(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 22)
                        .ios26Card(prominent: true, tint: IOS26Theme.accent)
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
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .ios26CapsuleControl(tint: IOS26Theme.accent)

            Text("Edit a clip with the iOS 26 visual language.")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text(
                "Pick a video from your gallery, edit it, and get the rendered result back on this screen."
            )
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            Text(
                "This screen now works as an example mode. It starts a temporary editing session and shows the exported output."
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.78))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ios26Card(prominent: true, tint: IOS26Theme.accentSecondary)
    }

    private var selectVideoCard: some View {
        PhotosPicker(selection: $item, matching: .videos) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .foregroundStyle(.white)
                    .ios26CircleControl(prominent: true, tint: IOS26Theme.accent)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose a Video")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Import a clip from Photos and open it directly in the editor.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .ios26Card(prominent: true, tint: IOS26Theme.accent)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edited Result")
                .font(.headline)
                .foregroundStyle(.white)

            if let editedVideoURL {
                VStack(alignment: .leading, spacing: 12) {
                    PlayerView(player: resultPlayer)
                        .frame(height: 260)
                        .clipShape(.rect(cornerRadius: 24))

                    Text(editedVideoURL.lastPathComponent)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(18)
                .ios26Card(tint: IOS26Theme.accentSecondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No edited video yet.")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("After exporting from the editor, the rendered video will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .ios26Card(tint: IOS26Theme.accentSecondary)
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
