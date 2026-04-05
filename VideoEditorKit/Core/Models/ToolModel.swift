//
//  ToolModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation

enum ToolEnum: Int, CaseIterable, Identifiable, Codable, Sendable {

    // MARK: - Public Properties

    case cut = 0
    case speed = 1
    case presets = 2
    case audio = 3
    case transcript = 4
    case adjusts = 6

    var id: Int {
        rawValue
    }

    static var all: [ToolEnum] {
        allCases
            .filter { $0 != .cut }
            .sorted { $0.order < $1.order }
    }

    var order: Int {
        switch self {
        case .presets: 0
        case .audio: 1
        case .transcript: 2
        case .adjusts: 3
        case .speed: 4
        case .cut: 5
        }
    }

    var title: String {
        switch self {
        case .cut: "Cut"
        case .speed: "Speed"
        case .presets: "Presets"
        case .audio: "Audio"
        case .transcript: "Transcript"
        case .adjusts: "Adjusts"
        }
    }

    var image: String {
        switch self {
        case .cut: "scissors"
        case .speed: "timer"
        case .presets: "aspectratio"
        case .audio: "waveform"
        case .transcript: "captions.bubble"
        case .adjusts: "circle.righthalf.filled"
        }
    }

}

struct ToolAvailability: Hashable, Identifiable {

    // MARK: - Public Properties

    enum Access: Hashable {
        case enabled
        case blocked
    }

    let tool: ToolEnum
    let access: Access
    let order: Int

    var id: ToolEnum {
        tool
    }

    var isBlocked: Bool {
        access == .blocked
    }

    var isEnabled: Bool {
        access == .enabled
    }

    // MARK: - Initializer

    init(
        _ tool: ToolEnum,
        access: Access = .enabled,
        order: Int? = nil
    ) {
        self.tool = tool
        self.access = access
        self.order = order ?? tool.order
    }

    static func enabled(
        _ tool: ToolEnum,
        order: Int? = nil
    ) -> Self {
        .init(tool, order: order)
    }

    static func blocked(
        _ tool: ToolEnum,
        order: Int? = nil
    ) -> Self {
        .init(tool, access: .blocked, order: order)
    }

    static func enabled(_ tools: [ToolEnum]) -> [Self] {
        tools.map { Self.enabled($0) }
    }

}
