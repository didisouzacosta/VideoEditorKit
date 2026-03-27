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
    @State private var blockedTool: ToolEnum?

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
                        
                        if viewModel.shouldShowVideoPicker {
                            selectVideoCard(
                                $bindableViewModel.selectedItem,
                                isLoading: viewModel.isLoading
                            )
                            .transition(.blurReplace)
                        }
                        
                        resultSection
                            .transition(.blurReplace)
                    }
                    .animation(.default, value: viewModel.shouldShowVideoPicker)
                }
                .defaultScrollAnchor(.center)
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
                VideoEditorView(
                    destination.url,
                    configuration: editorConfiguration
                ) { exportedVideo in
                    viewModel.handleExportedVideo(exportedVideo)
                }
                .alert(
                    "Premium Tool",
                    isPresented: blockedToolAlertBinding,
                    presenting: blockedTool
                ) { _ in
                    Button("OK", role: .cancel) {}
                } message: { tool in
                    Text(blockedToolAlertMessage(for: tool))
                }
            }
        }
    }

}

extension RootView {

    // MARK: - Private Properties

    private var blockedToolAlertBinding: Binding<Bool> {
        Binding(
            get: { blockedTool != nil },
            set: { isPresented in
                if !isPresented {
                    blockedTool = nil
                }
            }
        )
    }

    private var editorConfiguration: VideoEditorView.Configuration {
        .init(
            tools: [
                .enabled(.speed),
                .blocked(.audio),
                .blocked(.filters),
            ],
            onBlockedToolTap: { tool in
                blockedTool = tool
            }
        )
    }

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
                "This screen now works as an example integration. It exposes one tool, keeps premium tools visible as locked, and shows the exported output here."
            )
            .font(.subheadline)
            .foregroundStyle(Theme.secondary)
        }
        .padding(32)
        .card()
    }

    private func blockedToolAlertMessage(for tool: ToolEnum) -> String {
        "\(tool.title) is locked in this demo. Connect `onBlockedToolTap` to your paywall or upgrade flow in the host app."
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
        if let editedVideo = viewModel.editedVideo {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edited Result")
                    .font(.headline)
                    .padding(.horizontal)

                PlayerView(viewModel.resultPlayer, showControls: true)
                    .aspectRatio(viewModel.editedVideoAspectRatio, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 28))
                    .card()

                HStack(spacing: 12) {
                    ShareLink(item: editedVideo.url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.glassProminent)

                    Button(role: .destructive, action: viewModel.clearEditedVideo) {
                        Label("Clear", systemImage: "trash")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

}

#Preview {
    RootView()
}
