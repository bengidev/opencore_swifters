import SwiftUI
import UIKit

/// UIKit-backed wireframe cube hero.
///
/// Vertices fade/pop in first, then edges reveal from vertex to vertex with
/// slight overlap. After construction, the cube slowly morphs through random
/// 3D orientations while staying centered. The renderer avoids per-frame
/// SwiftUI body updates and uses a display link during construction and idle morph.
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
    private var constructionGeometryBounds: CGRect = .zero

    private enum Phase {
        case construction
        case morph
    }

    private var phase: Phase = .construction

    /// Starting orientation used during construction and for reduced-motion fallback.
    private let baseYaw: CGFloat = 0.6
    private let basePitch: CGFloat = 0.52
    private let baseRoll: CGFloat = 0

    private var morphFromYaw = CGFloat(0.6)
    private var morphFromPitch = CGFloat(0.52)
    private var morphFromRoll = CGFloat(0)
    private var morphToYaw = CGFloat(0.6)
    private var morphToPitch = CGFloat(0.52)
    private var morphToRoll = CGFloat(0)
    private var morphSegmentStart: CFTimeInterval?
    private var morphSegmentDuration: CFTimeInterval = 4

    /// Duration of the vertex + edge construction reveal, in seconds.
    private let constructionDuration: CFTimeInterval = 0.75

    /// Vertices finish popping by this fraction of master progress.
    private let vertexPhaseEnd: CGFloat = 0.35

    /// Edges begin drawing at this fraction — overlaps the tail of vertex pop.
    private let edgePhaseStart: CGFloat = 0.2

    /// Morph begins while the last edges are still drawing so there is no dead frame.
    private let morphOverlapStart: CGFloat = 0.9

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
        invalidateConstructionGeometry()
        let progress: CGFloat
        if isAppeared && reduceMotion {
            progress = 1
        } else if animationStart != nil {
            progress = currentProgress(at: CACurrentMediaTime())
        } else {
            progress = 0
        }
        render(progress: progress, timestamp: CACurrentMediaTime())
    }

    func setReduceMotion(_ value: Bool) {
        guard reduceMotion != value else { return }
        reduceMotion = value
        if value {
            stopDisplayLink()
            resetMorphState()
            render(progress: isAppeared ? 1 : 0, timestamp: nil)
        } else if isAppeared {
            startAnimationIfNeeded()
        }
    }

    func setAppeared(_ value: Bool) {
        guard isAppeared != value else { return }
        isAppeared = value
        if value {
            if reduceMotion {
                resetMorphState()
                render(progress: 1, timestamp: nil)
            } else {
                animationStart = nil
                resetMorphState()
                startAnimationIfNeeded()
            }
        } else {
            stopDisplayLink()
            animationStart = nil
            resetMorphState()
            render(progress: 0, timestamp: nil)
        }
    }

    private func configureLayers() {
        let ink = UIColor.label.cgColor
        for (index, layer) in edgeLayers.enumerated() {
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = ink
            layer.lineWidth = 2
            layer.lineCap = .round
            layer.strokeStart = 0
            layer.strokeEnd = 0
            if dashedEdges.contains(index) {
                layer.lineDashPattern = [4, 3]
            }
            self.layer.addSublayer(layer)
        }
        for layer in vertexLayers {
            layer.fillColor = ink
            layer.opacity = 0
            layer.path = circlePath(at: .zero, radius: 3.5)
            self.layer.addSublayer(layer)
        }
    }

    private func startAnimationIfNeeded() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: displayLinkProxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        updateDisplayLinkFrameRate()
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateDisplayLinkFrameRate() {
        switch phase {
        case .construction:
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        case .morph:
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        }
    }

    fileprivate func tick(_ timestamp: CFTimeInterval) {
        guard isAppeared, !reduceMotion else { return }
        if animationStart == nil { animationStart = timestamp }
        let progress = currentProgress(at: timestamp)

        if progress >= morphOverlapStart, phase == .construction {
            phase = .morph
            updateDisplayLinkFrameRate()
            beginMorphSegment(at: timestamp, immediate: true)
        } else if phase == .morph {
            advanceMorphIfNeeded(at: timestamp)
        }

        render(progress: progress, timestamp: timestamp)
    }

    private func currentProgress(at timestamp: CFTimeInterval) -> CGFloat {
        guard let animationStart else { return 0 }
        return min(max(CGFloat((timestamp - animationStart) / constructionDuration), 0), 1)
    }

    private func resetMorphState() {
        phase = .construction
        morphFromYaw = baseYaw
        morphFromPitch = basePitch
        morphFromRoll = baseRoll
        morphToYaw = baseYaw
        morphToPitch = basePitch
        morphToRoll = baseRoll
        morphSegmentStart = nil
        morphSegmentDuration = 4
        invalidateConstructionGeometry()
        updateDisplayLinkFrameRate()
    }

    private func invalidateConstructionGeometry() {
        constructionGeometryBounds = .zero
    }

    private func beginMorphSegment(at timestamp: CFTimeInterval, immediate: Bool = false) {
        let (yaw, pitch, roll) = currentOrientation(at: timestamp)
        morphFromYaw = yaw
        morphFromPitch = pitch
        morphFromRoll = roll
        let target = randomMorphTarget(
            from: (yaw, pitch, roll),
            preferNoticeableChange: immediate
        )
        morphToYaw = target.yaw
        morphToPitch = target.pitch
        morphToRoll = target.roll
        morphSegmentDuration = Double.random(in: 1.0...1.6)
        morphSegmentStart = timestamp
    }

    private func advanceMorphIfNeeded(at timestamp: CFTimeInterval) {
        guard let morphSegmentStart else {
            beginMorphSegment(at: timestamp)
            return
        }
        let elapsed = timestamp - morphSegmentStart
        if elapsed >= morphSegmentDuration {
            beginMorphSegment(at: timestamp)
        }
    }

    private func randomMorphTarget(
        from current: (yaw: CGFloat, pitch: CGFloat, roll: CGFloat)? = nil,
        preferNoticeableChange: Bool = false
    ) -> (yaw: CGFloat, pitch: CGFloat, roll: CGFloat) {
        let minimumDelta: CGFloat = preferNoticeableChange ? 0.18 : 0.08
        for _ in 0..<8 {
            let candidate = (
                CGFloat.random(in: 0.2...1.4),
                CGFloat.random(in: 0.22...0.78),
                CGFloat.random(in: -0.32...0.32)
            )
            if let current {
                let delta = abs(candidate.0 - current.yaw)
                    + abs(candidate.1 - current.pitch)
                    + abs(candidate.2 - current.roll)
                if delta >= minimumDelta { return candidate }
            } else {
                return candidate
            }
        }
        return (
            (current?.yaw ?? baseYaw) + 0.35,
            (current?.pitch ?? basePitch) + 0.2,
            (current?.roll ?? baseRoll) + 0.15
        )
    }

    /// Cubic ease-out for enter animations — fast start, gentle settle.
    private func easeOut(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    private func currentOrientation(at timestamp: CFTimeInterval?) -> (yaw: CGFloat, pitch: CGFloat, roll: CGFloat) {
        guard phase == .morph, let timestamp, let morphSegmentStart else {
            return (baseYaw, basePitch, baseRoll)
        }
        let t = easeOut(CGFloat((timestamp - morphSegmentStart) / morphSegmentDuration))
        return (
            morphFromYaw + (morphToYaw - morphFromYaw) * t,
            morphFromPitch + (morphToPitch - morphFromPitch) * t,
            morphFromRoll + (morphToRoll - morphFromRoll) * t
        )
    }

    private func project(vertex: Vertex, center: CGPoint, half: CGFloat, yaw: CGFloat, pitch: CGFloat, roll: CGFloat) -> CGPoint {
        let x1 = vertex.x * cos(yaw) + vertex.z * sin(yaw)
        let z1 = -vertex.x * sin(yaw) + vertex.z * cos(yaw)
        let y2 = vertex.y * cos(pitch) - z1 * sin(pitch)
        let x3 = x1 * cos(roll) - y2 * sin(roll)
        let y3 = x1 * sin(roll) + y2 * cos(roll)
        return CGPoint(x: center.x + x3 * half, y: center.y + y3 * half)
    }

    private func ensureConstructionGeometry(center: CGPoint, half: CGFloat) {
        guard constructionGeometryBounds != bounds else { return }
        constructionGeometryBounds = bounds

        let projected = vertices.map { vertex in
            project(
                vertex: vertex,
                center: center,
                half: half,
                yaw: baseYaw,
                pitch: basePitch,
                roll: baseRoll
            )
        }

        for (index, point) in projected.enumerated() {
            vertexLayers[index].position = point
            vertexLayers[index].path = circlePath(at: .zero, radius: 3.5)
        }

        for (index, edge) in edges.enumerated() {
            let path = UIBezierPath()
            path.move(to: projected[edge.start])
            path.addLine(to: projected[edge.end])
            edgeLayers[index].path = path.cgPath
            edgeLayers[index].opacity = 1
            edgeLayers[index].strokeEnd = 0
        }
    }

    private func render(progress: CGFloat, timestamp: CFTimeInterval?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let half = min(bounds.width, bounds.height) * 0.34

        if phase == .morph {
            renderMorph(
                timestamp: timestamp,
                center: center,
                half: half,
                constructionProgress: progress < 1 ? progress : nil
            )
        } else {
            renderConstruction(progress: progress, center: center, half: half)
        }

        CATransaction.commit()
    }

    private func constructionVertexOpacity(for index: Int, progress: CGFloat) -> Float {
        let vertexProgress = min(progress / vertexPhaseEnd, 1)
        let delay = CGFloat(index) * 0.025
        let normalizedDelay = delay / vertexPhaseEnd
        let linear = min(max((vertexProgress - normalizedDelay) / (1 - normalizedDelay), 0), 1)
        return Float(easeOut(linear))
    }

    private func constructionEdgeStrokeEnd(for index: Int, progress: CGFloat) -> CGFloat {
        let edgeSpan = max(1 - edgePhaseStart, 0.001)
        let edgeProgress = min(max((progress - edgePhaseStart) / edgeSpan, 0), 1)
        let linear: CGFloat
        if dashedEdges.contains(index) {
            linear = min(max((edgeProgress - 0.35) / 0.65, 0), 1)
        } else {
            let delay = CGFloat(index) * 0.05
            linear = min(max((edgeProgress - delay) / (1 - delay), 0), 1)
        }
        return easeOut(linear)
    }

    private func renderConstruction(progress: CGFloat, center: CGPoint, half: CGFloat) {
        ensureConstructionGeometry(center: center, half: half)

        for index in vertexLayers.indices {
            let eased = CGFloat(constructionVertexOpacity(for: index, progress: progress))
            let scale = 0.85 + 0.15 * eased
            vertexLayers[index].opacity = Float(eased)
            vertexLayers[index].setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }

        for index in edges.indices {
            edgeLayers[index].strokeEnd = constructionEdgeStrokeEnd(for: index, progress: progress)
        }
    }

    private func renderMorph(
        timestamp: CFTimeInterval?,
        center: CGPoint,
        half: CGFloat,
        constructionProgress: CGFloat? = nil
    ) {
        let orientation = currentOrientation(at: timestamp)
        let projected = vertices.map { vertex in
            project(
                vertex: vertex,
                center: center,
                half: half,
                yaw: orientation.yaw,
                pitch: orientation.pitch,
                roll: orientation.roll
            )
        }

        for (index, point) in projected.enumerated() {
            vertexLayers[index].position = point
            if let constructionProgress {
                let opacity = constructionVertexOpacity(for: index, progress: constructionProgress)
                let scale = 0.85 + 0.15 * CGFloat(opacity)
                vertexLayers[index].opacity = opacity
                vertexLayers[index].setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
            } else {
                vertexLayers[index].opacity = 1
                vertexLayers[index].setAffineTransform(.identity)
            }
        }

        for (index, edge) in edges.enumerated() {
            let path = UIBezierPath()
            path.move(to: projected[edge.start])
            path.addLine(to: projected[edge.end])
            edgeLayers[index].path = path.cgPath
            if let constructionProgress {
                edgeLayers[index].strokeEnd = constructionEdgeStrokeEnd(for: index, progress: constructionProgress)
            } else {
                edgeLayers[index].strokeEnd = 1
            }
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
