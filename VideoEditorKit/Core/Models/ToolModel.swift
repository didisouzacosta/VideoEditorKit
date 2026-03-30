//
//  ToolModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation

enum ToolEnum: Int, CaseIterable, Identifiable, Codable, Sendable {

    case cut, speed, crop, audio, text, filters, corrections, frames

    var id: Int {
        rawValue
    }

    static var all: [ToolEnum] {
        allCases.filter { $0 != .cut }
    }

    var title: String {
        switch self {
        case .cut: "Cut"
        case .speed: "Speed"
        case .crop: "Presets"
        case .audio: "Audio"
        case .text: "Text"
        case .filters: "Filters"
        case .corrections: "Corrections"
        case .frames: "Frames"
        }
    }

    var image: String {
        switch self {
        case .cut: "scissors"
        case .speed: "timer"
        case .crop: "aspectratio"
        case .audio: "waveform"
        case .text: "t.square.fill"
        case .filters: "camera.filters"
        case .corrections: "circle.righthalf.filled"
        case .frames: "person.crop.artframe"
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

    init(_ tool: ToolEnum, access: Access = .enabled) {
        self.tool = tool
        self.access = access
    }

    static func enabled(_ tool: ToolEnum) -> Self {
        .init(tool)
    }

    static func blocked(_ tool: ToolEnum) -> Self {
        .init(tool, access: .blocked)
    }

    static func enabled(_ tools: [ToolEnum]) -> [Self] {
        tools.map(Self.enabled)
    }

}
