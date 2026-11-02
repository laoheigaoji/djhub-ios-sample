import ImageIO
import CoreImage
import SwiftUI
import UIKit

/// The short brand handoff shown once per cold process launch. The real app is
/// already mounted below this view, so the final transparency animation reveals
/// live content without rebuilding the home hierarchy.
struct RoveBrandLaunchView: View {
    let onStarted: () -> Void
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoveBrandLaunchAnimator(
            reduceMotion: reduceMotion,
            onStarted: onStarted,
            onFinished: onFinished
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct RoveBrandLaunchAnimator: UIViewRepresentable {
    let reduceMotion: Bool
    let onStarted: () -> Void
    let onFinished: () -> Void

    func makeUIView(context: Context) -> RoveBrandLaunchAnimationView {
        RoveBrandLaunchAnimationView(
            reduceMotion: reduceMotion,
            onStarted: onStarted,
            onFinished: onFinished
        )
    }

    func updateUIView(_ uiView: RoveBrandLaunchAnimationView, context: Context) {}
}

@MainActor
private final class RoveBrandLaunchAnimationView: UIView {
    private let onStarted: () -> Void
    private let onFinished: () -> Void
    private let reduceMotion: Bool
    private let backdropLayer = CALayer()
    private let glowLayer = CAGradientLayer()
    private let logoLayer = CALayer()
    private let outlineContainer = CALayer()
    private let outlineGradientLayer = CAGradientLayer()
    private let outlineImageLayer = CALayer()
    private let outlineRevealLayer = CAGradientLayer()
    private let shimmerLayer = CAGradientLayer()
    private let shimmerImageLayer = CALayer()
    private let logoImage = UIImage(named: "MediaDeckBrandMark")
    private var didStart = false
    private var completionTask: Task<Void, Never>?

    init(
        reduceMotion: Bool,
        onStarted: @escaping () -> Void,
        onFinished: @escaping () -> Void
    ) {
        self.reduceMotion = reduceMotion
        self.onStarted = onStarted
        self.onFinished = onFinished
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        backgroundColor = .clear
        setupLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        completionTask?.cancel()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdropLayer.frame = bounds

        let logoSide = min(max(150, bounds.width * 0.42), 180)
        let logoFrame = CGRect(
            x: bounds.midX - logoSide / 2,
            y: bounds.midY - logoSide / 2,
            width: logoSide,
            height: logoSide
        )
        logoLayer.frame = logoFrame
        outlineContainer.frame = logoFrame
        outlineGradientLayer.frame = outlineContainer.bounds
        outlineImageLayer.frame = outlineContainer.bounds
        outlineRevealLayer.frame = outlineContainer.bounds.insetBy(dx: -12, dy: -8)
        shimmerLayer.frame = logoFrame.insetBy(dx: -logoSide, dy: 0)
        shimmerImageLayer.frame = CGRect(
            x: logoSide,
            y: 0,
            width: logoSide,
            height: logoSide
        )

        let glowSide = logoSide * 2.5
        glowLayer.frame = CGRect(
            x: bounds.midX - glowSide / 2,
            y: bounds.midY - glowSide / 2,
            width: glowSide,
            height: glowSide
        )
        glowLayer.cornerRadius = glowSide / 2
        CATransaction.commit()

        if window != nil, !didStart {
            startAnimation()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, bounds.width > 0, !didStart else { return }
        startAnimation()
    }

    private func setupLayers() {
        layer.addSublayer(backdropLayer)
        backdropLayer.backgroundColor = UIColor.black.cgColor

        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 1)
        glowLayer.colors = [
            UIColor(red: 0.08, green: 0.92, blue: 0.86, alpha: 0.22).cgColor,
            UIColor(red: 0.04, green: 0.55, blue: 0.72, alpha: 0.08).cgColor,
            UIColor.clear.cgColor
        ]
        glowLayer.locations = [0, 0.34, 1]
        glowLayer.opacity = 0
        layer.addSublayer(glowLayer)

        logoLayer.contents = logoImage?.cgImage
        logoLayer.contentsGravity = .resizeAspect
        logoLayer.opacity = 0
        logoLayer.shadowColor = UIColor(red: 0.12, green: 0.91, blue: 0.91, alpha: 1).cgColor
        logoLayer.shadowRadius = 14
        logoLayer.shadowOpacity = 0
        logoLayer.shadowOffset = .zero
        layer.addSublayer(logoLayer)

        outlineGradientLayer.colors = [
            UIColor(red: 0.48, green: 1.00, blue: 0.67, alpha: 1).cgColor,
            UIColor(red: 0.05, green: 0.92, blue: 0.96, alpha: 1).cgColor,
            UIColor(red: 0.65, green: 0.36, blue: 1.00, alpha: 1).cgColor
        ]
        outlineGradientLayer.startPoint = CGPoint(x: 0, y: 0.2)
        outlineGradientLayer.endPoint = CGPoint(x: 1, y: 0.8)
        outlineImageLayer.contents = Self.outlineImage(from: logoImage)?.cgImage
        outlineImageLayer.contentsGravity = .resizeAspect
        outlineGradientLayer.mask = outlineImageLayer
        outlineContainer.addSublayer(outlineGradientLayer)
        outlineRevealLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.cgColor,
            UIColor.white.cgColor,
            UIColor.clear.cgColor
        ]
        outlineRevealLayer.locations = [0, 0.16, 0.82, 1]
        outlineRevealLayer.startPoint = CGPoint(x: 0, y: 0.15)
        outlineRevealLayer.endPoint = CGPoint(x: 1, y: 0.85)
        outlineContainer.mask = outlineRevealLayer
        outlineContainer.opacity = 0
        layer.addSublayer(outlineContainer)

        shimmerLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.95).cgColor,
            UIColor.clear.cgColor
        ]
        shimmerLayer.locations = [0.38, 0.50, 0.62]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 1)
        shimmerImageLayer.contents = logoImage?.cgImage
        shimmerImageLayer.contentsGravity = .resizeAspect
        shimmerLayer.mask = shimmerImageLayer
        shimmerLayer.opacity = 0
        layer.addSublayer(shimmerLayer)
    }

    private func startAnimation() {
        guard !didStart else { return }
        didStart = true
        DispatchQueue.main.async { [weak self] in
            self?.onStarted()
        }

        if reduceMotion {
            logoLayer.opacity = 1
            completionTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled, let self else { return }
                UIView.animate(withDuration: 0.18, animations: {
                    self.alpha = 0
                }, completion: { [weak self] _ in self?.onFinished() })
            }
            return
        }

        animateLogo()
        animateOutline()
        animateGlowAndShimmer()

        completionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1_620))
            guard !Task.isCancelled, let self else { return }
            onFinished()
        }
    }

    private func animateLogo() {
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.14, 1, 1, 0.05, 0.05, 1, 1, 1]
        opacity.keyTimes = [0, 0.055, 0.20, 0.31, 0.57, 0.68, 0.82, 1]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.86, 1.03, 1, 0.92, 0.92, 1, 1, 1]
        scale.keyTimes = opacity.keyTimes
        scale.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeIn)
        ]

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = 1.62
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        logoLayer.add(group, forKey: "rove.brand.logo")

        let shadow = CAKeyframeAnimation(keyPath: "shadowOpacity")
        shadow.values = [0, 0, 0.78, 0.30, 0]
        shadow.keyTimes = [0, 0.52, 0.68, 0.84, 1]
        shadow.duration = 1.62
        shadow.fillMode = .forwards
        shadow.isRemovedOnCompletion = false
        logoLayer.add(shadow, forKey: "rove.brand.logoGlow")
    }

    private func animateOutline() {
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0, 1, 1, 0]
        opacity.keyTimes = [0, 0.24, 0.30, 0.67, 0.78]
        opacity.duration = 1.34
        opacity.fillMode = .forwards
        opacity.isRemovedOnCompletion = false
        outlineContainer.add(opacity, forKey: "rove.brand.outlineOpacity")

        let travel = CABasicAnimation(keyPath: "transform.translation.x")
        travel.fromValue = -outlineContainer.bounds.width * 1.05
        travel.toValue = outlineContainer.bounds.width * 1.05
        travel.beginTime = CACurrentMediaTime() + 0.40
        travel.duration = 0.62
        travel.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        travel.fillMode = .both
        travel.isRemovedOnCompletion = false
        outlineRevealLayer.add(travel, forKey: "rove.brand.trace")
    }

    private func animateGlowAndShimmer() {
        let glow = CAKeyframeAnimation(keyPath: "opacity")
        glow.values = [0, 0, 1, 0.72, 0]
        glow.keyTimes = [0, 0.28, 0.52, 0.76, 1]
        glow.duration = 1.54
        glow.fillMode = .forwards
        glow.isRemovedOnCompletion = false
        glowLayer.add(glow, forKey: "rove.brand.glow")

        let shimmerOpacity = CAKeyframeAnimation(keyPath: "opacity")
        shimmerOpacity.values = [0, 0, 0.9, 0]
        shimmerOpacity.keyTimes = [0, 0.54, 0.68, 0.82]
        shimmerOpacity.duration = 1.42
        shimmerOpacity.fillMode = .forwards
        shimmerOpacity.isRemovedOnCompletion = false
        shimmerLayer.add(shimmerOpacity, forKey: "rove.brand.shimmerOpacity")

        let shimmerTravel = CABasicAnimation(keyPath: "transform.translation.x")
        shimmerTravel.fromValue = -shimmerLayer.bounds.width * 0.35
        shimmerTravel.toValue = shimmerLayer.bounds.width * 0.35
        shimmerTravel.beginTime = CACurrentMediaTime() + 0.78
        shimmerTravel.duration = 0.34
        shimmerTravel.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmerTravel.fillMode = .both
        shimmerTravel.isRemovedOnCompletion = false
        shimmerLayer.add(shimmerTravel, forKey: "rove.brand.shimmerTravel")
    }

    private static func outlineImage(from image: UIImage?) -> UIImage? {
        guard let source = image?.cgImage else { return nil }
        let input = CIImage(cgImage: source)
        guard let monochrome = CIFilter(
            name: "CIColorMatrix",
            parameters: [
                kCIInputImageKey: input,
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ]
        )?.outputImage,
        let edge = CIFilter(
            name: "CIMorphologyGradient",
            parameters: [
                kCIInputImageKey: monochrome,
                "inputRadius": 3.2
            ]
        )?.outputImage?.cropped(to: input.extent),
        let cgImage = CIContext(options: [.cacheIntermediates: false]).createCGImage(
            edge,
            from: input.extent
        ) else { return nil }
        return UIImage(cgImage: cgImage, scale: image?.scale ?? 1, orientation: .up)
    }
}

