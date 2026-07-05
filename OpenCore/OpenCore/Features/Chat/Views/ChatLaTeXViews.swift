import LaTeXSwiftUI
import MarkdownUI
import SwiftUI
import UIKit

struct ChatAssistantMarkdownLaTeXImageProvider: ImageProvider {
    let uiFont: UIFont
    let textColor: Color

    @ViewBuilder
    func makeImage(url: URL?) -> some View {
        if let url,
           let decoded = ChatAssistantLaTeXPreprocessor.decodeLatex(from: url),
           !decoded.isBlock {
            ChatInlineLaTeXView(latex: "$\(decoded.latex)$", uiFont: uiFont, textColor: textColor)
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }
}

struct ChatAssistantMarkdownLaTeXInlineImageProvider: InlineImageProvider {
    let uiFont: UIFont

    func image(with url: URL, label: String) async throws -> Image {
        guard let decoded = ChatAssistantLaTeXPreprocessor.decodeLatex(from: url),
              !decoded.isBlock else {
            return Image(systemName: "function")
        }

        let uiImage = await ChatLaTeXSnapshot.image(
            for: "$\(decoded.latex)$",
            uiFont: uiFont,
            isBlock: false
        )
        if let uiImage {
            return Image(uiImage: uiImage).renderingMode(.original)
        }
        return Image(systemName: "function")
    }
}

enum ChatLaTeXSnapshot {
    @MainActor
    static func image(for latex: String, uiFont: UIFont, isBlock: Bool) -> UIImage? {
        let content = LaTeX(latex)
            .font(uiFont)
            .parsingMode(.onlyEquations)
            .blockMode(isBlock ? .blockViews : .alwaysInline)
            .processEscapes(true)
            .imageRenderingMode(.original)
            .renderingStyle(.wait)
            .fixedSize()

        let renderer = ImageRenderer(content: content)
        renderer.scale = UITraitCollection.current.displayScale
        return renderer.uiImage
    }
}

struct ChatBlockLaTeXView: View {
    let latex: String
    let uiFont: UIFont
    let textColor: Color

    var body: some View {
        LaTeX("\\[\(latex)\\]")
            .font(uiFont)
            .parsingMode(.onlyEquations)
            .blockMode(.blockViews)
            .processEscapes(true)
            .imageRenderingMode(.original)
            .renderingStyle(.wait)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
            .padding(.vertical, 8)
            .accessibilityLabel(latex)
    }
}

struct ChatInlineLaTeXView: View {
    let latex: String
    let uiFont: UIFont
    let textColor: Color

    var body: some View {
        LaTeX(latex)
            .font(uiFont)
            .parsingMode(.onlyEquations)
            .blockMode(.alwaysInline)
            .processEscapes(true)
            .imageRenderingMode(.original)
            .renderingStyle(.wait)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
            .accessibilityLabel(latex)
    }
}
