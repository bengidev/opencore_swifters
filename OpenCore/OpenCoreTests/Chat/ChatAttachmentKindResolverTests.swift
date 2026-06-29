import Foundation
import Testing
import UniformTypeIdentifiers

@testable import OpenCore

@Suite("Chat Attachment Kind Resolver")
struct ChatAttachmentKindResolverTests {
    @Test("classifies plain text extensions")
    func classifiesPlainText() {
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "txt") == .plainText)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "md") == .plainText)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "json") == .plainText)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "swift") == .plainText)
    }

    @Test("classifies image extensions")
    func classifiesImages() {
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "jpg") == .image)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "jpeg") == .image)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "png") == .image)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "heic") == .image)
    }

    @Test("classifies video extensions")
    func classifiesVideos() {
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "mp4") == .video)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "mov") == .video)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "m4v") == .video)
    }

    @Test("marks unknown extensions as unsupported")
    func classifiesUnsupported() {
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "zip") == .unsupported)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "") == .unsupported)
    }

    @Test("is case insensitive")
    func isCaseInsensitive() {
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "TXT") == .plainText)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "PNG") == .image)
        #expect(ChatAttachmentKindResolver.resolve(pathExtension: "MOV") == .video)
    }

    @Test("maps categories to attachment kinds")
    func mapsAttachmentKinds() {
        #expect(
            ChatAttachmentKindResolver.attachmentKind(filename: "note.txt", contentType: nil) == .file
        )
        #expect(
            ChatAttachmentKindResolver.attachmentKind(filename: "photo.png", contentType: .png) == .image
        )
    }
}
