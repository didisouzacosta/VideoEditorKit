//
//  RootView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import PhotosUI

struct RootView: View {
    private struct EditorDestination: Hashable, Identifiable {
        let id = UUID()
        let url: URL
    }

    @ObservedObject var rootVM: RootViewModel
    @State private var item: PhotosPickerItem?
    @State private var showLoader: Bool = false
    @State private var editorDestination: EditorDestination?
    @State private var itemLoadTask: Task<Void, Never>?
    private let columns = [
        GridItem(.adaptive(minimum: 150)),
        GridItem(.adaptive(minimum: 150)),
    ]
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(.vertical) {
                    VStack(alignment: .leading) {
                        Text("My projects")
                            .font(.headline)
                        LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
                            newProjectButton
                            
                            ForEach(rootVM.projects) { project in
                                
                                NavigationLink {
                                    MainEditorView(project: project)
                                } label: {
                                    cellView(project)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(item: $editorDestination) { destination in
                MainEditorView(selectedVideoURl: destination.url)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Video editor")
                        .font(.title2.bold())
                }
            }
            .onChange(of: item) { _, newItem in
                loadPhotosItem(newItem)
            }
            .task {
                rootVM.fetch()
            }
            .onDisappear {
                itemLoadTask?.cancel()
            }
            .overlay {
                if showLoader{
                    Color.secondary.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: 10){
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

@MainActor
extension RootView{
    
    
    private var newProjectButton: some View{
        
        PhotosPicker(selection: $item, matching: .videos) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                Text("New project")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 150)
            .background(Color(.systemGray6), in: .rect(cornerRadius: 5))
            .foregroundStyle(.white)
        }
    }
       
    private func cellView(_ project: ProjectEntity) -> some View{
        ZStack {
            Color.white
            Image(uiImage: project.uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
            LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.2), .black.opacity(0.1)], startPoint: .bottom, endPoint: .top)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 150)
        .clipShape(.rect(cornerRadius: 5))
        .clipped()
        .overlay {
            VStack{
                Button {
                    rootVM.removeProject(project)
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 5)
                }
                .accessibilityLabel("Delete project")
                .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
                Text(project.createAt?.formatted(date: .abbreviated, time: .omitted) ?? "")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.footnote.weight(.medium))
            .padding(10)
        }
    }
    
    
    private func loadPhotosItem(_ newItem: PhotosPickerItem?){
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
                    editorDestination = .init(url: video.url)
                }
            } catch {
                print("Failed to load video: \(error.localizedDescription)")
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(rootVM: RootViewModel(mainContext: DeveloperPreview.instance.viewContext))
    }
}
