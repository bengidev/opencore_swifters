import SwiftUI

/// App information tab — static metadata and project link.
struct AboutView: View {
    @Environment(\.sharedPalette) private var palette

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "OpenCore"
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        ZStack {
            palette.surfaceBase.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(appName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(palette.textPrimary)

                    Text(versionText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.textSecondary)

                    Text("OpenCore is a Swift-native chat shell for exploring models through OpenRouter-compatible providers.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Link("View on GitHub", destination: URL(string: "https://github.com/bengidev/opencore_swifters")!)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.accentPrimary)
                        .accessibilityIdentifier("about-github-link")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .accessibilityIdentifier("about-view")
    }
}

#Preview {
    AboutView()
        .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
