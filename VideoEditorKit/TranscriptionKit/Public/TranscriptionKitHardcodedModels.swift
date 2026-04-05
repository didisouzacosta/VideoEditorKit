//
//  TranscriptionKitHardcodedModels.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

public enum TranscriptionKitHardcodedModels {

    // MARK: - Public Properties

    /// Edit this file when wiring concrete remote Whisper model URLs.
    /// The goal is to keep model-location hardcodes easy to find and replace later.
    public static let availableModels: [RemoteModelDescriptor] = []

    public static var preferredModel: RemoteModelDescriptor? {
        availableModels.first
    }

}
