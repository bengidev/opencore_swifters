import Foundation

/// Pure metadata for an OpenAI-compatible chat provider. Carries endpoint,
/// auth, and credential UI copy — no request-encoding behavior.
nonisolated struct ProviderDescriptor: Equatable, Sendable {
    enum AuthScheme: Equatable, Sendable {
        case bearer
    }

    let id: String
    let displayName: String
    let baseURL: URL
    let authScheme: AuthScheme
    let defaultHeaders: [String: String]
    let credentialPlaceholder: String
    let credentialLabel: String
    let credentialPrompt: String

    init(
        id: String,
        displayName: String,
        baseURL: URL,
        authScheme: AuthScheme,
        defaultHeaders: [String: String] = [:],
        credentialPlaceholder: String,
        credentialLabel: String,
        credentialPrompt: String
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.authScheme = authScheme
        self.defaultHeaders = defaultHeaders
        self.credentialPlaceholder = credentialPlaceholder
        self.credentialLabel = credentialLabel
        self.credentialPrompt = credentialPrompt
    }

    var chatCompletionsURL: URL {
        baseURL.appendingPathComponent("chat/completions")
    }

    var modelsURL: URL {
        baseURL.appendingPathComponent("models")
    }

    func modelDetailURL(author: String, slug: String) -> URL {
        baseURL
            .appendingPathComponent("model")
            .appendingPathComponent(author)
            .appendingPathComponent(slug)
    }
}

extension ProviderDescriptor {
    nonisolated static let openRouter = ProviderDescriptor(
        id: "openrouter",
        displayName: "OpenRouter",
        baseURL: URL(string: "https://openrouter.ai/api/v1")!,
        authScheme: .bearer,
        defaultHeaders: [
            "HTTP-Referer": "https://github.com/bengidev/opencore_swifters",
            "X-Title": "OpenCore"
        ],
        credentialPlaceholder: "sk-or-v1-...",
        credentialLabel: "OPENROUTER_API_KEY",
        credentialPrompt: "Create a key at openrouter.ai/keys and paste it here. Requests send Authorization: Bearer <OPENROUTER_API_KEY> per the OpenRouter quickstart. Stored securely in the Keychain on this device."
    )

    nonisolated static let openCode = ProviderDescriptor(
        id: "opencode",
        displayName: "OpenCode",
        baseURL: URL(string: "https://opencode.ai/zen/v1")!,
        authScheme: .bearer,
        defaultHeaders: [
            "HTTP-Referer": "https://github.com/bengidev/opencore_swifters",
            "X-Title": "OpenCore"
        ],
        credentialPlaceholder: "API key from opencode.ai/auth",
        credentialLabel: "OpenCode Zen API key",
        credentialPrompt: "Sign in at opencode.ai/auth, add billing, and click Create API Key for OpenCode Zen (opencode.ai/docs/zen). Sent as Authorization: Bearer …. Stored securely in the Keychain on this device."
    )

    nonisolated static let commandCode = ProviderDescriptor(
        id: "commandcode",
        displayName: "Command Code",
        baseURL: URL(string: "https://api.commandcode.ai/provider/v1")!,
        authScheme: .bearer,
        credentialPlaceholder: "<CMD_API_KEY>",
        credentialLabel: "COMMAND_CODE_API_KEY",
        credentialPrompt: "Generate a key in Command Code Studio (commandcode.ai/docs/studio/api-keys). Same key as COMMAND_CODE_API_KEY — sent as Authorization: Bearer <CMD_API_KEY> per the Provider API docs. Stored securely in the Keychain on this device."
    )

    nonisolated static let ollamaCloud = ProviderDescriptor(
        id: "ollama",
        displayName: "Ollama Cloud",
        baseURL: URL(string: "https://ollama.com/v1")!,
        authScheme: .bearer,
        credentialPlaceholder: "ollama-...",
        credentialLabel: "OLLAMA_API_KEY",
        credentialPrompt: "Create an API key at ollama.com and paste it here. Sent as Authorization: Bearer $OLLAMA_API_KEY per docs.ollama.com/api/authentication. Stored securely in the Keychain on this device."
    )
}
