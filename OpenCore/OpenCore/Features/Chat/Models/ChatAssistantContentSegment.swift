import Foundation

enum ChatAssistantContentSegment: Equatable, Hashable, Sendable {
    case markdown(String)
    case blockLatex(String)
    case mermaid(String)
    case plainTail(String)
}
