import LaTeXSwiftUI
import MarkdownUI
import SwiftUI
import UIKit

extension SharedOpenCorePalette {
    @MainActor
    func richContentTheme(style: ChatRichContentStyle) -> Theme {
        let bodyUIFont = uiFont(for: style)
        let bodyFont = Font(bodyUIFont)
        let monoFont = Font(uiFont(for: .terminal))
        let textPrimary = self.textPrimary
        let textSecondary = self.textSecondary
        let accentPrimary = self.accentPrimary
        let surfaceSubtle = self.surfaceSubtle
        let surfaceRaised = self.surfaceRaised

        return Theme()
            .text {
                ForegroundColor(textPrimary)
                FontSize(bodyUIFont.pointSize)
                if style == .reasoning {
                    FontFamily(.custom("Menlo"))
                    FontStyle(.italic)
                }
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(style == .reasoning ? 13 : 12)
                ForegroundColor(textSecondary)
                BackgroundColor(surfaceSubtle)
            }
            .codeBlock { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(style == .reasoning ? 12 : 12)
                        ForegroundColor(textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .strong {
                FontWeight(.semibold)
            }
            .emphasis {
                if style == .reasoning {
                    FontStyle(.italic)
                }
            }
            .link {
                ForegroundColor(accentPrimary)
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(headingSize(level: 1, style: style))
                    }
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(headingSize(level: 2, style: style))
                    }
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(headingSize(level: 3, style: style))
                    }
            }
            .paragraph { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(bodyUIFont.pointSize)
                    }
                    .padding(.bottom, style == .system ? 4 : 10)
            }
            .blockquote { configuration in
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(textSecondary.opacity(0.5))
                        .frame(width: 3)
                    configuration.label
                        .markdownTextStyle {
                            ForegroundColor(textSecondary)
                        }
                }
            }
            .table { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: textSecondary.opacity(0.25)))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(surfaceSubtle.opacity(0.35), Color.clear)
                    )
                    .markdownMargin(top: 0, bottom: 12)
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontWeight(.semibold)
                        }
                        BackgroundColor(nil)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
            }
    }

    func uiFont(for style: ChatRichContentStyle) -> UIFont {
        switch style {
        case .assistant:
            SharedOpenCoreTypography.bodyMDUIFont
        case .reasoning, .terminal:
            UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        case .system:
            UIFont.systemFont(ofSize: 13, weight: .regular)
        }
    }

    func swiftUIFont(for style: ChatRichContentStyle) -> Font {
        switch style {
        case .assistant:
            SharedOpenCoreTypography.bodyMD
        case .reasoning:
            .system(size: 13, weight: .regular, design: .monospaced).italic()
        case .terminal:
            SharedOpenCoreTypography.monoSM
        case .system:
            .system(size: 13, weight: .regular)
        }
    }

    private func headingSize(level: Int, style: ChatRichContentStyle) -> CGFloat {
        let base: CGFloat = style == .reasoning ? 13 : 16
        switch level {
        case 1: return base + 6
        case 2: return base + 4
        default: return base + 2
        }
    }
}
