//
//  ContentView.swift
//  VideoEditorKit
//
//  Created by Didi on 22/03/26.
//

import PhotosUI
import SwiftUI

@MainActor
struct ContentView: View {
    @State private var rootState: ExampleRootState
    @State private var selectedPickerItem: PhotosPickerItem?

    init(rootState: ExampleRootState = ExampleRootState()) {
        _rootState = State(initialValue: rootState)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session = rootState.session {
                    VideoEditorView(
                        controller: session.controller,
                        videoSize: session.videoSize,
                        preferredTransform: session.preferredTransform
                    )
                } else {
                    ExampleVideoImportView(
                        selectedItem: $selectedPickerItem,
                        isImporting: rootState.isImporting,
                        errorMessage: rootState.errorMessage
                    )
                }
            }
            .navigationTitle(rootState.session == nil ? "Import Video" : "Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if rootState.session != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Change Video", systemImage: "arrow.trianglehead.2.clockwise") {
                            resetImportFlow()
                        }
                    }
                }
            }
        }
        .task(id: selectedPickerItem != nil) {
            guard let selectedPickerItem else {
                return
            }

            await rootState.importVideo(from: selectedPickerItem)
            self.selectedPickerItem = nil
        }
    }
}

private extension ContentView {
    func resetImportFlow() {
        selectedPickerItem = nil
        rootState.reset()
    }
}

#Preview("Import") {
    ContentView()
}

#Preview("Editor") {
    ContentView(rootState: .previewReady())
}
