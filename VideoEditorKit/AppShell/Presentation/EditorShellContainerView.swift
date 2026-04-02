//
//  EditorShellContainerView.swift
//  VideoEditorKit
//
//  Created by Codex on 02.04.2026.
//

import SwiftUI

@MainActor
struct EditorShellContainerView: View {

    // MARK: - Bindings

    @Binding private var shareDestination: RootViewModel.ShareDestination?

    // MARK: - Public Properties

    let destination: RootViewModel.EditorDestination
    let configuration: VideoEditorView.Configuration
    let callbacks: VideoEditorView.Callbacks
    let blockedToolAlertBinding: Binding<Bool>
    let blockedTool: ToolEnum?
    let blockedToolAlertMessage: (ToolEnum) -> String
    let onDismissShare: () -> Void

    // MARK: - Body

    var body: some View {
        VideoEditorView(
            destination.session,
            configuration: configuration,
            callbacks: callbacks
        )
        .sheet(
            item: $shareDestination,
            onDismiss: onDismissShare
        ) { destination in
            VideoShareSheet(activityItems: [destination.videoURL])
        }
        .alert(
            "Premium Tool",
            isPresented: blockedToolAlertBinding,
            presenting: blockedTool
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { tool in
            Text(blockedToolAlertMessage(tool))
        }
    }

    // MARK: - Initializer

    init(
        destination: RootViewModel.EditorDestination,
        shareDestination: Binding<RootViewModel.ShareDestination?>,
        configuration: VideoEditorView.Configuration,
        callbacks: VideoEditorView.Callbacks,
        blockedToolAlertBinding: Binding<Bool>,
        blockedTool: ToolEnum?,
        blockedToolAlertMessage: @escaping (ToolEnum) -> String,
        onDismissShare: @escaping () -> Void
    ) {
        _shareDestination = shareDestination

        self.destination = destination
        self.configuration = configuration
        self.callbacks = callbacks
        self.blockedToolAlertBinding = blockedToolAlertBinding
        self.blockedTool = blockedTool
        self.blockedToolAlertMessage = blockedToolAlertMessage
        self.onDismissShare = onDismissShare
    }

}
