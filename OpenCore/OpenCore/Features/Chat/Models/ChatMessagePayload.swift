import Foundation

nonisolated protocol ChatMessagePayload {
    var id: UUID { get }
    var role: ChatMessageRole { get }
    var timestamp: Date { get }
}
