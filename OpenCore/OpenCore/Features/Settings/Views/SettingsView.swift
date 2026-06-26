import SwiftUI

/// Settings tab — grouped provider, credentials, and context window sections.
struct SettingsView: View {
    @Bindable var flow: SettingsFlowController

    @FocusState private var isKeyFieldFocused: Bool

    var body: some View {
        Form {
            providerSection
            credentialsSection
            SettingsContextWindowSection(flow: flow)

            if let errorMessage = flow.state.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("settings-error")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { flow.onAppear() }
        .accessibilityIdentifier("settings-view")
    }

    private var providerSection: some View {
        Section {
            Picker(
                selection: Binding(
                    get: { flow.state.selectedProviderID },
                    set: { flow.selectProvider($0) }
                )
            ) {
                ForEach(ProviderRegistry.allDescriptors, id: \.id) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            } label: {
                Label("Active Provider", systemImage: "network")
            }
            .accessibilityIdentifier("settings-provider-picker")
        } header: {
            SettingsFormChrome.sectionHeader("Connection")
        } footer: {
            SettingsFormChrome.sectionFooter(
                "Models and credentials are scoped per provider."
            )
        }
    }

    private var selectedProvider: ProviderDescriptor {
        ProviderRegistry.resolve(id: flow.state.selectedProviderID).descriptor
    }

    private var credentialsSection: some View {
        Section {
            HStack(spacing: 8) {
                SecureField(
                    selectedProvider.credentialPlaceholder,
                    text: Binding(
                        get: { flow.state.draftAPIKey },
                        set: { flow.dispatch(SettingsDraftChangedCommand($0)) }
                    )
                )
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isKeyFieldFocused)
                .submitLabel(.done)
                .onSubmit { flow.save() }
                .accessibilityIdentifier("settings-api-key-field")

                if flow.state.hasStoredKey {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Key stored")
                        .accessibilityIdentifier("settings-key-stored")
                }
            }

            Button {
                isKeyFieldFocused = false
                flow.save()
            } label: {
                Text(flow.state.hasStoredKey ? "Update Key" : "Save Key")
            }
            .disabled(!flow.state.canSave)
            .accessibilityIdentifier("settings-save-button")

            if flow.state.hasStoredKey {
                Button("Remove Stored Key", role: .destructive) {
                    isKeyFieldFocused = false
                    flow.clear()
                }
                .accessibilityIdentifier("settings-clear-button")
            }
        } header: {
            SettingsFormChrome.sectionHeader("API Key")
        } footer: {
            SettingsFormChrome.sectionFooter(credentialFooterText)
        }
    }

    private var credentialFooterText: String {
        if flow.state.hasStoredKey {
            return "\(selectedProvider.displayName) key is saved in the Keychain. Enter a new value to replace it."
        }
        return selectedProvider.credentialPrompt
    }
}

#Preview {
    NavigationStack {
        SettingsView(
            flow: SettingsFlowController(
                credentialStore: CredentialInMemoryStore(),
                providerPreference: SidePanelInMemoryProviderPreferenceStore()
            )
        )
    }
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
