import SwiftUI

/// Auto-advancing feature carousel — cards swipe right-to-left on a spring loop with parallax,
/// scale, focus blur, and a soft blur bridge between hero art and copy (no hard divider).
/// Users can also drag horizontally to browse cards; auto-advance pauses during interaction.
struct OnboardingFeatureCardCarouselView: View {
    let isActive: Bool
    var initialAdvanceDelay: Duration = .milliseconds(900)

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scrollIndex: CGFloat = 0
    @State private var loopTask: Task<Void, Never>?
    @State private var resumeLoopTask: Task<Void, Never>?
    @State private var isUserDragging = false
    @State private var dragOriginScrollIndex: CGFloat = 0
    @State private var isImageRevealed = false
    @State private var isScrollAnimating = false
    @State private var settleTask: Task<Void, Never>?

    private let features = OnboardingFeature.catalog
    private let cardWidthRatio: CGFloat = 0.74
    private let cardHeightRatio: CGFloat = 0.84
    private let cardAspectRatio: CGFloat = 1.48
    /// Clear space between adjacent card edges when centred.
    private let cardInterCardGap: CGFloat = 14
    private let holdDuration: Duration = .seconds(4.4)
    /// Only mount cards within one step of center (focused ± 1).
    private let viewportWindow: CGFloat = 1.05

    private var isCarouselMoving: Bool {
        isUserDragging || isScrollAnimating
    }

    var body: some View {
        Group {
            if reduceMotion {
                staticFocusedCard
            } else {
                animatedCarousel
            }
        }
        .animation(.easeInOut(duration: 0.28), value: palette.isDark)
        .onAppear {
            if isActive {
                startLoop()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                startLoop()
            } else {
                stopLoop()
            }
        }
        .onDisappear {
            stopLoop()
            resumeLoopTask?.cancel()
            resumeLoopTask = nil
            settleTask?.cancel()
            settleTask = nil
        }
    }

    // MARK: - Animated Carousel

