import Foundation

public enum ToolEnum: Int, CaseIterable, Identifiable, Codable, Sendable {

    // MARK: - Public Properties

    case cut = 0
    case speed = 1
    case presets = 2
    case audio = 3
    case transcript = 4
    case adjusts = 6

    public var id: Int {
        rawValue
    }

    public static var all: [ToolEnum] {
        allCases
            .filter { $0 != .cut }
            .sorted { $0.order < $1.order }
    }

    public var order: Int {
        switch self {
        case .transcript: 0
        case .presets: 1
        case .audio: 2
        case .adjusts: 3
        case .speed: 4
        case .cut: 5
        }
    }

    public var title: String {
        switch self {
        case .cut: VideoEditorStrings.toolCut
        case .speed: VideoEditorStrings.toolSpeed
        case .presets: VideoEditorStrings.toolPresets
        case .audio: VideoEditorStrings.toolAudio
        case .transcript: VideoEditorStrings.toolTranscript
        case .adjusts: VideoEditorStrings.toolAdjusts
        }
    }

    public var image: String {
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

public struct ToolAvailability: Hashable, Identifiable {

    // MARK: - Public Properties

    public enum Access: Hashable {
        case enabled
        case blocked
    }

    public let tool: ToolEnum
    public let access: Access
    public let order: Int

    public var id: ToolEnum {
        tool
    }

    public var isBlocked: Bool {
        access == .blocked
    }

    public var isEnabled: Bool {
        access == .enabled
    }

    // MARK: - Initializer

    public init(
        _ tool: ToolEnum,
        access: Access = .enabled,
        order: Int? = nil
    ) {
        self.tool = tool
        self.access = access
        self.order = order ?? tool.order
    }

    public static func enabled(
        _ tool: ToolEnum,
        order: Int? = nil
    ) -> Self {
        .init(tool, order: order)
    }

    public static func blocked(
        _ tool: ToolEnum,
        order: Int? = nil
    ) -> Self {
        .init(tool, access: .blocked, order: order)
    }

    public static func enabled(_ tools: [ToolEnum]) -> [Self] {
        tools.map { Self.enabled($0) }
    }

}
