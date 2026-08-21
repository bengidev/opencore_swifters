import SwiftUI
import UIKit

/// UIKit-backed wireframe cube hero.
///
/// Vertices fade/pop in first, then edges reveal from vertex to vertex. The
/// renderer avoids per-frame SwiftUI body updates and uses a display link only
/// during construction and the subtle idle float.
struct OnboardingCubeView: View {
    let appeared: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingCubeUIKitView(
            appeared: appeared,
            reduceMotion: reduceMotion
        )
        .accessibilityHidden(true)
    }
}

private struct OnboardingCubeUIKitView: UIViewRepresentable {
    let appeared: Bool
    let reduceMotion: Bool

    func makeUIView(context: Context) -> CubeRendererView {
        CubeRendererView(reduceMotion: reduceMotion)
    }

    func updateUIView(_ view: CubeRendererView, context: Context) {
        view.setReduceMotion(reduceMotion)
        view.setAppeared(appeared)
    }
}

@MainActor
private final class CubeRendererView: UIView {
    private struct Vertex {
        let x: CGFloat
        let y: CGFloat
        let z: CGFloat
    }

    private struct Edge {
        let start: Int
        let end: Int
    }

    private let vertices: [Vertex] = [
        Vertex(x: -1, y: -1, z: -1), Vertex(x: 1, y: -1, z: -1),
        Vertex(x: 1, y: 1, z: -1), Vertex(x: -1, y: 1, z: -1),
        Vertex(x: -1, y: -1, z: 1), Vertex(x: 1, y: -1, z: 1),
        Vertex(x: 1, y: 1, z: 1), Vertex(x: -1, y: 1, z: 1)
    ]

    private let edges: [Edge] = [
        Edge(start: 0, end: 1), Edge(start: 1, end: 2),
        Edge(start: 2, end: 3), Edge(start: 3, end: 0),
        Edge(start: 4, end: 5), Edge(start: 5, end: 6),
        Edge(start: 6, end: 7), Edge(start: 7, end: 4),
        Edge(start: 0, end: 4), Edge(start: 1, end: 5),
        Edge(start: 2, end: 6), Edge(start: 3, end: 7),
    ]

    /// The three edges meeting at the hidden back-bottom-left vertex use dashed strokes.
    private let dashedEdges: Set<Int> = [6, 7, 11]
    private let edgeLayers: [CAShapeLayer]
    private let vertexLayers: [CAShapeLayer]
    private let displayLinkProxy: DisplayLinkProxy
    private var displayLink: CADisplayLink?
    private var animationStart: CFTimeInterval?
    private var isAppeared = false
    private var reduceMotion: Bool
    private var lastBounds: CGRect = .zero

    /// Duration of the vertex + edge construction reveal, in seconds.
    private let constructionDuration: CFTimeInterval = 1.0

    /// Idle float frequency (radians/sec); larger = faster bobbing.
    private let bobFrequency: CGFloat = 0.9