/// First-run introduction. The poster field is a single Core Animation tree:
/// SwiftUI never receives per-frame state and the app's real root view remains mounted below it.
struct RoveLaunchCoverView: View {
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentIsVisible = false
    @State private var isDismissing = false
    @State private var currentPage = 0

    private static let pageCount = 2

    private static let pageCopy: [(title: String, subtitle: String)] = [
        ("专注短剧元数据", "汇集剧情、演员、出品商、官方徽章与家长指南。"),
        ("发现下一部好剧", "浏览 Top 200、分类与人物资料，随时搜索和收藏。")
    ]

    var body: some View {
        ZStack {
            Color(red: 0.985, green: 0.976, blue: 0.992)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let pageWidth = proxy.size.width

                ZStack {
                    ForEach(0..<Self.pageCount, id: \.self) { index in
                        launchPage(index: index, size: proxy.size)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .offset(x: CGFloat(index - currentPage) * pageWidth)
                            .accessibilityHidden(index != currentPage)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .animation(.spring(response: 0.52, dampingFraction: 0.90), value: currentPage)
            }
            .opacity(contentIsVisible ? 1 : 0)
            .ignoresSafeArea(.container, edges: .all)

            Color.white.opacity(0.10)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 116)

                VStack(spacing: 9) {
                    Text(Self.pageCopy[currentPage].title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black)

                    Text(Self.pageCopy[currentPage].subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.68))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .opacity(contentIsVisible ? 1 : 0)
                .offset(y: contentIsVisible ? 0 : 12)

                HStack(spacing: 6) {
                    ForEach(0..<Self.pageCount, id: \.self) { index in
                        Button {
                            guard currentPage != index else { return }
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                currentPage = index
                            }
                        } label: {
                            Capsule()
                                .fill(Color.black.opacity(index == currentPage ? 0.72 : 0.18))
                                .frame(width: index == currentPage ? 22 : 5, height: 4)
                                .frame(minWidth: 18, minHeight: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("第 \(index + 1) 页")
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: currentPage)
                    .padding(.top, 23)

                Button(action: advanceOrDismiss) {
                    Text(currentPage == Self.pageCount - 1 ? "开始使用" : "下一步")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color(red: 0.07, green: 0.09, blue: 0.15))
                        )
                }
                .buttonStyle(RoveLaunchButtonStyle())
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)
                .opacity(contentIsVisible ? 1 : 0)
                .offset(y: contentIsVisible ? 0 : 18)
            }
            .safeAreaPadding(.top, 8)
            .safeAreaPadding(.bottom, 8)

