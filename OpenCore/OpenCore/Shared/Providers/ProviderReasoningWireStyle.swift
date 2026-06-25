import Foundation

/// How a provider encodes reasoning effort on chat completion requests.
nonisolated enum ProviderReasoningWireStyle: Equatable, Sendable {
    /// `{ "reasoning": { "effort": "high" } }` (OpenRouter).
    case reasoningObject
    /// Top-level `reasoning_effort` (OpenAI-compatible default).
    case topLevelEffort
}
