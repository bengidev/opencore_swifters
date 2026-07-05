import SwiftUI
import WebKit

@MainActor
enum ChatMermaidRenderer {
    private static var pool: [WKWebView] = []
    private static let poolLimit = 2

    static func snapshot(
        source: String,
        isDark: Bool,
        width: CGFloat
    ) async -> UIImage? {
        let webView = borrowWebView()
        defer { returnWebView(webView) }

        guard let htmlURL = Bundle.main.url(forResource: "mermaid-render", withExtension: "html", subdirectory: "Mermaid")
            ?? Bundle.main.url(forResource: "mermaid-render", withExtension: "html") else {
            return nil
        }

        webView.frame = CGRect(x: 0, y: 0, width: width, height: 400)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        await load(webView: webView, url: htmlURL)

        let theme = isDark ? "dark" : "light"
        let sourceArg = ChatMermaidJSEscaping.quotedJavaScriptString(source)
        let script = "window.renderMermaid(\(sourceArg), \"\(theme)\")"
        guard let result = try? await webView.evaluateJavaScript(script) as? [String: Any],
              (result["ok"] as? Bool) == true else {
            return nil
        }

        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds
        return await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: config) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private static func load(webView: WKWebView, url: URL) async {
        await withCheckedContinuation { continuation in
            final class Delegate: NSObject, WKNavigationDelegate {
                let onFinish: () -> Void
                init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
                func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onFinish() }
                func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { onFinish() }
            }
            let delegate = Delegate { continuation.resume() }
            objc_setAssociatedObject(webView, "navDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            webView.navigationDelegate = delegate
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    private static func borrowWebView() -> WKWebView {
        if let webView = pool.popLast() {
            return webView
        }
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        return WKWebView(frame: .zero, configuration: config)
    }

    private static func returnWebView(_ webView: WKWebView) {
        guard pool.count < poolLimit else { return }
        webView.navigationDelegate = nil
        pool.append(webView)
    }
}

@MainActor
private final class MermaidSnapshotCache {
    static let shared = MermaidSnapshotCache()

    private struct Key: Hashable {
        let source: String
        let isDark: Bool
        let widthBucket: Int
    }

    private let limit = 32
    private var storage: [Key: UIImage] = [:]
    private var order: [Key] = []

    func image(for source: String, isDark: Bool, width: CGFloat) -> UIImage? {
        storage[Key(source: source, isDark: isDark, widthBucket: Int(width.rounded()))]
    }

    func store(_ image: UIImage, for source: String, isDark: Bool, width: CGFloat) {
        let key = Key(source: source, isDark: isDark, widthBucket: Int(width.rounded()))
        if storage[key] != nil {
            order.removeAll { $0 == key }
        }
        storage[key] = image
        order.append(key)
        while order.count > limit {
            let evicted = order.removeFirst()
            storage.removeValue(forKey: evicted)
        }
    }
}

private struct ContainerWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ChatMermaidSnapshotView: View {
    let source: String
    let palette: SharedOpenCorePalette

    @State private var image: UIImage?
    @State private var failed = false
    @State private var isExpanded = false
    @State private var layoutWidth: CGFloat = 0

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { isExpanded = true }
                    .accessibilityLabel(source)
                    .accessibilityHint("Double tap to expand diagram.")
            } else if failed {
                ChatMermaidFailureCard(source: source, palette: palette)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.surfaceSubtle)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .overlay {
                        ProgressView()
                            .tint(palette.textSecondary)
                    }
                    .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ContainerWidthPreferenceKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(ContainerWidthPreferenceKey.self) { width in
            layoutWidth = width
        }
        .sheet(isPresented: $isExpanded) {
            ChatMermaidExpandedSheet(source: source, palette: palette)
        }
        .task(id: "\(taskKey)-\(Int(layoutWidth))") {
            guard layoutWidth > 0 else { return }
            await renderSnapshot(width: layoutWidth)
        }
    }

    private var taskKey: String {
        "\(palette.isDark)-\(source.hashValue)"
    }

    @MainActor
    private func renderSnapshot(width: CGFloat) async {
        if let cached = MermaidSnapshotCache.shared.image(for: source, isDark: palette.isDark, width: width) {
            image = cached
            failed = false
            return
        }
        let rendered = await ChatMermaidRenderer.snapshot(
            source: source,
            isDark: palette.isDark,
            width: width
        )
        if let rendered {
            image = rendered
            failed = false
            MermaidSnapshotCache.shared.store(rendered, for: source, isDark: palette.isDark, width: width)
        } else {
            image = nil
            failed = true
        }
    }
}

struct ChatMermaidFailureCard: View {
    let source: String
    let palette: SharedOpenCorePalette

    @State private var showsSource = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagram could not be rendered")
                .font(SharedOpenCoreTypography.monoSM)
                .foregroundStyle(palette.textSecondary)
            Button(showsSource ? "Hide source" : "Show source") {
                showsSource.toggle()
            }
            .font(SharedOpenCoreTypography.monoSM)
            .foregroundStyle(palette.accentPrimary)
            if showsSource {
                Text(source)
                    .font(SharedOpenCoreTypography.monoXS)
                    .foregroundStyle(palette.textTertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.vertical, 8)
    }
}

struct ChatMermaidExpandedSheet: View {
    let source: String
    let palette: SharedOpenCorePalette

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ChatMermaidLiveWebView(source: source, isDark: palette.isDark)
                .background(palette.surfaceBase)
                .navigationTitle("Diagram")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: source) {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct ChatMermaidLiveWebView: UIViewRepresentable {
    let source: String
    let isDark: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastSource != source || context.coordinator.lastTheme != isDark else { return }
        context.coordinator.lastSource = source
        context.coordinator.lastTheme = isDark
        context.coordinator.pendingRender = (source, isDark)

        guard let htmlURL = Bundle.main.url(forResource: "mermaid-render", withExtension: "html", subdirectory: "Mermaid")
            ?? Bundle.main.url(forResource: "mermaid-render", withExtension: "html") else {
            return
        }

        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastSource: String?
        var lastTheme: Bool?
        var pendingRender: (String, Bool)?
        weak var webView: WKWebView?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let pendingRender else { return }
            self.pendingRender = nil
            let sourceArg = ChatMermaidJSEscaping.quotedJavaScriptString(pendingRender.0)
            let theme = pendingRender.1 ? "dark" : "light"
            webView.evaluateJavaScript("window.renderMermaid(\(sourceArg), \"\(theme)\")")
        }
    }
}
