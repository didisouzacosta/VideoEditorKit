import Foundation

enum CaptionState: Equatable {
    case idle
    case loading
    case failed(message: String)
}
