import Foundation
import SwiftUI
import UIKit

/// Native markdown styling for assistant answer prose (inline code, emphasis, blocks).
@MainActor
enum ChatAssistantMarkdownRenderer {
    private static let codeBlockHorizontalPadding: CGFloat = 8
    private static let allowedLinkSchemes: Set<String> = ["https", "http", "mailto"]
    private static let cache = BoundedCache()

    static func attributedString(
        from markdown: String,
        palette: SharedOpenCorePalette
    ) -> AttributedString {
        let canCache = !shouldUsePlainFallback(for: markdown)
        if canCache, let cached = cache.value(for: markdown, isDark: palette.isDark) {
            return cached
        }

        let rendered = render(markdown: markdown, palette: palette)
        if canCache {
            cache.store(rendered, for: markdown, isDark: palette.isDark)
        }
        return rendered
    }

    static func nsAttributedString(
        from markdown: String,
        palette: SharedOpenCorePalette
    ) -> NSAttributedString {
        NSAttributedString(attributedString(from: markdown, palette: palette))
    }

    private static func render(markdown: String, palette: SharedOpenCorePalette) -> AttributedString {
        guard !shouldUsePlainFallback(for: markdown) else {
            return plainBody(markdown, palette: palette)
        }

        do {
            var attributed = try AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
            )
            applyStyles(to: &attributed, palette: palette)
            return attributed
        } catch {
            return plainBody(markdown, palette: palette)
        }
    }

    private static func plainBody(_ text: String, palette: SharedOpenCorePalette) -> AttributedString {
        var attributed = AttributedString(text)
        let bodyFont = SharedOpenCoreTypography.bodyMDUIFont
        let textColor = UIColor(palette.textPrimary)
        for run in attributed.runs {
            attributed[run.range].uiKit.font = bodyFont
            attributed[run.range].uiKit.foregroundColor = textColor
        }
        return attributed
    }

    private static func shouldUsePlainFallback(for text: String) -> Bool {
        let fenceDelimiter = "```"
        let fenceCount = text.components(separatedBy: fenceDelimiter).count - 1
        if fenceCount % 2 != 0 { return true }

        let segments = text.components(separatedBy: fenceDelimiter)
        for (index, segment) in segments.enumerated() where index.isMultiple(of: 2) {
            let backtickCount = segment.filter { $0 == "`" }.count
            if backtickCount % 2 != 0 { return true }
        }
        return false
    }

    private static func isAllowedLink(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return allowedLinkSchemes.contains(scheme)
    }

    private static func applyStyles(to attributed: inout AttributedString, palette: SharedOpenCorePalette) {
        let bodyFont = SharedOpenCoreTypography.bodyMDUIFont
        let codeBlockFont = SharedOpenCoreTypography.monoSMUIFont
        let textPrimary = UIColor(palette.textPrimary)
        let textSecondary = UIColor(palette.textSecondary)
        let accentPrimary = UIColor(palette.accentPrimary)
        let surfaceSubtle = UIColor(palette.surfaceSubtle)

        for run in attributed.runs {
            let range = run.range
            var isCodeBlock = false
            var headingLevel: Int?

            if let presentationIntent = run.presentationIntent {
                for component in presentationIntent.components {
                    switch component.kind {
                    case .codeBlock:
                        isCodeBlock = true
                    case let .header(level):
                        headingLevel = level
                    default:
                        break
                    }
                }
            }

            if isCodeBlock {
                attributed[range].uiKit.font = codeBlockFont
                attributed[range].uiKit.foregroundColor = textSecondary
                attributed[range].uiKit.backgroundColor = surfaceSubtle
                let blockStyle = NSMutableParagraphStyle()
                blockStyle.firstLineHeadIndent = codeBlockHorizontalPadding
                blockStyle.headIndent = codeBlockHorizontalPadding
                blockStyle.tailIndent = -codeBlockHorizontalPadding
                blockStyle.paragraphSpacingBefore = 4
                blockStyle.paragraphSpacing = 4
                attributed[range].uiKit.paragraphStyle = blockStyle
                continue
            }

            attributed[range].uiKit.font = bodyFont
            attributed[range].uiKit.foregroundColor = textPrimary

            if let headingLevel {
                let size = headingPointSize(for: headingLevel)
                attributed[range].uiKit.font = UIFont.systemFont(ofSize: size, weight: .semibold)
                continue
            }

            if let inlineIntent = run.inlinePresentationIntent {
                let hasCode = inlineIntent.contains(.code)
                let hasStrong = inlineIntent.contains(.stronglyEmphasized)
                let hasEmphasis = inlineIntent.contains(.emphasized)

                if hasCode {
                    let weight: UIFont.Weight = hasStrong ? .semibold : .regular
                    let codeSize = SharedOpenCoreTypography.monoBodyUIFont.pointSize
                    attributed[range].uiKit.font = UIFont.monospacedSystemFont(ofSize: codeSize, weight: weight)
                    attributed[range].uiKit.foregroundColor = textSecondary
                } else if hasStrong {
                    attributed[range].uiKit.font = UIFont.systemFont(
                        ofSize: SharedOpenCoreTypography.bodyMDUIFont.pointSize,
                        weight: .semibold
                    )
                    attributed[range].uiKit.foregroundColor = textPrimary
                }

                if hasEmphasis {
                    let currentFont = attributed[range].uiKit.font ?? bodyFont
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits(.traitItalic)
                        ?? currentFont.fontDescriptor
                    attributed[range].uiKit.font = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                }
            }

            if let link = run.link {
                if isAllowedLink(link) {
                    attributed[range].uiKit.foregroundColor = accentPrimary
                    attributed[range].uiKit.underlineStyle = .patternDot
                    attributed[range].uiKit.underlineColor = accentPrimary
                } else {
                    attributed[range].link = nil
                }
            }
        }
    }

    private static func headingPointSize(for level: Int) -> CGFloat {
        switch level {
        case 1: 22
        case 2: 20
        case 3: 18
        case 4: 17
        case 5: 16
        default: 16
        }
    }
}

private final class BoundedCache {
    private struct Key: Hashable {
        let content: String
        let isDark: Bool
    }

    private let limit = 64
    private var storage: [Key: AttributedString] = [:]
    private var order: [Key] = []

    func value(for content: String, isDark: Bool) -> AttributedString? {
        storage[Key(content: content, isDark: isDark)]
    }

    func store(_ value: AttributedString, for content: String, isDark: Bool) {
        let key = Key(content: content, isDark: isDark)
        if storage[key] != nil {
            order.removeAll { $0 == key }
        }
        storage[key] = value
        order.append(key)
        while order.count > limit {
            let evicted = order.removeFirst()
            storage.removeValue(forKey: evicted)
        }
    }
}
