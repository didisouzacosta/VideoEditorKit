//
//  EditorToolSelectionCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 01.04.2026.
//

struct EditorToolSelectionCoordinator {

    // MARK: - Public Methods

    static func enabledTools(
        from availabilities: [ToolAvailability]
    ) -> Set<ToolEnum> {
        Set(availabilities.filter(\.isEnabled).map(\.tool))
    }

    static func resolvedSelection(
        currentSelection: ToolEnum?,
        enabledTools: Set<ToolEnum>
    ) -> ToolEnum? {
        guard let currentSelection else { return nil }
        return enabledTools.contains(currentSelection) ? currentSelection : nil
    }

    static func selectTool(
        _ tool: ToolEnum,
        enabledTools: Set<ToolEnum>
    ) -> ToolEnum? {
        enabledTools.contains(tool) ? tool : nil
    }

    static func closeSelectedTool() -> ToolEnum? {
        nil
    }

}