            VStack {
                HStack {
                    Spacer()
                    Button(action: dismiss) {
                        Text("跳过")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.68))
                            .frame(minWidth: 48, minHeight: 42)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(RoveLaunchButtonStyle())
                    .accessibilityLabel("跳过引导")
                }
                Spacer()
            }
            .safeAreaPadding(.top, 2)
            .padding(.horizontal, 10)
            .opacity(contentIsVisible ? 1 : 0)
        }
        .opacity(isDismissing ? 0 : 1)
        .onAppear {
            guard !contentIsVisible else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.72, dampingFraction: 0.84)) {
                contentIsVisible = true
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            onDismiss()
        }
    }

    private func advanceOrDismiss() {
        if currentPage < Self.pageCount - 1 {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.easeInOut(duration: 0.42)) {
                currentPage += 1
            }
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private func launchPage(index: Int, size: CGSize) -> some View {
        switch index {
        case 0:
            RoveLaunchPosterField(
                posterURLs: Self.posterURLs,
                reduceMotion: reduceMotion
            )
        default:
            RoveLaunchPosterWall(
                posterURLs: Self.posterURLs,
                reduceMotion: reduceMotion
            )
        }
    }

    private static var posterURLs: [URL] {
        []
    }
}

private struct RoveLaunchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.80), value: configuration.isPressed)
    }
}

private struct RoveMediaSourceConstellationView: View {
    private struct SourceItem: Identifiable {
        let id: Int
        let assetName: String?
        let label: String?
        let symbol: String?
        let tint: Color
        let position: CGPoint
        let size: CGFloat
    }

    let isActive: Bool
    let reduceMotion: Bool

    @State private var revealProgress: CGFloat = 0

