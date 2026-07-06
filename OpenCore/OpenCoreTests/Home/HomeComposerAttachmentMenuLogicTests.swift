import Testing
@testable import OpenCore

@Suite("Home Composer Attachment Menu Logic")
struct HomeComposerAttachmentMenuLogicTests {
    @Test("text-only capabilities hide plus button")
    func hidesPlusForTextOnly() {
        let state = HomeComposerAttachmentMenuLogic.plusButtonState(
            isLoading: false,
            capabilities: ModelInputCapabilities(inputModalities: [.text])
        )
        #expect(state == .hidden)
    }

    @Test("loading dims plus button")
    func loadingState() {
        let state = HomeComposerAttachmentMenuLogic.plusButtonState(
            isLoading: true,
            capabilities: nil
        )
        #expect(state == .loading)
    }

    @Test("filters menu options by modality")
    func filteredOptions() {
        let caps = ModelInputCapabilities(inputModalities: [.text, .file])
        let options = HomeComposerAttachmentMenuLogic.menuOptions(for: caps)
        #expect(options == [.importFile])
    }

    @Test("image and video share photo library option")
    func photoLibraryOption() {
        let caps = ModelInputCapabilities(inputModalities: [.text, .image, .video])
        let options = HomeComposerAttachmentMenuLogic.menuOptions(for: caps)
        #expect(options.contains(.photoLibrary))
        #expect(!options.contains(.importFile))
    }
}
