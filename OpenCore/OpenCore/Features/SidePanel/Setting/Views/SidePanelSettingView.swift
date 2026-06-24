import SwiftUI

/// Settings sheet for secure provider credential entry.
///
/// Provider selection is a menu picker over the built-in `SidePanelProviderAPI` catalog.
/// Users choose from app-shipped providers only; custom endpoints are out of scope.
///
/// A single secure field accepts the API key; saving persists it to the Keychain
/// via the flow controller. The field is never pre-filled with the stored secret — the
/// secret is write-only from the UI's perspective — and shows only whether a key
/// is currently stored.
struct SidePanelSettingView: View {
    @Bindable var flow: SidePanelSettingFlowController

    @Environment(\.sharedPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isKeyFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                palette.surfaceBase.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        providerPicker
                        header
                        keyField
                        if let errorMessage = flow.state.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.accentPrimary)
                                .accessibilityIdentifier("settings-error")
                        }
                        actions
                        if flow.state.modelSupportsReasoning {
                            reasoningControl
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(palette.textPrimary)
                }
            }
            .onAppear { flow.onAppear() }
        }
    }

    private var providerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Provider")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            Text("Choose which AI provider to use. Each provider has its own API key and model catalog.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Picker(
                    "Provider",
                    selection: Binding(
                        get: { flow.state.selectedProviderID },
                        set: { flow.selectProvider($0) }
                    )
                ) {
                    ForEach(SidePanelProviderAPI.all, id: \.id) { provider in
                        Text(provider.displayName).tag(provider.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(palette.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surfaceRaised.opacity(palette.isDark ? 0.5 : 0.85))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.lineSoft.opacity(palette.isDark ? 0.45 : 0.6), lineWidth: 1)
            }
            .accessibilityIdentifier("settings-provider-picker")
        }
    }

    private var selectedProvider: SidePanelProviderAPI {
        SidePanelProviderAPI.resolve(id: flow.state.selectedProviderID)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedProvider.credentialLabel)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            Text(flow.state.hasStoredKey
                 ? "A \(selectedProvider.credentialLabel) is stored in the Keychain. Enter a new value to replace it."
                 : selectedProvider.credentialPrompt)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: flow.state.hasStoredKey ? "key.fill" : "key")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)

                SecureField(
                    selectedProvider.credentialPlaceholder,
                    text: Binding(
                        get: { flow.state.draftAPIKey },
                        set: { flow.dispatch(SidePanelSettingDraftChangedCommand($0)) }
                    )
                )
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(palette.textPrimary)
                .focused($isKeyFieldFocused)
                .submitLabel(.done)
                .onSubmit { flow.save() }
                .accessibilityIdentifier("settings-api-key-field")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surfaceRaised.opacity(palette.isDark ? 0.5 : 0.85))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.lineSoft.opacity(palette.isDark ? 0.45 : 0.6), lineWidth: 1)
            }

            if flow.state.hasStoredKey {
                Label("Key stored", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .accessibilityIdentifier("settings-key-stored")
            }
        }
    }

    private var reasoningControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reasoning")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            Text("Choose how much effort the model spends reasoning before it answers. Off sends no reasoning request.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(
                "Reasoning level",
                selection: Binding(
                    get: { flow.state.reasoningModel },
                    set: { flow.selectReasoningModel($0) }
                )
            ) {
                ForEach(SidePanelReasoningModel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings-reasoning-picker")
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                isKeyFieldFocused = false
                flow.save()
            } label: {
                Text(flow.state.hasStoredKey ? "Update key" : "Save key")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(flow.state.canSave ? palette.controlStrongText : palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(flow.state.canSave ? palette.controlStrong : palette.surfaceSubtle.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!flow.state.canSave)
            .accessibilityIdentifier("settings-save-button")

            if flow.state.hasStoredKey {
                Button(role: .destructive) {
                    isKeyFieldFocused = false
                    flow.clear()
                } label: {
                    Text("Remove stored key")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-clear-button")
            }
        }
    }
}

#Preview {
    SidePanelSettingView(
        flow: SidePanelSettingFlowController(
            credentialStore: SidePanelInMemoryCredentialStore(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        )
    )
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