    private let items: [SourceItem] = [
        SourceItem(id: 0, assetName: "CloudAliLogo", label: nil, symbol: nil, tint: .orange, position: CGPoint(x: 0.18, y: 0.24), size: 52),
        SourceItem(id: 1, assetName: nil, label: "SMB", symbol: nil, tint: .cyan, position: CGPoint(x: 0.68, y: 0.20), size: 54),
        SourceItem(id: 2, assetName: "JellyfinLogo", label: nil, symbol: nil, tint: .purple, position: CGPoint(x: 0.50, y: 0.35), size: 48),
        SourceItem(id: 3, assetName: "FeiniuVideoLogo", label: nil, symbol: nil, tint: .orange, position: CGPoint(x: 0.12, y: 0.46), size: 54),
        SourceItem(id: 4, assetName: "EmbyLogo", label: nil, symbol: nil, tint: .green, position: CGPoint(x: 0.33, y: 0.47), size: 48),
        SourceItem(id: 5, assetName: "Cloud115Logo", label: nil, symbol: nil, tint: .blue, position: CGPoint(x: 0.71, y: 0.45), size: 49),
        SourceItem(id: 6, assetName: nil, label: "DAV", symbol: nil, tint: .cyan, position: CGPoint(x: 0.88, y: 0.47), size: 48),
        SourceItem(id: 7, assetName: "Cloud123Logo", label: nil, symbol: nil, tint: .indigo, position: CGPoint(x: 0.28, y: 0.57), size: 47),
        SourceItem(id: 8, assetName: "ZSpaceLogo", label: nil, symbol: nil, tint: .purple, position: CGPoint(x: 0.56, y: 0.55), size: 46),
        SourceItem(id: 9, assetName: nil, label: nil, symbol: "folder", tint: .indigo, position: CGPoint(x: 0.81, y: 0.59), size: 45)
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let source = CGPoint(x: size.width * 0.50, y: min(size.height * 0.68, 570))

            ZStack {
                ForEach(items) { item in
                    let end = CGPoint(
                        x: size.width * item.position.x,
                        y: size.height * item.position.y
                    )
                    let localProgress = itemProgress(for: item.id)

                    RoveSourceConnectionShape(
                        source: source,
                        destination: end,
                        progress: localProgress
                    )
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.10), Color.indigo.opacity(0.30)],
                            startPoint: .bottom,
                            endPoint: .top
                        ),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                    )

                    sourceIcon(item)
                        .frame(width: item.size, height: item.size)
                        .scaleEffect(0.36 + localProgress * 0.64)
                        .opacity(localProgress)
                        .position(end)
                        .shadow(color: item.tint.opacity(0.17 * localProgress), radius: 12, y: 5)

                    Circle()
                        .fill(Color.cyan.opacity(0.36 * localProgress))
                        .frame(width: 5, height: 5)
                        .blur(radius: 2)
                        .position(
                            x: source.x + (end.x - source.x) * (0.30 + CGFloat(item.id % 3) * 0.16),
                            y: source.y + (end.y - source.y) * (0.30 + CGFloat(item.id % 3) * 0.16)
                        )
                }

                Image("MediaDeckBrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                    .scaleEffect(0.74 + revealProgress * 0.26)
                    .opacity(revealProgress)
                    .shadow(color: Color.cyan.opacity(0.30), radius: 20)
                    .position(x: source.x, y: source.y + 32)
            }
        }
        .onAppear { updateAnimation(active: isActive) }
        .onChange(of: isActive) { _, active in
            updateAnimation(active: active)
        }
    }

    @ViewBuilder
    private func sourceIcon(_ item: SourceItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.88))

            if let assetName = item.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(7)
            } else if let label = item.label {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [item.tint.opacity(0.94), item.tint.opacity(0.58)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(label)
                    .font(.system(size: label == "SMB" ? 13 : 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else if let symbol = item.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(item.tint)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
    }

    private func itemProgress(for index: Int) -> CGFloat {
        let delayed = (revealProgress - CGFloat(index) * 0.035) / 0.68
        return min(max(delayed, 0), 1)
    }

    private func updateAnimation(active: Bool) {
        guard active else {
            withAnimation(.none) { revealProgress = 0 }
            return
        }
        if reduceMotion {
            revealProgress = 1
            return
        }
        withAnimation(.none) { revealProgress = 0 }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 1.25)) {
                revealProgress = 1
            }
        }
    }
}

private struct RoveSourceConnectionShape: Shape {
    let source: CGPoint
    let destination: CGPoint
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: source)
        let controlY = source.y - max(68, abs(source.y - destination.y) * 0.52)
        path.addCurve(
            to: destination,
            control1: CGPoint(x: source.x + (destination.x - source.x) * 0.14, y: controlY),
            control2: CGPoint(x: destination.x, y: destination.y + 54)
        )
        return path.trimmedPath(from: 0, to: min(max(progress, 0), 1))
    }
}

private struct RoveRecognitionRevealView: View {
    let isActive: Bool
    let reduceMotion: Bool

    @State private var revealProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(proxy.size.width * 0.79, 320)
            let cardHeight = min(cardWidth * 1.28, proxy.size.height * 0.55)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.76))

                RoveContourPatternView()
                    .opacity(0.55)

                recognitionContent
                    .padding(.horizontal, 22)
                    .padding(.vertical, 22)
                    .mask(RoveDiagonalRevealShape(progress: revealProgress))

                RoveDiagonalSweepShape(progress: revealProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.clear, .white, .cyan.opacity(0.85), .white, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                    )
                    .shadow(color: .cyan.opacity(0.66), radius: 10)
                    .opacity(sin(Double.pi * Double(revealProgress)))
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.84), lineWidth: 1)
            )
            .shadow(color: Color.indigo.opacity(0.12), radius: 22, y: 13)
            .scaleEffect(0.975 + revealProgress * 0.025)
            .position(x: proxy.size.width / 2, y: min(proxy.size.height * 0.40, 345))
        }
        .onAppear { updateAnimation(active: isActive) }
        .onChange(of: isActive) { _, active in
            updateAnimation(active: active)
        }
    }

    private var recognitionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let poster = RoveBundledLaunchPosters.images.first {
                    Image(uiImage: poster)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [.black, .orange.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: 144, height: 205)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(maxWidth: .infinity)

            Text("光影档案")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))

            Text("2026 · 2 小时 18 分\n剧情 / 科幻 / 冒险")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.28, blue: 0.34))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                ratingBadge("TMDB", value: "8.7", color: .green)
                ratingBadge("IMDb", value: "8.4", color: .yellow)
                ratingBadge("新鲜", value: "93%", color: .red)
            }

            Text("自动整理作品信息，并将海报、评分和简介完整呈现。")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.30, green: 0.33, blue: 0.39))
                .lineLimit(2)
        }
    }

    private func ratingBadge(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(color, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.22))
        }
    }

    private func updateAnimation(active: Bool) {
        guard active else {
            withAnimation(.none) { revealProgress = 0 }
            return
        }
        if reduceMotion {
            revealProgress = 1
            return
        }
        withAnimation(.none) { revealProgress = 0 }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 2.25)) {
                revealProgress = 1
            }
        }
    }
}

