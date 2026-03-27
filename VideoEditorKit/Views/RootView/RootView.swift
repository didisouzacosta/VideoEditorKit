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

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        heroSection
                        selectVideoCard(
                            $bindableViewModel.selectedItem,
                            isLoading: viewModel.isLoading
                        )
                        resultSection
                    }
                }
                .scrollIndicators(.hidden)
                .contentMargins(16)
            }
            .onDisappear(perform: viewModel.handleViewDisappear)
            .onChange(of: viewModel.selectedItem) { _, newItem in
                viewModel.loadSelectedItem(newItem)
            }
            .fullScreenCover(
                item: $bindableViewModel.editorDestination,
                onDismiss: viewModel.handleEditorDismiss
            ) { destination in
                VideoEditorView(destination.url) { exportedURL in
                    viewModel.handleExportedVideo(exportedURL)
                }
            }
        }
    }

}

extension RootView {

    // MARK: - Private Properties

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
        .padding(32)
        .card()
    }

    private func selectVideoCard(
        _ selectedItem: Binding<PhotosPickerItem?>,
        isLoading: Bool
    ) -> some View {
        PhotosPicker(selection: selectedItem, matching: .videos) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .circleControl(prominent: true, tint: Theme.accent)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose a Video")
                        .font(.headline)
                    Text("Import a clip from Photos and open it directly in the editor.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .padding(32)
            .card(prominent: true, tint: Theme.accent)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var resultSection: some View {
        if viewModel.editedVideoURL != nil {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edited Result")
                    .font(.headline)
                    .padding(.horizontal)

                PlayerView(viewModel.resultPlayer, showControls: true)
                    .scaledToFill()
            }
        }
    }

}

#Preview {
    RootView()
}
