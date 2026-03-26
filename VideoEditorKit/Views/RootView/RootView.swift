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

    // MARK: - States

    @State private var viewModel = RootViewModel()

    // MARK: - Body

    var body: some View {
        @Bindable var bindableViewModel = viewModel
        
        NavigationStack {
            ZStack {
                Theme.rootBackground
                    .ignoresSafeArea()

                if viewModel.showLoader {
                    loadingView
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            heroSection
                            selectVideoCard($bindableViewModel.selectedItem)
                            resultSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Example Mode")
            .onDisappear(perform: viewModel.handleViewDisappear)
            .sheet(item: $bindableViewModel.editorDestination, onDismiss: viewModel.handleEditorDismiss) {
                destination in
                VideoEditorView(destination.url) { exportedURL in
                    viewModel.handleExportedVideo(exportedURL)
                }
            }
            .onChange(of: viewModel.selectedItem) { _, newItem in
                viewModel.loadSelectedItem(newItem)
            }
        }
    }

}

extension RootView {

    // MARK: - Private Properties

    private var loadingView: some View {
        ZStack {
            Theme.scrim.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Loading video")
                    .font(.headline)
                ProgressView()
                    .tint(Theme.accent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .card(prominent: true, tint: Theme.secondary)
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
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

    private func selectVideoCard(_ selectedItem: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: selectedItem, matching: .videos) {
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

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edited Result")
                .font(.headline)

            if let editedVideoURL = viewModel.editedVideoURL {
                VStack(alignment: .leading, spacing: 12) {
                    PlayerView(viewModel.resultPlayer)
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

}

#Preview {
    RootView()
}