private struct RoveContourPatternView: View {
    var body: some View {
        Canvas { context, size in
            let ink = Color(red: 0.56, green: 0.67, blue: 0.79).opacity(0.22)
            let spacing: CGFloat = 38
            let rows = Int(size.height / spacing) + 2
            let columns = Int(size.width / spacing) + 2

            for row in 0..<rows {
                for column in 0..<columns {
                    let center = CGPoint(
                        x: CGFloat(column) * spacing + (row.isMultiple(of: 2) ? 0 : spacing / 2),
                        y: CGFloat(row) * spacing
                    )
                    for radius in stride(from: CGFloat(8), through: CGFloat(32), by: 8) {
                        let rect = CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.stroke(Path(ellipseIn: rect), with: .color(ink), lineWidth: 0.75)
                    }
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.60), Color(red: 0.89, green: 0.94, blue: 0.98).opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct RoveDiagonalRevealShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        let threshold = clamped * (rect.width + rect.height)
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: min(threshold, rect.width), y: 0))
        if threshold > rect.width {
            path.addLine(to: CGPoint(x: rect.width, y: min(threshold - rect.width, rect.height)))
        }
        if threshold > rect.height {
            path.addLine(to: CGPoint(x: min(threshold - rect.height, rect.width), y: rect.height))
        }
        path.addLine(to: CGPoint(x: 0, y: min(threshold, rect.height)))
        path.closeSubpath()
        return path
    }
}

private struct RoveDiagonalSweepShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let threshold = min(max(progress, 0), 1) * (rect.width + rect.height)
        var intersections: [CGPoint] = []
        if threshold >= 0, threshold <= rect.width {
            intersections.append(CGPoint(x: threshold, y: 0))
        }
        if threshold >= rect.width, threshold <= rect.width + rect.height {
            intersections.append(CGPoint(x: rect.width, y: threshold - rect.width))
        }
        if threshold >= rect.height, threshold <= rect.width + rect.height {
            intersections.append(CGPoint(x: threshold - rect.height, y: rect.height))
        }
        if threshold >= 0, threshold <= rect.height {
            intersections.append(CGPoint(x: 0, y: threshold))
        }

        var path = Path()
        guard let first = intersections.first, let last = intersections.last else { return path }
        path.move(to: first)
        path.addLine(to: last)
        return path
    }
}

private struct RoveLaunchPosterField: UIViewRepresentable {
    let posterURLs: [URL]
    let reduceMotion: Bool

    func makeUIView(context: Context) -> RoveLaunchPosterFieldView {
        RoveLaunchPosterFieldView(posterURLs: posterURLs, reduceMotion: reduceMotion)
    }

    func updateUIView(_ uiView: RoveLaunchPosterFieldView, context: Context) {
        uiView.setReduceMotion(reduceMotion)
    }
}

@MainActor
private final class RoveLaunchPosterFieldView: UIView {
    private struct ParticleSpec {
        let latitude: CGFloat
        let longitude: CGFloat
        let width: CGFloat
    }

    // A Fibonacci sphere keeps the posters evenly distributed on one closed
    // surface. Rotating only the shared longitude makes the whole field read
    // as a single globe instead of unrelated cards drifting in horizontal rows.
    private static let particleSpecs: [ParticleSpec] = {
        let count = 24
        let goldenAngle = CGFloat.pi * (3 - sqrt(5.0))
        return (0..<count).map { index in
            let progress = (CGFloat(index) + 0.5) / CGFloat(count)
            let normalizedY = 0.92 - progress * 1.84
            return ParticleSpec(
                latitude: asin(normalizedY),
                longitude: CGFloat(index) * goldenAngle,
                width: 0.132 + CGFloat((index * 7) % 5) * 0.006
            )
        }
    }()

    private let posterURLs: [URL]
    private let orbitLayer = CALayer()
    private var particles: [RoveLaunchPosterParticleLayer] = []
    private var imageTasks: [Task<Void, Never>] = []
    private var reduceMotion: Bool
    private var lastLayoutSize: CGSize = .zero
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var rotation: CGFloat = 0
    private var angularVelocity: CGFloat = 0
    private var dragStartRotation: CGFloat = 0
    private var isDragging = false

    init(posterURLs: [URL], reduceMotion: Bool) {
        self.posterURLs = posterURLs
        self.reduceMotion = reduceMotion
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        backgroundColor = .clear
        clipsToBounds = true

        layer.addSublayer(orbitLayer)
        createParticles()
        applyBundledPosterImages()
        loadPosterImages()

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        imageTasks.forEach { $0.cancel() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            displayLink?.invalidate()
            displayLink = nil
        } else {
            startDisplayLinkIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, bounds.size != lastLayoutSize else { return }
        lastLayoutSize = bounds.size
        layoutPosterField()
    }

    func setReduceMotion(_ value: Bool) {
        guard reduceMotion != value else { return }
        reduceMotion = value
        angularVelocity = 0
        if value {
            displayLink?.invalidate()
            displayLink = nil
        } else {
            startDisplayLinkIfNeeded()
        }
        updateParticlePositions()
    }

    private func createParticles() {
        particles = Self.particleSpecs.enumerated().map { index, _ in
            let particle = RoveLaunchPosterParticleLayer(seed: index)
            orbitLayer.addSublayer(particle)
            return particle
        }
    }

    private func layoutPosterField() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        orbitLayer.frame = bounds
        for (index, particle) in particles.enumerated() {
            let spec = Self.particleSpecs[index]
            let posterWidth = max(42, bounds.width * spec.width)
            particle.bounds = CGRect(x: 0, y: 0, width: posterWidth, height: posterWidth * 1.48)
        }
        CATransaction.commit()
        updateParticlePositions()
        startDisplayLinkIfNeeded()
    }

