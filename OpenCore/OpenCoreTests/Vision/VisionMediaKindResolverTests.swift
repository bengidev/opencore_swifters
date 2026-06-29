import Foundation
import Testing

@testable import OpenCore

@Suite("Vision Media Kind Resolver")
struct VisionMediaKindResolverTests {
    @Test("classifies common plain-text extensions")
    func plainTextExtensions() {
        #expect(VisionMediaKindResolver.resolve(pathExtension: "txt") == .plainText)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "md") == .plainText)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "json") == .plainText)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "swift") == .plainText)
    }

    @Test("classifies image extensions")
    func imageExtensions() {
        #expect(VisionMediaKindResolver.resolve(pathExtension: "jpg") == .image)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "jpeg") == .image)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "png") == .image)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "heic") == .image)
    }

    @Test("classifies video extensions")
    func videoExtensions() {
        #expect(VisionMediaKindResolver.resolve(pathExtension: "mp4") == .video)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "mov") == .video)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "m4v") == .video)
    }

    @Test("marks unknown extensions as unsupported")
    func unsupportedExtensions() {
        #expect(VisionMediaKindResolver.resolve(pathExtension: "zip") == .unsupported)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "") == .unsupported)
    }

    @Test("is case insensitive for path extensions")
    func caseInsensitiveExtensions() {
        #expect(VisionMediaKindResolver.resolve(pathExtension: "TXT") == .plainText)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "PNG") == .image)
        #expect(VisionMediaKindResolver.resolve(pathExtension: "MOV") == .video)
    }
}