    init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        self.edgeLayers = edges.map { _ in CAShapeLayer() }
        self.vertexLayers = vertices.map { _ in CAShapeLayer() }
        self.displayLinkProxy = DisplayLinkProxy()
        super.init(frame: .zero)
        displayLinkProxy.owner = self
        backgroundColor = .clear
        isOpaque = false
        configureLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopDisplayLink()
        } else if isAppeared && !reduceMotion {
            startAnimationIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds != lastBounds else { return }
        lastBounds = bounds
        render(progress: isAppeared && reduceMotion ? 1 : currentProgress(at: CACurrentMediaTime()), bob: 0)
    }

    func setReduceMotion(_ value: Bool) {
        guard reduceMotion != value else { return }
        reduceMotion = value
        if value {
            stopDisplayLink()
            render(progress: isAppeared ? 1 : 0, bob: 0)
        } else if isAppeared {
            startAnimationIfNeeded()
        }
    }

    func setAppeared(_ value: Bool) {
        guard isAppeared != value else { return }
        isAppeared = value
        if value {
            if reduceMotion {
                render(progress: 1, bob: 0)
            } else {
                animationStart = nil
                startAnimationIfNeeded()
            }
        } else {
            stopDisplayLink()
            animationStart = nil
            render(progress: 0, bob: 0)
        }
    }

    private func configureLayers() {
        let ink = UIColor.label.cgColor
        for layer in edgeLayers {
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = ink
            layer.lineWidth = 2
            layer.lineCap = .round
            layer.strokeStart = 0
            layer.strokeEnd = 0
            self.layer.addSublayer(layer)
        }
        for (index, layer) in vertexLayers.enumerated() {
            layer.fillColor = ink
            layer.opacity = 0
            layer.path = circlePath(at: .zero, radius: index == 0 ? 3.5 : 3.5)
            self.layer.addSublayer(layer)
        }
    }

    private func startAnimationIfNeeded() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: displayLinkProxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    fileprivate func tick(_ timestamp: CFTimeInterval) {
        guard isAppeared, !reduceMotion else { return }
        if animationStart == nil { animationStart = timestamp }
        let progress = currentProgress(at: timestamp)
        let bob = progress >= 1 ? CGFloat(sin(timestamp * bobFrequency) * 3.5) : 0
        render(progress: progress, bob: bob)
        if progress >= 1 {
            // Keep the display link for the low-cost idle float.
            _ = constructionDuration
        }
    }

    private func currentProgress(at timestamp: CFTimeInterval) -> CGFloat {
        guard let animationStart else { return isAppeared ? 0 : 0 }
        return min(max(CGFloat((timestamp - animationStart) / constructionDuration), 0), 1)
    }

    private func render(progress: CGFloat, bob: CGFloat) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY + bob)
        let half = min(bounds.width, bounds.height) * 0.34
        let yaw: CGFloat = 0.6
        let pitch: CGFloat = 0.52
        let projected = vertices.map { vertex -> CGPoint in
            let x1 = vertex.x * cos(yaw) + vertex.z * sin(yaw)
            let z1 = -vertex.x * sin(yaw) + vertex.z * cos(yaw)
            let y1 = vertex.y * cos(pitch) - z1 * sin(pitch)
            return CGPoint(x: center.x + x1 * half, y: center.y + y1 * half)
        }

        let vertexProgress = min(progress / 0.3, 1)
        let edgeProgress = min(max((progress - 0.3) / 0.7, 0), 1)
        let ink = UIColor.label.cgColor

        for (index, point) in projected.enumerated() {
            let delay = CGFloat(index) * 0.03
            let local = min(max((vertexProgress - delay / 0.3) / (1 - delay / 0.3), 0), 1)
            vertexLayers[index].position = point
            vertexLayers[index].path = circlePath(at: .zero, radius: 3.5 * (0.5 + 0.5 * local))
            vertexLayers[index].opacity = Float(local)
            vertexLayers[index].fillColor = ink
        }

        for (index, edge) in edges.enumerated() {
            let local: CGFloat
            if dashedEdges.contains(index) {
                local = min(max((edgeProgress - 0.5) / 0.5, 0), 1)
            } else {
                let delay = CGFloat(index) * 0.06
                local = min(max((edgeProgress - delay) / (1 - delay), 0), 1)
            }
            let path = UIBezierPath()
            path.move(to: projected[edge.start])
            path.addLine(to: projected[edge.end])
            edgeLayers[index].path = path.cgPath
            edgeLayers[index].strokeColor = ink
            edgeLayers[index].opacity = 1
            edgeLayers[index].lineDashPattern = dashedEdges.contains(index) ? [4, 3] : nil
            edgeLayers[index].strokeEnd = local
        }
    }

    private func circlePath(at center: CGPoint, radius: CGFloat) -> CGPath {
        UIBezierPath(ovalIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )).cgPath
    }
}

private final class DisplayLinkProxy: NSObject {
    weak var owner: CubeRendererView?

    @objc func tick(_ displayLink: CADisplayLink) {
        owner?.tick(displayLink.timestamp)
    }
}