    private func startDisplayLinkIfNeeded() {
        guard !reduceMotion, window != nil, displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(advanceOrbit(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func advanceOrbit(_ link: CADisplayLink) {
        guard !reduceMotion else { return }
        defer { lastFrameTimestamp = link.timestamp }
        guard lastFrameTimestamp > 0 else { return }
        let delta = min(max(link.timestamp - lastFrameTimestamp, 0), 1.0 / 20.0)
        guard !isDragging else { return }

        if abs(angularVelocity) > 0.012 {
            rotation += angularVelocity * delta
            angularVelocity *= CGFloat(pow(0.065, delta))
        } else {
            angularVelocity = 0
            rotation += 0.095 * delta
        }
        normalizeRotation()
        updateParticlePositions()
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard bounds.width > 0 else { return }
        switch recognizer.state {
        case .began:
            isDragging = true
            angularVelocity = 0
            dragStartRotation = rotation
        case .changed:
            let translation = recognizer.translation(in: self).x
            rotation = dragStartRotation - (translation / bounds.width) * (.pi * 2.2)
            normalizeRotation()
            updateParticlePositions()
        case .ended, .cancelled:
            let velocity = recognizer.velocity(in: self).x
            angularVelocity = min(max(-(velocity / bounds.width) * (.pi * 2.2), -5.2), 5.2)
            isDragging = false
            startDisplayLinkIfNeeded()
        default:
            break
        }
    }

    private func normalizeRotation() {
        let fullTurn = CGFloat.pi * 2
        if rotation > fullTurn || rotation < -fullTurn {
            rotation.formTruncatingRemainder(dividingBy: fullTurn)
        }
    }

    private func updateParticlePositions() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let horizontalRadius = bounds.width * 0.64
        let verticalRadius = min(bounds.height * 0.31, bounds.width * 0.86)
        let center = CGPoint(x: bounds.midX, y: bounds.height * 0.38)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, particle) in particles.enumerated() {
            let spec = Self.particleSpecs[index]
            let longitude = spec.longitude + rotation
            let latitudeRadius = cos(spec.latitude)
            let projectedDepth = latitudeRadius * cos(longitude)
            let depth = (projectedDepth + 1) * 0.5
            let scale = 0.56 + depth * 0.82

            particle.position = CGPoint(
                x: center.x + latitudeRadius * sin(longitude) * horizontalRadius,
                y: center.y - sin(spec.latitude) * verticalRadius
            )
            particle.zPosition = projectedDepth * 1_000
            particle.updateOrbit(
                scale: scale,
                opacity: Float(0.12 + depth * 0.86),
                tilt: sin(longitude) * -0.035
            )
        }
        CATransaction.commit()
    }

    private func loadPosterImages() {
        guard !posterURLs.isEmpty else { return }
        for (urlIndex, url) in posterURLs.enumerated() {
            let task = Task { [weak self] in
                guard let bitmap = await RoveLaunchPosterLoader.shared.image(for: url) else { return }
                guard !Task.isCancelled, let self else { return }
                self.apply(bitmap.image, forURLIndex: urlIndex)
            }
            imageTasks.append(task)
        }
    }

    private func applyBundledPosterImages() {
        let images = RoveBundledLaunchPosters.images
        guard !images.isEmpty else { return }
        for (index, particle) in particles.enumerated() {
            particle.setImage(
                images[index % images.count],
                revealDelay: Double(index % 8) * 0.035
            )
        }
    }

    private func apply(_ image: UIImage, forURLIndex urlIndex: Int) {
        let matchingIndices = particles.indices.filter { $0 % posterURLs.count == urlIndex }
        for index in matchingIndices {
            particles[index].setImage(image, revealDelay: Double(index % 7) * 0.08)
        }
    }
}

private struct RoveLaunchPosterWall: UIViewRepresentable {
    let posterURLs: [URL]
    let reduceMotion: Bool

    func makeUIView(context: Context) -> RoveLaunchPosterWallView {
        RoveLaunchPosterWallView(posterURLs: posterURLs, reduceMotion: reduceMotion)
    }

    func updateUIView(_ uiView: RoveLaunchPosterWallView, context: Context) {
        uiView.setReduceMotion(reduceMotion)
    }
}

@MainActor
private final class RoveLaunchPosterWallView: UIView {
    private static let tileCount = 48
    private static let scrollAnimationKey = "rove.launch.poster-wall.scroll"

    private let posterURLs: [URL]
    private let rotatedLayer = CALayer()
    private let scrollLayer = CALayer()
    private let firstGridLayer = CALayer()
    private let secondGridLayer = CALayer()
    private var firstTiles: [CALayer] = []
    private var secondTiles: [CALayer] = []
    private var imageTasks: [Task<Void, Never>] = []
    private var reduceMotion: Bool
    private var lastLayoutSize: CGSize = .zero
    private var gridHeight: CGFloat = 0

