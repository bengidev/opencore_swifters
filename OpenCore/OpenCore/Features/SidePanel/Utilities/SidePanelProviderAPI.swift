import Foundation

/// A thin, Sendable value descriptor for an OpenAI-compatible chat provider.
///
/// This is pure data with no behavior: it carries everything the generic
/// streaming client needs to address a backend (endpoint, auth scheme, and any
/// default headers the provider recommends). One concrete client is
/// parameterized by this descriptor, so adding another OpenAI-compatible
/// backend is a value, not a new client.
nonisolated struct SidePanelProviderAPI: Equatable, Sendable {
    /// How the credential is presented on the wire.
    enum AuthScheme: Equatable, Sendable {
        /// `Authorization: Bearer <token>`.
        case bearer
    }

    /// Stable provider identifier (e.g. `"openrouter"`).
    let id: String
    /// Human-facing name (e.g. `"OpenRouter"`).
    let displayName: String
    /// Base URL of the OpenAI-compatible API root (no trailing `/chat/completions`).
    let baseURL: URL
    /// How the secret is attached to each request.
    let authScheme: AuthScheme
    /// Provider-recommended default headers attached to every request
    /// (e.g. OpenRouter attribution headers). Never carries the secret.
    let defaultHeaders: [String: String]
    /// Placeholder shown in the credential field (e.g. `sk-or-v1-...`).
    let credentialPlaceholder: String
    /// Section label for the credential field.
    let credentialLabel: String
    /// Helper copy when no credential is stored yet.
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

    /// The chat-completions endpoint derived from the base URL.
    var chatCompletionsURL: URL {
        baseURL.appendingPathComponent("chat/completions")
    }

    /// The models-catalog endpoint derived from the base URL. OpenAI-compatible
    /// backends expose the catalog at `GET {base}/models`.
    var modelsURL: URL {
        baseURL.appendingPathComponent("models")
    }
}

extension SidePanelProviderAPI {
    /// OpenRouter, configured with bearer auth and recommended attribution
    /// headers. The attribution headers identify the app to OpenRouter and are
    /// safe to commit (they carry no secret).
    nonisolated static let openRouter = SidePanelProviderAPI(
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

    /// OpenCode, configured with bearer auth and recommended attribution
    /// headers. The attribution headers identify the app to OpenCode and are
    /// safe to commit (they carry no secret).
    nonisolated static let openCode = SidePanelProviderAPI(
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

    /// Command Code Provider API — OpenAI-compatible chat completions and models
    /// catalog. Auth is bearer-only per the provider docs; no attribution headers
    /// are required. See https://commandcode.ai/docs/provider-api
    nonisolated static let commandCode = SidePanelProviderAPI(
        id: "commandcode",
        displayName: "Command Code",
        baseURL: URL(string: "https://api.commandcode.ai/provider/v1")!,
        authScheme: .bearer,
        credentialPlaceholder: "<CMD_API_KEY>",
        credentialLabel: "COMMAND_CODE_API_KEY",
        credentialPrompt: "Generate a key in Command Code Studio (commandcode.ai/docs/studio/api-keys). Same key as COMMAND_CODE_API_KEY — sent as Authorization: Bearer <CMD_API_KEY> per the Provider API docs. Stored securely in the Keychain on this device."
    )

    /// Ollama Cloud — OpenAI-compatible chat at ollama.com/v1. See
    /// https://docs.ollama.com/cloud
    nonisolated static let ollamaCloud = SidePanelProviderAPI(
        id: "ollama",
        displayName: "Ollama Cloud",
        baseURL: URL(string: "https://ollama.com/v1")!,
        authScheme: .bearer,
        credentialPlaceholder: "ollama-...",
        credentialLabel: "OLLAMA_API_KEY",
        credentialPrompt: "Create an API key at ollama.com and paste it here. Sent as Authorization: Bearer $OLLAMA_API_KEY per docs.ollama.com/api/authentication. Stored securely in the Keychain on this device."
    )

    /// Every provider the app knows how to address. Adding an OpenAI-compatible
    /// backend is a value appended here, not a new client.
    nonisolated static let all: [SidePanelProviderAPI] = [
        .openRouter, .openCode, .commandCode, .ollamaCloud
    ]

    /// The provider used when no preference has been stored yet.
    nonisolated static let `default`: SidePanelProviderAPI = .openRouter

    /// Resolves a stored provider id to its descriptor, falling back to the
    /// default when the id is unknown or absent (e.g. a stale persisted id from
    /// a removed provider).
    nonisolated static func resolve(id: String?) -> SidePanelProviderAPI {
        guard let id else { return .default }
        return all.first { $0.id == id } ?? .default
    }
}
