import Foundation

/// Builds OpenRouter-compatible base64 video data URLs from local files.
nonisolated enum ChatMultimodalVideoPayloadLogic: Sendable {
    static func dataURL(fromFileAt localPath: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: localPath)),
              !data.isEmpty else {
            return nil
        }

        let filename = (localPath as NSString).lastPathComponent
        let mimeType = mimeType(forFilename: filename)
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    static func mimeType(forFilename filename: String) -> String {
        switch (filename as NSString).pathExtension.lowercased() {
        case "mov":
            return "video/quicktime"
        case "mpeg", "mpg":
            return "video/mpeg"
        case "webm":
            return "video/webm"
        default:
            return "video/mp4"
        }
    }
}