    init(posterURLs: [URL], reduceMotion: Bool) {
        self.posterURLs = posterURLs
        self.reduceMotion = reduceMotion
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true

        layer.addSublayer(rotatedLayer)
        rotatedLayer.addSublayer(scrollLayer)
        scrollLayer.addSublayer(firstGridLayer)
        scrollLayer.addSublayer(secondGridLayer)
        createTiles()
        applyBundledPosterImages()
        loadPosterImages()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        imageTasks.forEach { $0.cancel() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, bounds.size != lastLayoutSize else { return }
        lastLayoutSize = bounds.size
        layoutWall()
    }

    func setReduceMotion(_ value: Bool) {
        guard reduceMotion != value else { return }
        reduceMotion = value
        updateScrollAnimation()
    }

    private func createTiles() {
        firstTiles = (0..<Self.tileCount).map { index in
            let tile = makeTile(seed: index)
            firstGridLayer.addSublayer(tile)
            return tile
        }
        secondTiles = (0..<Self.tileCount).map { index in
            let tile = makeTile(seed: index)
            secondGridLayer.addSublayer(tile)
            return tile
        }
    }

    private func makeTile(seed: Int) -> CALayer {
        let palette: [UIColor] = [
            UIColor(red: 0.82, green: 0.90, blue: 0.98, alpha: 1),
            UIColor(red: 0.96, green: 0.82, blue: 0.87, alpha: 1),
            UIColor(red: 0.84, green: 0.92, blue: 0.84, alpha: 1),
            UIColor(red: 0.91, green: 0.86, blue: 0.97, alpha: 1),
            UIColor(red: 0.98, green: 0.91, blue: 0.78, alpha: 1)
        ]
        let tile = CALayer()
        tile.backgroundColor = palette[seed % palette.count].cgColor
        tile.contentsGravity = .resizeAspectFill
        tile.minificationFilter = .trilinear
        tile.cornerRadius = 9
        tile.masksToBounds = true
        tile.opacity = 0
        return tile
    }

    private func layoutWall() {
        let expandedWidth = max(bounds.width * 1.55, 590)
        let expandedHeight = bounds.height * 1.45
        let columnCount = bounds.width >= 700 ? 7 : 5
        let gap: CGFloat = bounds.width >= 700 ? 18 : 13
        let tileWidth = (expandedWidth - gap * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        let tileHeight = tileWidth * 1.50
        let rowHeight = tileHeight + gap
        let requiredRows = Int(ceil(expandedHeight / rowHeight)) + 2
        let rowCount = min(max(requiredRows, 7), Self.tileCount / columnCount)
        gridHeight = CGFloat(rowCount) * rowHeight

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rotatedLayer.bounds = CGRect(x: 0, y: 0, width: expandedWidth, height: expandedHeight)
        rotatedLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        rotatedLayer.setAffineTransform(CGAffineTransform(rotationAngle: -.pi / 17))
        scrollLayer.frame = CGRect(x: 0, y: -rowHeight, width: expandedWidth, height: gridHeight * 2)
        firstGridLayer.frame = CGRect(x: 0, y: 0, width: expandedWidth, height: gridHeight)
        secondGridLayer.frame = CGRect(x: 0, y: gridHeight, width: expandedWidth, height: gridHeight)

        for index in 0..<Self.tileCount {
            let row = index / columnCount
            let column = index % columnCount
            let isVisible = row < rowCount
            let stagger = row.isMultiple(of: 2) ? -tileWidth * 0.30 : tileWidth * 0.18
            let tileFrame = CGRect(
                x: CGFloat(column) * (tileWidth + gap) + stagger,
                y: CGFloat(row) * rowHeight,
                width: tileWidth,
                height: tileHeight
            )
            firstTiles[index].frame = tileFrame
            secondTiles[index].frame = tileFrame
            firstTiles[index].isHidden = !isVisible
            secondTiles[index].isHidden = !isVisible
        }
        CATransaction.commit()
        updateScrollAnimation()
    }

    private func updateScrollAnimation() {
        scrollLayer.removeAnimation(forKey: Self.scrollAnimationKey)
        guard gridHeight > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scrollLayer.setAffineTransform(reduceMotion ? CGAffineTransform(translationX: 0, y: -gridHeight * 0.14) : .identity)
        CATransaction.commit()
        guard !reduceMotion else { return }

        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = 0
        animation.toValue = -gridHeight
        animation.duration = 64
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        scrollLayer.add(animation, forKey: Self.scrollAnimationKey)
    }

    private func loadPosterImages() {
        guard !posterURLs.isEmpty else { return }
        for (urlIndex, url) in posterURLs.enumerated() {
            let task = Task { [weak self] in
                guard let bitmap = await RoveLaunchPosterLoader.shared.image(for: url) else { return }
                guard !Task.isCancelled, let self else { return }
                self.apply(bitmap.image, forURLIndex: urlIndex)
            }
            imageTasks.append(task)
        }
    }

    private func applyBundledPosterImages() {
        let images = RoveBundledLaunchPosters.images
        guard !images.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for index in firstTiles.indices {
            let image = images[index % images.count]
            firstTiles[index].contents = image.cgImage
            secondTiles[index].contents = image.cgImage
            firstTiles[index].opacity = 0.80
            secondTiles[index].opacity = 0.80
        }
        CATransaction.commit()
    }

    private func apply(_ image: UIImage, forURLIndex urlIndex: Int) {
        let matchingIndices = firstTiles.indices.filter { $0 % posterURLs.count == urlIndex }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.42)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        for index in matchingIndices {
            firstTiles[index].contents = image.cgImage
            secondTiles[index].contents = image.cgImage
            firstTiles[index].opacity = 0.80
            secondTiles[index].opacity = 0.80
        }
        CATransaction.commit()
    }
}

private final class RoveLaunchPosterParticleLayer: CALayer {
    private let imageLayer = CALayer()
    private var targetOpacity: Float = 0.5
    private var hasImage = false

