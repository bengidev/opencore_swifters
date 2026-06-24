import Foundation
import Testing

@testable import OpenCore

@Suite("Context Window Usage")
struct ContextWindowUsageTests {
    @Test("Zero sentinel represents unknown empty usage")
    func zeroSentinel() {
        let usage = ContextWindowUsage.zero

        #expect(usage.tokensUsed == 0)
        #expect(usage.tokenLimit == 0)
        #expect(usage.fractionUsed == 0)
        #expect(usage.percentUsed == 0)
        #expect(usage.percentRemaining == 0)
    }

    @Test("Tokens used clamps to token limit")
    func clampsTokensUsedToLimit() {
        let usage = ContextWindowUsage(tokensUsed: 300_000, tokenLimit: 258_400)

        #expect(usage.tokensUsed == 258_400)
        #expect(usage.fractionUsed == 1)
        #expect(usage.percentUsed == 100)
        #expect(usage.percentRemaining == 0)
    }

    @Test("Fraction and percent derive from used and limit")
    func fractionAndPercentCalculations() {
        let usage = ContextWindowUsage(tokensUsed: 129_000, tokenLimit: 258_000)

        #expect(usage.fractionUsed == 0.5)
        #expect(usage.percentUsed == 50)
        #expect(usage.percentRemaining == 50)
    }

    @Test("Token labels compact thousands with one decimal when needed")
    func tokenLabelFormatting() {
        let usage = ContextWindowUsage(tokensUsed: 158_158, tokenLimit: 258_400)

        #expect(usage.tokensUsedFormatted == "158.2K")
        #expect(usage.tokenLimitFormatted == "258.4K")
    }

    @Test("Token labels omit decimal for exact thousands")
    func tokenLabelFormattingExactThousands() {
        let usage = ContextWindowUsage(tokensUsed: 107_000, tokenLimit: 258_000)

        #expect(usage.tokensUsedFormatted == "107K")
        #expect(usage.tokenLimitFormatted == "258K")
    }

    @Test("Token labels pass through counts below one thousand")
    func tokenLabelFormattingBelowThousands() {
        let usage = ContextWindowUsage(tokensUsed: 512, tokenLimit: 999)

        #expect(usage.tokensUsedFormatted == "512")
        #expect(usage.tokenLimitFormatted == "999")
    }

    @Test("Unknown limit reports zero fraction")
    func unknownLimitShowsZeroFraction() {
        let usage = ContextWindowUsage(tokensUsed: 50_000, tokenLimit: 0)

        #expect(usage.fractionUsed == 0)
        #expect(usage.percentUsed == 0)
        #expect(usage.percentRemaining == 0)
    }
}
