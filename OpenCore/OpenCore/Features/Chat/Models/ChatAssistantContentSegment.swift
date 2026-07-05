import Foundation

enum ChatAssistantContentSegment: Equatable, Sendable {
    case markdown(String)
    case blockLatex(String)
    case mermaid(String)
    case inlineLatexProse(String)
    case plainTail(String)
}
