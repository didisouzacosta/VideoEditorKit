//
//  VideoEditorKitApp.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftData
import SwiftUI

@main
struct VideoEditorKitApp: App {

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: EditedVideoProject.self)
    }

}
