//
//  VideoShareSheet.swift
//  VideoEditorKit
//
//  Created by Codex on 02.04.2026.
//

import SwiftUI

struct VideoShareSheet: UIViewControllerRepresentable {

    // MARK: - Public Properties

    let activityItems: [Any]
    let applicationActivities: [UIActivity]?

    // MARK: - Initializer

    init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }

    // MARK: - Public Methods

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}

}
