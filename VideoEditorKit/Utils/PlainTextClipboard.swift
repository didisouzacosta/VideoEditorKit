//
//  PlainTextClipboard.swift
//  VideoEditorKit
//
//  Created by Codex on 07.04.2026.
//

import UIKit

@MainActor
enum PlainTextClipboard {

    // MARK: - Public Methods

    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }

}
