import Foundation

enum CaptionPlacementModeSnapshot: Codable, Equatable {
    case freeform
    case preset(CaptionPlacementPresetSnapshot)
}

extension CaptionPlacementModeSnapshot {
    private enum CodingKeys: String, CodingKey {
        case kind
        case preset
    }

    private enum Kind: String, Codable {
        case freeform
        case preset
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .freeform:
            self = .freeform
        case .preset:
            self = .preset(try container.decode(CaptionPlacementPresetSnapshot.self, forKey: .preset))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .freeform:
            try container.encode(Kind.freeform, forKey: .kind)
        case .preset(let preset):
            try container.encode(Kind.preset, forKey: .kind)
            try container.encode(preset, forKey: .preset)
        }
    }
}
