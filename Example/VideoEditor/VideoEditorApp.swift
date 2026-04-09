//
//  VideoEditorApp.swift
//  VideoEditor
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftData
import SwiftUI

@main
struct VideoEditorApp: App {

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: EditedVideoProject.self)
    }

}
