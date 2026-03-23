import Foundation

struct ValidationResult: Equatable {
    let canExport: Bool
    let warnings: [String]
    let errors: [String]

    nonisolated init(
        warnings: [String] = [],
        errors: [String] = []
    ) {
        self.warnings = warnings
        self.errors = errors
        canExport = errors.isEmpty
    }
}