    init(seed: Int) {
        super.init()
        let palette: [UIColor] = [
            UIColor(red: 0.82, green: 0.90, blue: 0.98, alpha: 1),
            UIColor(red: 0.96, green: 0.82, blue: 0.87, alpha: 1),
            UIColor(red: 0.84, green: 0.92, blue: 0.84, alpha: 1),
            UIColor(red: 0.91, green: 0.86, blue: 0.97, alpha: 1),
            UIColor(red: 0.98, green: 0.91, blue: 0.78, alpha: 1)
        ]
        backgroundColor = palette[seed % palette.count].cgColor
        cornerRadius = 9
        shadowColor = UIColor.black.cgColor
        shadowOpacity = 0.14
        shadowRadius = 8
        shadowOffset = CGSize(width: 0, height: 5)
        opacity = 0

        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.minificationFilter = .trilinear
        imageLayer.magnificationFilter = .trilinear
        imageLayer.masksToBounds = true
        imageLayer.cornerRadius = cornerRadius
        imageLayer.opacity = 0
        addSublayer(imageLayer)
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let source = layer as? RoveLaunchPosterParticleLayer {
            targetOpacity = source.targetOpacity
            hasImage = source.hasImage
            imageLayer.contents = source.imageLayer.contents
            imageLayer.contentsGravity = source.imageLayer.contentsGravity
            imageLayer.opacity = source.imageLayer.opacity
            imageLayer.cornerRadius = source.imageLayer.cornerRadius
        } else {
            targetOpacity = 0.5
            imageLayer.contentsGravity = .resizeAspectFill
            imageLayer.cornerRadius = 9
        }
        imageLayer.masksToBounds = true
        addSublayer(imageLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        imageLayer.frame = bounds
        shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    func setImage(_ image: UIImage, revealDelay: CFTimeInterval) {
        hasImage = true
        imageLayer.contents = image.cgImage
        imageLayer.opacity = 1
        opacity = targetOpacity

        let reveal = CAAnimationGroup()
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = targetOpacity
        let rise = CABasicAnimation(keyPath: "transform.scale")
        rise.fromValue = 0.72
        rise.toValue = 1
        reveal.animations = [fade, rise]
        reveal.beginTime = CACurrentMediaTime() + revealDelay
        reveal.duration = 0.72
        reveal.fillMode = .backwards
        reveal.timingFunction = CAMediaTimingFunction(name: .easeOut)
        reveal.isRemovedOnCompletion = true
        add(reveal, forKey: "rove.launch.poster-field.reveal")
    }

    func updateOrbit(scale: CGFloat, opacity: Float, tilt: CGFloat) {
        targetOpacity = opacity
        self.opacity = hasImage ? opacity : 0
        var transform = CATransform3DMakeScale(scale, scale, 1)
        transform = CATransform3DRotate(transform, tilt, 0, 0, 1)
        self.transform = transform
        shadowOpacity = hasImage ? min(0.24, opacity * 0.25) : 0
        shadowRadius = 5 + 7 * scale
        shadowOffset = CGSize(width: 0, height: 3 + 4 * scale)
    }
}

private struct RoveLaunchPosterBitmap: @unchecked Sendable {
    let image: UIImage
}

@MainActor
private enum RoveBundledLaunchPosters {
    static let images: [UIImage] = {
        guard let directory = Bundle.main.resourceURL?.appendingPathComponent(
            "DJHUBPosters",
            isDirectory: true
        ), let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return urls
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { UIImage(contentsOfFile: $0.path) }
    }()
}

private actor RoveLaunchPosterLoader {
    static let shared = RoveLaunchPosterLoader()

    private let memory = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private var inFlight: [URL: Task<RoveLaunchPosterBitmap?, Never>] = [:]

    private init() {
        memory.countLimit = 24
        memory.totalCostLimit = 12 * 1_024 * 1_024
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache.shared
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.timeoutIntervalForRequest = 8
        session = URLSession(configuration: configuration)
    }

    func image(for url: URL) async -> RoveLaunchPosterBitmap? {
        if let image = memory.object(forKey: url as NSURL) {
            return RoveLaunchPosterBitmap(image: image)
        }
        if let task = inFlight[url] {
            return await task.value
        }

        let session = session
        let task = Task<RoveLaunchPosterBitmap?, Never> {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            guard let (data, response) = try? await session.data(for: request),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false
            else { return nil }

            return await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 360,
                    kCGImageSourceShouldCacheImmediately: true
                ]
                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                else { return nil }
                return RoveLaunchPosterBitmap(image: UIImage(cgImage: cgImage))
            }.value
        }
        inFlight[url] = task
        let bitmap = await task.value
        inFlight[url] = nil
        if let bitmap {
            memory.setObject(bitmap.image, forKey: url as NSURL, cost: bitmap.image.jpegData(compressionQuality: 0.5)?.count ?? 0)
        }
        return bitmap
    }
}
