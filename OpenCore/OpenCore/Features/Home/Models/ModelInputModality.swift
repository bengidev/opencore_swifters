import Foundation

nonisolated enum ModelInputModality: String, Equatable, Sendable, CaseIterable {
    case text
    case file
    case image
    case video
    case audio

    init?(wireValue: String) {
        self.init(rawValue: wireValue.lowercased())
    }
}
