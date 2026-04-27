//
//  VideoShareSheet.swift
//  VideoEditorKit
//
//  Created by Codex on 02.04.2026.
//

import SwiftUI

enum VideoShareCompletionResult: Equatable {

    // MARK: - Cases

    case completed
    case cancelled
    case failed(String)

}

enum VideoShareSheetCompletionResolver {

    // MARK: - Public Methods

    static func result(
        completed: Bool,
        error: (any Error)?
    ) -> VideoShareCompletionResult {
        if completed {
            return .completed
        }

        guard let error else {
            return .cancelled
        }

        guard isCancellationError(error) == false else {
            return .cancelled
        }

        return .failed(error.localizedDescription)
    }

    // MARK: - Private Methods

    private static func isCancellationError(_ error: any Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain
            && nsError.code == CocoaError.Code.userCancelled.rawValue
    }

}

struct VideoShareSheet: UIViewControllerRepresentable {

    // MARK: - Public Properties

    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    let onCompletion: (VideoShareCompletionResult) -> Void

    // MARK: - Initializer

    init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil,
        onCompletion: @escaping (VideoShareCompletionResult) -> Void = { _ in }
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.onCompletion = onCompletion
    }

    // MARK: - Public Methods

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let viewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        viewController.completionWithItemsHandler = { _, completed, _, error in
            onCompletion(
                VideoShareSheetCompletionResolver.result(
                    completed: completed,
                    error: error
                )
            )
        }
        return viewController
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}

}
