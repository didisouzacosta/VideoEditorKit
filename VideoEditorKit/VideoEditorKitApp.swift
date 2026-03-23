//
//  VideoEditorKitApp.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@main
struct VideoEditorKitApp: App {
    
    @StateObject var rootVM = RootViewModel(mainContext: PersistenceController.shared.viewContext)
    
    var body: some Scene {
        WindowGroup {
            RootView(rootVM: rootVM)
        }
    }
    
}
