import PhotosUI
import SwiftUI

/// Prompt panel with context rail, speed/model chips, and send action.
struct HomeComposerView: View {
    @Bindable var home: HomeFlowController
    @Bindable var chat: ChatFlowController
    @Bindable var speech: SpeechFlowController
    @Bindable var vision: VisionFlowController
    let isComposerFocused: FocusState<Bool>.Binding

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            HomeComposerPromptPanel(
                home: home,
                chat: chat,
                speech: speech,
                vision: vision,
                isComposerFocused: isComposerFocused
            )
            HomeComposerContextRail(
                home: home,
                dismissKeyboard: dismissKeyboard
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(palette.surfaceBase)
    }

    private func dismissKeyboard() {
        isComposerFocused.wrappedValue = false
    }
}

#Preview {
    struct PreviewHost: View {
        @FocusState private var isComposerFocused: Bool

        var body: some View {
            ZStack {
                SharedOpenCorePalette.resolve(.light).surfaceBase.ignoresSafeArea()
                HomeComposerView(
                    home: HomeFlowController(
                        credentialStore: CredentialInMemoryStore(),
                        providerPreference: SidePanelInMemoryProviderPreferenceStore()
                    ),
                    chat: ChatFlowController(),
                    speech: SpeechFlowController(),
                    vision: VisionFlowController(),
                    isComposerFocused: $isComposerFocused
                )
            }
            .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
        }
    }

    return PreviewHost()
}