    private var animatedCarousel: some View {
        GeometryReader { proxy in
            let cardSize = cardDimensions(in: proxy.size)
            let cardWidth = cardSize.width
            let cardHeight = cardSize.height
            let visibleIndices = visibleFeatureIndices(scroll: scrollIndex)

            ZStack {
                ForEach(visibleIndices, id: \.self) { index in
                    let relative = modularRelative(featureIndex: index, scroll: scrollIndex)
                    let isFocused = abs(relative) < 0.05
                    let isRevealed = isFocused && isImageRevealed
                    let shouldAmbientBob = isFocused && !isRevealed && !isUserDragging && !isScrollAnimating

                    OnboardingFeatureCarouselCardView(
                        feature: features[index],
                        relativePosition: relative,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        shouldAmbientBob: shouldAmbientBob,
                        isFocused: isFocused,
                        isRevealed: isRevealed,
                        onRevealChanged: setImageRevealed
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(cardScale(for: relative, isRevealed: isRevealed))
                    .blur(radius: cardBlur(for: relative, isRevealed: isRevealed))
                    .opacity(cardOpacity(for: relative))
                    .offset(x: cardXOffset(for: relative, cardWidth: cardWidth))
                    .zIndex(cardZIndex(for: relative, isRevealed: isRevealed))
                    .allowsHitTesting(abs(relative) <= 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(isImageRevealed ? nil : carouselDragGesture(cardWidth: cardWidth))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentFeatureAccessibilityLabel)
        .accessibilityAdjustableAction { direction in
            nudgeCarousel(by: direction == .increment ? 1 : -1, animated: true)
        }
    }

    // MARK: - Reduced Motion

    private var staticFocusedCard: some View {
        GeometryReader { proxy in
            let cardSize = cardDimensions(in: proxy.size)
            let cardWidth = cardSize.width
            let cardHeight = cardSize.height
            let feature = features[wrappedIndex(Int(scrollIndex.rounded()))]

            OnboardingFeatureCarouselCardView(
                feature: feature,
                relativePosition: 0,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                shouldAmbientBob: false,
                isFocused: true,
                isRevealed: isImageRevealed,
                onRevealChanged: setImageRevealed
            )
            .frame(width: cardWidth, height: cardHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(isImageRevealed ? nil : carouselDragGesture(cardWidth: cardWidth, animated: false))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentFeatureAccessibilityLabel)
        .accessibilityAdjustableAction { direction in
            nudgeCarousel(by: direction == .increment ? 1 : -1, animated: false)
        }
    }

    // MARK: - Layout Math

    private func modularRelative(featureIndex: Int, scroll: CGFloat) -> CGFloat {
        let count = CGFloat(features.count)
        guard count > 1 else { return CGFloat(featureIndex) - scroll }

        let base = CGFloat(featureIndex) - scroll
        var best = base
        for shift in [-count, 0, count] {
            let candidate = base + shift
            if abs(candidate) < abs(best) {
                best = candidate
            }
        }
        return best
    }

    private func wrappedIndex(_ index: Int) -> Int {
        let count = features.count
        guard count > 0 else { return 0 }
        return ((index % count) + count) % count
    }

    private func cardXOffset(for relative: CGFloat, cardWidth: CGFloat) -> CGFloat {
        relative * (cardWidth + cardInterCardGap)
    }

    private func cardScale(for relative: CGFloat, isRevealed: Bool = false) -> CGFloat {
        if isRevealed { return 1.05 }
        let distance = min(abs(relative), 1)
        return 1 - (distance * 0.08)
    }

    private func cardBlur(for relative: CGFloat, isRevealed: Bool) -> CGFloat {
        if isRevealed { return 0 }
        let distance = min(abs(relative), 1)
        return distance * 1.5
    }

    private func cardOpacity(for relative: CGFloat) -> Double {
        let distance = min(abs(relative), 1)
        return 1 - (Double(distance) * 0.28)
    }

    private func visibleFeatureIndices(scroll: CGFloat) -> [Int] {
        let window = isCarouselMoving ? 1.2 : viewportWindow
        return features.indices.filter { abs(modularRelative(featureIndex: $0, scroll: scroll)) <= window }
    }

    private func cardDimensions(in size: CGSize) -> CGSize {
        let height = size.height * cardHeightRatio
        let width = min(size.width * cardWidthRatio, height / cardAspectRatio)
        return CGSize(width: width, height: height)
    }

    private func cardStep(for cardWidth: CGFloat) -> CGFloat {
        cardWidth + cardInterCardGap
    }

    private var currentFeatureAccessibilityLabel: String {
        let feature = features[wrappedIndex(Int(scrollIndex.rounded()))]
        return "\(feature.title). \(feature.subtitle)"
    }

    // MARK: - User Interaction

    private func carouselDragGesture(cardWidth: CGFloat, animated: Bool = true) -> some Gesture {
        let step = cardStep(for: cardWidth)

        return DragGesture(minimumDistance: 8)
            .onChanged { value in
                pauseLoopForUserInteraction()

                if !isUserDragging {
                    isUserDragging = true
                    isScrollAnimating = true
                    settleTask?.cancel()
                    settleTask = nil

                    var snapTransaction = Transaction()
                    snapTransaction.disablesAnimations = true
                    withTransaction(snapTransaction) {
                        normalizeScrollIndexIfNeeded()
                        dragOriginScrollIndex = scrollIndex
                    }
                }

                let anchor = dragOriginScrollIndex
                let rawScroll = anchor - (value.translation.width / step)
                let clampedScroll = min(max(rawScroll, anchor - 1), anchor + 1)

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    scrollIndex = clampedScroll
                }
            }
            .onEnded { value in
                isUserDragging = false
                isScrollAnimating = true

                let anchor = dragOriginScrollIndex
                let flickDistance = value.predictedEndTranslation.width - value.translation.width
                let projected = scrollIndex - (flickDistance / step)
                let target = min(max(round(projected), round(anchor) - 1), round(anchor) + 1)

                if animated {
                    withAnimation(carouselSpring) {
                        scrollIndex = target
                    }
                } else {
                    scrollIndex = target
                }

                settleScrollIndex()
                scheduleLoopResume()
            }
    }

    private func nudgeCarousel(by delta: Int, animated: Bool) {
        pauseLoopForUserInteraction()
        isScrollAnimating = true

        if animated {
            withAnimation(carouselSpring) {
                scrollIndex += CGFloat(delta)
            }
        } else {
            scrollIndex += CGFloat(delta)
        }

        settleScrollIndex()
        scheduleLoopResume()
    }

    private func pauseLoopForUserInteraction() {
        stopLoop()
        resumeLoopTask?.cancel()
        resumeLoopTask = nil
        settleTask?.cancel()
        settleTask = nil
    }

    private func scheduleLoopResume() {
        resumeLoopTask?.cancel()
        resumeLoopTask = Task {
            try? await Task.sleep(for: holdDuration)
            guard !Task.isCancelled, isActive, !isUserDragging else { return }
            startLoop()
        }
    }

    @MainActor
    private func settleScrollIndex(after delay: Duration = .milliseconds(620)) {
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, !isUserDragging else { return }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                normalizeScrollIndexIfNeeded()
            }
            isScrollAnimating = false
        }
    }

    @MainActor
    private func normalizeScrollIndexIfNeeded() {
        let count = CGFloat(features.count)
        guard count > 0 else { return }

        var normalized = scrollIndex.truncatingRemainder(dividingBy: count)
        if normalized < 0 { normalized += count }

        guard abs(normalized - scrollIndex) > 0.001 else { return }
        scrollIndex = normalized
    }

    private func cardZIndex(for relative: CGFloat, isRevealed: Bool = false) -> Double {
        if isRevealed { return 100 }
        return 10 - Double(abs(relative)) * 5
    }

    private func setImageRevealed(_ revealed: Bool) {
        guard revealed != isImageRevealed else { return }

        if revealed {
            pauseLoopForUserInteraction()
            withAnimation(revealSpring) {
                isImageRevealed = true
            }
        } else {
            withAnimation(revealSpring) {
                isImageRevealed = false
            }
            scheduleLoopResume()
        }
    }

    // MARK: - Loop

    private func startLoop() {
        stopLoop()
        guard !reduceMotion, features.count > 1 else { return }

        loopTask = Task {
            try? await Task.sleep(for: initialAdvanceDelay)
            guard !Task.isCancelled, isActive else { return }

            while !Task.isCancelled, isActive {
                await advanceCarousel()
                try? await Task.sleep(for: holdDuration)
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }

    @MainActor
    private func advanceCarousel() {
        guard features.count > 1, !isUserDragging, !isImageRevealed else { return }

        isScrollAnimating = true
        let nextIndex = scrollIndex + 1
        withAnimation(carouselSpring) {
            scrollIndex = nextIndex
        }

        settleScrollIndex()
    }

    private var carouselSpring: Animation {
        .spring(response: 0.58, dampingFraction: 0.84)
    }

    private var revealSpring: Animation {
        .spring(response: 0.44, dampingFraction: 0.86)
    }
}

// MARK: - Carousel Card

private struct OnboardingFeatureCarouselCardView: View {
    let feature: OnboardingFeature
    let relativePosition: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let shouldAmbientBob: Bool
    let isFocused: Bool
    let isRevealed: Bool
    let onRevealChanged: (Bool) -> Void

    @Environment(\.sharedPalette) private var palette
    @State private var ambientOffset: CGSize = .zero
    @State private var ambientTask: Task<Void, Never>?

    private var layout: CardLayoutMetrics {
        CardLayoutMetrics(cardWidth: cardWidth, cardHeight: cardHeight)
    }

    private var revealSpring: Animation {
        .spring(response: 0.44, dampingFraction: 0.86)
    }

    private var showsShadow: Bool {
        isRevealed || abs(relativePosition) < 0.05
    }

    var body: some View {
        ZStack {
            if isRevealed {
                heroImage(height: cardHeight, parallaxScale: 0.22)
            } else {
                cardContent
            }
        }
        .background {
            if isRevealed {
                Color.black
            } else {
                cardBackground
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                .strokeBorder(palette.lineSoft.opacity(palette.isDark ? 0.45 : 0.85), lineWidth: 1)
        )
        .shadow(
            color: showsShadow ? palette.elevation(.popover) : .clear,
            radius: isRevealed
                ? layout.focusedShadowRadius * 1.15
                : layout.focusedShadowRadius,
            y: isRevealed
                ? layout.focusedShadowY * 1.2
                : layout.focusedShadowY
        )
        .offset(ambientOffset)
        .animation(revealSpring, value: isRevealed)
        .contentShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
        .onAppear { syncAmbientBob() }
        .onChange(of: shouldAmbientBob) { _, _ in syncAmbientBob() }
        .onDisappear { stopAmbientBob() }
        .onLongPressGesture(
            minimumDuration: 0.38,
            maximumDistance: 14,
            pressing: { pressing in
                guard isFocused else { return }
                if !pressing {
                    onRevealChanged(false)
                }
            },
            perform: {
                guard isFocused else { return }
                onRevealChanged(true)
            }
        )
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isRevealed) { _, newValue in
            newValue
        }
        .accessibilityHint(isFocused ? "Long press to preview the full artwork." : "")
    }

    // MARK: - Card Layout

    /// Single stacked layout so the hero can fade and blur into copy — no hard clip seam.
    private var cardContent: some View {
        let imageSpanHeight = layout.heroHeight + layout.transitionBlendHeight

        return ZStack(alignment: .top) {
            heroImageStack(totalHeight: imageSpanHeight)
                .frame(width: cardWidth, height: imageSpanHeight, alignment: .top)
                .mask(heroFadeMask(totalHeight: imageSpanHeight))

            copyPaperBacking

            copySection
                .frame(height: layout.copyHeight, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, layout.heroHeight + layout.copySectionOffset)
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .top)
        .clipped()
    }

    private func heroImageStack(totalHeight: CGFloat, parallaxScale: CGFloat = 1) -> some View {
        heroImage(height: totalHeight, parallaxScale: parallaxScale)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: palette.surfacePaper.opacity(palette.isDark ? 0.22 : 0.28), location: 0.45),
                        .init(color: palette.surfacePaper.opacity(palette.isDark ? 0.55 : 0.62), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: layout.transitionBlendHeight * 1.6)
                .allowsHitTesting(false)
            }
    }

    private func syncAmbientBob() {
        stopAmbientBob()
        guard shouldAmbientBob else {
            ambientOffset = .zero
            return
        }

        ambientTask = Task {
            while !Task.isCancelled {
                let t = Date().timeIntervalSinceReferenceDate
                ambientOffset = CGSize(
                    width: sin(t * 0.55) * 2.5,
                    height: sin(t * 0.72 + 0.6) * 4
                )
                try? await Task.sleep(for: .milliseconds(66))
            }
        }
    }

    private func stopAmbientBob() {
        ambientTask?.cancel()
        ambientTask = nil
    }

    private func heroFadeMask(totalHeight: CGFloat) -> LinearGradient {
        let split = layout.heroHeight / totalHeight

        return LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: split * 0.94),
                .init(color: .white.opacity(0.82), location: split),
                .init(color: .white.opacity(0.18), location: min(1, split + 0.55 * (1 - split))),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Paper fill only below the blend zone — top stays clear so blurred art shows through.
    private var copyPaperBacking: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: layout.heroHeight - layout.transitionBlendHeight * 0.45)

            LinearGradient(
                stops: [
                    .init(color: palette.surfacePaper.opacity(0), location: 0),
                    .init(color: palette.surfacePaper.opacity(palette.isDark ? 0.38 : 0.48), location: 0.18),
                    .init(color: palette.surfacePaper.opacity(palette.isDark ? 0.78 : 0.86), location: 0.42),
                    .init(color: palette.surfacePaper, location: 0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: layout.copyHeight + layout.transitionBlendHeight * 0.55)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Hero

    private func heroImage(height: CGFloat, parallaxScale: CGFloat = 1) -> some View {
        Image(feature.imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: cardWidth, height: height)
            .offset(
                x: parallaxX * 0.42 * parallaxScale,
                y: parallaxY * 0.32 * parallaxScale
            )
            .frame(width: cardWidth, height: height)
            .clipped()
    }

    // MARK: - Copy

    private var copySection: some View {
        VStack(alignment: .leading, spacing: layout.textSpacing) {
            Text(feature.title)
                .font(.system(size: layout.titleFontSize, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(feature.subtitle)
                .font(.system(size: layout.subtitleFontSize, weight: .medium))
                .foregroundStyle(palette.textPrimary.opacity(palette.isDark ? 0.82 : 0.78))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(feature.description)
                .font(.system(size: layout.bodyFontSize, weight: .regular))
                .foregroundStyle(palette.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, layout.copyTopPadding)
        .padding(.bottom, layout.copyBottomPadding)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
            .fill(palette.surfacePaper.opacity(palette.isDark ? 0.9 : 1))
    }

    // MARK: - Parallax

    private var parallaxX: CGFloat {
        relativePosition * -14
    }

    private var parallaxY: CGFloat {
        relativePosition * -5
    }
}

// MARK: - Card Layout Metrics

private struct CardLayoutMetrics {
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    var heroHeightRatio: CGFloat { 0.60 }
    var copyHeightRatio: CGFloat { 0.40 }

    var heroHeight: CGFloat { cardHeight * heroHeightRatio }
    var copyHeight: CGFloat { cardHeight * copyHeightRatio }
    /// Extra space below the hero split before copy text begins.
    var copySectionOffset: CGFloat { cardHeight * 0.035 }
    /// Narrow band below the 60/40 split where hero art blurs into copy — not the full text area.
    var transitionBlendHeight: CGFloat { cardHeight * 0.10 }

    var cornerRadius: CGFloat { cardWidth * 0.074 }
    var orbSize: CGFloat { min(cardWidth * 0.42, heroHeight * 0.54) }

    var titleFontSize: CGFloat { max(18, cardWidth * 0.052) }
    var subtitleFontSize: CGFloat { max(14, cardWidth * 0.041) }
    var bodyFontSize: CGFloat { max(13, cardWidth * 0.038) }

    var horizontalPadding: CGFloat { cardWidth * 0.058 }
    var textSpacing: CGFloat { cardHeight * 0.016 }
    var copyTopPadding: CGFloat { copyHeight * 0.06 }
    var copyBottomPadding: CGFloat { copyHeight * 0.11 }

    var focusedShadowRadius: CGFloat { cardWidth * 0.062 }
    var focusedShadowY: CGFloat { cardHeight * 0.024 }
    var sideShadowRadius: CGFloat { cardWidth * 0.028 }
    var sideShadowY: CGFloat { cardHeight * 0.010 }
}
