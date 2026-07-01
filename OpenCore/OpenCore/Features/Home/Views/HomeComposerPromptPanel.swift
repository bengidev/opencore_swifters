import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct HomeComposerPromptPanel: View {
    @Bindable var home: HomeFlowController
    @Bindable var chat: ChatFlowController
    @Bindable var speech: SpeechFlowController
    @Bindable var vision: VisionFlowController
    let isComposerFocused: FocusState<Bool>.Binding

    @Environment(\.sharedPalette) private var palette
    @State private var sendFeedbackTrigger = false
    @State private var isAttachmentMenuPresented = false
    @State private var isFileImporterPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var importTask: Task<Void, Never>?
    @State private var isVisualCapabilityWarningPresented = false
    @State private var visualCapabilityWarningMessage = ""

    private var selectedModel: ChatModel? {
        home.state.selectedModelOption?.model
    }

    private var selectedModelName: String {
        home.state.selectedModelOption?.title ?? "This model"
    }

    private var composerText: String {
        chat.state.draftMessage
    }

    private var isSpeechComposerActive: Bool {
        speech.state.isListening || speech.state.isTranscribing
    }

    private var canSend: Bool {
        let hasVisibleText = !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachments = !chat.state.draftAttachments.isEmpty
        return (hasVisibleText || hasAttachments)
            && !chat.state.isSending
            && !speech.state.isListening
            && !speech.state.isTranscribing
            && !vision.state.isProcessing
            && home.state.hasAPIKey
            && home.state.hasSelectedModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !home.state.hasAPIKey {
                MissingAPIKeyHint { home.openSettingsTab() }
            }

            if let errorMessage = speech.state.errorMessage {
                HomeComposerInputErrorHint(systemImage: "mic.slash", message: errorMessage) {
                    speech.clearError()
                }
            }

            if let errorMessage = vision.state.errorMessage {
                HomeComposerInputErrorHint(systemImage: "doc.text.magnifyingglass", message: errorMessage) {
                    vision.clearError()
                }
            }

            if !chat.state.draftAttachments.isEmpty, !isSpeechComposerActive {
                ChatComposerAttachmentsStripView(
                    attachments: chat.state.draftAttachments,
                    onRemove: { chat.removeDraftAttachment(id: $0) }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if vision.state.isProcessing, let statusMessage = vision.state.statusMessage {
                VisionProcessingIndicatorView(statusMessage: statusMessage) {
                    cancelMediaImport()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isSpeechComposerActive {
                SpeechRecordingComposerView(
                    elapsedDuration: speech.state.isTranscribing
                        ? speech.state.transcribingDuration
                        : speech.state.elapsedDuration,
                    audioLevels: speech.state.isTranscribing
                        ? speech.state.transcribingWaveformSamples
                        : speech.state.audioLevels,
                    isVoiceActive: speech.state.isVoiceActive,
                    isTranscribing: speech.state.isTranscribing,
                    onCancel: cancelVoiceInput
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                TextField(
                    "Ask anything... @files, $skills, /commands",
                    text: Binding(
                        get: { composerText },
                        set: { chat.setDraftMessage($0) }
                    ),
                    axis: .vertical
                )
                .frame(minHeight: 50)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(palette.textPrimary)
                .tint(palette.accentPrimary)
                .lineLimit(1...5)
                .textInputAutocapitalization(.sentences)
                .disabled(vision.state.isProcessing)
                .focused(isComposerFocused)
                .contentShape(Rectangle())
                .onTapGesture(perform: focusComposerIfAllowed)
            }

            HStack(spacing: 6) {
                HomeComposerIconButton(
                    systemImage: "plus",
                    accessibilityLabel: "Add attachment",
                    action: presentAttachmentMenu
                )

                Spacer(minLength: 4)

                if speech.state.isListening || speech.state.isTranscribing {
                    HomeComposerStopRecordingButton(action: stopVoiceInput)
                } else {
                    HomeComposerIconButton(
                        systemImage: "mic",
                        accessibilityLabel: "Start voice input",
                        action: startVoiceInput
                    )
                }

                HomeComposerSendButton(canSend: canSend, action: send)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .homeComposerGlass(cornerRadius: 28, shadowOpacity: 0.16)
        .sensoryFeedback(.success, trigger: sendFeedbackTrigger)
        .animation(.easeInOut(duration: 0.18), value: isSpeechComposerActive)
        .animation(.easeInOut(duration: 0.18), value: chat.state.draftAttachments.count)
        .animation(.easeInOut(duration: 0.18), value: vision.state.isProcessing)
        .confirmationDialog(
            "Add to message",
            isPresented: $isAttachmentMenuPresented,
            titleVisibility: .visible
        ) {
            Button("Import File") {
                isFileImporterPresented = true
            }
            Button("Photo Library") {
                isPhotoPickerPresented = true
            }
        } message: {
            Text("Attach a file or photo to include with your message.")
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.plainText, .text, .image, .movie, .video, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $photoPickerItem,
            matching: .any(of: [.images, .videos]),
            photoLibrary: .shared()
        )
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            handlePhotoPickerItem(newItem)
        }
        .alert(
            "Attachment not supported",
            isPresented: $isVisualCapabilityWarningPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(visualCapabilityWarningMessage)
        }
        .onAppear {
            speech.voiceCaptureHandler = { capture in
                applyVoiceCapture(capture)
            }
        }
    }

    private func send() {
        guard canSend else { return }
        switch HomeComposerModelCapabilityLogic.validateDraft(
            attachments: chat.state.draftAttachments,
            model: selectedModel,
            modelName: selectedModelName
        ) {
        case .allowed:
            performSend()
        case let .blocked(message):
            presentCapabilityWarning(message)
        }
    }

    private func performSend() {
        guard canSend else { return }
        dismissKeyboard()
        sendFeedbackTrigger.toggle()
        vision.dismissProcessingPresentation()
        Task {
            await chat.sendMessage(
                providerSortBy: home.state.activeProviderSortBy,
                reasoningEffort: home.state.activeReasoningEffort
            )
        }
    }

    private func startVoiceInput() {
        dismissKeyboard()
        switch HomeComposerModelCapabilityLogic.validateDraft(
            attachments: chat.state.draftAttachments,
            model: selectedModel,
            modelName: selectedModelName
        ) {
        case .allowed:
            Task { await speech.startListening() }
        case let .blocked(message):
            presentCapabilityWarning(message)
        }
    }

    private func stopVoiceInput() {
        dismissKeyboard()
        Task {
            if let capture = await speech.stopListening() {
                applyVoiceCapture(capture)
            }
        }
    }

    private func applyVoiceCapture(_ capture: SpeechCaptureResult) {
        let transcript = capture.composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }

        let existing = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if existing.isEmpty {
            chat.setDraftMessage(transcript)
        } else {
            chat.setDraftMessage("\(existing) \(transcript)")
        }
        isComposerFocused.wrappedValue = true
    }

    private func cancelVoiceInput() {
        dismissKeyboard()
        Task { await speech.cancelListening() }
    }

    private func presentAttachmentMenu() {
        dismissKeyboard()
        isAttachmentMenuPresented = true
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        importTask?.cancel()
        importTask = Task {
            if let attachment = await vision.attachFile(at: url) {
                guard !Task.isCancelled else { return }
                addImportedAttachment(attachment)
            }
        }
    }

    private func handlePhotoPickerItem(_ item: PhotosPickerItem) {
        photoPickerItem = nil
        importTask?.cancel()
        importTask = Task {
            defer { photoPickerItem = nil }
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let filename = photoFilename(for: item)
            if let attachment = await vision.attachImportedData(
                data,
                filename: filename,
                contentType: item.supportedContentTypes.first
            ) {
                guard !Task.isCancelled else { return }
                addImportedAttachment(attachment)
            }
        }
    }

    private func addImportedAttachment(_ attachment: ChatMessageAttachment) {
        switch HomeComposerModelCapabilityLogic.validateNewAttachment(
            attachment,
            model: selectedModel,
            modelName: selectedModelName
        ) {
        case .allowed:
            chat.addDraftAttachment(attachment)
        case let .blocked(message):
            ChatAttachmentStore.remove(at: attachment.localPath)
            presentCapabilityWarning(message)
        }
    }

    private func presentCapabilityWarning(_ message: String) {
        visualCapabilityWarningMessage = message
        isVisualCapabilityWarningPresented = true
    }

    private func photoFilename(for item: PhotosPickerItem) -> String {
        if let contentType = item.supportedContentTypes.first,
           let ext = contentType.preferredFilenameExtension {
            return "photo.\(ext)"
        }
        return item.itemIdentifier ?? "photo"
    }

    private func cancelMediaImport() {
        importTask?.cancel()
        importTask = nil
        vision.dismissProcessingPresentation()
    }

    private func dismissKeyboard() {
        isComposerFocused.wrappedValue = false
    }

    private func focusComposerIfAllowed() {
        guard !isSpeechComposerActive, !vision.state.isProcessing else { return }
        isComposerFocused.wrappedValue = true
    }
}

struct HomeComposerInputErrorHint: View {
    let systemImage: String
    let message: String
    let dismiss: () -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        Button(action: dismiss) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)

                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.5 : 0.8))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(message)
    }
}
