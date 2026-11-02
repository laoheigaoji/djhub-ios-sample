import SwiftUI

#if DJHUB_METADATA_ONLY
private enum PlaybackProgressStore {
    static func clear(for channel: Channel) {}
}

private struct ChannelLogoView: View {
    @Environment(\.colorScheme) private var colorScheme
    let channel: Channel
    var placeholderSystemName = "play.tv.fill"
    var prefersLightOverride: Bool? = nil
    var placeholderColor: Color = .secondary
    var placeholderScale: CGFloat = 1
    @State private var remoteImage: UIImage?

    var body: some View {
        Group {
            if let image = ChannelLogoProvider.image(
                for: channel,
                prefersLight: prefersLightOverride ?? (colorScheme == .dark)
            ) {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let remoteImage {
                Image(uiImage: remoteImage).resizable().scaledToFit()
            } else {
                Image(systemName: placeholderSystemName)
                    .foregroundStyle(placeholderColor)
                    .scaleEffect(placeholderScale)
            }
        }
        .task(id: channel) {
            remoteImage = await ChannelArtworkLoader.shared.image(for: channel)
        }
    }
}

private struct EmbyCollectionCard: View {
    let configurationID: UUID
    let collection: MetadataLibraryCollection
    let width: CGFloat?
    let displaysPosterStrip: Bool

    init(
        configurationID: UUID,
        collection: MetadataLibraryCollection,
        width: CGFloat? = nil,
        displaysPosterStrip: Bool = false
    ) {
        self.configurationID = configurationID
        self.collection = collection
        self.width = width
        self.displaysPosterStrip = displaysPosterStrip
    }

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            Image(systemName: "rectangle.stack.fill")
                .foregroundStyle(.secondary)
        }
        .frame(width: width)
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EmbyCollectionView: View {
    let configurationID: UUID
    let collection: MetadataLibraryCollection
    @Binding var selectedChannel: Channel?

    init(
        configurationID: UUID,
        collection: MetadataLibraryCollection,
        selectedChannel: Binding<Channel?>,
        parentID: String? = nil,
        genre: String? = nil,
        showsSections: Bool = true,
        prefersSeries: Bool? = nil,
        initialChannels: [Channel] = []
    ) {
        self.configurationID = configurationID
        self.collection = collection
        _selectedChannel = selectedChannel
    }

    var body: some View {
        Color.black.ignoresSafeArea()
    }
}

private struct RoveServerBrandIcon: View {
    let configuration: PlaylistConfiguration
    let size: CGFloat

    var body: some View {
        Image(systemName: configuration.kind.systemImage)
            .font(.system(size: size * 0.52, weight: .bold))
            .frame(width: size, height: size)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
    }
}

private extension Color {
    static let roadCard = Color(uiColor: .secondarySystemBackground)
}

private enum ProxyNetworkConfiguration {
    static func ephemeral() -> URLSessionConfiguration { .ephemeral }
    static func configured(_ configuration: URLSessionConfiguration) -> URLSessionConfiguration { configuration }
}

private enum RoveAIProvider: String, CaseIterable, Identifiable {
    case deepSeek = "deepseek"
    case miniMax = "minimax"
    var id: String { rawValue }
    var title: String { self == .deepSeek ? "DeepSeek" : "MiniMax" }
}

private final class RoveDeepSeekService: @unchecked Sendable {
    static let shared = RoveDeepSeekService()
    static let providerDefaultsKey = "djhub.disabled.ai.provider"
    static let baseURLDefaultsKey = "djhub.disabled.ai.url"
    static let modelDefaultsKey = "djhub.disabled.ai.model"
    static let miniMaxBaseURLDefaultsKey = "djhub.disabled.ai.minimax.url"
    static let miniMaxModelDefaultsKey = "djhub.disabled.ai.minimax.model"
    static let recommendationsEnabledKey = "djhub.disabled.ai.recommendations"
    var provider: RoveAIProvider { .deepSeek }
    var hasAPIKey: Bool { false }
    var configuredProviderTitle: String { "未启用" }
    func saveAPIKey(_ value: String) throws {}
    func deleteAPIKey() {}
    func testConnection() async throws {}
    func recommendedNames(history: [Channel], favorites: [Channel] = [], candidates: [Channel]) async throws -> [String] { [] }
}

@MainActor
private final class MetadataSyncA: ObservableObject {
    static let shared = MetadataSyncA()
    static let syncEnabledDefaultsKey = "djhub.disabled.trakt"
    func setWatched(_ watched: Bool, channel: Channel) async {}
}

@MainActor
private final class MetadataSyncB: ObservableObject {
    static let shared = MetadataSyncB()
    static let syncEnabledDefaultsKey = "djhub.disabled.simkl"
    func setWatched(_ watched: Bool, channel: Channel) async {}
}

#endif
import UniformTypeIdentifiers
import CoreTransferable
import CryptoKit
import LocalAuthentication
import PDFKit
@preconcurrency import Translation

enum RoveMotion {
    static let quick = Animation.snappy(duration: 0.18, extraBounce: 0.03)
    static let press = Animation.spring(duration: 0.22, bounce: 0.16)
    static let layout = Animation.spring(duration: 0.38, bounce: 0.10)
    static let reveal = Animation.spring(duration: 0.46, bounce: 0.08)
    static let carousel = Animation.smooth(duration: 0.34)
}

/// Large poster titles use the bundled poster face from the first polished
/// carousel treatment. Keeping one proven display face avoids mixing brush
/// and calligraphy glyphs across titles while still staying away from the
/// system font stack.
enum RovePosterTitleStyle {
    static func font(size: CGFloat, seed: String = "") -> Font {
        _ = seed
        return .custom("ZCOOL QingKe HuangYou", size: size)
    }

    static func color(seed: String) -> Color {
        let value = seed.unicodeScalars.reduce(into: 0) { result, scalar in
            result = (result &* 31) &+ Int(scalar.value)
        }
        let palette: [Color] = [
            Color(red: 1.00, green: 0.82, blue: 0.08),
            Color(red: 1.00, green: 0.38, blue: 0.02),
            Color(red: 0.82, green: 1.00, blue: 0.02),
            Color(red: 0.19, green: 0.91, blue: 0.96),
            Color(red: 1.00, green: 0.40, blue: 0.64)
        ]
        return palette[abs(value) % palette.count]
    }
}

enum RoveAPISettings {
    static let tmdbAPIAddressKey = "rove.api.tmdb.address.v1"
    static let tmdbImageAddressKey = "rove.api.tmdb.image-address.v1"
    static let reverseProxyAddressesKey = "rove.api.reverse-proxy-addresses.v1"

    static let defaultTMDBAPIAddress = "https://api.tmdb.org/3"
    static let defaultTMDBImageAddress = "https://image.tmdb.org/t/p"

    static var tmdbAPIAddress: String {
        normalized(UserDefaults.standard.string(forKey: tmdbAPIAddressKey))
            ?? defaultTMDBAPIAddress
    }

    static var tmdbImageAddress: String {
        normalized(UserDefaults.standard.string(forKey: tmdbImageAddressKey))
            ?? defaultTMDBImageAddress
    }

    static var reverseProxyAddresses: [String] {
        (UserDefaults.standard.stringArray(forKey: reverseProxyAddressesKey) ?? [])
            .compactMap { normalized($0) }
    }

    static func tmdbAPIURL(path: String) -> URL? {
        guard var base = URL(string: tmdbAPIAddress) else { return nil }
        if !base.path.lowercased().hasSuffix("/3") {
            base.appendPathComponent("3")
        }
        return path.split(separator: "/").reduce(base) {
            $0.appendingPathComponent(String($1))
        }
    }

    static func tmdbImageURL(size: String, path: String) -> URL? {
        guard let base = URL(string: tmdbImageAddress) else { return nil }
        return base
            .appendingPathComponent(size)
            .appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false else { return nil }
        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

private struct RoveMotionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(reduceMotion ? nil : RoveMotion.press, value: configuration.isPressed)
    }
}

private struct RoveHomePullOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct RoveHomePullProbe: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: RoveHomePullOffsetKey.self,
                value: max(0, geometry.frame(in: .named("rove-home-scroll")).minY)
            )
        }
        .frame(height: 0)
    }
}

private struct RoveElasticRefreshIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: CGFloat
    let isRefreshing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !isRefreshing || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = isRefreshing ? time * 5.4 : Double(progress) * .pi * 0.72
            let pulse = isRefreshing ? sin(phase * 1.7) : 0
            let clamped = min(max(progress, 0), 1)

            ZStack {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.96, blue: 0.42),
                                Color(red: 0.55, green: 0.96, blue: 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 20)
                    .scaleEffect(
                        x: isRefreshing ? 0.78 + pulse * 0.18 : 0.58 + clamped * 0.42,
                        y: isRefreshing ? 1.05 - pulse * 0.14 : 0.72 + clamped * 0.28
                    )
                    .rotationEffect(.radians(phase))

                Circle()
                    .fill(Color(red: 0.10, green: 0.83, blue: 0.72).opacity(0.92))
                    .frame(width: 10, height: 10)
                    .offset(x: isRefreshing ? cos(phase) * 11 : -8 + clamped * 5)
                    .blendMode(.plusLighter)
            }
            .frame(width: 42, height: 42)
            .scaleEffect(isRefreshing ? 1 : 0.42 + clamped * 0.58)
            .opacity(isRefreshing ? 1 : Double(clamped))
            .shadow(color: Color.green.opacity(0.28), radius: 8, y: 3)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel(isRefreshing ? "正在刷新" : "下拉刷新")
    }
}

private enum RoveDiscoveryCategoryCardStyle {
    case featured
    case posterMatrix
}

private struct RoveDiscoveryCategoryPage: Identifiable {
    let shelf: TMDBFeaturedMovie.Shelf
    let title: String
    let style: RoveDiscoveryCategoryCardStyle

    var id: String { "\(shelf.id)-\(title)" }
}

private struct RoveStreamingPlatform: Identifiable {
    enum Brand: String {
        case appleTV
        case netflix
        case disney
        case hboMax
    }

    let brand: Brand
    let shelf: TMDBFeaturedMovie.Shelf
    let movieOffset: Int

    var id: String { brand.rawValue }
}

private struct RoveRankedShowcasePage: Identifiable {
    let shelf: TMDBFeaturedMovie.Shelf
    let title: String
    let subtitle: String
    let movieOffset: Int

    var id: String { "\(shelf.id)-\(title)" }
}

extension View {
    @ViewBuilder
    func roveHeroTransitionSource(
        id: AnyHashable?,
        namespace: Namespace.ID?
    ) -> some View {
        if #available(iOS 18.0, *), let id, let namespace {
            matchedTransitionSource(id: id, in: namespace) { source in
                source
                    .background(.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func roveHeroNavigationTransition(
        id: AnyHashable?,
        namespace: Namespace.ID
    ) -> some View {
        if #available(iOS 18.0, *), let id {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

private struct RoveEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let delay: Double
    let distance: CGFloat
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible || reduceMotion ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : distance)
            .onAppear {
                guard !isVisible else { return }
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(RoveMotion.reveal.delay(delay)) {
                        isVisible = true
                    }
                }
            }
    }
}

private final class RoveHeroMotionDriver: @unchecked Sendable {
    struct Position {
        let fromIndex: Int
        let toIndex: Int
        let progress: CGFloat
    }

    private var observers: [UUID: (Position) -> Void] = [:]
    private(set) var latest = Position(fromIndex: 0, toIndex: 0, progress: 0)

    @discardableResult
    func observe(_ observer: @escaping (Position) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        observer(latest)
        return id
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    func update(from: Int, to: Int, progress: CGFloat) {
        let position = Position(
            fromIndex: from,
            toIndex: to,
            progress: min(max(progress, 0), 1)
        )
        latest = position
        for observer in observers.values {
            observer(position)
        }
    }
}

/// UIKit owns the gesture, snap physics, and three reusable pages. The scroll
/// view is recentered after every completed swipe, which gives the carousel an
/// effectively infinite page space without keeping every SwiftUI page alive.
private struct RoveNativePagingSurface<Content: View>: UIViewControllerRepresentable {
    @Binding var selectedIndex: Int
    let itemCount: Int
    let width: CGFloat
    let height: CGFloat
    let contentIdentities: [String]
    let motionDriver: RoveHeroMotionDriver
    let onTap: (Int) -> Void
    let content: (Int, CGFloat) -> Content

    init(
        selectedIndex: Binding<Int>,
        itemCount: Int,
        width: CGFloat,
        height: CGFloat,
        contentIdentities: [String],
        motionDriver: RoveHeroMotionDriver,
        onTap: @escaping (Int) -> Void,
        @ViewBuilder content: @escaping (Int, CGFloat) -> Content
    ) {
        _selectedIndex = selectedIndex
        self.itemCount = itemCount
        self.width = width
        self.height = height
        self.contentIdentities = contentIdentities
        self.motionDriver = motionDriver
        self.onTap = onTap
        self.content = content
    }

    func makeUIViewController(context: Context) -> PagingViewController {
        let controller = PagingViewController()
        controller.loadViewIfNeeded()
        configure(controller)
        return controller
    }

    func updateUIViewController(_ controller: PagingViewController, context: Context) {
        configure(controller)
    }

    private func configure(_ controller: PagingViewController) {
        controller.onVisibleIndexChanged = { index in
            guard selectedIndex != index else { return }
            selectedIndex = index
        }
        controller.onTransitionProgress = { from, to, progress in
            motionDriver.update(from: from, to: to, progress: progress)
        }
        controller.onTap = onTap
        controller.updateGeometry(width: width, height: height, itemCount: itemCount)
        controller.updateContent(identities: contentIdentities) { index in
            AnyView(
                content(index, width)
                    .frame(width: width, height: height)
                    .contentShape(Rectangle())
            )
        }
        controller.applyExternalSelection(selectedIndex)
    }

    @MainActor
    final class PagingViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        /// A nested horizontal pager must reject vertical pans immediately so
        /// the parent home ScrollView can begin scrolling on the same touch.
        private final class HorizontalPagingScrollView: UIScrollView {
            override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
                guard gestureRecognizer === panGestureRecognizer else {
                    return super.gestureRecognizerShouldBegin(gestureRecognizer)
                }
                let velocity = panGestureRecognizer.velocity(in: self)
                let horizontalSpeed = abs(velocity.x)
                let verticalSpeed = abs(velocity.y)
                guard horizontalSpeed > 0 || verticalSpeed > 0 else { return false }
                return horizontalSpeed > verticalSpeed * 1.08
            }
        }

        private let scrollView = HorizontalPagingScrollView()
        private var hostingControllers: [UIHostingController<AnyView>] = []
        private var renderedIndices: [Int?] = []
        private var renderedIdentities: [String?] = []
        private var pageProvider: ((Int) -> AnyView)?
        private var contentIdentities: [String] = []
        private var pendingContent: (((Int) -> AnyView), [String])?
        private var pageWidth: CGFloat = 1
        private var pageHeight: CGFloat = 1
        private var itemCount = 0
        private var currentIndex = 0
        private var isApplyingExternalSelection = false

        var onVisibleIndexChanged: ((Int) -> Void)?
        var onTransitionProgress: ((Int, Int, CGFloat) -> Void)?
        var onTap: ((Int) -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            scrollView.backgroundColor = .clear
            scrollView.delegate = self
            scrollView.isPagingEnabled = true
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.alwaysBounceHorizontal = false
            scrollView.alwaysBounceVertical = false
            scrollView.bounces = false
            scrollView.isDirectionalLockEnabled = true
            scrollView.delaysContentTouches = false
            scrollView.canCancelContentTouches = true
            scrollView.decelerationRate = .fast
            scrollView.contentInsetAdjustmentBehavior = .never
            scrollView.clipsToBounds = true
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: view.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            let tap = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
            tap.cancelsTouchesInView = true
            tap.delegate = self
            tap.require(toFail: scrollView.panGestureRecognizer)
            scrollView.addGestureRecognizer(tap)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            layoutPages(recenter: !scrollView.isDragging && !scrollView.isDecelerating)
        }

        func updateGeometry(width: CGFloat, height: CGFloat, itemCount: Int) {
            let normalizedWidth = max(1, width)
            let normalizedHeight = max(1, height)
            let geometryChanged = abs(pageWidth - normalizedWidth) > 0.5
                || abs(pageHeight - normalizedHeight) > 0.5
            let countChanged = self.itemCount != itemCount
            pageWidth = normalizedWidth
            pageHeight = normalizedHeight
            self.itemCount = itemCount
            scrollView.isScrollEnabled = itemCount > 1
            if countChanged {
                currentIndex = normalized(currentIndex)
            }
            if geometryChanged || countChanged {
                invalidateRenderedPages()
                view.setNeedsLayout()
            }
        }

        func updateContent(identities: [String], provider: @escaping (Int) -> AnyView) {
            if scrollView.isDragging || scrollView.isDecelerating {
                pendingContent = (provider, identities)
                return
            }
            applyContent(provider, identities: identities)
        }

        func applyExternalSelection(_ index: Int) {
            guard itemCount > 0 else { return }
            let target = min(max(index, 0), itemCount - 1)
            guard target != currentIndex else {
                onTransitionProgress?(currentIndex, currentIndex, 0)
                return
            }
            guard !scrollView.isDragging, !scrollView.isDecelerating else { return }
            currentIndex = target
            refreshAllPages()
            isApplyingExternalSelection = true
            scrollView.setContentOffset(
                CGPoint(x: CGFloat(centerPage) * pageWidth, y: 0),
                animated: false
            )
            isApplyingExternalSelection = false
            onTransitionProgress?(currentIndex, currentIndex, 0)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isApplyingExternalSelection, itemCount > 0, pageWidth > 1 else { return }
            let position = scrollView.contentOffset.x / pageWidth - CGFloat(centerPage)
            let completedPages = position >= 0 ? floor(position) : ceil(position)
            let progress = abs(position - completedPages)
            let from = normalized(currentIndex + Int(completedPages))
            guard progress > 0.001 else {
                onTransitionProgress?(from, from, 0)
                return
            }
            let direction = position - completedPages < 0 ? -1 : 1
            onTransitionProgress?(from, normalized(from + direction), progress)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            finishInteraction()
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { finishInteraction() }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }

        @objc private func didTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, itemCount > 0 else { return }
            onTap?(currentIndex)
        }

        private func finishInteraction() {
            guard itemCount > 0 else { return }
            let settledPage = Int((scrollView.contentOffset.x / pageWidth).rounded())
            let pageDelta = settledPage - centerPage
            currentIndex = normalized(currentIndex + pageDelta)
            rotateHostedPages(by: pageDelta)
            refreshAllPages()
            layoutPages(recenter: false)
            recenterWithoutAnimation()
            onTransitionProgress?(currentIndex, currentIndex, 0)
            onVisibleIndexChanged?(currentIndex)

            if let pendingContent {
                self.pendingContent = nil
                applyContent(pendingContent.0, identities: pendingContent.1)
            }
        }

        private func applyContent(
            _ provider: @escaping (Int) -> AnyView,
            identities: [String]
        ) {
            pageProvider = provider
            contentIdentities = identities
            ensureHostingControllers()
            refreshAllPages()
            layoutPages(recenter: true)
        }

        private func ensureHostingControllers() {
            while hostingControllers.count < bufferedPageCount {
                let controller = UIHostingController(rootView: AnyView(Color.clear))
                controller.view.backgroundColor = .clear
                addChild(controller)
                scrollView.addSubview(controller.view)
                controller.didMove(toParent: self)
                hostingControllers.append(controller)
                renderedIndices.append(nil)
                renderedIdentities.append(nil)
            }
        }

        private func refreshAllPages() {
            guard let pageProvider, itemCount > 0 else { return }
            ensureHostingControllers()
            let indices = (0..<bufferedPageCount).map { page in
                normalized(currentIndex + page - centerPage)
            }
            for (slot, (controller, index)) in zip(hostingControllers, indices).enumerated() {
                let identity = contentIdentities.indices.contains(index)
                    ? contentIdentities[index]
                    : "item:\(index)"
                guard renderedIndices[slot] != index
                        || renderedIdentities[slot] != identity else { continue }
                controller.rootView = pageProvider(index)
                renderedIndices[slot] = index
                renderedIdentities[slot] = identity
            }
        }

        private func rotateHostedPages(by delta: Int) {
            guard abs(delta) == 1, hostingControllers.count == bufferedPageCount else {
                invalidateRenderedPages()
                return
            }
            if delta > 0 {
                hostingControllers.append(hostingControllers.removeFirst())
                renderedIndices.append(renderedIndices.removeFirst())
                renderedIdentities.append(renderedIdentities.removeFirst())
            } else {
                hostingControllers.insert(hostingControllers.removeLast(), at: 0)
                renderedIndices.insert(renderedIndices.removeLast(), at: 0)
                renderedIdentities.insert(renderedIdentities.removeLast(), at: 0)
            }
        }

        private func invalidateRenderedPages() {
            renderedIndices = Array(repeating: nil, count: hostingControllers.count)
            renderedIdentities = Array(repeating: nil, count: hostingControllers.count)
        }

        private func layoutPages(recenter: Bool) {
            guard isViewLoaded else { return }
            for (pageIndex, controller) in hostingControllers.enumerated() {
                controller.view.frame = CGRect(
                    x: CGFloat(pageIndex) * pageWidth,
                    y: 0,
                    width: pageWidth,
                    height: pageHeight
                )
            }
            scrollView.contentSize = CGSize(
                width: CGFloat(bufferedPageCount) * pageWidth,
                height: pageHeight
            )
            if recenter, !scrollView.isDragging, !scrollView.isDecelerating {
                recenterWithoutAnimation()
            }
        }

        private func recenterWithoutAnimation() {
            isApplyingExternalSelection = true
            scrollView.setContentOffset(
                CGPoint(x: CGFloat(centerPage) * pageWidth, y: 0),
                animated: false
            )
            isApplyingExternalSelection = false
        }

        private var centerPage: Int { 1 }
        private var bufferedPageCount: Int { centerPage * 2 + 1 }

        private func normalized(_ index: Int) -> Int {
            guard itemCount > 0 else { return 0 }
            return (index % itemCount + itemCount) % itemCount
        }
    }
}

private struct RoveHeroBackdropSurface: UIViewRepresentable {
    let motionDriver: RoveHeroMotionDriver
    let images: [UIImage?]
    let colors: [UIColor]
    let selectedIndex: Int

    func makeUIView(context: Context) -> BackdropView {
        BackdropView()
    }

    func updateUIView(_ view: BackdropView, context: Context) {
        view.configure(
            motionDriver: motionDriver,
            images: images,
            colors: colors,
            selectedIndex: selectedIndex
        )
    }

    final class BackdropView: UIView {
        private let fromImageView = UIImageView()
        private let toImageView = UIImageView()
        private let gradientLayer = CAGradientLayer()
        private weak var motionDriver: RoveHeroMotionDriver?
        private var observerID: UUID?
        private var images: [UIImage?] = []
        private var colors: [UIColor] = []
        private var selectedIndex = 0

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
            backgroundColor = .black
            for imageView in [fromImageView, toImageView] {
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                addSubview(imageView)
            }
            layer.addSublayer(gradientLayer)
            gradientLayer.locations = [0, 0.28, 0.40, 0.56, 0.70, 0.86, 1]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            if let observerID {
                motionDriver?.removeObserver(observerID)
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            fromImageView.frame = bounds
            toImageView.frame = bounds
            gradientLayer.frame = bounds
        }

        func configure(
            motionDriver: RoveHeroMotionDriver,
            images: [UIImage?],
            colors: [UIColor],
            selectedIndex: Int
        ) {
            self.images = images
            self.colors = colors
            self.selectedIndex = selectedIndex
            if self.motionDriver !== motionDriver {
                if let observerID {
                    self.motionDriver?.removeObserver(observerID)
                }
                self.motionDriver = motionDriver
                observerID = motionDriver.observe { [weak self] position in
                    self?.render(position)
                }
            }
            let latest = motionDriver.latest
            if latest.fromIndex == latest.toIndex {
                render(.init(fromIndex: selectedIndex, toIndex: selectedIndex, progress: 0))
            } else {
                render(latest)
            }
        }

        private func render(_ position: RoveHeroMotionDriver.Position) {
            guard !images.isEmpty else { return }
            let from = normalized(position.fromIndex, count: images.count)
            let to = normalized(position.toIndex, count: images.count)
            let progress = min(max(position.progress, 0), 1)
            fromImageView.image = images[from]
            toImageView.image = images[to]
            fromImageView.alpha = 1 - progress
            toImageView.alpha = progress

            let fromColor = colors.indices.contains(from) ? colors[from] : .black
            let toColor = colors.indices.contains(to) ? colors[to] : fromColor
            let color = fromColor.roveInterpolated(to: toColor, progress: progress)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradientLayer.colors = [
                UIColor.black.withAlphaComponent(0.02).cgColor,
                UIColor.clear.cgColor,
                color.withAlphaComponent(0.12).cgColor,
                color.withAlphaComponent(0.42).cgColor,
                color.withAlphaComponent(0.78).cgColor,
                color.cgColor,
                color.cgColor
            ]
            CATransaction.commit()
        }

        private func normalized(_ index: Int, count: Int) -> Int {
            (index % count + count) % count
        }
    }
}

private struct RoveHeroThemeSurface: UIViewRepresentable {
    let motionDriver: RoveHeroMotionDriver
    let colors: [UIColor]
    let selectedIndex: Int

    func makeUIView(context: Context) -> ThemeView {
        ThemeView()
    }

    func updateUIView(_ view: ThemeView, context: Context) {
        view.configure(
            motionDriver: motionDriver,
            colors: colors,
            selectedIndex: selectedIndex
        )
    }

    final class ThemeView: UIView {
        private weak var motionDriver: RoveHeroMotionDriver?
        private var observerID: UUID?
        private var colors: [UIColor] = []
        private var selectedIndex = 0

        deinit {
            if let observerID {
                motionDriver?.removeObserver(observerID)
            }
        }

        func configure(
            motionDriver: RoveHeroMotionDriver,
            colors: [UIColor],
            selectedIndex: Int
        ) {
            self.colors = colors
            self.selectedIndex = selectedIndex
            if self.motionDriver !== motionDriver {
                if let observerID {
                    self.motionDriver?.removeObserver(observerID)
                }
                self.motionDriver = motionDriver
                observerID = motionDriver.observe { [weak self] position in
                    self?.render(position)
                }
            }
            let latest = motionDriver.latest
            if latest.fromIndex == latest.toIndex {
                render(.init(fromIndex: selectedIndex, toIndex: selectedIndex, progress: 0))
            } else {
                render(latest)
            }
        }

        private func render(_ position: RoveHeroMotionDriver.Position) {
            guard !colors.isEmpty else {
                backgroundColor = .black
                return
            }
            let from = normalized(position.fromIndex)
            let to = normalized(position.toIndex)
            backgroundColor = colors[from].roveInterpolated(
                to: colors[to],
                progress: position.progress
            ).roveHomeExtendedBackground
        }

        private func normalized(_ index: Int) -> Int {
            (index % colors.count + colors.count) % colors.count
        }
    }
}

private struct RoveHeroPageIndicator: UIViewRepresentable {
    let motionDriver: RoveHeroMotionDriver
    let itemCount: Int
    let selectedIndex: Int
    let inactiveAlpha: CGFloat

    func makeUIView(context: Context) -> IndicatorView {
        IndicatorView()
    }

    func updateUIView(_ view: IndicatorView, context: Context) {
        view.configure(
            motionDriver: motionDriver,
            itemCount: itemCount,
            selectedIndex: selectedIndex,
            inactiveAlpha: inactiveAlpha
        )
    }

    final class IndicatorView: UIView {
        private weak var motionDriver: RoveHeroMotionDriver?
        private var observerID: UUID?
        private var dotLayers: [CALayer] = []
        private var itemCount = 0
        private var selectedIndex = 0
        private var inactiveAlpha: CGFloat = 0.4
        private var position = RoveHeroMotionDriver.Position(
            fromIndex: 0,
            toIndex: 0,
            progress: 0
        )

        override var intrinsicContentSize: CGSize {
            CGSize(width: totalWidth, height: Self.dotHeight)
        }

        deinit {
            if let observerID {
                motionDriver?.removeObserver(observerID)
            }
        }

        func configure(
            motionDriver: RoveHeroMotionDriver,
            itemCount: Int,
            selectedIndex: Int,
            inactiveAlpha: CGFloat
        ) {
            let countChanged = self.itemCount != itemCount
            self.itemCount = itemCount
            self.selectedIndex = selectedIndex
            self.inactiveAlpha = inactiveAlpha
            if countChanged {
                rebuildLayers()
                invalidateIntrinsicContentSize()
            }
            if self.motionDriver !== motionDriver {
                if let observerID {
                    self.motionDriver?.removeObserver(observerID)
                }
                self.motionDriver = motionDriver
                observerID = motionDriver.observe { [weak self] position in
                    self?.render(position)
                }
            }
            let latest = motionDriver.latest
            if latest.fromIndex == latest.toIndex {
                render(.init(fromIndex: selectedIndex, toIndex: selectedIndex, progress: 0))
            } else {
                render(latest)
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            layoutDots()
        }

        private func rebuildLayers() {
            dotLayers.forEach { $0.removeFromSuperlayer() }
            dotLayers = (0..<itemCount).map { _ in
                let dot = CALayer()
                dot.cornerRadius = Self.dotHeight / 2
                layer.addSublayer(dot)
                return dot
            }
        }

        private func render(_ position: RoveHeroMotionDriver.Position) {
            self.position = position
            setNeedsLayout()
            layoutIfNeeded()
        }

        private func layoutDots() {
            guard itemCount > 0, dotLayers.count == itemCount else { return }
            let from = normalized(position.fromIndex)
            let to = normalized(position.toIndex)
            let progress = min(max(position.progress, 0), 1)
            var widths = Array(repeating: Self.dotWidth, count: itemCount)
            if from == to {
                widths[from] = Self.activeWidth
            } else {
                widths[from] += (Self.activeWidth - Self.dotWidth) * (1 - progress)
                widths[to] += (Self.activeWidth - Self.dotWidth) * progress
            }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            var x = max(0, (bounds.width - totalWidth) / 2)
            for index in dotLayers.indices {
                let width = widths[index]
                let weight: CGFloat
                if from == to {
                    weight = index == from ? 1 : 0
                } else if index == from {
                    weight = 1 - progress
                } else if index == to {
                    weight = progress
                } else {
                    weight = 0
                }
                let alpha = inactiveAlpha + (1 - inactiveAlpha) * weight
                dotLayers[index].backgroundColor = UIColor.white.withAlphaComponent(alpha).cgColor
                dotLayers[index].frame = CGRect(x: x, y: 0, width: width, height: Self.dotHeight)
                x += width + Self.spacing
            }
            CATransaction.commit()
        }

        private var totalWidth: CGFloat {
            guard itemCount > 0 else { return 0 }
            return Self.activeWidth
                + CGFloat(max(0, itemCount - 1)) * Self.dotWidth
                + CGFloat(max(0, itemCount - 1)) * Self.spacing
        }

        private func normalized(_ index: Int) -> Int {
            guard itemCount > 0 else { return 0 }
            return (index % itemCount + itemCount) % itemCount
        }

        private static let activeWidth: CGFloat = 24
        private static let dotWidth: CGFloat = 7
        private static let dotHeight: CGFloat = 7
        private static let spacing: CGFloat = 9
    }
}

extension View {
    func roveEntrance(delay: Double = 0, distance: CGFloat = 14) -> some View {
        modifier(RoveEntranceModifier(delay: delay, distance: distance))
    }

    /// Shared liquid-glass treatment for custom panels and modal controls.
    /// iOS 26 uses the native glass renderer; earlier systems retain the same
    /// frosted hierarchy through regular material.
    @ViewBuilder
    func roveLiquidGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self
                // Apply the native glass to the complete surface. Putting a
                // glass layer behind the content only produces a translucent
                // fill and misses the system's refraction/highlight pass.
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.24), lineWidth: 0.8)
                }
        } else {
            self
                .background(shape.fill(.regularMaterial))
                .overlay {
                    shape.stroke(.white.opacity(0.20), lineWidth: 0.8)
                }
        }
    }

    /// Dark, contrast-preserving glass for sheets over colorful artwork.
    /// The tint keeps the material neutral while the native glass renderer
    /// still samples and blurs the artwork behind it.
    @ViewBuilder
    func roveDarkLiquidGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background {
                    Color.black.opacity(0.26)
                        .glassEffect(.regular, in: shape)
                }
                .overlay {
                    shape
                        .stroke(.white.opacity(0.27), lineWidth: 0.8)
                        .shadow(color: .black.opacity(0.24), radius: 12, y: 7)
                }
        } else {
            self
                .background(shape.fill(.ultraThinMaterial))
                .background(shape.fill(Color.black.opacity(0.28)))
                .overlay {
                    shape
                        .stroke(.white.opacity(0.24), lineWidth: 0.8)
                        .shadow(color: .black.opacity(0.24), radius: 12, y: 7)
                }
        }
    }

    /// Applies a translucent presentation background to SwiftUI sheets so
    /// their content does not fall back to an opaque white/black rectangle.
    /// ultraThinMaterial keeps the frosted look without the milky-white wash
    /// that regularMaterial introduces over dark video content.
    @ViewBuilder
    func roveLiquidGlassSheet() -> some View {
        if #available(iOS 26.0, *) {
            self.presentationBackground(.clear)
                .background(.ultraThinMaterial.opacity(0.82))
        } else {
            self.presentationBackground(.ultraThinMaterial)
        }
    }
}

private enum RoveAccentTheme: String, CaseIterable, Identifiable {
    static let defaultsKey = "rove.appearance.accent.v1"

    case cyan
    case blue
    case green
    case violet
    case coral
    case amber

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cyan: "青蓝"
        case .blue: "海蓝"
        case .green: "翡翠"
        case .violet: "紫罗兰"
        case .coral: "珊瑚红"
        case .amber: "琥珀"
        }
    }

    var color: Color {
        switch self {
        case .cyan: Color(red: 0.02, green: 0.67, blue: 0.78)
        case .blue: Color(red: 0.16, green: 0.48, blue: 0.84)
        case .green: Color(red: 0.18, green: 0.62, blue: 0.39)
        case .violet: Color(red: 0.48, green: 0.35, blue: 0.78)
        case .coral: Color(red: 0.92, green: 0.24, blue: 0.31)
        case .amber: Color(red: 0.91, green: 0.59, blue: 0.12)
        }
    }

    static var selected: RoveAccentTheme {
        let rawValue = UserDefaults.standard.string(forKey: defaultsKey)
        return RoveAccentTheme(rawValue: rawValue ?? "") ?? .cyan
    }
}

private enum RoveDefaultHomeStore {
    static let defaultsKey = "rove.default.home.v1"
    static func server(_ id: UUID) -> String { "server:\(id.uuidString)" }
    static func builtIn(_ id: String) -> String { "builtin:\(id)" }
}

private enum RoveHomeModeStore {
    static let defaultsKey = "rove.home.content-mode.v1"
    static let local = "local"
    static let server = "server"
}

struct MediaDeckShell: View {
#if DJHUB_METADATA_ONLY
    @State private var selectedTab: RootTab = .home
    @AppStorage(RoveAccentTheme.defaultsKey) private var accentThemeRaw = RoveAccentTheme.cyan.rawValue

    var body: some View {
        nativeTabs
            .background { RoveBackdrop() }
            .tint(RoveAccentTheme(rawValue: accentThemeRaw)?.color ?? RoveAccentTheme.cyan.color)
    }
#else
    @EnvironmentObject private var library: ChannelLibrary
    @EnvironmentObject private var playback: PlaybackCoordinator
    @Binding var selectedTab: RootTab
    @Binding var pendingWebImport: WebPlaylistImportRequest?
    @Binding var pendingEmbyImport: EmbyConfigurationImportRequest?
    @Binding var pendingLocalVideoImport: URL?
    @Binding var pendingExternalPlayback: RoveExternalPlaybackRequest?
    let languageRaw: String
    let onScannedImport: (QRCodeConfigurationImportRequest) -> Void

    @State private var sourceSheet: RoveSourceSheet?
    @State private var showingLegacySearch = false
    @State private var lastNonSearchTab: RootTab = .home
#if DEBUG
    @State private var showingMinorModePreview = ProcessInfo.processInfo.arguments.contains("-showMinorModePreview")
    @State private var showingMinorPINPreview = ProcessInfo.processInfo.arguments.contains("-showMinorPINPreview")
    @State private var showingCategorySortPreview = ProcessInfo.processInfo.arguments.contains("-showCategorySortPreview")
#endif
    @AppStorage(RoveAccentTheme.defaultsKey) private var accentThemeRaw = RoveAccentTheme.cyan.rawValue
    @AppStorage(RoveHomeModeStore.defaultsKey) private var homeMode = RoveHomeModeStore.server

    var body: some View {
        nativeTabs
        .background { RoveBackdrop() }
        .tint(RoveAccentTheme(rawValue: accentThemeRaw)?.color ?? RoveAccentTheme.cyan.color)
        .sheet(isPresented: $showingLegacySearch) {
            RoveSearchView()
        }
        .sheet(item: $sourceSheet) { sheet in
            RoveSourceSheetView(
                sheet: sheet,
                pendingLocalVideoImport: $pendingLocalVideoImport,
                onSelect: openSource
            )
        }
#if DEBUG
        .fullScreenCover(isPresented: $showingMinorModePreview) {
            NavigationStack { RoveMinorModeView() }
        }
        .fullScreenCover(isPresented: $showingMinorPINPreview) {
            RoveMinorPINView(action: .enable)
        }
        .fullScreenCover(isPresented: $showingCategorySortPreview) {
            NavigationStack {
                RoveCategoryGridView(category: .movies, channels: library.channels)
            }
        }
#endif
        .onChange(of: pendingWebImport, initial: true) { _, request in
            guard let request else { return }
            sourceSheet = .playlist(request)
            pendingWebImport = nil
        }
        .onChange(of: pendingEmbyImport, initial: true) { _, request in
            guard let request else { return }
            sourceSheet = .mediaServer(.legacyLibraryB, request)
            pendingEmbyImport = nil
        }
        .onChange(of: pendingLocalVideoImport) { _, url in
            guard let url else { return }
            homeMode = RoveHomeModeStore.local
            selectedTab = .home
            sourceSheet = nil
            Task {
                defer { pendingLocalVideoImport = nil }
                try? await LocalVideoLibrary.shared.importVideo(from: url)
                playback.updateQueue(LocalVideoLibrary.shared.channels)
            }
        }
        .onChange(of: selectedTab, initial: true) { oldTab, newTab in
            if newTab != .search {
                lastNonSearchTab = newTab
            } else if oldTab != .search {
                lastNonSearchTab = oldTab
            }
        }
        .task {
            await importDebugEmbyConfigurationIfNeeded()
            await openDefaultHomeIfNeeded()
        }
    }

    @MainActor
    private func openDefaultHomeIfNeeded() async {
        // The persisted library is restored asynchronously during app launch.
        // Wait for it here so a default IPTV home can select its saved source
        // instead of briefly treating the empty pre-restore state as a request
        // to present the M3U import form.
        await library.restorePersistedStateIfNeeded()
        guard let raw = UserDefaults.standard.string(forKey: RoveDefaultHomeStore.defaultsKey), !raw.isEmpty else { return }
        if raw.hasPrefix("server:"),
           let id = UUID(uuidString: String(raw.dropFirst("server:".count))),
           library.configurations.contains(where: { $0.id == id }) {
            library.selectConfiguration(id)
            homeMode = RoveHomeModeStore.server
            selectedTab = .home
            return
        }
        guard raw.hasPrefix("builtin:") else { return }
        selectedTab = .configurations
        switch String(raw.dropFirst("builtin:".count)) {
        case "localFiles":
            homeMode = RoveHomeModeStore.local
            selectedTab = .home
        case "directStream":
            // A default home is a landing destination, not an add-source
            // command. Keep the form available from the Sources page.
            selectedTab = .home
        case "playlist":
            // Prefer the first saved IPTV configuration when one exists.
            // Never present RovePlaylistForm during cold launch; that form is
            // only for an explicit user action.
            if let configuration = library.configurations.first(where: {
                [.subscription, .legacySourceB, .legacySourceA, .single].contains($0.kind) && !$0.isExpired
            }) {
                library.selectConfiguration(configuration.id)
                homeMode = RoveHomeModeStore.server
            }
            selectedTab = .home
        default: break
        }
    }

    @MainActor
    private func importDebugEmbyConfigurationIfNeeded() async {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard let server = environment["ROVE_TEST_EMBY_SERVER"],
              let username = environment["ROVE_TEST_EMBY_USERNAME"],
              let password = environment["ROVE_TEST_EMBY_PASSWORD"],
              !server.isEmpty, !username.isEmpty, !password.isEmpty else { return }
        for configuration in library.configurations where configuration.name == "Emby 测试库" {
            await library.deleteConfiguration(configuration.id)
        }
        await library.addEmbyConfiguration(
            name: "Emby 测试库",
            server: server,
            username: username,
            password: password
        )
#endif
    }
#endif

    @ViewBuilder
    private var nativeTabs: some View {
        if #available(iOS 26.0, *) {
            TabView(selection: $selectedTab) {
                Tab("首页", systemImage: "house.fill", value: RootTab.home) {
                    homeTab
                }
                Tab("Top 200", systemImage: "trophy.fill", value: RootTab.channels) {
                    RoveTop200TabView()
                }
                Tab("分类", systemImage: "square.grid.2x2.fill", value: RootTab.configurations) {
                    RoveShortDramaCategoriesTab()
                }
                Tab("收藏", systemImage: "bookmark.fill", value: RootTab.favorites) {
                    NavigationStack { RoveSavedView(initialFilter: .favorites, showsBackButton: false) }
                }
                Tab(value: RootTab.search, role: .search) {
                    RoveTMDBSearchTab()
                } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                }
            }
            .tabViewStyle(.tabBarOnly)
            .tabBarMinimizeBehavior(selectedTab == .search ? .never : .onScrollDown)
        } else {
            TabView(selection: $selectedTab) {
                homeTab
                    .tabItem { Label("首页", systemImage: "house.fill") }
                    .tag(RootTab.home)
                RoveTop200TabView()
                    .tabItem { Label("Top 200", systemImage: "trophy.fill") }
                    .tag(RootTab.channels)
                RoveShortDramaCategoriesTab()
                    .tabItem { Label("分类", systemImage: "square.grid.2x2.fill") }
                    .tag(RootTab.configurations)
                NavigationStack { RoveSavedView(initialFilter: .favorites, showsBackButton: false) }
                    .tabItem { Label("收藏", systemImage: "bookmark.fill") }
                    .tag(RootTab.favorites)
                RoveTMDBSearchTab()
                    .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                    .tag(RootTab.search)
            }
        }
    }

    private var homeTab: some View {
#if DJHUB_METADATA_ONLY
        RoveHomeView(
            selectedTab: $selectedTab,
            onSearch: { selectedTab = .search },
            onAddSource: {}
        )
#else
        RoveHomeView(
            selectedTab: $selectedTab,
            onSearch: { selectedTab = .search },
            onAddSource: { sourceSheet = .picker }
        )
#endif
    }

#if !DJHUB_METADATA_ONLY
    private var libraryTab: some View {
        RoveDiscoverView(
            onAddSource: { sourceSheet = .picker },
            onOpenSource: openSource,
            onOpenSettings: { selectedTab = .settings }
        )
    }

    private var sourcesTab: some View {
        RoveSourcesView(
            selectedTab: $selectedTab,
            onAddSource: { sourceSheet = .picker },
            onOpenSource: openSource
        )
    }

    private var settingsTab: some View {
        RoveSettingsView()
    }

    private func openSource(_ destination: RoveSourceSheet) {
        if case .localFiles = destination {
            sourceSheet = nil
            homeMode = RoveHomeModeStore.local
            selectedTab = .home
        } else {
            sourceSheet = destination
        }
    }
#endif
}

@available(iOS 26.0, *)
private struct RoveMiniPlayerBar: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    let channel: Channel
    let isPlaying: Bool
    let onOpen: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void

    private var isInline: Bool { placement == .inline }

    var body: some View {
        HStack(spacing: isInline ? 8 : 12) {
            Button(action: onOpen) {
                HStack(spacing: isInline ? 8 : 12) {
                    RoveMiniPlayerArtwork(channel: channel)
                        .frame(width: isInline ? 36 : 48, height: isInline ? 36 : 48)
                        .background(.black.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                    Text(channel.name)
                        .font(.system(size: isInline ? 15 : 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(RoveMotionButtonStyle())
            .accessibilityLabel("打开 \(channel.name)")

            Button(action: onTogglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(RoveMotionButtonStyle())
            .foregroundStyle(.primary)
            .accessibilityLabel(isPlaying ? "暂停" : "播放")

            Button(action: onNext) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(RoveMotionButtonStyle())
            .foregroundStyle(.primary)
            .accessibilityLabel("下一项")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(RoveMotionButtonStyle())
            .foregroundStyle(.primary)
            .accessibilityLabel("关闭")
        }
        .padding(.horizontal, isInline ? 6 : 10)
        .padding(.vertical, isInline ? 2 : 5)
    }
}

@available(iOS 26.0, *)
private struct RoveMiniPlayerArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let channel: Channel
    @State private var artwork: UIImage?

    var body: some View {
        ZStack {
            if let artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: channel.streamURL.isFileURL ? "film" : "play.rectangle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
        .animation(reduceMotion ? nil : RoveMotion.quick, value: artwork != nil)
        .task(id: channel.id) {
            artwork = await ChannelArtworkLoader.shared.landscapeImage(
                for: channel,
                maxWidth: 240
            )
        }
        .accessibilityHidden(true)
    }
}

private extension View {
    @available(iOS 26.0, *)
    @ViewBuilder
    func roveMiniPlayerAccessory<Accessory: View>(
        isEnabled: Bool,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: isEnabled, content: accessory)
        } else if isEnabled {
            tabViewBottomAccessory(content: accessory)
        } else {
            self
        }
    }
}

#if !DJHUB_METADATA_ONLY
private enum RoveSourceSheet: Identifiable {
    case picker
    case mediaServer(PlaylistConfigurationKind, EmbyConfigurationImportRequest?)
    case moviePilot(MoviePilotConnection?)
    case legacyLibraryD
    case networkShare(String)
    case webDAV
    case playlist(WebPlaylistImportRequest?)
    case rss
    case directStream
    case localFiles
    case privateLocalFiles
    case cloudDrives
    case cloudDrive(NativeCloudDriveProvider)

    var id: String {
        switch self {
        case .picker: "picker"
        case .mediaServer(let kind, _): "media-server-\(kind.rawValue)"
        case .moviePilot(let connection): "moviepilot-\(connection?.id.uuidString ?? "new")"
        case .legacyLibraryD: "legacyLibraryD"
        case .networkShare(let scheme): "network-share-\(scheme)"
        case .webDAV: "legacySourceC"
        case .playlist: "playlist"
        case .rss: "rss"
        case .directStream: "direct-stream"
        case .localFiles: "local-files"
        case .privateLocalFiles: "private-local-files"
        case .cloudDrives: "cloud-drives"
        case .cloudDrive(let provider): "cloud-drive-\(provider.rawValue)"
        }
    }
}
#endif

struct RoveBackdrop: View {
    var body: some View {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()
    }
}

private struct RovePageHeader<Trailing: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.roveAccent)
                }
                Text(title)
                    .font(.largeTitle.weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

private struct RoveSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.roveAccent)
            }
        }
    }
}

private struct RoveServerHomeSection: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var isEnabled: Bool
}

private enum RoveServerHomeSectionStore {
    private static func key(configurationID: UUID?) -> String {
        "rove.home.server-sections.v1.\(configurationID?.uuidString.lowercased() ?? "all")"
    }

    static func load(
        configurationID: UUID?,
        collections: [RoveHomeMediaCollection]
    ) -> [RoveServerHomeSection] {
        let available = collections.map {
            RoveServerHomeSection(id: $0.id, title: $0.collection.name, isEnabled: true)
        }
        guard let data = UserDefaults.standard.data(forKey: key(configurationID: configurationID)),
              let saved = try? JSONDecoder().decode([RoveServerHomeSection].self, from: data)
        else { return available }

        let availableByID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        var merged = saved.compactMap { section -> RoveServerHomeSection? in
            guard let current = availableByID[section.id] else { return nil }
            return RoveServerHomeSection(
                id: current.id,
                title: current.title,
                isEnabled: section.isEnabled
            )
        }
        let knownIDs = Set(merged.map(\.id))
        merged.append(contentsOf: available.filter { !knownIDs.contains($0.id) })
        return merged
    }

    static func save(_ sections: [RoveServerHomeSection], configurationID: UUID?) {
        guard let data = try? JSONEncoder().encode(sections) else { return }
        UserDefaults.standard.set(data, forKey: key(configurationID: configurationID))
    }
}

private struct RoveHomeBlock: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case continueWatching
        case aiRecommendations
        case mediaCollections
        case mediaShelf
    }

    let id: String
    let kind: Kind
    var title: String
    var isEnabled: Bool
}

private enum RoveHomeBlockStore {
    private static func key(configurationID: UUID?) -> String {
        "rove.home.blocks.v1.\(configurationID?.uuidString.lowercased() ?? "all")"
    }

    static func defaults(collections: [RoveHomeMediaCollection]) -> [RoveHomeBlock] {
        [
            RoveHomeBlock(id: "continue-watching", kind: .continueWatching, title: "继续观看", isEnabled: true),
            RoveHomeBlock(id: "ai-recommendations", kind: .aiRecommendations, title: "AI 为你推荐", isEnabled: true),
            RoveHomeBlock(id: "media-collections", kind: .mediaCollections, title: "我的媒体", isEnabled: true)
        ] + collections.map {
            RoveHomeBlock(
                id: "media-shelf:\($0.id)",
                kind: .mediaShelf,
                title: $0.collection.name,
                isEnabled: true
            )
        }
    }

    static func load(
        configurationID: UUID?,
        collections: [RoveHomeMediaCollection]
    ) -> [RoveHomeBlock] {
        let available = defaults(collections: collections)
        guard let data = UserDefaults.standard.data(forKey: key(configurationID: configurationID)),
              let saved = try? JSONDecoder().decode([RoveHomeBlock].self, from: data)
        else { return available }

        let availableByID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        var merged = saved.compactMap { block -> RoveHomeBlock? in
            guard let current = availableByID[block.id] else { return nil }
            return RoveHomeBlock(
                id: current.id,
                kind: current.kind,
                title: block.title,
                isEnabled: block.isEnabled
            )
        }
        let knownIDs = Set(merged.map(\.id))
        merged.append(contentsOf: available.filter { !knownIDs.contains($0.id) })
        return merged
    }

    static func save(_ blocks: [RoveHomeBlock], configurationID: UUID?) {
        guard let data = try? JSONEncoder().encode(blocks) else { return }
        UserDefaults.standard.set(data, forKey: key(configurationID: configurationID))
    }
}

private enum RoveSourceCardOrderStore {
    private static let key = "rove.source-card-order.v1"

    static func merged(saved: [String], available: [String]) -> [String] {
        let availableIDs = Set(available)
        var result = saved.filter { availableIDs.contains($0) }
        let knownIDs = Set(result)
        result.append(contentsOf: available.filter { !knownIDs.contains($0) })
        return result
    }

    static func load(available: [String]) -> [String] {
        merged(
            saved: UserDefaults.standard.stringArray(forKey: key) ?? [],
            available: available
        )
    }

    static func save(_ order: [String]) {
        UserDefaults.standard.set(order, forKey: key)
    }
}

private struct RoveHomeMediaCollection: Identifiable, Hashable, Sendable {
    let configurationID: UUID
    let collection: MetadataLibraryCollection
    let displaysPosterStrip: Bool
    let prefersSeries: Bool

    var id: String { "\(configurationID.uuidString)|\(collection.id)" }
}

private struct RoveHomeMediaShelf: Identifiable, Sendable {
    let source: RoveHomeMediaCollection
    let channels: [Channel]

    var id: String { source.id }
}

private struct RoveHomeShelfLoadResult: Sendable {
    let sourceID: String
    let shelf: RoveHomeMediaShelf?
    let resolvedPage: Bool
}

private struct RoveHomeSnapshot: Sendable {
    let mediaCollections: [RoveHomeMediaCollection]
    let mediaShelves: [RoveHomeMediaShelf]
    let continueWatching: [MetadataContinueItem]
}

private struct RoveUncheckedOptionalImage: @unchecked Sendable {
    let value: UIImage?
}

private struct RoveUncheckedOptionalColor: @unchecked Sendable {
    let value: UIColor?
}

private struct RovePreloadedArtwork: @unchecked Sendable {
    let id: String
    let image: UIImage
    let logo: UIImage?
    let color: UIColor

    init(id: String, image: UIImage, logo: UIImage? = nil, color: UIColor? = nil) {
        self.id = id
        self.image = image
        self.logo = logo
        self.color = color ?? image.roveImmersiveColor
    }
}

private struct RoveHeroVisual: @unchecked Sendable {
    let image: UIImage
    let color: UIColor
}

private struct RovePreloadedLogo: @unchecked Sendable {
    let id: Int
    let image: UIImage
}

private struct RoveServerHeroTMDBAssets: @unchecked Sendable {
    let id: UUID
    let artwork: UIImage?
    let logo: UIImage?
    let color: UIColor?
    let overview: String?
}

private struct TMDBFeaturedMovie: Identifiable, Hashable, Codable, Sendable {
    enum Shelf: String, Codable, CaseIterable, Sendable, Identifiable {
        case popular = "热门电影"
        case trending = "本周热门"
        case trendingToday = "实时热门"
        case nowPlaying = "正在上映"
        case animation = "热门动画"
        case scienceFiction = "科幻精选"
        case action = "动作冒险"
        case comedy = "喜剧片"
        case drama = "剧情片"
        case horror = "惊悚恐怖"
        case classics = "高分经典"
        case classics70s = "70年代经典"
        case classics80s = "80年代经典"
        case classics90s = "90年代经典"
        case classics2000s = "00年代经典"
        case classics2010s = "10年代经典"
        case classics2020s = "20年代经典"
        case upcoming = "即将上映"
        case popularSeries = "热门剧集"
        case trendingSeries = "本周热播剧"
        case airingToday = "今日播出"
        case onTheAir = "正在播出"
        case topSeries = "高分剧集"
        case animationSeries = "动画剧集"
        case crimeSeries = "犯罪剧集"
        case dramaSeries = "剧情剧集"
        case variety = "综艺"
        case realitySeries = "真人秀"
        case talkSeries = "脱口秀"
        case top200 = "Top 200"
        case shortDrama = "热门短剧"
        case shortRomance = "爱情短剧"
        case shortComedy = "喜剧短剧"
        case shortMystery = "悬疑短剧"
        case shortAction = "动作短剧"

        var id: String { rawValue }
    }

    let id: Int
    let title: String
    let originalTitle: String
    let aliases: [String]
    let overview: String
    let year: Int
    let rating: Double
    let genres: [String]
    let posterPath: String
    let backdropPath: String
    let shelves: Set<Shelf>
    var isTV: Bool = false
    var djhubID: String? = nil
    var posterURLOverride: String? = nil
    var backdropURLOverride: String? = nil
    var episodeCount: Int? = nil
    var platformName: String? = nil
    var contentType: String? = nil

    init(
        id: Int,
        title: String,
        originalTitle: String,
        aliases: [String],
        overview: String,
        year: Int,
        rating: Double,
        genres: [String],
        posterPath: String,
        backdropPath: String,
        shelves: Set<Shelf>,
        isTV: Bool = false,
        djhubID: String? = nil,
        posterURLOverride: String? = nil,
        backdropURLOverride: String? = nil,
        episodeCount: Int? = nil,
        platformName: String? = nil,
        contentType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.originalTitle = originalTitle
        self.aliases = aliases
        self.overview = overview
        self.year = year
        self.rating = rating
        self.genres = genres
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.shelves = shelves
        self.isTV = isTV
        self.djhubID = djhubID
        self.posterURLOverride = posterURLOverride
        self.backdropURLOverride = backdropURLOverride
        self.episodeCount = episodeCount
        self.platformName = platformName
        self.contentType = contentType
    }

    var posterURL: URL? {
        if let posterURLOverride { return URL(string: posterURLOverride) }
        return RoveAPISettings.tmdbImageURL(size: "w500", path: posterPath)
    }

    var backdropURL: URL? {
        if let backdropURLOverride { return URL(string: backdropURLOverride) }
        return RoveAPISettings.tmdbImageURL(size: "w1280", path: backdropPath)
    }

    var displayRating: Double? {
        rating > 0 ? rating : nil
    }

    var searchableTitles: [String] {
        [title, originalTitle] + aliases
    }

    /// TMDB uses separate ID spaces for movies and TV series.
    /// Keep the numeric ID for API calls, but expose a stable mixed-media identity
    /// for SwiftUI collections and local deduplication.
    var identity: String {
        if let djhubID { return "djhub-\(djhubID)" }
        return (isTV ? "tv-" : "movie-") + String(id)
    }
}

private enum RoveLuckyPick: Identifiable, Hashable {
    case channel(Channel)
    case tmdb(TMDBFeaturedMovie)

    var id: String {
        switch self {
        case .channel(let channel): "channel-\(channel.id.uuidString)"
        case .tmdb(let movie): "tmdb-\(movie.identity)"
        }
    }

    var heroID: String { "home-lucky-pick-\(id)" }

    var title: String {
        switch self {
        case .channel(let channel): channel.name
        case .tmdb(let movie): movie.title
        }
    }

    var yearText: String? {
        switch self {
        case .channel(let channel): channel.productionYear.map(String.init)
        case .tmdb(let movie): movie.year > 0 ? String(movie.year) : nil
        }
    }

    var categoryText: String {
        switch self {
        case .channel(let channel):
            if channel.isMediaServerSeries { return "剧集" }
            return channel.group.nonEmpty ?? "电影"
        case .tmdb(let movie):
            return movie.genres.prefix(2).joined(separator: " · ").nonEmpty
                ?? (movie.isTV ? "剧集" : "电影")
        }
    }

    var rating: Double? {
        switch self {
        case .channel(let channel): channel.communityRating
        case .tmdb(let movie): movie.displayRating
        }
    }

    var ticketSummary: String {
        switch self {
        case .channel:
            return "来自你的私人媒体库，今晚就看这一部。"
        case .tmdb(let movie):
            return movie.overview.nonEmpty ?? "为你随机抽取的高分佳作。"
        }
    }
}

private struct RoveWatchlistEntry: Identifiable, Codable, Hashable {
    let id: String
    let channel: Channel?
    let recommendation: TMDBFeaturedMovie?
    let addedAt: Date

    init(channel: Channel, addedAt: Date = .now) {
        id = Self.channelID(channel)
        self.channel = channel
        recommendation = nil
        self.addedAt = addedAt
    }

    init(recommendation: TMDBFeaturedMovie, addedAt: Date = .now) {
        id = "tmdb-\(recommendation.identity)"
        channel = nil
        self.recommendation = recommendation
        self.addedAt = addedAt
    }

    var displayChannel: Channel {
        if let channel { return channel }
        let movie = recommendation!
        return Channel(
            id: UUID(uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                movie.id
            ))!,
            name: movie.title,
            streamURL: URL(string: "rove-tmdb://\(movie.isTV ? "tv" : "movie")/\(movie.id)")!,
            group: "TMDB 推荐",
            logoURL: movie.posterURL,
            tvgID: String(movie.id),
            tvgName: movie.originalTitle,
            playbackKind: .onDemand,
            productionYear: movie.year,
            communityRating: movie.rating,
            mediaServerItemType: movie.isTV ? "Series" : "Movie"
        )
    }

    private static func channelID(_ channel: Channel) -> String {
        switch channel.resolver {
        case .legacyLibraryB(let configurationID, let itemID):
            return "legacyLibraryB-\(configurationID.uuidString)-\(itemID)"
        case .legacyLibraryA(let configurationID, let itemID):
            return "legacyLibraryA-\(configurationID.uuidString)-\(itemID)"
        case .movieClaw(let configurationID, let itemID):
            return "movieclaw-\(configurationID.uuidString)-\(itemID)"
        case .legacyLibraryC(let configurationID, let itemID):
            return "feiniu-\(configurationID.uuidString)-\(itemID)"
        case .legacyLibraryD(let configurationID, let itemID):
            return "legacyLibraryD-\(configurationID.uuidString)-\(itemID)"
        case .legacySourceA(let configurationID, let command):
            return "legacySourceA-\(configurationID.uuidString)-\(command)"
        case nil:
            return "url-\(channel.streamURL.absoluteString)"
        }
    }
}

@MainActor
private final class RoveWatchlistStore: ObservableObject {
    static let shared = RoveWatchlistStore()

    @Published private(set) var entries: [RoveWatchlistEntry]

    private let storageKey = "rove.watchlist.entries.v1"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RoveWatchlistEntry].self, from: data)
        else {
            entries = []
            return
        }
        entries = decoded.sorted { $0.addedAt > $1.addedAt }
    }

    func contains(_ entry: RoveWatchlistEntry) -> Bool {
        entries.contains { $0.id == entry.id }
    }

    @discardableResult
    func toggle(_ entry: RoveWatchlistEntry) -> Bool {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries.remove(at: index)
            persist()
            return false
        }
        entries.insert(entry, at: 0)
        persist()
        return true
    }

    func remove(_ entry: RoveWatchlistEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func entry(for channel: Channel) -> RoveWatchlistEntry? {
        let entryID = RoveWatchlistEntry(channel: channel).id
        return entries.first { $0.id == entryID }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

private struct TMDBMoviePerson: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let tmdbID: Int
    let name: String
    let role: String
    let profilePath: String?

    init(id: String, tmdbID: Int, name: String, role: String, profilePath: String?) {
        self.id = id
        self.tmdbID = tmdbID
        self.name = name
        self.role = role
        self.profilePath = profilePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        tmdbID = try container.decodeIfPresent(Int.self, forKey: .tmdbID)
            ?? id.split(separator: "-").dropFirst().first.flatMap { Int($0) }
            ?? 0
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(String.self, forKey: .role)
        profilePath = try container.decodeIfPresent(String.self, forKey: .profilePath)
    }

    private enum CodingKeys: String, CodingKey {
        case id, tmdbID, name, role, profilePath
    }

    var profileURL: URL? {
        guard let profilePath else { return nil }
        if profilePath.hasPrefix("http") { return URL(string: profilePath) }
        return RoveAPISettings.tmdbImageURL(size: "w342", path: profilePath)
    }
}

private enum RovePopularPeopleCatalog {
    struct Entry: Sendable {
        let name: String
        let query: String
    }

    static let entries = [
        Entry(name: "斯嘉丽·约翰逊", query: "Scarlett Johansson"),
        Entry(name: "安娜·德·阿玛斯", query: "Ana de Armas"),
        Entry(name: "赞达亚", query: "Zendaya"),
        Entry(name: "杨紫琼", query: "Michelle Yeoh"),
        Entry(name: "提莫西·查拉梅", query: "Timothee Chalamet"),
        Entry(name: "弗洛伦丝·皮尤", query: "Florence Pugh"),
        Entry(name: "莱昂纳多·迪卡普里奥", query: "Leonardo DiCaprio"),
        Entry(name: "玛格特·罗比", query: "Margot Robbie")
    ]

    static let defaults = entries.enumerated().map { index, entry in
        TMDBMoviePerson(
            id: "popular-placeholder-\(index)",
            tmdbID: 0,
            name: entry.name,
            role: "演员",
            profilePath: nil
        )
    }
}

private struct TMDBTrailer: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool
    let publishedAt: String?
    let languageCode: String?

    var thumbnailURL: URL? {
        guard site.caseInsensitiveCompare("YouTube") == .orderedSame else { return nil }
        return URL(string: "https://i.ytimg.com/vi/\(key)/hqdefault.jpg")
    }

    var playbackURL: URL? {
        guard site.caseInsensitiveCompare("YouTube") == .orderedSame else { return nil }
        var components = URLComponents(string: "https://www.youtube.com/watch")
        components?.queryItems = [URLQueryItem(name: "v", value: key)]
        return components?.url
    }
}

private struct TMDBMovieDetails: Hashable, Codable, Sendable {
    let title: String
    let originalTitle: String
    let imdbID: String?
    let tvdbID: Int?
    let overview: String
    let tagline: String?
    let releaseDate: String?
    let rating: Double
    let runtimeMinutes: Int?
    let certification: String?
    let genres: [String]
    let studios: [String]
    let people: [TMDBMoviePerson]
    let relatedMovies: [TMDBFeaturedMovie]
    let keywords: [String]?
    /// Optional for backwards compatibility with detail caches written before
    /// TMDB artwork shelves were introduced.
    let backdropPaths: [String]?
    let posterPaths: [String]?
    let logoPaths: [String]?
    /// TMDB image language keyed by file path. Optional for older detail caches.
    let logoLanguages: [String: String]?
    var djhubBadges: [DJHUBBadge]? = nil
    /// Optional so detail caches written before trailer support still decode.
    let trailers: [TMDBTrailer]?

    var preferredChineseLogoPath: String? {
        guard let logoPaths else { return nil }
        return logoPaths.first { path in
            let language = logoLanguages?[path]?.lowercased()
            return language == "zh" || language == "zh-cn" || language == "zh-tw"
        }
    }

    /// Posters are preferred for the home hero to match the detail page. The
    /// first path is already quality-ranked when the TMDB response is decoded.
    var bestHeroArtworkPath: String? {
        posterPaths?.first ?? backdropPaths?.first
    }
}

private struct RoveParentGuideItem: Identifiable {
    let id: String
    let title: String
    let level: String
    let color: Color
    let evidence: String
}

private enum RoveDetailArtworkTab: String, CaseIterable, Identifiable {
    case stills = "剧照"
    case posters = "海报"
    case logos = "Logo"

    var id: String { rawValue }
}

private struct TMDBPersonCredit: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let title: String
    let character: String?
    let job: String?
    let year: Int?
    let posterPath: String?

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return RoveAPISettings.tmdbImageURL(size: "w342", path: posterPath)
    }

    var role: String {
        character?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? job?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? ""
    }
}

private struct TMDBPersonDetails: Hashable, Codable, Sendable {
    let id: Int
    let name: String
    let biography: String
    let birthday: String?
    let deathday: String?
    let placeOfBirth: String?
    let knownForDepartment: String?
    let profilePath: String?
    let credits: [TMDBPersonCredit]

    var profileURL: URL? {
        guard let profilePath else { return nil }
        return RoveAPISettings.tmdbImageURL(size: "w780", path: profilePath)
    }
}

private enum TMDBFeaturedCatalog {
    private static let featured: [TMDBFeaturedMovie] = [
        TMDBFeaturedMovie(
            id: 693134,
            title: "沙丘2",
            originalTitle: "Dune: Part Two",
            aliases: ["沙丘：第二部", "沙丘 第二部", "Dune Part 2"],
            overview: "保罗与契妮并肩踏上复仇之路。当预知中的黑暗未来逐渐逼近，他必须在爱情与宇宙命运之间作出选择。",
            year: 2024,
            rating: 8.1,
            genres: ["科幻", "冒险"],
            posterPath: "/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg",
            backdropPath: "/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg",
            shelves: [.popular, .scienceFiction]
        ),
        TMDBFeaturedMovie(
            id: 872585,
            title: "奥本海默",
            originalTitle: "Oppenheimer",
            aliases: [],
            overview: "一位理论物理学家被推到历史转折点的中心，他的创造改变了战争，也永久改变了世界。",
            year: 2023,
            rating: 8.1,
            genres: ["剧情", "历史"],
            posterPath: "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
            backdropPath: "/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg",
            shelves: [.popular]
        ),
        TMDBFeaturedMovie(
            id: 1022789,
            title: "头脑特工队2",
            originalTitle: "Inside Out 2",
            aliases: ["脑筋急转弯2", "玩转脑朋友2"],
            overview: "莱莉进入青春期，大脑总部迎来一群全新的情绪伙伴，熟悉的情绪团队也面临前所未有的变化。",
            year: 2024,
            rating: 7.6,
            genres: ["动画", "喜剧"],
            posterPath: "/vpnVM9B6NMmQpWeZvzLvDESb2QY.jpg",
            backdropPath: "/p5ozvmdgsmbWe0H8Xk7Rc8SCwAB.jpg",
            shelves: [.popular, .animation]
        ),
        TMDBFeaturedMovie(
            id: 533535,
            title: "死侍与金刚狼",
            originalTitle: "Deadpool & Wolverine",
            aliases: ["死侍3", "Deadpool 3"],
            overview: "韦德被迫重披战衣，并说服一位不情愿的金刚狼加入任务，共同面对足以撼动多重宇宙的危机。",
            year: 2024,
            rating: 7.6,
            genres: ["动作", "科幻"],
            posterPath: "/8cdWjvZQUExUUTzyp4t6EDMubfO.jpg",
            backdropPath: "/dvBCdCohwWbsP5qAaglOXagDMtk.jpg",
            shelves: [.popular, .scienceFiction]
        ),
        TMDBFeaturedMovie(
            id: 1184918,
            title: "荒野机器人",
            originalTitle: "The Wild Robot",
            aliases: ["野生机器人"],
            overview: "机器人萝斯意外流落荒岛，在学习适应自然的过程中，与岛上的动物建立起超越程序的深厚联系。",
            year: 2024,
            rating: 8.3,
            genres: ["动画", "冒险"],
            posterPath: "/wTnV3PCVW5O92JMrFvvrRcV39RU.jpg",
            backdropPath: "/v9acaWVVFdZT5yAU7J2QjwfhXyD.jpg",
            shelves: [.popular, .animation]
        ),
        TMDBFeaturedMovie(
            id: 823464,
            title: "哥斯拉大战金刚2：帝国崛起",
            originalTitle: "Godzilla x Kong: The New Empire",
            aliases: ["哥斯拉大战金刚2", "Godzilla x Kong"],
            overview: "哥斯拉与金刚再次集结，深入地心世界，迎战隐藏在人类文明之外的远古威胁。",
            year: 2024,
            rating: 7.1,
            genres: ["动作", "科幻"],
            posterPath: "/z1p34vh7dEOnLDmyCrlUVLuoDzd.jpg",
            backdropPath: "/j3Z3XktmWB1VhsS8iXNcrR86PXi.jpg",
            shelves: [.popular, .scienceFiction]
        ),
        TMDBFeaturedMovie(
            id: 653346,
            title: "猩球崛起：新世界",
            originalTitle: "Kingdom of the Planet of the Apes",
            aliases: ["猩球崛起4", "猿人争霸战：猩凶帝国"],
            overview: "凯撒时代过去多年后，一只年轻猿猴踏上旅程，并开始重新理解猿族与人类共同留下的历史。",
            year: 2024,
            rating: 7.1,
            genres: ["科幻", "冒险"],
            posterPath: "/gKkl37BQuKTanygYQG1pyYgLVgf.jpg",
            backdropPath: "/fqv8v6AycXKsivp1T5yKtLbGXce.jpg",
            shelves: [.scienceFiction]
        ),
        TMDBFeaturedMovie(
            id: 786892,
            title: "疯狂的麦克斯：狂暴女神",
            originalTitle: "Furiosa: A Mad Max Saga",
            aliases: ["芙莉欧莎：疯狂麦斯传奇", "疯狂的麦克斯5"],
            overview: "年轻的芙莉欧莎被掠离家园，在废土军阀的争斗中寻找归途，也逐渐成为传说中的战士。",
            year: 2024,
            rating: 7.5,
            genres: ["动作", "科幻"],
            posterPath: "/iADOJ8Zymht2JPMoy3R7xceZprc.jpg",
            backdropPath: "/wNAhuOZ3Zf84jCIlrcI6JhgmY5q.jpg",
            shelves: [.popular, .scienceFiction]
        ),
        TMDBFeaturedMovie(
            id: 945961,
            title: "异形：夺命舰",
            originalTitle: "Alien: Romulus",
            aliases: ["异形 罗穆路斯", "异形9"],
            overview: "一群年轻殖民者在废弃空间站中寻找机会，却遭遇宇宙中最致命的生命体。",
            year: 2024,
            rating: 7.2,
            genres: ["科幻", "惊悚"],
            posterPath: "/b33nnKl1GSFbao4l3fZDDqsMx0F.jpg",
            backdropPath: "/9SSEUrSqhljBMzRe4aBTh17rUaC.jpg",
            shelves: [.popular, .scienceFiction]
        )
    ]

    private static let supplemental: [TMDBFeaturedMovie] = [
        entry(969681, "蜘蛛侠：崭新之日", "Spider-Man: Brand New Day", 2026, 0, ["动作", "科幻"], "/7AjIupf0lxNKNq0p8z36jv5ZpiJ.jpg", [.popular]),
        entry(1204680, "歪心狼对阵ACME", "Coyote vs. Acme", 2026, 0, ["动画", "喜剧"], "/xONOMna5Z102bw0jMPBM4H73B9m.jpg", [.animation]),
        entry(1368337, "奥德赛", "The Odyssey", 2026, 0, ["冒险", "奇幻"], "/Aj0Uykxj0vhwVsyrRJka0aM3SP1.jpg", [.popular]),
        entry(1108427, "海洋奇缘：启航", "Moana", 2026, 0, ["冒险", "家庭"], "/8f4OJJrMtZcoB4h1BLyyZewd96X.jpg", [.popular]),
        entry(1084244, "玩具总动员5", "Toy Story 5", 2026, 0, ["动画", "家庭"], "/oo46YfPuMcV9t7KsTiaMVUVRjvJ.jpg", [.animation]),
        entry(687163, "挽救计划", "Project Hail Mary", 2026, 0, ["科幻", "冒险"], "/qf8HaEGNUFXU6nVAq9BVEk4Tiqb.jpg", [.scienceFiction]),
        entry(980431, "安昂传奇：最后的气宗", "The Legend of Aang: The Last Airbender", 2026, 0, ["动画", "奇幻"], "/uMnhXLchOwDUdlKxCoPO6ijJbEU.jpg", [.animation]),
        entry(1560520, "蝙蝠侠：骑士陨落 第一部", "Batman: Knightfall Part One", 2026, 0, ["动画", "动作"], "/nN0MbX8D5HlTYztl3PDXkiQQLzf.jpg", [.animation]),
        entry(1311031, "鬼灭之刃：无限城篇 第一章", "Demon Slayer: Kimetsu no Yaiba Infinity Castle", 2025, 8.0, ["动画", "动作"], "/7kelotRA447lTaBviPrw2jom9cr.jpg", [.popular, .animation]),
        entry(1218925, "电锯人剧场版：蕾塞篇", "Chainsaw Man - The Movie: Reze Arc", 2025, 8.4, ["动画", "动作"], "/yFsmS9rayF2iGogqB9McesEN5kG.jpg", [.popular, .animation]),
        entry(823219, "猫猫的奇幻漂流", "Flow", 2024, 8.2, ["动画", "冒险"], "/tn89woD33WgLgT7ZMUr1r47hnql.jpg", [.animation, .classics]),
        entry(10681, "机器人总动员", "WALL-E", 2008, 8.1, ["动画", "科幻"], "/eVcHArmmMXajXaqVBH4dhUWfwmS.jpg", [.animation, .scienceFiction, .classics]),
        entry(129, "千与千寻", "Spirited Away", 2001, 8.5, ["动画", "奇幻"], "/dnwMqbndJpOEhoVqjlMU9U7LFle.jpg", [.animation, .classics]),
        entry(278, "肖申克的救赎", "The Shawshank Redemption", 1994, 9.3, ["剧情"], "/iKZev9OgfklidO8AvdrYlwung2o.jpg", [.popular, .classics]),
        entry(238, "教父", "The Godfather", 1972, 9.2, ["剧情", "犯罪"], "/y03tzUKvkRCYwJ5NWys4W4bnS9m.jpg", [.classics]),
        entry(240, "教父2", "The Godfather Part II", 1974, 9.0, ["剧情", "犯罪"], "/4J8jUmjgKPggRPJqqdkjWCj2k0D.jpg", [.classics]),
        entry(389, "十二怒汉", "12 Angry Men", 1957, 9.0, ["剧情"], "/tbhKU2naM5ItPO4ICdF2GKow9ik.jpg", [.classics]),
        entry(155, "蝙蝠侠：黑暗骑士", "The Dark Knight", 2008, 9.0, ["动作", "犯罪"], "/qYB7QqwT1NtTW9aCwtopGy80rmA.jpg", [.popular, .classics]),
        entry(122, "指环王3：王者无敌", "The Lord of the Rings: The Return of the King", 2003, 9.0, ["奇幻", "冒险"], "/kKUgYEOVebuu21N0KnQiGpIStiN.jpg", [.classics]),
        entry(299534, "复仇者联盟4：终局之战", "Avengers: Endgame", 2019, 8.4, ["动作", "科幻"], "/wXyZYO6BKDh8Evf80DF80VzKcz3.jpg", [.popular, .scienceFiction]),
        entry(424, "辛德勒的名单", "Schindler's List", 1993, 9.0, ["剧情", "历史"], "/7cDI6MrIi12uQxfipiNIeJPYljy.jpg", [.classics]),
        entry(497, "绿里奇迹", "The Green Mile", 1999, 8.6, ["剧情", "奇幻"], "/oHL5har21XS91tAL0gUnDCg9kvD.jpg", [.classics]),
        entry(414419, "杀死比尔：血色全传", "Kill Bill: The Whole Bloody Affair", 2011, 8.8, ["动作", "犯罪"], "/8w8bV7nmHq25mH68bqZaopMxnV7.jpg", [.popular, .classics])
    ]

    static let movies = featured + supplemental
    static let heroes = Array(featured.prefix(5))

    private static func entry(
        _ id: Int,
        _ title: String,
        _ originalTitle: String,
        _ year: Int,
        _ rating: Double,
        _ genres: [String],
        _ posterPath: String,
        _ shelves: Set<TMDBFeaturedMovie.Shelf>
    ) -> TMDBFeaturedMovie {
        TMDBFeaturedMovie(
            id: id,
            title: title,
            originalTitle: originalTitle,
            aliases: [],
            overview: "来自 TMDB 的影片资料。连接 Emby、Jellyfin 或旧版资料库后，会自动匹配媒体库中的同名资源。",
            year: year,
            rating: rating,
            genres: genres,
            posterPath: posterPath,
            backdropPath: posterPath,
            shelves: shelves
        )
    }
}

private enum TMDBPersistentCache {
    private static let rootName = "TuboTMDB"

    static func movies() async -> [TMDBFeaturedMovie]? {
        await read([TMDBFeaturedMovie].self, from: fileURL("discovery-v3.json"))
    }

    static func storeMovies(_ value: [TMDBFeaturedMovie]) async {
        await write(value, to: fileURL("discovery-v3.json"))
    }

    static func details(movieID: Int) async -> TMDBMovieDetails? {
        await read(TMDBMovieDetails.self, from: fileURL("details-v1-\(movieID).json"))
    }

    static func storeDetails(_ value: TMDBMovieDetails, movieID: Int) async {
        await write(value, to: fileURL("details-v1-\(movieID).json"))
    }

    static func person(personID: Int) async -> TMDBPersonDetails? {
        await read(TMDBPersonDetails.self, from: fileURL("person-v1-\(personID).json"))
    }

    static func storePerson(_ value: TMDBPersonDetails, personID: Int) async {
        await write(value, to: fileURL("person-v1-\(personID).json"))
    }

    private static func fileURL(_ name: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(rootName, isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
    }

    private static func read<Value: Decodable & Sendable>(_ type: Value.Type, from url: URL) async -> Value? {
        await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(type, from: data)
        }.value
    }

    private static func write<Value: Encodable & Sendable>(_ value: Value, to url: URL) async {
        await Task.detached(priority: .utility) {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                var directoryValues = URLResourceValues()
                directoryValues.isExcludedFromBackup = true
                var directoryURL = url.deletingLastPathComponent()
                try? directoryURL.setResourceValues(directoryValues)
                try JSONEncoder().encode(value).write(to: url, options: .atomic)
            } catch {
                return
            }
        }.value
    }
}

private enum TMDBDiscoveryService {
    private struct Response: Decodable {
        let results: [Item]
    }

    private struct Item: Decodable {
        let id: Int
        let title: String
        let originalTitle: String
        let overview: String
        let releaseDate: String?
        let voteAverage: Double
        let genreIDs: [Int]
        let posterPath: String?
        let backdropPath: String?
        let isTV: Bool

        private enum CodingKeys: String, CodingKey {
            case id, title, name, overview
            case originalTitle = "original_title"
            case originalName = "original_name"
            case releaseDate = "release_date"
            case firstAirDate = "first_air_date"
            case voteAverage = "vote_average"
            case genreIDs = "genre_ids"
            case posterPath = "poster_path"
            case backdropPath = "backdrop_path"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            let movieTitle = try container.decodeIfPresent(String.self, forKey: .title)
            let tvTitle = try container.decodeIfPresent(String.self, forKey: .name)
            title = movieTitle ?? tvTitle ?? ""
            originalTitle = try container.decodeIfPresent(String.self, forKey: .originalTitle)
                ?? container.decodeIfPresent(String.self, forKey: .originalName)
                ?? title
            overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
            releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
                ?? container.decodeIfPresent(String.self, forKey: .firstAirDate)
            voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage) ?? 0
            genreIDs = try container.decodeIfPresent([Int].self, forKey: .genreIDs) ?? []
            posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
            backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
            isTV = movieTitle == nil && tvTitle != nil
        }
    }

    private struct Feed {
        let path: String
        let shelf: TMDBFeaturedMovie.Shelf
        let pageCount: Int
        let isTV: Bool
        var queryItems: [URLQueryItem] = []

        init(
            path: String,
            shelf: TMDBFeaturedMovie.Shelf,
            pageCount: Int,
            isTV: Bool = false,
            queryItems: [URLQueryItem] = []
        ) {
            self.path = path
            self.shelf = shelf
            self.pageCount = pageCount
            self.isTV = isTV
            self.queryItems = queryItems
        }
    }

    private struct DetailResponse: Decodable {
        struct ImageAsset: Decodable {
            let filePath: String
            let languageCode: String?
            let voteAverage: Double
            let voteCount: Int

            private enum CodingKeys: String, CodingKey {
                case filePath = "file_path"
                case languageCode = "iso_639_1"
                case voteAverage = "vote_average"
                case voteCount = "vote_count"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                filePath = try container.decode(String.self, forKey: .filePath)
                languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode)
                voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage) ?? 0
                voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount) ?? 0
            }
        }

        struct Images: Decodable {
            let backdrops: [ImageAsset]
            let posters: [ImageAsset]
            let logos: [ImageAsset]

            private enum CodingKeys: String, CodingKey {
                case backdrops, posters, logos
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                backdrops = try container.decodeIfPresent([ImageAsset].self, forKey: .backdrops) ?? []
                posters = try container.decodeIfPresent([ImageAsset].self, forKey: .posters) ?? []
                logos = try container.decodeIfPresent([ImageAsset].self, forKey: .logos) ?? []
            }
        }

        struct NamedValue: Decodable {
            let name: String
        }

        struct Person: Decodable {
            let id: Int
            let name: String
            let character: String?
            let job: String?
            let department: String?
            let profilePath: String?

            private enum CodingKeys: String, CodingKey {
                case id, name, character, job, department
                case profilePath = "profile_path"
            }
        }

        struct Credits: Decodable {
            let cast: [Person]
            let crew: [Person]
        }

        struct ReleaseDate: Decodable {
            let certification: String
            let type: Int
        }

        struct ReleaseDateRegion: Decodable {
            let region: String
            let releaseDates: [ReleaseDate]

            private enum CodingKeys: String, CodingKey {
                case region = "iso_3166_1"
                case releaseDates = "release_dates"
            }
        }

        struct ReleaseDates: Decodable {
            let results: [ReleaseDateRegion]
        }

        struct Keywords: Decodable {
            let keywords: [NamedValue]?
            let results: [NamedValue]?

            var values: [NamedValue] { keywords ?? results ?? [] }
        }

        struct ExternalIDs: Decodable {
            let imdbID: String?
            let tvdbID: Int?

            private enum CodingKeys: String, CodingKey {
                case imdbID = "imdb_id"
                case tvdbID = "tvdb_id"
            }
        }

        struct Video: Decodable {
            let id: String
            let key: String
            let name: String
            let site: String
            let type: String
            let official: Bool
            let publishedAt: String?
            let languageCode: String?

            private enum CodingKeys: String, CodingKey {
                case id, key, name, site, type, official
                case publishedAt = "published_at"
                case languageCode = "iso_639_1"
            }
        }

        struct Videos: Decodable {
            let results: [Video]
        }

        let title: String
        let originalTitle: String
        let overview: String
        let tagline: String?
        let releaseDate: String?
        let voteAverage: Double
        let runtime: Int?
        let genres: [NamedValue]
        let productionCompanies: [NamedValue]
        let networks: [NamedValue]?
        let credits: Credits?
        let recommendations: Response?
        let similar: Response?
        let releaseDates: ReleaseDates?
        let keywords: Keywords?
        let externalIDs: ExternalIDs?
        let images: Images?
        let videos: Videos?

        private enum CodingKeys: String, CodingKey {
            case title, name, overview, tagline, runtime, episodeRunTime, genres, credits, recommendations, similar, keywords, networks, images, videos
            case createdBy = "created_by"
            case originalTitle = "original_title"
            case originalName = "original_name"
            case releaseDate = "release_date"
            case firstAirDate = "first_air_date"
            case voteAverage = "vote_average"
            case productionCompanies = "production_companies"
            case releaseDates = "release_dates"
            case externalIDs = "external_ids"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title)
                ?? container.decodeIfPresent(String.self, forKey: .name) ?? ""
            originalTitle = try container.decodeIfPresent(String.self, forKey: .originalTitle)
                ?? container.decodeIfPresent(String.self, forKey: .originalName) ?? title
            overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
            tagline = try container.decodeIfPresent(String.self, forKey: .tagline)
            releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
                ?? container.decodeIfPresent(String.self, forKey: .firstAirDate)
            voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage) ?? 0
            runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
                ?? container.decodeIfPresent([Int].self, forKey: .episodeRunTime)?.first
            genres = try container.decodeIfPresent([NamedValue].self, forKey: .genres) ?? []
            productionCompanies = try container.decodeIfPresent([NamedValue].self, forKey: .productionCompanies)
                ?? container.decodeIfPresent([NamedValue].self, forKey: .createdBy) ?? []
            networks = try container.decodeIfPresent([NamedValue].self, forKey: .networks)
            credits = try container.decodeIfPresent(Credits.self, forKey: .credits)
            recommendations = try container.decodeIfPresent(Response.self, forKey: .recommendations)
            similar = try container.decodeIfPresent(Response.self, forKey: .similar)
            releaseDates = try container.decodeIfPresent(ReleaseDates.self, forKey: .releaseDates)
            keywords = try container.decodeIfPresent(Keywords.self, forKey: .keywords)
            externalIDs = try container.decodeIfPresent(ExternalIDs.self, forKey: .externalIDs)
            images = try container.decodeIfPresent(Images.self, forKey: .images)
            videos = try container.decodeIfPresent(Videos.self, forKey: .videos)
        }
    }

    private struct PersonDetailResponse: Decodable {
        struct MovieCredits: Decodable {
            struct Credit: Decodable {
                let id: Int
                let title: String
                let character: String?
                let job: String?
                let releaseDate: String?
                let posterPath: String?
                let voteCount: Int

                private enum CodingKeys: String, CodingKey {
                    case id, title, character, job
                    case releaseDate = "release_date"
                    case posterPath = "poster_path"
                    case voteCount = "vote_count"
                }
            }

            let cast: [Credit]
            let crew: [Credit]
        }

        let id: Int
        let name: String
        let biography: String
        let birthday: String?
        let deathday: String?
        let placeOfBirth: String?
        let knownForDepartment: String?
        let profilePath: String?
        let movieCredits: MovieCredits?

        private enum CodingKeys: String, CodingKey {
            case id, name, biography, birthday, deathday
            case placeOfBirth = "place_of_birth"
            case knownForDepartment = "known_for_department"
            case profilePath = "profile_path"
            case movieCredits = "movie_credits"
        }
    }

    private struct PersonSearchResponse: Decodable {
        struct Person: Decodable {
            let id: Int
            let name: String
            let knownForDepartment: String?
            let profilePath: String?
            let popularity: Double

            private enum CodingKeys: String, CodingKey {
                case id, name, popularity
                case knownForDepartment = "known_for_department"
                case profilePath = "profile_path"
            }
        }

        let results: [Person]
    }

    private static var feeds: [Feed] {
        let upcomingRange = upcomingDateRange()
        return [
            Feed(path: "trending/movie/day", shelf: .trendingToday, pageCount: 2),
            Feed(path: "trending/movie/week", shelf: .trending, pageCount: 2),
            Feed(path: "movie/popular", shelf: .popular, pageCount: 2),
            Feed(path: "movie/now_playing", shelf: .nowPlaying, pageCount: 2),
            Feed(path: "movie/top_rated", shelf: .classics, pageCount: 2),
            Feed(path: "discover/movie", shelf: .classics70s, pageCount: 1, queryItems: decadeQueryItems(startYear: 1970, endYear: 1979)),
            Feed(path: "discover/movie", shelf: .classics80s, pageCount: 1, queryItems: decadeQueryItems(startYear: 1980, endYear: 1989)),
            Feed(path: "discover/movie", shelf: .classics90s, pageCount: 1, queryItems: decadeQueryItems(startYear: 1990, endYear: 1999)),
            Feed(path: "discover/movie", shelf: .classics2000s, pageCount: 1, queryItems: decadeQueryItems(startYear: 2000, endYear: 2009)),
            Feed(path: "discover/movie", shelf: .classics2010s, pageCount: 1, queryItems: decadeQueryItems(startYear: 2010, endYear: 2019)),
            Feed(path: "discover/movie", shelf: .classics2020s, pageCount: 1, queryItems: decadeQueryItems(startYear: 2020, endYear: 2029)),
            Feed(
                path: "discover/movie",
                shelf: .animation,
                pageCount: 2,
                queryItems: discoveryQueryItems(genreID: 16)
            ),
            Feed(
                path: "discover/movie",
                shelf: .scienceFiction,
                pageCount: 2,
                queryItems: discoveryQueryItems(genreID: 878)
            ),
            Feed(path: "discover/movie", shelf: .action, pageCount: 1, queryItems: discoveryQueryItems(genreID: 28)),
            Feed(path: "discover/movie", shelf: .comedy, pageCount: 1, queryItems: discoveryQueryItems(genreID: 35)),
            Feed(path: "discover/movie", shelf: .drama, pageCount: 1, queryItems: discoveryQueryItems(genreID: 18)),
            Feed(path: "discover/movie", shelf: .horror, pageCount: 1, queryItems: discoveryQueryItems(genreID: 27)),
            Feed(
                path: "discover/movie",
                shelf: .upcoming,
                pageCount: 2,
                queryItems: [
                    URLQueryItem(name: "include_adult", value: "false"),
                    URLQueryItem(name: "include_video", value: "false"),
                    URLQueryItem(name: "sort_by", value: "popularity.desc"),
                    URLQueryItem(name: "primary_release_date.gte", value: upcomingRange.start),
                    URLQueryItem(name: "primary_release_date.lte", value: upcomingRange.end)
                ]
            ),
            Feed(path: "trending/tv/day", shelf: .trendingSeries, pageCount: 2, isTV: true),
            Feed(path: "trending/tv/week", shelf: .popularSeries, pageCount: 2, isTV: true),
            Feed(path: "tv/popular", shelf: .popularSeries, pageCount: 2, isTV: true),
            Feed(path: "tv/airing_today", shelf: .airingToday, pageCount: 1, isTV: true),
            Feed(path: "tv/on_the_air", shelf: .onTheAir, pageCount: 1, isTV: true),
            Feed(path: "tv/top_rated", shelf: .topSeries, pageCount: 2, isTV: true),
            Feed(path: "tv/top_rated", shelf: .top200, pageCount: 10, isTV: true),
            Feed(path: "discover/tv", shelf: .shortDrama, pageCount: 3, isTV: true, queryItems: shortDramaQueryItems()),
            Feed(path: "discover/tv", shelf: .shortRomance, pageCount: 2, isTV: true, queryItems: shortDramaQueryItems(genreID: 10749)),
            Feed(path: "discover/tv", shelf: .shortComedy, pageCount: 2, isTV: true, queryItems: shortDramaQueryItems(genreID: 35)),
            Feed(path: "discover/tv", shelf: .shortMystery, pageCount: 2, isTV: true, queryItems: shortDramaQueryItems(genreID: 9648)),
            Feed(path: "discover/tv", shelf: .shortAction, pageCount: 2, isTV: true, queryItems: shortDramaQueryItems(genreID: 10759)),
            Feed(path: "discover/tv", shelf: .animationSeries, pageCount: 1, isTV: true, queryItems: discoveryQueryItems(genreID: 16)),
            Feed(path: "discover/tv", shelf: .crimeSeries, pageCount: 1, isTV: true, queryItems: discoveryQueryItems(genreID: 80)),
            Feed(path: "discover/tv", shelf: .dramaSeries, pageCount: 1, isTV: true, queryItems: discoveryQueryItems(genreID: 18)),
            Feed(path: "discover/tv", shelf: .variety, pageCount: 1, isTV: true, queryItems: discoveryQueryItems(genreID: 10764)),
            Feed(path: "discover/tv", shelf: .talkSeries, pageCount: 1, isTV: true, queryItems: discoveryQueryItems(genreID: 10767)),
            Feed(path: "discover/tv", shelf: .realitySeries, pageCount: 1, isTV: true, queryItems: discoveryQueryItems(genreID: 10764))
        ]
    }

    private static func shortDramaQueryItems(genreID: Int? = nil) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "include_null_first_air_dates", value: "false"),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "vote_count.gte", value: "5"),
            URLQueryItem(name: "with_runtime.lte", value: "20")
        ]
        if let genreID {
            items.append(URLQueryItem(name: "with_genres", value: String(genreID)))
        }
        return items
    }

    static func load(forceRefresh: Bool = false) async -> [TMDBFeaturedMovie] {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String,
              !apiKey.isEmpty else { return [] }

        var loaded: [(Feed, [Item])] = []
        await withTaskGroup(of: (Feed, [Item]).self) { group in
            for feed in feeds {
                for page in 1...feed.pageCount {
                    group.addTask {
                        (
                            feed,
                            await request(
                                path: feed.path,
                                page: page,
                                apiKey: apiKey,
                                queryItems: feed.queryItems,
                                forceRefresh: forceRefresh
                            )
                        )
                    }
                }
            }
            for await result in group {
                loaded.append(result)
            }
        }

        var order: [String] = []
        var itemsByID: [String: TMDBFeaturedMovie] = [:]
        for (feed, items) in loaded {
            let shelf = feed.shelf
            for item in items where item.posterPath != nil {
                if shelf == .upcoming, !isUpcoming(item.releaseDate) { continue }
                let key = (feed.isTV ? "tv-" : "movie-") + String(item.id)
                let existing = itemsByID[key]
                var shelves = existing?.shelves ?? []
                shelves.insert(shelf)
                if feed.isTV {
                    if item.genreIDs.contains(16) { shelves.insert(.animationSeries) }
                    if item.genreIDs.contains(18) { shelves.insert(.dramaSeries) }
                    if item.genreIDs.contains(80) { shelves.insert(.crimeSeries) }
                    if item.genreIDs.contains(10764) { shelves.insert(.variety) }
                } else {
                    if item.genreIDs.contains(16) { shelves.insert(.animation) }
                    if item.genreIDs.contains(878) { shelves.insert(.scienceFiction) }
                    if item.genreIDs.contains(28) { shelves.insert(.action) }
                    if item.genreIDs.contains(35) { shelves.insert(.comedy) }
                    if item.genreIDs.contains(18) { shelves.insert(.drama) }
                    if item.genreIDs.contains(27) { shelves.insert(.horror) }
                }
                let movie = TMDBFeaturedMovie(
                    id: item.id,
                    title: item.title,
                    originalTitle: item.originalTitle,
                    aliases: [],
                    overview: item.overview.isEmpty ? "TMDB 暂未提供简介。" : item.overview,
                    year: item.releaseDate.flatMap { Int($0.prefix(4)) } ?? 0,
                    rating: item.voteAverage,
                    genres: item.genreIDs.compactMap(genreName).prefix(3).map { $0 },
                    posterPath: item.posterPath!,
                    backdropPath: item.backdropPath ?? item.posterPath!,
                    shelves: shelves,
                    isTV: feed.isTV
                )
                if existing == nil { order.append(key) }
                itemsByID[key] = movie
            }
        }
        let result = order.compactMap { itemsByID[$0] }
        if !result.isEmpty {
            await TMDBPersistentCache.storeMovies(result)
        }
        return result
    }

    static func cachedMovies() async -> [TMDBFeaturedMovie]? {
        await TMDBPersistentCache.movies()
    }

    static func search(query: String) async -> [TMDBFeaturedMovie] {
        guard let apiKey,
              let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
              var components = RoveAPISettings.tmdbAPIURL(path: "search/multi")
                .flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "zh-CN"),
            URLQueryItem(name: "query", value: cleanQuery),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        guard let url = components.url,
              let data = await requestData(url: url),
              let response = try? JSONDecoder().decode(Response.self, from: data) else {
            return []
        }
        return response.results.compactMap { item in
            guard item.id > 0, let posterPath = item.posterPath else { return nil }
            return featuredMovie(from: item, posterPath: posterPath)
        }
    }

    static func loadDetails(movieID: Int, isTV: Bool = false) async -> TMDBMovieDetails? {
        guard let apiKey = apiKey else { return nil }
        var components = RoveAPISettings.tmdbAPIURL(path: "\(isTV ? "tv" : "movie")/\(movieID)")
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "zh-CN"),
            URLQueryItem(name: "include_image_language", value: "zh,null,en"),
            URLQueryItem(name: "include_video_language", value: "zh-CN,zh,en,null"),
            URLQueryItem(name: "append_to_response", value: isTV
                ? "credits,recommendations,similar,keywords,external_ids,images,videos"
                : "credits,recommendations,similar,release_dates,keywords,external_ids,images,videos")
        ]
        guard let url = components?.url,
              let data = await requestData(url: url),
              let response = try? JSONDecoder().decode(DetailResponse.self, from: data)
        else { return nil }

        let cast = Array((response.credits?.cast ?? []).prefix(14)).map {
            TMDBMoviePerson(
                id: "cast-\($0.id)-\($0.character ?? "")",
                tmdbID: $0.id,
                name: $0.name,
                role: $0.character?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "演员",
                profilePath: $0.profilePath
            )
        }
        let keyCrew = (response.credits?.crew ?? []).filter {
            let department = $0.department?.lowercased() ?? ""
            let job = $0.job?.lowercased() ?? ""
            return department == "directing"
                || department == "writing"
                || job.contains("director")
                || job.contains("writer")
                || job.contains("screenplay")
        }
        let crew = Array(keyCrew.prefix(8)).map {
            TMDBMoviePerson(
                id: "crew-\($0.id)-\($0.job ?? "")",
                tmdbID: $0.id,
                name: $0.name,
                role: localizedCrewRole($0.job),
                profilePath: $0.profilePath
            )
        }
        let relatedItems = (response.recommendations?.results ?? [])
            + (response.similar?.results ?? [])
        var relatedIDs = Set<Int>()
        let relatedMovies = relatedItems.compactMap { item -> TMDBFeaturedMovie? in
            guard item.id != movieID,
                  relatedIDs.insert(item.id).inserted,
                  let posterPath = item.posterPath else { return nil }
            return featuredMovie(from: item, posterPath: posterPath)
        }

        let posterAssets = response.images?.posters ?? []
        let backdropAssets = response.images?.backdrops ?? []
        let logoAssets = response.images?.logos ?? []
        let qualityOrder: (DetailResponse.ImageAsset, DetailResponse.ImageAsset) -> Bool = { lhs, rhs in
            if lhs.voteAverage != rhs.voteAverage { return lhs.voteAverage > rhs.voteAverage }
            if lhs.voteCount != rhs.voteCount { return lhs.voteCount > rhs.voteCount }
            return lhs.filePath < rhs.filePath
        }
        let orderedPosters = posterAssets.sorted { lhs, rhs in
            // Avoid English lettering baked into a poster when a Chinese or
            // language-neutral alternative is available.
            func languageRank(_ code: String?) -> Int {
                if code?.lowercased().hasPrefix("zh") == true { return 2 }
                return code == nil ? 1 : 0
            }
            let lhsRank = languageRank(lhs.languageCode)
            let rhsRank = languageRank(rhs.languageCode)
            return lhsRank == rhsRank ? qualityOrder(lhs, rhs) : lhsRank > rhsRank
        }
        let orderedBackdrops = backdropAssets.sorted(by: qualityOrder)
        // Chinese logos are sorted first, while retaining English/null logos
        // for the detail artwork shelf. The home hero only renders the Chinese
        // candidate through preferredChineseLogoPath.
        let orderedLogos = logoAssets.sorted { lhs, rhs in
            let lhsChinese = lhs.languageCode?.lowercased().hasPrefix("zh") == true
            let rhsChinese = rhs.languageCode?.lowercased().hasPrefix("zh") == true
            if lhsChinese != rhsChinese { return lhsChinese }
            return qualityOrder(lhs, rhs)
        }
        let videoTypeRank = ["trailer": 3, "teaser": 2, "clip": 1]
        let orderedVideos = (response.videos?.results ?? [])
            .filter {
                $0.site.caseInsensitiveCompare("YouTube") == .orderedSame
                    && !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && videoTypeRank[$0.type.lowercased()] != nil
            }
            .sorted { lhs, rhs in
                let lhsType = videoTypeRank[lhs.type.lowercased()] ?? 0
                let rhsType = videoTypeRank[rhs.type.lowercased()] ?? 0
                if lhsType != rhsType { return lhsType > rhsType }
                if lhs.official != rhs.official { return lhs.official }
                let lhsChinese = lhs.languageCode?.lowercased().hasPrefix("zh") == true
                let rhsChinese = rhs.languageCode?.lowercased().hasPrefix("zh") == true
                if lhsChinese != rhsChinese { return lhsChinese }
                return (lhs.publishedAt ?? "") > (rhs.publishedAt ?? "")
            }
        var seenVideoKeys = Set<String>()
        let trailers = orderedVideos.compactMap { video -> TMDBTrailer? in
            guard seenVideoKeys.insert(video.key).inserted else { return nil }
            return TMDBTrailer(
                id: video.id,
                key: video.key,
                name: video.name,
                site: video.site,
                type: video.type,
                official: video.official,
                publishedAt: video.publishedAt,
                languageCode: video.languageCode
            )
        }

        let result = TMDBMovieDetails(
            title: response.title,
            originalTitle: response.originalTitle,
            imdbID: response.externalIDs?.imdbID,
            tvdbID: response.externalIDs?.tvdbID,
            overview: response.overview,
            tagline: response.tagline?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            releaseDate: response.releaseDate,
            rating: response.voteAverage,
            runtimeMinutes: response.runtime,
            certification: isTV ? nil : certification(from: response.releaseDates),
            genres: response.genres.map(\.name),
            studios: (response.networks ?? response.productionCompanies).map(\.name),
            people: cast + crew,
            relatedMovies: Array(relatedMovies.prefix(20)),
            keywords: response.keywords?.values.map(\.name),
            backdropPaths: orderedBackdrops.map(\.filePath),
            posterPaths: orderedPosters.map(\.filePath),
            logoPaths: orderedLogos.map(\.filePath),
            logoLanguages: Dictionary(uniqueKeysWithValues: orderedLogos.map {
                ($0.filePath, $0.languageCode ?? "")
            }),
            trailers: Array(trailers.prefix(8))
        )
        await TMDBPersistentCache.storeDetails(result, movieID: isTV ? -movieID : movieID)
        return result
    }

    static func cachedDetails(movieID: Int, isTV: Bool = false) async -> TMDBMovieDetails? {
        await TMDBPersistentCache.details(movieID: isTV ? -movieID : movieID)
    }

    /// Resolves a media-server item to TMDB when the server did not expose a
    /// provider id. This keeps the artwork shelves available for Emby,
    /// Jellyfin and Feiniu detail pages as well as TMDB recommendation pages.
    static func loadDetails(title: String, year: Int?, isTV: Bool) async -> TMDBMovieDetails? {
        guard let apiKey,
              let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
              var components = RoveAPISettings.tmdbAPIURL(path: "search/multi")
                .flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "zh-CN"),
            URLQueryItem(name: "query", value: cleanTitle),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        guard let url = components.url,
              let data = await requestData(url: url),
              let response = try? JSONDecoder().decode(Response.self, from: data) else {
            return nil
        }

        let normalizedTitle = cleanTitle.lowercased()
            .filter { $0.isLetter || $0.isNumber }
        let match = response.results
            .filter { $0.id > 0 && ($0.posterPath != nil || $0.backdropPath != nil) }
            .filter { result in
                // Multi-search also returns people. Prefer the requested
                // media kind while retaining a title-only fallback below.
                result.isTV == isTV
            }
            .sorted { lhs, rhs in
                func score(_ item: Item) -> Int {
                    let candidate = item.title.lowercased().filter { $0.isLetter || $0.isNumber }
                    var value = candidate == normalizedTitle ? 100 : 0
                    if candidate.contains(normalizedTitle) || normalizedTitle.contains(candidate) { value += 25 }
                    if let year, let release = item.releaseDate, let itemYear = Int(release.prefix(4)) {
                        value += max(0, 20 - abs(itemYear - year))
                    }
                    value += Int(item.voteAverage.rounded())
                    return value
                }
                return score(lhs) > score(rhs)
            }
            .first
            ?? response.results
                .filter { $0.id > 0 && ($0.posterPath != nil || $0.backdropPath != nil) }
                .first

        guard let match else { return nil }
        return await loadDetails(movieID: match.id, isTV: match.isTV)
    }

    static func cachedPersonDetails(personID: Int) async -> TMDBPersonDetails? {
        await TMDBPersistentCache.person(personID: personID)
    }

    static func searchPerson(named name: String, role: String?) async -> TMDBMoviePerson? {
        guard let apiKey else { return nil }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        var components = RoveAPISettings.tmdbAPIURL(path: "search/person")
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "zh-CN"),
            URLQueryItem(name: "query", value: cleanName),
            URLQueryItem(name: "include_adult", value: "false"),
        ]
        guard let url = components?.url,
              let data = await requestData(url: url),
              let response = try? JSONDecoder().decode(PersonSearchResponse.self, from: data),
              let result = response.results.sorted(by: { lhs, rhs in
                  let lhsExact = lhs.name.caseInsensitiveCompare(cleanName) == .orderedSame
                  let rhsExact = rhs.name.caseInsensitiveCompare(cleanName) == .orderedSame
                  if lhsExact != rhsExact { return lhsExact }
                  return lhs.popularity > rhs.popularity
              }).first else { return nil }
        return TMDBMoviePerson(
            id: "person-\(result.id)",
            tmdbID: result.id,
            name: result.name,
            role: role?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? result.knownForDepartment
                ?? "演职人员",
            profilePath: result.profilePath
        )
    }

    static func loadPersonDetails(personID: Int) async -> TMDBPersonDetails? {
        guard personID > 0, let apiKey else { return nil }
        var components = RoveAPISettings.tmdbAPIURL(path: "person/\(personID)")
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "zh-CN"),
            URLQueryItem(name: "append_to_response", value: "movie_credits")
        ]
        guard let url = components?.url,
              let data = await requestData(url: url),
              let response = try? JSONDecoder().decode(PersonDetailResponse.self, from: data)
        else { return nil }

        let cast = response.movieCredits?.cast ?? []
        let crew = response.movieCredits?.crew ?? []
        var seen = Set<Int>()
        let ordered = (cast + crew)
            .filter { $0.posterPath != nil }
            .sorted {
                let lhsYear = $0.releaseDate.flatMap { Int($0.prefix(4)) } ?? 0
                let rhsYear = $1.releaseDate.flatMap { Int($0.prefix(4)) } ?? 0
                if lhsYear != rhsYear { return lhsYear > rhsYear }
                return $0.voteCount > $1.voteCount
            }
        let credits = ordered.compactMap { credit -> TMDBPersonCredit? in
            guard seen.insert(credit.id).inserted else { return nil }
            return TMDBPersonCredit(
                id: credit.id,
                title: credit.title,
                character: credit.character,
                job: credit.job,
                year: credit.releaseDate.flatMap { Int($0.prefix(4)) },
                posterPath: credit.posterPath
            )
        }
        let result = TMDBPersonDetails(
            id: response.id,
            name: response.name,
            biography: response.biography,
            birthday: response.birthday,
            deathday: response.deathday,
            placeOfBirth: response.placeOfBirth,
            knownForDepartment: response.knownForDepartment,
            profilePath: response.profilePath,
            credits: Array(credits.prefix(60))
        )
        await TMDBPersistentCache.storePerson(result, personID: personID)
        return result
    }

    private static func request(
        path: String,
        page: Int,
        apiKey: String,
        queryItems: [URLQueryItem] = [],
        forceRefresh: Bool = false
    ) async -> [Item] {
        var components = RoveAPISettings.tmdbAPIURL(path: path)
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "zh-CN"),
            URLQueryItem(name: "region", value: "CN"),
            URLQueryItem(name: "page", value: String(page))
        ] + queryItems
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = forceRefresh
            ? .reloadIgnoringLocalAndRemoteCacheData
            : .returnCacheDataElseLoad
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let configuration = ProxyNetworkConfiguration.configured(.default)
            configuration.urlCache = URLCache(
                memoryCapacity: 4 * 1_024 * 1_024,
                diskCapacity: 24 * 1_024 * 1_024
            )
            let (data, response) = try await URLSession(configuration: configuration).data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return [] }
            return (try? JSONDecoder().decode(Response.self, from: data).results) ?? []
        } catch {
            return []
        }
    }

    private static var apiKey: String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private static func discoveryQueryItems(genreID: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "include_video", value: "false"),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "with_genres", value: String(genreID))
        ]
    }

    private static func decadeQueryItems(startYear: Int, endYear: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "include_video", value: "false"),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "primary_release_date.gte", value: "\(startYear)-01-01"),
            URLQueryItem(name: "primary_release_date.lte", value: "\(endYear)-12-31"),
            URLQueryItem(name: "vote_count.gte", value: "20")
        ]
    }

    private static func upcomingDateRange(now: Date = Date()) -> (start: String, end: String) {
        let calendar = Calendar(identifier: .gregorian)
        let end = calendar.date(byAdding: .month, value: 12, to: now) ?? now
        return (tmdbDateString(now), tmdbDateString(end))
    }

    private static func isUpcoming(_ releaseDate: String?) -> Bool {
        guard let releaseDate, releaseDate.count >= 10 else { return false }
        let range = upcomingDateRange()
        return releaseDate >= range.start && releaseDate <= range.end
    }

    private static func tmdbDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func requestData(url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let configuration = ProxyNetworkConfiguration.configured(.default)
        configuration.urlCache = URLCache(
            memoryCapacity: 8 * 1_024 * 1_024,
            diskCapacity: 48 * 1_024 * 1_024
        )
        guard let (data, response) = try? await URLSession(configuration: configuration).data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else { return nil }
        return data
    }

    private static func featuredMovie(from item: Item, posterPath: String) -> TMDBFeaturedMovie {
        var shelves = Set<TMDBFeaturedMovie.Shelf>()
        if item.isTV {
            if item.genreIDs.contains(16) { shelves.insert(.animationSeries) }
            if item.genreIDs.contains(18) { shelves.insert(.dramaSeries) }
            if item.genreIDs.contains(80) { shelves.insert(.crimeSeries) }
            if item.genreIDs.contains(10764) { shelves.insert(.variety) }
        } else {
            if item.genreIDs.contains(16) { shelves.insert(.animation) }
            if item.genreIDs.contains(878) { shelves.insert(.scienceFiction) }
        }
        return TMDBFeaturedMovie(
            id: item.id,
            title: item.title,
            originalTitle: item.originalTitle,
            aliases: [],
            overview: item.overview.isEmpty ? "TMDB 暂未提供简介。" : item.overview,
            year: item.releaseDate.flatMap { Int($0.prefix(4)) } ?? 0,
            rating: item.voteAverage,
            genres: item.genreIDs.compactMap(genreName).prefix(3).map { $0 },
            posterPath: posterPath,
            backdropPath: item.backdropPath ?? posterPath,
            shelves: shelves,
            isTV: item.isTV
        )
    }

    private static func certification(from releaseDates: DetailResponse.ReleaseDates?) -> String? {
        let regions = releaseDates?.results ?? []
        for code in ["CN", "US", "HK", "TW"] {
            guard let dates = regions.first(where: { $0.region == code })?.releaseDates else { continue }
            if let value = dates.sorted(by: { $0.type < $1.type }).first(where: {
                !$0.certification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })?.certification {
                return value
            }
        }
        return nil
    }

    private static func localizedCrewRole(_ job: String?) -> String {
        switch job?.lowercased() {
        case "director": "导演"
        case "screenplay": "编剧"
        case "writer": "编剧"
        case "story": "故事"
        default: job?.nonEmpty ?? "幕后"
        }
    }

    private static func genreName(_ id: Int) -> String? {
        switch id {
        case 28: "动作"
        case 12: "冒险"
        case 16: "动画"
        case 35: "喜剧"
        case 80: "犯罪"
        case 99: "纪录片"
        case 18: "剧情"
        case 10751: "家庭"
        case 14: "奇幻"
        case 36: "历史"
        case 27: "恐怖"
        case 10402: "音乐"
        case 9648: "悬疑"
        case 10749: "爱情"
        case 878: "科幻"
        case 53: "惊悚"
        case 10752: "战争"
        case 37: "西部"
        default: nil
        }
    }
}

private enum DJHUBDiscoveryService {
    struct CategoryPage {
        let movies: [TMDBFeaturedMovie]
        let hasMore: Bool
    }

    private static let cacheURL: URL = {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DJHUBSample", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("discovery-v1.json")
    }()

    private static let categoryCacheDirectory: URL = {
        let directory = cacheURL.deletingLastPathComponent()
            .appendingPathComponent("categories-v1", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private static let client = DJHUBAPIClient {
        let environment = ProcessInfo.processInfo.environment["DJHUB_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bundled = (Bundle.main.object(forInfoDictionaryKey: "DJHUBAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return environment?.nonEmpty ?? bundled?.nonEmpty
    }

    static let defaultTaxonomy = TaxonomyResponse(
        contentTypes: [
            TaxonomyItem(id: "live_action", name: "真人剧", sortOrder: 10),
            TaxonomyItem(id: "motion_comic", name: "漫剧", sortOrder: 20),
            TaxonomyItem(id: "ai_drama", name: "AI剧", sortOrder: 30),
            TaxonomyItem(id: "comic", name: "漫画", sortOrder: 40)
        ],
        genres: [
            TaxonomyItem(id: "10749", slug: "romance", name: "爱情", categoryGroup: "genre", sortOrder: 10),
            TaxonomyItem(id: "20001", slug: "era", name: "年代", categoryGroup: "genre", sortOrder: 20),
            TaxonomyItem(id: "20002", slug: "comeback", name: "逆袭", categoryGroup: "genre", sortOrder: 30),
            TaxonomyItem(id: "20003", slug: "legend", name: "传奇", categoryGroup: "genre", sortOrder: 40),
            TaxonomyItem(id: "20004", slug: "growth", name: "成长", categoryGroup: "genre", sortOrder: 50),
            TaxonomyItem(id: "10751", slug: "family", name: "家庭", categoryGroup: "genre", sortOrder: 60),
            TaxonomyItem(id: "20005", slug: "clan", name: "家族", categoryGroup: "genre", sortOrder: 70),
            TaxonomyItem(id: "20006", slug: "cute", name: "萌宝", categoryGroup: "genre", sortOrder: 80),
            TaxonomyItem(id: "9648", slug: "mystery", name: "悬疑", categoryGroup: "genre", sortOrder: 90),
            TaxonomyItem(id: "20007", slug: "thriller", name: "惊悚", categoryGroup: "genre", sortOrder: 100),
            TaxonomyItem(id: "27", slug: "horror", name: "恐怖", categoryGroup: "genre", sortOrder: 110),
            TaxonomyItem(id: "20008", slug: "chronicle", name: "志怪", categoryGroup: "genre", sortOrder: 120),
            TaxonomyItem(id: "36", slug: "costume", name: "古装", categoryGroup: "genre", sortOrder: 130),
            TaxonomyItem(id: "14", slug: "fantasy", name: "玄幻", categoryGroup: "genre", sortOrder: 140),
            TaxonomyItem(id: "20009", slug: "wonder", name: "奇幻", categoryGroup: "genre", sortOrder: 150),
            TaxonomyItem(id: "20010", slug: "urban", name: "都市", categoryGroup: "genre", sortOrder: 160),
            TaxonomyItem(id: "20011", slug: "youth", name: "青春", categoryGroup: "genre", sortOrder: 170),
            TaxonomyItem(id: "35", slug: "comedy", name: "喜剧", categoryGroup: "genre", sortOrder: 180),
            TaxonomyItem(id: "878", slug: "science-fiction", name: "科幻", categoryGroup: "genre", sortOrder: 190),
            TaxonomyItem(id: "20012", slug: "disaster", name: "灾难", categoryGroup: "genre", sortOrder: 200),
            TaxonomyItem(id: "28", slug: "action-adventure", name: "动作冒险", categoryGroup: "genre", sortOrder: 210),
            TaxonomyItem(id: "20013", slug: "war", name: "战争", categoryGroup: "genre", sortOrder: 220),
            TaxonomyItem(id: "20014", slug: "variety", name: "综艺", categoryGroup: "genre", sortOrder: 230),
            TaxonomyItem(id: "18", slug: "drama", name: "剧情", categoryGroup: "genre", sortOrder: 240)
        ]
    )

    static func cachedMovies() async -> [TMDBFeaturedMovie]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode([TMDBFeaturedMovie].self, from: data)
    }

    static func cachedDramas(
        genre: String?,
        contentType: String?,
        page: Int = 1
    ) async -> [TMDBFeaturedMovie] {
        let categoryURL = categoryCacheURL(genre: genre, contentType: contentType, page: page)
        if let data = try? Data(contentsOf: categoryURL),
           let cached = try? JSONDecoder().decode([TMDBFeaturedMovie].self, from: data),
           !cached.isEmpty {
            return cached
        }

        guard page == 1 else { return [] }
        guard let discovery = await cachedMovies() else { return [] }
        return discovery.filter { movie in
            if let genre, !movie.genres.contains(where: { $0.caseInsensitiveCompare(genre) == .orderedSame }) {
                return false
            }
            if let contentType, movie.contentType != contentType {
                return false
            }
            return true
        }
    }

    static func loadHome() async -> [TMDBFeaturedMovie] {
        do {
            async let topResult = client.dramas(sort: "score", limit: 200)
            async let popularResult = client.dramas(sort: "popular", limit: 200)
            async let taxonomyResult = client.taxonomy()
            let (top, popular, taxonomy) = try await (topResult, popularResult, taxonomyResult)

            let categorySpecs = categoryShelves(from: taxonomy.value.genres)
            var categoryResults: [(TMDBFeaturedMovie.Shelf, [Drama])] = []
            await withTaskGroup(of: (TMDBFeaturedMovie.Shelf, [Drama]).self) { group in
                for (shelf, genre) in categorySpecs {
                    group.addTask {
                        let dramas = try? await client.dramas(
                            sort: "popular",
                            limit: 60,
                            genre: genre.name
                        ).value.data
                        return (shelf, dramas ?? [])
                    }
                }
                for await result in group { categoryResults.append(result) }
            }

            var order: [String] = []
            var byID: [String: TMDBFeaturedMovie] = [:]
            func merge(_ dramas: [Drama], shelf: TMDBFeaturedMovie.Shelf) {
                for drama in dramas {
                    let key = drama.id
                    var shelves = byID[key]?.shelves ?? inferredShelves(for: drama)
                    shelves.insert(shelf)
                    let movie = featuredMovie(from: drama, shelves: shelves)
                    if byID[key] == nil { order.append(key) }
                    byID[key] = movie
                }
            }
            merge(top.value.data, shelf: .top200)
            merge(popular.value.data, shelf: .shortDrama)
            for (shelf, dramas) in categoryResults { merge(dramas, shelf: shelf) }
            let result = order.compactMap { byID[$0] }
            if let data = try? JSONEncoder().encode(result) {
                try? data.write(to: cacheURL, options: .atomic)
            }
            return result
        } catch {
            return await cachedMovies() ?? []
        }
    }

    static func search(query: String) async -> [TMDBFeaturedMovie] {
        do {
            let result = try await client.dramas(limit: 60, query: query)
            return result.value.data.map { featuredMovie(from: $0, shelves: [.shortDrama]) }
        } catch {
            return []
        }
    }

    static func taxonomy() async -> TaxonomyResponse? {
        try? await client.taxonomy().value
    }

    static func popularPeople() async -> [TMDBMoviePerson] {
        guard let people = try? await client.people(limit: 20).value.data else { return [] }
        return people.map { person in
            TMDBMoviePerson(
                id: person.id,
                tmdbID: -1,
                name: person.name,
                role: "演员",
                profilePath: person.avatar.nonEmpty
            )
        }
    }

    static func companies() async -> [DJHUBCompany] {
        (try? await client.companies(limit: 4).value.data) ?? []
    }

    static func person(id: String) async -> DJHUBPerson? {
        try? await client.person(id: id).value
    }

    static func company(id: String) async -> DJHUBCompany? {
        try? await client.company(id: id).value
    }

    static func dramaPage(
        genre: String?,
        contentType: String?,
        page: Int,
        limit: Int = 30
    ) async -> CategoryPage {
        do {
            let result = try await client.dramas(
                sort: "popular",
                limit: limit,
                page: page,
                genre: genre,
                contentType: contentType
            )
            let movies = result.value.data.map { featuredMovie(from: $0, shelves: [.shortDrama]) }
            if let data = try? JSONEncoder().encode(movies) {
                try? data.write(
                    to: categoryCacheURL(genre: genre, contentType: contentType, page: page),
                    options: .atomic
                )
            }
            return CategoryPage(
                movies: movies,
                hasMore: result.value.meta.page < result.value.meta.pages
            )
        } catch {
            return CategoryPage(
                movies: await cachedDramas(
                    genre: genre,
                    contentType: contentType,
                    page: page
                ),
                hasMore: false
            )
        }
    }

    private static func categoryCacheURL(
        genre: String?,
        contentType: String?,
        page: Int
    ) -> URL {
        let key = "genre=\(genre ?? "")&contentType=\(contentType ?? "")&page=\(page)"
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return categoryCacheDirectory.appendingPathComponent(digest + ".json")
    }

    static func details(for movie: TMDBFeaturedMovie) async -> TMDBMovieDetails? {
        guard let id = movie.djhubID,
              let drama = try? await client.drama(id: id).value else { return nil }
        let cast = (drama.credits?.cast ?? []).prefix(14).enumerated().map { index, person in
            TMDBMoviePerson(
                id: person.stableID,
                tmdbID: -(index + 1),
                name: person.name,
                role: person.characterName?.nonEmpty ?? "演员",
                profilePath: person.avatar
            )
        }
        let crew = (drama.credits?.crew ?? []).prefix(8).enumerated().map { index, person in
            TMDBMoviePerson(
                id: person.stableID,
                tmdbID: -(100 + index),
                name: person.name,
                role: person.job?.nonEmpty ?? person.department?.nonEmpty ?? "幕后",
                profilePath: person.avatar
            )
        }
        let backdrops = ([drama.images?.backdrop, drama.cover]
            + (drama.images?.backdrops.map(\.url) ?? [])
            + (drama.images?.stills.map(\.url) ?? []))
            .compactMap { $0?.nonEmpty }
        let posters = ([drama.images?.poster, drama.poster]
            + (drama.images?.posters.map(\.url) ?? []))
            .compactMap { $0?.nonEmpty }
        return TMDBMovieDetails(
            title: drama.title,
            originalTitle: drama.originalTitle,
            imdbID: nil,
            tvdbID: nil,
            overview: drama.overview,
            tagline: drama.tagline.nonEmpty,
            releaseDate: drama.releaseDate.nonEmpty,
            rating: drama.score,
            runtimeMinutes: drama.minutes > 0 ? drama.minutes : nil,
            certification: nil,
            genres: drama.genres,
            studios: drama.companies.map(\.name) + (drama.platform.nonEmpty.map { [$0] } ?? []),
            people: cast + crew,
            relatedMovies: drama.recommendations.map {
                featuredMovie(from: $0, shelves: [.shortDrama])
            },
            keywords: drama.keywords,
            backdropPaths: backdrops,
            posterPaths: posters,
            logoPaths: drama.images?.logos.map(\.url),
            logoLanguages: nil,
            djhubBadges: drama.badges,
            trailers: nil
        )
    }

    static func featuredMovie(
        from drama: Drama,
        shelves: Set<TMDBFeaturedMovie.Shelf>
    ) -> TMDBFeaturedMovie {
        let poster = drama.posterURL?.absoluteString
        let backdrop = drama.bestArtworkURL?.absoluteString ?? poster
        return TMDBFeaturedMovie(
            id: numericID(for: drama.id),
            title: drama.title,
            originalTitle: drama.originalTitle,
            aliases: drama.keywords,
            overview: drama.overview.nonEmpty ?? "DJHUB 暂未提供简介。",
            year: Int(drama.displayYear) ?? 0,
            rating: drama.score,
            genres: drama.genres,
            posterPath: "",
            backdropPath: "",
            shelves: shelves,
            isTV: true,
            djhubID: drama.id,
            posterURLOverride: poster,
            backdropURLOverride: backdrop,
            episodeCount: drama.episodes > 0 ? drama.episodes : nil,
            platformName: drama.platform.nonEmpty,
            contentType: drama.contentType.nonEmpty
        )
    }

    private static func categoryShelves(
        from genres: [TaxonomyItem]
    ) -> [(TMDBFeaturedMovie.Shelf, TaxonomyItem)] {
        let available = genres.filter { $0.name != "综艺" }
        func match(_ terms: [String]) -> TaxonomyItem? {
            available.first { item in terms.contains { item.name.contains($0) } }
        }
        return [
            (.shortRomance, match(["爱情", "甜宠", "情感", "婚恋"])),
            (.shortComedy, match(["喜剧", "搞笑", "轻喜"])),
            (.shortMystery, match(["悬疑", "推理", "惊悚"])),
            (.shortAction, match(["动作", "武侠", "战神"]))
        ].compactMap { shelf, genre in genre.map { (shelf, $0) } }
    }

    private static func inferredShelves(for drama: Drama) -> Set<TMDBFeaturedMovie.Shelf> {
        let text = (drama.genres + drama.keywords).joined(separator: " ")
        var shelves: Set<TMDBFeaturedMovie.Shelf> = [.shortDrama]
        if ["爱情", "甜宠", "情感", "婚恋"].contains(where: text.contains) { shelves.insert(.shortRomance) }
        if ["喜剧", "搞笑", "轻喜"].contains(where: text.contains) { shelves.insert(.shortComedy) }
        if ["悬疑", "推理", "惊悚"].contains(where: text.contains) { shelves.insert(.shortMystery) }
        if ["动作", "武侠", "战神"].contains(where: text.contains) { shelves.insert(.shortAction) }
        return shelves
    }

    private static func numericID(for value: String) -> Int {
        if let number = Int(value) { return number }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(Int.max))
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

struct RoveShimmerBlock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoveCoreAnimationShimmer(
            cornerRadius: cornerRadius,
            backgroundOpacity: 0.085,
            highlightOpacity: 0.16,
            reduceMotion: reduceMotion
        )
    }
}

/// Runs the shimmer entirely in Core Animation. A SwiftUI repeat-forever
/// animation invalidates its parent view every frame; on the home screen that
/// used to re-evaluate the complete media hierarchy while placeholders loaded.
private struct RoveCoreAnimationShimmer: UIViewRepresentable {
    let cornerRadius: CGFloat
    let backgroundOpacity: CGFloat
    let highlightOpacity: CGFloat
    let reduceMotion: Bool

    func makeUIView(context: Context) -> ShimmerView {
        ShimmerView()
    }

    func updateUIView(_ view: ShimmerView, context: Context) {
        view.configure(
            cornerRadius: cornerRadius,
            backgroundOpacity: backgroundOpacity,
            highlightOpacity: highlightOpacity,
            reduceMotion: reduceMotion
        )
    }

    final class ShimmerView: UIView {
        private let gradient = CAGradientLayer()
        private var reduceMotion = false
        private var highlightOpacity: CGFloat = 0
        private var lastSize = CGSize.zero

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            clipsToBounds = true
            gradient.startPoint = CGPoint(x: 0, y: 0.35)
            gradient.endPoint = CGPoint(x: 1, y: 0.65)
            gradient.locations = [0, 0.38, 0.5, 0.62, 1]
            layer.addSublayer(gradient)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.size != lastSize else { return }
            lastSize = bounds.size
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradient.frame = bounds.insetBy(dx: -bounds.width, dy: 0)
            CATransaction.commit()
            restartAnimationIfNeeded()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            restartAnimationIfNeeded()
        }

        func configure(
            cornerRadius: CGFloat,
            backgroundOpacity: CGFloat,
            highlightOpacity: CGFloat,
            reduceMotion: Bool
        ) {
            layer.cornerRadius = cornerRadius
            backgroundColor = UIColor.white.withAlphaComponent(backgroundOpacity)
            let appearanceChanged = self.highlightOpacity != highlightOpacity
                || self.reduceMotion != reduceMotion
            self.highlightOpacity = highlightOpacity
            self.reduceMotion = reduceMotion
            gradient.colors = [
                UIColor.clear.cgColor,
                UIColor.white.withAlphaComponent(highlightOpacity * 0.28).cgColor,
                UIColor.white.withAlphaComponent(highlightOpacity).cgColor,
                UIColor.white.withAlphaComponent(highlightOpacity * 0.28).cgColor,
                UIColor.clear.cgColor
            ]
            if appearanceChanged { restartAnimationIfNeeded() }
        }

        private func restartAnimationIfNeeded() {
            gradient.removeAnimation(forKey: "rove.shimmer")
            guard window != nil, !reduceMotion, bounds.width > 0 else { return }
            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = -bounds.width
            animation.toValue = bounds.width
            animation.duration = 1.35
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            gradient.add(animation, forKey: "rove.shimmer")
        }
    }
}

private struct RoveHomeView: View {
    private enum HomeLayoutMode: Equatable {
        case local
        case iptv
        case discovery
        case mediaServer
    }

    @EnvironmentObject private var library: ChannelLibrary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var mediaHeroNamespace
    @Binding var selectedTab: RootTab
    let onSearch: () -> Void
    let onAddSource: () -> Void

    @State private var selectedChannel: Channel?
    @State private var selectedChannelHeroID: AnyHashable?
    @State private var playingChannel: Channel?
    @State private var selectedTMDBMovie: TMDBFeaturedMovie?
    @State private var selectedTMDBHeroID: AnyHashable?
    @State private var selectedTMDBShelf: TMDBFeaturedMovie.Shelf?
    @State private var selectedTMDBPerson: TMDBMoviePerson?
    @State private var selectedDJHUBCompany: DJHUBCompany?
    @State private var showingAllPopularPeople = false
    @State private var browseCategory: RoveBrowseCategory?
    @State private var selectedHeroIndex = 0
    @State private var serverHeroMotionDriver = RoveHeroMotionDriver()
    @State private var selectedDiscoveryHeroIndex = 0
    @State private var discoveryHeroMotionDriver = RoveHeroMotionDriver()
    @State private var tmdbMovies: [TMDBFeaturedMovie] = []
    @State private var discoveryPopularPeople = RovePopularPeopleCatalog.defaults
    @State private var discoveryCompanies: [DJHUBCompany] = []
    @State private var isLoadingTMDB = false
    @State private var didLoadTMDBDiscovery = false
    @State private var featuredDetails: MetadataDetails?
    @State private var serverHeroDetails: [UUID: MetadataDetails] = [:]
    @State private var serverHeroLogoImages: [UUID: UIImage] = [:]
    @State private var serverHeroTMDBArtwork: [UUID: UIImage] = [:]
    @State private var serverHeroTMDBThemeColors: [UUID: UIColor] = [:]
    @State private var serverHeroTMDBOverviews: [UUID: String] = [:]
    @State private var serverHeroVisuals: [UUID: RoveHeroVisual] = [:]
    @State private var serverHeroEnrichedIDs = Set<UUID>()
    @State private var discoveryHeroThemeColors: [Int: UIColor] = [:]
    @State private var discoveryHeroArtworkImages: [Int: UIImage] = [:]
    @State private var discoveryHeroLogoImages: [Int: UIImage] = [:]
    @State private var serverHomeSections: [RoveServerHomeSection] = []
    @State private var homeBlocks: [RoveHomeBlock] = []
    @State private var mediaCollections: [RoveHomeMediaCollection] = []
    @State private var mediaShelves: [RoveHomeMediaShelf] = []
    @State private var serverContinueWatching: [MetadataContinueItem] = []
    // Keep the last rendered snapshot for each media server so switching
    // between servers does not blank the home page while disk/network caches
    // are being read. The snapshot is replaced after the background refresh.
    @State private var homeSnapshotCache: [UUID: RoveHomeSnapshot] = [:]
    @State private var aiRecommendations: [Channel] = []
    @State private var isLoadingAIRecommendations = false
    @State private var lastAIRecommendationSignature = ""
    @State private var draggedMediaCollectionID: String?
    @State private var loadedHomeConfigurationID: UUID?
    @State private var showingHomeManager = false
    @State private var showingAllMediaCollections = false
    @State private var selectedMediaCollection: RoveHomeMediaCollection?
    @State private var selectedSavedFilter: RoveSavedFilter?
    @State private var mediaStateRevision = 0
    @State private var homeReloadRevision = 0
    @State private var lockedHomeLayout: HomeLayoutMode?
    @State private var homePullDistance: CGFloat = 0
    @State private var homePullPeak: CGFloat = 0
    @State private var isHomeRefreshArmed = false
    @State private var isHomeRefreshing = false
    @AppStorage(RoveHomeModeStore.defaultsKey) private var homeMode = RoveHomeModeStore.server
    @AppStorage(RoveDeepSeekService.recommendationsEnabledKey) private var aiRecommendationsEnabled = false

    private var featuredChannel: Channel? {
        guard !heroChannels.isEmpty else { return nil }
        return heroChannels[min(selectedHeroIndex, heroChannels.count - 1)]
    }

    private var homeHeroHeight: CGFloat {
        let size = UIScreen.main.bounds.size
        if size.width > size.height {
            return min(400, max(320, size.height * 0.78))
        }
        return min(560, max(500, size.height * 0.59))
    }

    private var allChannels: [Channel] { Array(library.channels) }
    private var mediaServerConfigurations: [PlaylistConfiguration] {
        library.configurations.filter {
            $0.kind.usesMediaLibraryBrowser && !$0.isExpired
        }
    }
    private var activeMediaServer: PlaylistConfiguration? {
        guard let id = library.activeConfigurationID else { return nil }
        return mediaServerConfigurations.first { $0.id == id }
    }
    private var activeMediaLibraryLabel: String {
        guard let configuration = activeMediaServer else { return "媒体库" }
        return mediaServerDisplayName(configuration)
    }
    private func mediaServerDisplayName(_ configuration: PlaylistConfiguration) -> String {
        let remark = configuration.serverRemark?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !remark.isEmpty { return remark }
        let reportedName = configuration.serverReportedName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !reportedName.isEmpty { return reportedName }
        let savedName = configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return savedName.isEmpty ? configuration.kind.title : savedName
    }
    private var isLocalHome: Bool {
        lockedHomeLayout == .local
    }
    /// IPTV sources have a different home contract from Emby/Jellyfin/Feiniu:
    /// the source's groups are the page, not a set of TMDB/movie shelves.
    private var isIPTVHome: Bool {
        lockedHomeLayout == .iptv
    }
    private var supportsDiscoverySections: Bool {
        lockedHomeLayout == .discovery || lockedHomeLayout == .mediaServer
    }

    private var iptvGroups: [(name: String, channels: [Channel])] {
        library.groupedChannels
            .map { (name: library.localizedDisplayGroup($0.name), channels: $0.channels.filter { !$0.isMediaServerItem }) }
            .filter { !$0.channels.isEmpty }
    }
    private var heroChannels: [Channel] {
        let preferredKeywords = [
            "推荐", "精选", "国产", "华语", "中文", "电影",
            "recommend", "featured", "china", "chinese", "movie"
        ]
        func isMovie(_ channel: Channel) -> Bool {
            channel.isMediaServerItem
                && !channel.isMediaServerSeries
                && !channel.isMediaServerEpisode
        }
        func isPreferred(_ channel: Channel, collectionName: String? = nil) -> Bool {
            let text = [collectionName, channel.group, channel.name]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            return preferredKeywords.contains(where: text.contains)
        }

        // Keep the hero tied to intentional recommendation/movie shelves. The
        // old allChannels fallback made arbitrary series and episodes appear
        // in the carousel simply because they happened to be loaded first.
        let preferredShelfChannels = mediaShelves
            .filter { shelf in
                preferredKeywords.contains { shelf.source.collection.name.lowercased().contains($0) }
            }
            .flatMap(\.channels)
            .filter { isMovie($0) }
        let recommendedMovies = aiRecommendations.filter { isMovie($0) }
        let curatedMovies = recommendedMovies
            + preferredShelfChannels
            + allChannels.filter { isMovie($0) && isPreferred($0) }
        let fallbackMovies = allChannels.filter(isMovie)
        // Some Jellyfin/Emby short-drama libraries expose their shelves as
        // series (or even episode records) instead of movie items. If the
        // movie-only query is empty, keep the hero useful by using the first
        // loaded shelf records instead of leaving a permanent loading spinner
        // above an otherwise populated home page. Their real video ratio is
        // still detected by the player when opened.
        let loadedShelfFallback = mediaShelves
            .flatMap(\.channels)
            .filter { !$0.isMediaServerEpisode }
        let loadedEpisodeFallback = mediaShelves.flatMap(\.channels)

        var result: [Channel] = []
        var seen = Set<UUID>()
        for channel in (curatedMovies + fallbackMovies + loadedShelfFallback + loadedEpisodeFallback)
            where seen.insert(channel.id).inserted {
            result.append(channel)
            if result.count == 10 { break }
        }
        return result
    }
    private func serverHeroContentIdentities(for channels: [Channel]) -> [String] {
        channels.map { channel in
            let details = serverHeroDetails[channel.id]
            let detailRevision: Int = [
                details?.title ?? "",
                details?.overview ?? "",
                serverHeroTMDBOverviews[channel.id] ?? "",
                details?.productionYear.map(String.init) ?? ""
            ].joined(separator: "|").hashValue
            return [
                channel.id.uuidString,
                channel.name,
                channel.group,
                channel.communityRating.map { String($0) } ?? "",
                channel.productionYear.map { String($0) } ?? "",
                String(detailRevision),
                serverHeroLogoImages[channel.id] == nil ? "0" : "1",
                serverHeroVisuals[channel.id] == nil ? "0" : "1",
                serverHeroTMDBArtwork[channel.id] == nil ? "0" : "1"
            ].joined(separator: ":")
        }
    }
    private var discoveryHeroContentIdentities: [String] {
        discoveryHeroMovies.map { movie in
            [
                "tmdb-\(movie.id)",
                discoveryHeroArtworkImages[movie.id] == nil ? "0" : "1",
                discoveryHeroLogoImages[movie.id] == nil ? "0" : "1"
            ].joined(separator: ":")
        }
    }
    private var serverHeroBackdropImages: [UIImage?] {
        heroChannels.map { channel in
            serverHeroVisuals[channel.id]?.image
                ?? serverHeroTMDBArtwork[channel.id]
                ?? ChannelArtworkLoader.shared.cachedPrimaryImage(for: channel, maxWidth: 900)
        }
    }
    private var serverHeroBackdropColors: [UIColor] {
        heroChannels.map {
            serverHeroVisuals[$0.id]?.color
                ?? serverHeroTMDBThemeColors[$0.id]
                ?? .black
        }
    }
    private var discoveryHeroBackdropImages: [UIImage?] {
        discoveryHeroMovies.map { movie in
            discoveryHeroArtworkImages[movie.id]
                ?? TMDBArtworkLoader.shared.cachedImage(for: movie.posterURL)
        }
    }
    private var discoveryHeroBackdropColors: [UIColor] {
        discoveryHeroMovies.map { discoveryHeroThemeColors[$0.id] ?? .black }
    }
    private var serverHeroDatasetTaskID: String {
        let ids = heroChannels.map(\.id.uuidString).joined(separator: ",")
        return "server-hero:\(library.activeConfigurationID?.uuidString ?? "none"):\(ids)"
    }
    private var discoveryHeroDatasetTaskID: String {
        "discovery-hero:" + discoveryHeroMovies.map(\.identity).joined(separator: ",")
    }
    private var discoveryHeroMovies: [TMDBFeaturedMovie] {
        let preferred = movies(in: .shortDrama)
        return Array((preferred.isEmpty ? tmdbMovies : preferred).prefix(5))
    }
    private var popularMovies: [Channel] { shelf(.movies) }
    private var popularSeries: [Channel] { shelf(.series) }
    private var animation: [Channel] { shelf(.animation) }
    private var documentaries: [Channel] { shelf(.documentaries) }
    private var visibleMediaCollections: [RoveHomeMediaCollection] {
        guard !serverHomeSections.isEmpty else { return mediaCollections }
        let collectionsByID = Dictionary(uniqueKeysWithValues: mediaCollections.map { ($0.id, $0) })
        return serverHomeSections
            .filter(\.isEnabled)
            .compactMap { collectionsByID[$0.id] }
    }
    private var visibleMediaShelves: [RoveHomeMediaShelf] {
        let shelvesByID = Dictionary(uniqueKeysWithValues: mediaShelves.map { ($0.id, $0) })
        return visibleMediaCollections.compactMap { shelvesByID[$0.id] }
    }

    var body: some View {
#if DJHUB_METADATA_ONLY
        NavigationStack {
            discoveryHome
                .background(Color.black)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Label {
                            Text("DJHUB")
                                .font(.title2.bold())
                        } icon: {
                            Image("MediaDeckBrandMark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            refreshHome()
                        } label: {
                            if isLoadingTMDB {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isLoadingTMDB)
                        .accessibilityLabel("刷新发现")
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .navigationDestination(item: $selectedChannel) { channel in
                    RoveMediaDetailView(channel: channel)
                        .roveHeroNavigationTransition(
                            id: selectedChannelHeroID,
                            namespace: mediaHeroNamespace
                        )
                }
                .navigationDestination(item: $selectedTMDBMovie) { movie in
                    RoveMediaDetailView(recommendation: movie)
                        .roveHeroNavigationTransition(
                            id: selectedTMDBHeroID,
                            namespace: mediaHeroNamespace
                        )
                }
                .navigationDestination(item: $selectedTMDBShelf) { shelf in
                    RoveTMDBShelfGridView(shelf: shelf, movies: movies(in: shelf))
                }
                .navigationDestination(item: $selectedTMDBPerson) { person in
                    if person.tmdbID < 0 {
                        DJHUBPersonDetailView(person: person)
                    } else {
                        TMDBPersonDetailView(person: person)
                    }
                }
                .navigationDestination(item: $selectedDJHUBCompany) { company in
                    DJHUBCompanyDetailView(company: company)
                }
                .navigationDestination(isPresented: $showingAllPopularPeople) {
                    RovePopularPeopleGridView(people: discoveryPopularPeople)
                }
                .navigationDestination(item: $browseCategory) { category in
                    RoveCategoryGridView(category: category, channels: shelf(category))
                }
                .navigationDestination(item: $selectedSavedFilter) { filter in
                    RoveSavedView(initialFilter: filter)
                }
                .task {
                    await lockInitialHomeLayoutIfNeeded()
                }
                .task(id: lockedHomeLayout) {
                    guard lockedHomeLayout == .discovery,
                          !didLoadTMDBDiscovery else { return }
                    for attempt in 0..<3 {
                        let loaded = await loadTMDBDiscovery()
                        guard !Task.isCancelled else { return }
                        if loaded {
                            didLoadTMDBDiscovery = true
                            return
                        }
                        guard attempt < 2 else { return }
                        try? await Task.sleep(for: .seconds(attempt + 1))
                    }
                }
                .task(id: "djhub-home-people-\(String(describing: lockedHomeLayout))") {
                    guard lockedHomeLayout == .discovery else { return }
                    await loadDiscoveryPopularPeople()
                }
                .task(id: "djhub-home-companies-\(String(describing: lockedHomeLayout))") {
                    guard lockedHomeLayout == .discovery else { return }
                    await loadDiscoveryCompanies()
                }
                .task(id: discoveryHeroDatasetTaskID) {
                    guard lockedHomeLayout == .discovery else { return }
                    await preloadDiscoveryHeroArtwork(around: 0)
                }
        }
#else
        NavigationStack {
            Group {
#if DJHUB_METADATA_ONLY
                discoveryHome
#else
                if lockedHomeLayout == nil {
                    homeLayoutPlaceholder
                } else if isLocalHome {
                    RoveLocalHomeView(
                        onAddSource: onAddSource,
                        onShowSaved: { selectedSavedFilter = $0 }
                    )
                } else if isIPTVHome {
                    iptvHome
                } else if lockedHomeLayout == .discovery {
                    discoveryHome
                } else {
                    populatedHome
                }
#endif
            }
            .overlay {
                if showingAllMediaCollections, !visibleMediaCollections.isEmpty {
                    RoveMediaCollectionsBrowseOverlay(
                        collections: visibleMediaCollections,
                        onClose: {
                            withAnimation(reduceMotion ? nil : RoveMotion.quick) {
                                showingAllMediaCollections = false
                            }
                        },
                        onSelect: { collection in
                            showingAllMediaCollections = false
                            selectedMediaCollection = collection
                        }
                    )
                    .zIndex(30)
                    .transition(.opacity)
                }
            }
            .background(isLocalHome || isIPTVHome ? Color(uiColor: .systemBackground) : Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if lockedHomeLayout == .discovery {
                    ToolbarItem(placement: .topBarLeading) {
                        Label {
                            Text("DJHUB")
                                .font(.title2.bold())
                        } icon: {
                            Image("MediaDeckBrandMark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        }
                    }
                }
                if lockedHomeLayout == .mediaServer {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingHomeManager = true
                        } label: {
                            Image(systemName: "rectangle.3.group")
                        }
                        .accessibilityLabel("媒体分类管理")
                    }
                }
                if lockedHomeLayout == .discovery {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            refreshHome()
                        } label: {
                            if isLoadingTMDB {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isLoadingTMDB)
                        .accessibilityLabel("刷新发现")
                    }
                }
                if lockedHomeLayout == .mediaServer {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            savedMenuButtons
                            Divider()
                            Button("刷新首页", systemImage: "arrow.clockwise") {
                                refreshHome()
                            }
                            Button("媒体管理", systemImage: "rectangle.3.group") {
                                showingHomeManager = true
                            }

                            Button("添加来源", systemImage: "plus") {
                                onAddSource()
                            }

                            Button("设置", systemImage: "gearshape") {
                                selectedTab = .settings
                            }

                            Divider()

                        Button("发现", systemImage: "sparkles.rectangle.stack") {
                            selectedTab = .channels
                        }

                            if !mediaServerConfigurations.isEmpty {
                                Divider()
                                ForEach(mediaServerConfigurations) { configuration in
                                    Button {
                                        selectMediaServer(configuration)
                                    } label: {
                                        Label(
                                            mediaServerDisplayName(configuration),
                                            systemImage: library.activeConfigurationID == configuration.id
                                                ? "checkmark"
                                                : configuration.kind.systemImage
                                        )
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if let activeMediaServer {
                                    RoveServerBrandIcon(
                                        configuration: activeMediaServer,
                                        size: 22
                                    )
                                }
                                Text(activeMediaLibraryLabel)
                                    .font(.subheadline.weight(.bold))
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.bold))
                            }
                        }
                        .accessibilityLabel("当前媒体库：\(activeMediaLibraryLabel)")
                    }
                }
                if lockedHomeLayout == .iptv {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            savedMenuButtons
                            Divider()
                            Button("添加来源", systemImage: "plus") {
                                onAddSource()
                            }
                            Button("设置", systemImage: "gearshape") {
                                selectedTab = .settings
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("更多")
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isIPTVHome || isLocalHome ? .light : .dark, for: .navigationBar)
            .navigationDestination(item: $selectedChannel) { channel in
                RoveMediaDetailView(channel: channel)
                    .roveHeroNavigationTransition(
                        id: selectedChannelHeroID,
                        namespace: mediaHeroNamespace
                    )
            }
            .navigationDestination(item: $selectedTMDBMovie) { movie in
                RoveMediaDetailView(recommendation: movie)
                    .roveHeroNavigationTransition(
                        id: selectedTMDBHeroID,
                        namespace: mediaHeroNamespace
                    )
            }
            .navigationDestination(item: $selectedTMDBShelf) { shelf in
                RoveTMDBShelfGridView(
                    shelf: shelf,
                    movies: movies(in: shelf)
                )
            }
            .navigationDestination(item: $selectedTMDBPerson) { person in
                if person.tmdbID < 0 {
                    DJHUBPersonDetailView(person: person)
                } else {
                    TMDBPersonDetailView(person: person)
                }
            }
            .navigationDestination(item: $selectedDJHUBCompany) { company in
                DJHUBCompanyDetailView(company: company)
            }
            .navigationDestination(isPresented: $showingAllPopularPeople) {
                RovePopularPeopleGridView(people: discoveryPopularPeople)
            }
            .navigationDestination(item: $browseCategory) { category in
                RoveCategoryGridView(category: category, channels: shelf(category))
            }
            .navigationDestination(item: $selectedSavedFilter) { filter in
                RoveSavedView(initialFilter: filter)
            }
#if !DJHUB_METADATA_ONLY
            .navigationDestination(item: $selectedMediaCollection) { item in
                EmbyCollectionView(
                    configurationID: item.configurationID,
                    collection: item.collection,
                    selectedChannel: $selectedChannel,
                    showsSections: false,
                    prefersSeries: item.prefersSeries,
                    initialChannels: mediaShelves.first(where: { $0.id == item.id })?.channels ?? []
                )
            }
#endif
            .onChange(of: selectedChannel) { _, channel in
                if channel == nil {
                    selectedChannelHeroID = nil
                }
            }
            .sheet(isPresented: $showingHomeManager) {
                RoveHomeManagerView(
                    blocks: homeBlocks,
                    sections: serverHomeSections
                ) { updatedBlocks, updatedSections in
                    homeBlocks = updatedBlocks
                    RoveHomeBlockStore.save(
                        updatedBlocks,
                        configurationID: library.activeConfigurationID
                    )
                    serverHomeSections = updatedSections
                    RoveServerHomeSectionStore.save(updatedSections, configurationID: library.activeConfigurationID)
                }
            }
            .task {
                await lockInitialHomeLayoutIfNeeded()
            }
            .task(id: library.activeConfigurationID) {
                guard let activeMediaServer else { return }
                try? await Task.sleep(for: .milliseconds(1_000))
                guard !Task.isCancelled else { return }
                await library.refreshServerReportedName(activeMediaServer.id)
            }
            .task(id: serverHeroDatasetTaskID) {
                guard lockedHomeLayout == .mediaServer else { return }
                await preloadServerHeroArtwork(around: 0)
            }
            .task(id: homeContentTaskID) {
                guard lockedHomeLayout == .mediaServer else { return }
                await loadMediaCollections()
            }
            .task(id: "ai-recommendations-\(homeContentTaskID)-\(mediaShelves.count)") {
                guard lockedHomeLayout == .mediaServer else { return }
                try? await Task.sleep(for: .milliseconds(1_200))
                guard !Task.isCancelled else { return }
                await loadAIRecommendations()
            }
            .task(id: lockedHomeLayout) {
                guard supportsDiscoverySections,
                      !didLoadTMDBDiscovery else { return }
                for attempt in 0..<3 {
                    let loaded = await loadTMDBDiscovery()
                    guard !Task.isCancelled else { return }
                    if loaded {
                        didLoadTMDBDiscovery = true
                        return
                    }
                    guard attempt < 2 else { return }
                    try? await Task.sleep(for: .seconds(attempt + 1))
                }
            }
            .task(id: "djhub-home-people-\(String(describing: lockedHomeLayout))") {
                guard lockedHomeLayout == .discovery else { return }
                await loadDiscoveryPopularPeople()
            }
            .task(id: "djhub-home-companies-\(String(describing: lockedHomeLayout))") {
                guard lockedHomeLayout == .discovery else { return }
                await loadDiscoveryCompanies()
            }
            .task(id: discoveryHeroDatasetTaskID) {
                guard lockedHomeLayout == .discovery else { return }
                await preloadDiscoveryHeroArtwork(around: 0)
            }
            .onChange(of: library.activeConfigurationID) { _, _ in
                guard lockedHomeLayout != nil,
                      homeMode == RoveHomeModeStore.server else { return }
                resetHomeForServerSwitch()
                lockedHomeLayout = resolvedHomeLayout()
            }
            .onChange(of: mediaCollections) { _, _ in
                synchronizeServerHomeSections()
                synchronizeHomeBlocks()
            }
            .onChange(of: homeMode) { _, _ in
                guard lockedHomeLayout != nil else { return }
                lockedHomeLayout = resolvedHomeLayout()
            }
            .onChange(of: lockedHomeLayout) { _, layout in
                guard layout != nil else { return }
                Task { @MainActor in
                    await Task.yield()
                    NotificationCenter.default.post(name: .roveHomePrimaryScrollViewReady, object: nil)
                }
            }
        }
#if !DJHUB_METADATA_ONLY
        .fullScreenCover(item: $playingChannel) { channel in
            PlayerDetailView(channel: channel)
        }
#endif
#endif
    }

    @ViewBuilder
    private var savedMenuButtons: some View {
        Button("待看", systemImage: "ticket") {
            selectedSavedFilter = .watchlist
        }
        Button("观看记录", systemImage: "clock.arrow.circlepath") {
            selectedSavedFilter = .recent
        }
        Button("收藏", systemImage: "bookmark") {
            selectedSavedFilter = .favorites
        }
    }

    @MainActor
    private func lockInitialHomeLayoutIfNeeded() async {
        guard lockedHomeLayout == nil else { return }
#if DJHUB_METADATA_ONLY
        lockedHomeLayout = .discovery
#else
        await library.restorePersistedStateIfNeeded()
        guard !Task.isCancelled, lockedHomeLayout == nil else { return }
        lockedHomeLayout = resolvedHomeLayout()
#endif
    }

#if DJHUB_METADATA_ONLY
    private func resolvedHomeLayout() -> HomeLayoutMode {
        .discovery
    }
#else
    private func resolvedHomeLayout() -> HomeLayoutMode {
        if homeMode == RoveHomeModeStore.local {
            return .local
        }
        if let configuration = library.activeConfiguration {
            return configuration.kind.usesMediaLibraryBrowser ? .mediaServer : .iptv
        }
        if !localLibrary.videos.isEmpty {
            return .local
        }
        if library.channels.contains(where: { !$0.isMediaServerItem }) {
            return .iptv
        }
        if !mediaServerConfigurations.isEmpty {
            return .mediaServer
        }
        return .discovery
    }
#endif

    private var homeLayoutPlaceholder: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack(alignment: .bottom) {
                    Color(red: 0.08, green: 0.09, blue: 0.11)
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.86)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            RoveShimmerBlock(cornerRadius: 28)
                                .frame(width: 58, height: 58)
                            Spacer()
                        }
                        Spacer()
                        RoveShimmerBlock(cornerRadius: 6)
                            .frame(width: 190, height: 32)
                        RoveShimmerBlock(cornerRadius: 5)
                            .frame(width: 290, height: 20)
                        RoveShimmerBlock(cornerRadius: 5)
                            .frame(width: 235, height: 18)
                        HStack(spacing: 8) {
                            ForEach(0..<7, id: \.self) { index in
                                RoveShimmerBlock(cornerRadius: 8)
                                    .frame(width: index == 3 ? 30 : 10, height: 10)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 54)
                    .padding(.bottom, 24)
                }
                .frame(height: 690)

                VStack(alignment: .leading, spacing: 14) {
                    RoveShimmerBlock(cornerRadius: 5)
                        .frame(width: 152, height: 26)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoveShimmerBlock(cornerRadius: 18)
                                    .frame(width: 320, height: 180)
                            }
                        }
                    }

                    RoveShimmerBlock(cornerRadius: 5)
                        .frame(width: 128, height: 24)
                        .padding(.top, 12)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                        spacing: 18
                    ) {
                        ForEach(0..<6, id: \.self) { _ in
                            RoveShimmerBlock(cornerRadius: 10)
                                .aspectRatio(0.68, contentMode: .fit)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(Color(red: 0.08, green: 0.09, blue: 0.11))
        .ignoresSafeArea(edges: .top)
    }

    private var homeContentTaskID: String {
        let configurationIDs = library.configurations
            .map(\.id.uuidString)
            .joined(separator: ",")
        return "\(String(describing: lockedHomeLayout))|\(library.activeConfigurationID?.uuidString ?? "all")|\(configurationIDs)|\(homeReloadRevision)"
    }

    /// The IPTV landing page intentionally stays structural while previews and
    /// EPG data arrive. A fixed 16:9 slot prevents artwork from reflowing the
    /// page, matching the reference app's live-channel browsing behavior.
#if !DJHUB_METADATA_ONLY
    private var iptvHome: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if iptvGroups.isEmpty {
                    ContentUnavailableView("暂无频道", systemImage: "tv.slash", description: Text("请在设置中导入 M3U 播放列表"))
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    ForEach(iptvGroups, id: \.name) { group in
                        iptvSection(title: group.name, channels: group.channels)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemBackground))
        .task(id: iptvPreviewTaskID) {
            guard isIPTVHome else { return }
            // IPTV cards use the same shared frame cache as the channel tab,
            // but this home surface is not hosted by RootView's channel page.
            // Explicitly opt it into the preview policy before asking for the
            // first visible burst.
            ChannelPreviewService.shared.setChannelBrowserVisible(true)
            await ChannelPreviewService.shared.beginInitialVisiblePreviewBurst(
                channels: iptvGroups.flatMap(\.channels)
            )
        }
        .onDisappear {
            ChannelPreviewService.shared.setChannelBrowserVisible(false)
        }
    }

    private var iptvPreviewTaskID: String {
        let channelIDs = iptvGroups
            .flatMap(\.channels)
            .map { $0.id.uuidString }
            .joined(separator: ",")
        return "iptv|\(library.activeConfigurationID?.uuidString ?? "none")|\(channelIDs)"
    }

    private func iptvSection(title: String, channels: [Channel]) -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                RoveIPTVGroupView(title: title, channels: channels)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 25, weight: .black))
                    Spacer()
                    Text("\(channels.count) 个频道")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(channels.prefix(16)) { channel in
                        Button { playingChannel = channel } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                LiveChannelPreview(channel: channel)
                                    .frame(width: 160, height: 90)
                                    .background(Color.black, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(.primary.opacity(0.18), lineWidth: 1)
                                    }
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text(channel.name)
                                        .font(.system(size: 18, weight: .black))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Image(systemName: "tv")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 160, alignment: .leading)
                            }
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                    }
                }
            }
        }
    }

private struct RoveIPTVGroupView: View {
    let title: String
    let channels: [Channel]

    @State private var playingChannel: Channel?

    private let columns = [
        GridItem(.adaptive(minimum: 156, maximum: 260), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                ForEach(channels) { channel in
                    Button { playingChannel = channel } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            LiveChannelPreview(channel: channel)
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .background(Color.black, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(.primary.opacity(0.18), lineWidth: 1)
                                }
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text(channel.name)
                                    .font(.system(size: 17, weight: .bold))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: "tv")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RoveMotionButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Text("\(channels.count) 个频道")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .fullScreenCover(item: $playingChannel) { channel in
            PlayerDetailView(channel: channel)
        }
        .task(id: previewTaskID) {
            ChannelPreviewService.shared.setChannelBrowserVisible(true)
            await ChannelPreviewService.shared.beginInitialVisiblePreviewBurst(
                channels: channels
            )
        }
        .onDisappear {
            ChannelPreviewService.shared.setChannelBrowserVisible(false)
        }
    }

    private var previewTaskID: String {
        "iptv-group|\(title)|" + channels.map { $0.id.uuidString }.joined(separator: ",")
    }
}
#endif

    private var populatedHome: some View {
        homeScrollView
    }

    private var homeScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RoveHomePullProbe()
                // Keep the native carousel mounted while it is off-screen.
                // Recreating its UIKit pager and three hosted pages during an
                // upward scroll causes a visible hitch at the hero boundary.
                featuredHero
                LazyVStack(alignment: .leading, spacing: 30) {
                    ForEach(homeBlocks) { block in
                        homeBlockView(block)
                    }
                    sharedDiscoverySections
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: "rove-home-scroll")
        .onPreferenceChange(RoveHomePullOffsetKey.self, perform: updateHomePullDistance)
        .simultaneousGesture(homeRefreshGesture)
        .overlay(alignment: .top) {
            homeRefreshIndicator
        }
        .background {
            RoveHeroThemeSurface(
                motionDriver: serverHeroMotionDriver,
                colors: serverHeroBackdropColors,
                selectedIndex: selectedHeroIndex
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private func homeBlockView(_ block: RoveHomeBlock) -> some View {
        switch block.kind {
        case .continueWatching:
            if block.isEnabled && !serverContinueWatching.isEmpty {
                serverContinueWatchingShelf(title: block.title)
            }
        case .aiRecommendations:
            if block.isEnabled && (isLoadingAIRecommendations || !aiRecommendations.isEmpty) {
                aiRecommendationShelf(title: block.title)
            }
        case .mediaCollections:
            if block.isEnabled && !visibleMediaCollections.isEmpty {
                mediaCollectionShelf(title: block.title)
            }
        case .mediaShelf:
            if block.isEnabled,
               let shelfID = block.id.split(separator: ":", maxSplits: 1).last,
               let shelf = visibleMediaShelves.first(where: { $0.id == shelfID }) {
                mediaFolderShelf(shelf, title: block.title)
            }
        }
    }

    private func selectMediaServer(_ configuration: PlaylistConfiguration) {
        // Dismiss any detail/category destination before changing the source.
        // Otherwise NavigationStack can keep rendering the old server's page
        // while the new library snapshot is being prepared.
        dismissHomeDestinations()
        library.selectConfiguration(configuration.id)
        homeMode = RoveHomeModeStore.server
        lockedHomeLayout = .mediaServer
        selectedHeroIndex = 0
        serverHeroMotionDriver.update(from: 0, to: 0, progress: 0)
        homeReloadRevision &+= 1
    }

    private func dismissHomeDestinations() {
        selectedChannel = nil
        selectedTMDBMovie = nil
        selectedChannelHeroID = nil
        selectedTMDBHeroID = nil
        selectedTMDBShelf = nil
        browseCategory = nil
        selectedMediaCollection = nil
        selectedSavedFilter = nil
        showingAllMediaCollections = false
    }

    private func openChannel(_ channel: Channel, heroID: AnyHashable) {
        selectedChannelHeroID = heroID
        Task { @MainActor in
            await Task.yield()
            guard selectedChannelHeroID == heroID else { return }
            selectedChannel = channel
        }
    }

    private func openTMDBMovie(_ movie: TMDBFeaturedMovie, heroID: AnyHashable) {
        selectedTMDBHeroID = heroID
        Task { @MainActor in
            await Task.yield()
            guard selectedTMDBHeroID == heroID else { return }
            selectedTMDBMovie = movie
        }
    }

    private func resetHomeForServerSwitch() {
        dismissHomeDestinations()
        let configurationID = library.activeConfigurationID
        selectedHeroIndex = 0
        serverHeroMotionDriver.update(from: 0, to: 0, progress: 0)
        featuredDetails = nil
        if let configurationID, let snapshot = homeSnapshotCache[configurationID] {
            // Restore the target server's last rendered state immediately;
            // the async loader below will replace it with fresh data.
            serverContinueWatching = snapshot.continueWatching
            mediaCollections = snapshot.mediaCollections
            mediaShelves = snapshot.mediaShelves
            serverHomeSections = RoveServerHomeSectionStore.load(
                configurationID: configurationID,
                collections: snapshot.mediaCollections
            )
        } else {
            serverContinueWatching = []
            mediaCollections = []
            mediaShelves = []
            serverHomeSections = []
        }
        // Keep the new server's structural blocks visible while its
        // collections are loading. Shelf-specific blocks are merged back in
        // once the new collection snapshot arrives.
        homeBlocks = RoveHomeBlockStore.load(
            configurationID: configurationID,
            collections: mediaCollections
        )
        // The view already contains the target server's snapshot. Mark it as
        // loaded so loadMediaCollections does not clear it before its cache
        // read completes.
        loadedHomeConfigurationID = configurationID
        homeReloadRevision &+= 1
    }

    private func cacheHomeSnapshot(for configurationID: UUID) {
        homeSnapshotCache[configurationID] = RoveHomeSnapshot(
            mediaCollections: mediaCollections.filter { $0.configurationID == configurationID },
            mediaShelves: mediaShelves.filter { $0.source.configurationID == configurationID },
            continueWatching: serverContinueWatching.filter {
                mediaServerConfigurationID(for: $0.channel) == configurationID
            }
        )
    }

    private func synchronizeServerHomeSections() {
        guard !mediaCollections.isEmpty else { return }
        serverHomeSections = RoveServerHomeSectionStore.load(
            configurationID: library.activeConfigurationID,
            collections: mediaCollections
        )
    }

    private func synchronizeHomeBlocks() {
        homeBlocks = RoveHomeBlockStore.load(
            configurationID: library.activeConfigurationID,
            collections: mediaCollections
        )
    }

    private func refreshHome() {
        Task { @MainActor in
            await refreshHomeContent()
        }
    }

    @MainActor
    private func refreshHomeContent() async {
        switch lockedHomeLayout {
        case .discovery:
            _ = await loadTMDBDiscovery(forceRefresh: true)
            await preloadDiscoveryHeroArtwork(around: selectedDiscoveryHeroIndex)
        case .mediaServer, .iptv:
            if let id = library.activeConfigurationID,
               mediaServerConfigurations.contains(where: { $0.id == id }) || isIPTVHome {
                await library.refreshConfiguration(id)
            }
            homeReloadRevision &+= 1
        default:
            break
        }
    }

    private var homeRefreshGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onEnded { value in
                let isVertical = value.translation.height > abs(value.translation.width) * 1.15
                if isVertical, isHomeRefreshArmed, homePullPeak >= 86 {
                    performHomePullRefresh()
                }
                homePullPeak = 0
                isHomeRefreshArmed = false
            }
    }

    @ViewBuilder
    private var homeRefreshIndicator: some View {
        let progress = isHomeRefreshing ? CGFloat(1) : min(homePullDistance / 86, 1)
        if progress > 0.02 || isHomeRefreshing {
            RoveElasticRefreshIndicator(progress: progress, isRefreshing: isHomeRefreshing)
                .padding(.top, 62 + min(homePullDistance * 0.22, 24))
                .transition(.scale(scale: 0.35).combined(with: .opacity))
                .allowsHitTesting(false)
                .zIndex(80)
        }
    }

    private func updateHomePullDistance(_ distance: CGFloat) {
        guard !isHomeRefreshing else { return }
        homePullDistance = distance
        homePullPeak = max(homePullPeak, distance)
        let armed = distance >= 86
        if armed && !isHomeRefreshArmed {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.82)
        }
        isHomeRefreshArmed = armed
    }

    private func performHomePullRefresh() {
        guard !isHomeRefreshing else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.90)
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.72)) {
            isHomeRefreshing = true
            homePullDistance = 86
        }
        Task { @MainActor in
            async let refresh: Void = refreshHomeContent()
            async let minimumDisplay: Void = {
                try? await Task.sleep(for: .milliseconds(720))
            }()
            _ = await (refresh, minimumDisplay)
            guard !Task.isCancelled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.82)) {
                isHomeRefreshing = false
                homePullDistance = 0
                homePullPeak = 0
            }
        }
    }

    private func mediaCollectionShelf(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.weight(.heavy))
                Spacer()
                Button {
                    withAnimation(reduceMotion ? nil : RoveMotion.quick) {
                        showingAllMediaCollections = true
                    }
                } label: {
                    Label("全部", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看全部媒体分类")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(visibleMediaCollections) { item in
                        NavigationLink {
                            EmbyCollectionView(
                                configurationID: item.configurationID,
                                collection: item.collection,
                                selectedChannel: $selectedChannel,
                                showsSections: false,
                                prefersSeries: item.prefersSeries,
                                initialChannels: mediaShelves.first(where: { $0.id == item.id })?.channels ?? []
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                EmbyCollectionCard(
                                    configurationID: item.configurationID,
                                    collection: item.collection,
                                    width: 176,
                                    displaysPosterStrip: item.displaysPosterStrip
                                )
                                Text(item.collection.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .frame(width: 176, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .onDrag {
                            draggedMediaCollectionID = item.id
                            return NSItemProvider(object: item.id as NSString)
                        }
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: RoveMediaCollectionDropDelegate(
                                targetID: item.id,
                                sections: $serverHomeSections,
                                draggedID: $draggedMediaCollectionID,
                                configurationID: library.activeConfigurationID
                            )
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .foregroundStyle(.white)
    }

    @MainActor
    private func loadMediaCollections() async {
        let requestedConfigurationID = library.activeConfigurationID
        if loadedHomeConfigurationID != requestedConfigurationID {
            serverContinueWatching = []
            mediaCollections = []
            mediaShelves = []
            loadedHomeConfigurationID = requestedConfigurationID
        }

        for configuration in library.configurations
        where configuration.kind.usesMediaLibraryBrowser
            && !configuration.isExpired
            && (library.activeConfigurationID == nil || library.activeConfigurationID == configuration.id) {
            async let cachedContinueWatching = library.cachedEmbyContinueWatching(
                configurationID: configuration.id
            )
            var collections = await library.cachedEmbyCollections(
                configurationID: configuration.id
            )
            guard homeLoadIsCurrent(requestedConfigurationID) else { return }
            let hadCachedCollections = !collections.isEmpty
            let homeCacheIsFresh = await library.isMediaServerHomeCacheFresh(
                configurationID: configuration.id
            )
            guard homeLoadIsCurrent(requestedConfigurationID) else { return }
            if collections.isEmpty {
                collections = (try? await library.loadEmbyCollections(
                    configurationID: configuration.id
                )) ?? []
            }
            guard homeLoadIsCurrent(requestedConfigurationID) else { return }
            var sources = homeMediaSources(
                configurationID: configuration.id,
                collections: collections
            )
            mediaCollections.removeAll { $0.configurationID == configuration.id }
            mediaCollections.append(contentsOf: sources)
            synchronizeServerHomeSections()
            synchronizeHomeBlocks()
            let initialContinueWatching = await cachedContinueWatching
            guard homeLoadIsCurrent(requestedConfigurationID) else { return }
            if !initialContinueWatching.isEmpty {
                serverContinueWatching.removeAll {
                    mediaServerConfigurationID(for: $0.channel) == configuration.id
                }
                serverContinueWatching.append(contentsOf: visibleContinueWatching(initialContinueWatching))
            }

            // Disk-backed shelves are cheap and should appear before any live
            // refresh. Publish each one independently so a single slow file or
            // server category never holds the rest of the home page blank.
            let cachedPageSourceIDs = await loadHomeShelfPages(
                sources: sources,
                cachedOnly: true,
                requestedConfigurationID: requestedConfigurationID
            )
            guard homeLoadIsCurrent(requestedConfigurationID) else { return }
            cacheHomeSnapshot(for: configuration.id)

            // A fresh collection index does not imply that every shelf page is
            // cached. Only stay network-free when the whole home snapshot is
            // present; otherwise fetch just the missing shelves below.
            let requiredSourceIDs = Set(sources.map(\.id))
            let hasCompleteCachedHome = requiredSourceIDs.isSubset(of: cachedPageSourceIDs)
            guard !homeCacheIsFresh || !hadCachedCollections || !hasCompleteCachedHome else {
                continue
            }
            if hadCachedCollections && !homeCacheIsFresh {
                try? await Task.sleep(for: .milliseconds(900))
                guard homeLoadIsCurrent(requestedConfigurationID) else { return }
            }

            async let refreshedContinueWatching = try? await library.loadEmbyContinueWatching(
                configurationID: configuration.id,
                limit: 12
            )
            let liveCollections: [MetadataLibraryCollection]?
            if hadCachedCollections {
                liveCollections = try? await library.loadEmbyCollections(
                    configurationID: configuration.id
                )
            } else {
                liveCollections = collections
            }
            guard homeLoadIsCurrent(requestedConfigurationID) else { return }

            if let liveCollections, !liveCollections.isEmpty {
                collections = liveCollections
                sources = homeMediaSources(
                    configurationID: configuration.id,
                    collections: liveCollections
                )
                mediaCollections.removeAll { $0.configurationID == configuration.id }
                mediaCollections.append(contentsOf: sources)
                synchronizeServerHomeSections()
                synchronizeHomeBlocks()
                let validShelfIDs = Set(sources.map(\.id))
                mediaShelves.removeAll {
                    $0.source.configurationID == configuration.id
                        && !validShelfIDs.contains($0.id)
                }
            }

            let liveSources: [RoveHomeMediaCollection]
            if homeCacheIsFresh && hadCachedCollections {
                liveSources = sources.filter { !cachedPageSourceIDs.contains($0.id) }
            } else {
                liveSources = sources
            }
            _ = await loadHomeShelfPages(
                sources: liveSources,
                cachedOnly: false,
                requestedConfigurationID: requestedConfigurationID
            )
            guard homeLoadIsCurrent(requestedConfigurationID) else { return }
            cacheHomeSnapshot(for: configuration.id)

            if let liveContinueWatching = await refreshedContinueWatching {
                guard homeLoadIsCurrent(requestedConfigurationID) else { return }
                serverContinueWatching.removeAll {
                    mediaServerConfigurationID(for: $0.channel) == configuration.id
                }
                serverContinueWatching.append(contentsOf: visibleContinueWatching(liveContinueWatching))
            }
            cacheHomeSnapshot(for: configuration.id)
        }

        guard !Task.isCancelled else { return }
        // Do not rely only on SwiftUI's collection observer here. A source
        // switch can publish cached collections and shelves in the same main
        // actor turn, so explicitly rebuild the visible section/block order
        // after the complete snapshot has been assembled.
        synchronizeServerHomeSections()
        synchronizeHomeBlocks()
    }

    private func homeLoadIsCurrent(_ requestedConfigurationID: UUID?) -> Bool {
        !Task.isCancelled && library.activeConfigurationID == requestedConfigurationID
    }

    private func visibleContinueWatching(
        _ items: [MetadataContinueItem]
    ) -> [MetadataContinueItem] {
        items.filter { !RoveContinueWatchingStore.contains($0.channel) }
    }

    private func removeFromContinueWatching(_ item: MetadataContinueItem) {
        RoveContinueWatchingStore.remove(item.channel)
        serverContinueWatching.removeAll { $0.id == item.id }
    }

    private func markContinueWatchingAsPlayed(_ item: MetadataContinueItem) {
        _ = RoveWatchedStore.mark(item.channel)
        PlaybackProgressStore.clear(for: item.channel)
        RoveContinueWatchingStore.remove(item.channel)
        serverContinueWatching.removeAll { $0.id == item.id }
        Task {
            _ = await library.setMediaServerPlayed(true, for: item.channel)
            await MetadataSyncA.shared.setWatched(true, channel: item.channel)
            await MetadataSyncB.shared.setWatched(true, channel: item.channel)
        }
        mediaStateRevision += 1
    }

    private func homeMediaSources(
        configurationID: UUID,
        collections: [MetadataLibraryCollection]
    ) -> [RoveHomeMediaCollection] {
        // The media-server home must include every root collection. The
        // shelves are loaded lazily below, so keeping all nodes here does not
        // render every poster at once and avoids hiding hosted short-drama
        // categories after the first twenty entries.
        collections.map { collection in
            let prefersSeries = ["tvshows", "series", "shows"].contains(
                collection.collectionType?.lowercased() ?? ""
            )
            return RoveHomeMediaCollection(
                configurationID: configurationID,
                collection: collection,
                displaysPosterStrip: true,
                prefersSeries: prefersSeries
            )
        }
    }

    @MainActor
    private func loadHomeShelfPages(
        sources: [RoveHomeMediaCollection],
        cachedOnly: Bool,
        requestedConfigurationID: UUID?
    ) async -> Set<String> {
        guard !sources.isEmpty else { return [] }
        let parallelism = min(cachedOnly ? 6 : 4, sources.count)
        let channelLibrary = library
        var nextIndex = 0
        var resolvedSourceIDs = Set<String>()

        await withTaskGroup(of: RoveHomeShelfLoadResult.self) { group in
            func enqueue(_ source: RoveHomeMediaCollection) {
                group.addTask {
                    let page: MetadataLibraryPage?
                    if cachedOnly {
                        page = await channelLibrary.cachedEmbyPage(
                            configurationID: source.configurationID,
                            parentID: source.collection.id,
                            limit: 12,
                            prefersSeries: source.prefersSeries
                        )
                    } else {
                        page = try? await channelLibrary.loadEmbyPage(
                            configurationID: source.configurationID,
                            parentID: source.collection.id,
                            startIndex: 0,
                            limit: 12,
                            prefersSeries: source.prefersSeries
                        )
                    }
                    guard let page else {
                        return RoveHomeShelfLoadResult(
                            sourceID: source.id,
                            shelf: nil,
                            resolvedPage: false
                        )
                    }
                    let shelf = page.channels.isEmpty
                        ? nil
                        : RoveHomeMediaShelf(source: source, channels: page.channels)
                    return RoveHomeShelfLoadResult(
                        sourceID: source.id,
                        shelf: shelf,
                        resolvedPage: true
                    )
                }
            }

            while nextIndex < parallelism {
                enqueue(sources[nextIndex])
                nextIndex += 1
            }

            while let result = await group.next() {
                guard homeLoadIsCurrent(requestedConfigurationID) else {
                    group.cancelAll()
                    return
                }
                if result.resolvedPage {
                    resolvedSourceIDs.insert(result.sourceID)
                }
                if let shelf = result.shelf {
                    publishHomeShelves([shelf], orderedBy: sources)
                    cacheHomeSnapshot(for: shelf.source.configurationID)
                }
                if nextIndex < sources.count {
                    enqueue(sources[nextIndex])
                    nextIndex += 1
                }
            }
        }
        guard homeLoadIsCurrent(requestedConfigurationID) else { return [] }
        return resolvedSourceIDs
    }

    @MainActor
    private func publishHomeShelves(
        _ shelves: [RoveHomeMediaShelf],
        orderedBy sources: [RoveHomeMediaCollection]
    ) {
        var shelvesByID = Dictionary(uniqueKeysWithValues: mediaShelves.map { ($0.id, $0) })
        for shelf in shelves {
            shelvesByID[shelf.id] = shelf
        }
        guard let configurationID = sources.first?.configurationID else { return }
        let otherConfigurations = mediaShelves.filter {
            $0.source.configurationID != configurationID
        }
        mediaShelves = otherConfigurations + sources.compactMap { shelvesByID[$0.id] }
    }

    private func serverContinueWatchingShelf(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.heavy))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(serverContinueWatching) { item in
                        Button {
                            openChannel(
                                item.channel,
                                heroID: "home-continue-\(item.channel.id.uuidString)"
                            )
                        } label: {
                            RoveServerContinueWatchingCard(item: item)
                                .roveHeroTransitionSource(
                                    id: "home-continue-\(item.channel.id.uuidString)",
                                    namespace: mediaHeroNamespace
                                )
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                        .contextMenu {
                            Button {
                                removeFromContinueWatching(item)
                            } label: {
                                Label("从继续观看中移除", systemImage: "eye.slash")
                            }

                            Button {
                                library.toggleFavorite(item.channel)
                                mediaStateRevision += 1
                            } label: {
                                Label(
                                    library.isFavorite(item.channel) ? "取消收藏" : "添加到收藏",
                                    systemImage: library.isFavorite(item.channel) ? "heart.slash" : "heart"
                                )
                            }

                            Button {
                                markContinueWatchingAsPlayed(item)
                            } label: {
                                Label("标记为已播放", systemImage: "checkmark.rectangle")
                            }

                            Button {
                                openChannel(
                                    item.channel,
                                    heroID: "home-continue-\(item.channel.id.uuidString)"
                                )
                            } label: {
                                Label("查看详情", systemImage: "info.circle")
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .foregroundStyle(.white)
    }

    private func aiRecommendationShelf(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: "sparkles")
                    .font(.title2.weight(.heavy))
                Spacer()
                if isLoadingAIRecommendations { ProgressView().tint(.white) }
            }

            if !aiRecommendations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 18) {
                        ForEach(aiRecommendations) { channel in
                            Button {
                                openChannel(
                                    channel,
                                    heroID: "home-ai-\(channel.id.uuidString)"
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    RoveArtworkView(channel: channel, landscape: false)
                                        .frame(width: 112, height: 168)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .roveHeroTransitionSource(
                                            id: "home-ai-\(channel.id.uuidString)",
                                            namespace: mediaHeroNamespace
                                        )
                                    Text(channel.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    if let year = channel.productionYear {
                                        Text(String(year))
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.62))
                                    }
                                }
                                .frame(width: 112, alignment: .leading)
                            }
                            .buttonStyle(RoveMotionButtonStyle())
                            .roveMediaActions(
                                for: channel,
                                onOpen: {
                                    openChannel(
                                        channel,
                                        heroID: "home-ai-\(channel.id.uuidString)"
                                    )
                                },
                                onStateChange: { mediaStateRevision += 1 }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .foregroundStyle(.white)
    }

    @MainActor
    private func loadAIRecommendations() async {
        guard aiRecommendationsEnabled,
              RoveDeepSeekService.shared.hasAPIKey,
              !isLoadingAIRecommendations else {
            if !aiRecommendationsEnabled { aiRecommendations = [] }
            return
        }
        let shelfChannels = mediaShelves.flatMap(\.channels)
        let candidates = shelfChannels.isEmpty ? allChannels : shelfChannels
        var seen = Set<String>()
        let uniqueCandidates = candidates.filter { channel in
            let key = channel.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !key.isEmpty && seen.insert(key).inserted
        }
        guard !uniqueCandidates.isEmpty else { return }
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }
        let signature = uniqueCandidates.map(\.id.uuidString).joined(separator: "|")
            + "#" + library.recentChannels.map(\.id.uuidString).joined(separator: "|")
        guard signature != lastAIRecommendationSignature else { return }

        isLoadingAIRecommendations = true
        defer { isLoadingAIRecommendations = false }
        do {
            let names = try await RoveDeepSeekService.shared.recommendedNames(
                history: library.recentChannels,
                candidates: uniqueCandidates
            )
            let byName = Dictionary(
                grouping: uniqueCandidates,
                by: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            )
            var selected: [Channel] = []
            var selectedIDs = Set<UUID>()
            for name in names {
                let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let match = byName[normalized]?.first ?? uniqueCandidates.first {
                    $0.name.localizedCaseInsensitiveContains(name)
                        || name.localizedCaseInsensitiveContains($0.name)
                }
                if let match, selectedIDs.insert(match.id).inserted { selected.append(match) }
                if selected.count == 12 { break }
            }
            aiRecommendations = selected
            lastAIRecommendationSignature = signature
        } catch {
            aiRecommendations = []
        }
    }

    private func mediaFolderShelf(_ shelf: RoveHomeMediaShelf, title: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title ?? shelf.source.collection.name)
                    .font(.title2.weight(.heavy))
                Spacer()
                NavigationLink {
                    EmbyCollectionView(
                        configurationID: shelf.source.configurationID,
                        collection: shelf.source.collection,
                        selectedChannel: $selectedChannel,
                        showsSections: false,
                        prefersSeries: shelf.source.prefersSeries,
                        initialChannels: shelf.channels
                    )
                } label: {
                    Label("查看全部", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.86))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(shelf.channels) { channel in
                        Button {
                            openChannel(
                                channel,
                                heroID: "home-shelf-\(shelf.id)-\(channel.id.uuidString)"
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomTrailing) {
                                    RoveArtworkView(channel: channel, landscape: false)
                                        .frame(width: 112, height: 168)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .roveHeroTransitionSource(
                                            id: "home-shelf-\(shelf.id)-\(channel.id.uuidString)",
                                            namespace: mediaHeroNamespace
                                        )
                                    if let rating = channel.communityRating, rating > 0 {
                                        Text(String(format: "%.1f", rating))
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 5)
                                            .background(.black.opacity(0.7))
                                    }
                                }
                                Text(channel.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if let year = channel.productionYear {
                                    Text(String(year))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.62))
                                }
                            }
                            .frame(width: 112, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .roveMediaActions(
                            for: channel,
                            onOpen: {
                                openChannel(
                                    channel,
                                    heroID: "home-shelf-\(shelf.id)-\(channel.id.uuidString)"
                                )
                            },
                            onStateChange: { mediaStateRevision += 1 }
                        )
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .id("\(shelf.id)|\(mediaStateRevision)")
    }

    private var discoveryHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RoveHomePullProbe()
                discoveryHero
                LazyVStack(alignment: .leading, spacing: 30) {
                    sharedDiscoverySections
                    ForEach([
                        TMDBFeaturedMovie.Shelf.shortRomance,
                        .shortComedy,
                        .shortMystery,
                        .shortAction,
                        .trendingSeries,
                        .topSeries
                    ], id: \.self) { shelf in
                        tmdbRecommendationShelf(shelf: shelf, movies: movies(in: shelf))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 0)
                .padding(.bottom, 28)
            }
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: "rove-home-scroll")
        .onPreferenceChange(RoveHomePullOffsetKey.self, perform: updateHomePullDistance)
        .simultaneousGesture(homeRefreshGesture)
        .overlay(alignment: .top) {
            homeRefreshIndicator
        }
        .background {
            RoveHeroThemeSurface(
                motionDriver: discoveryHeroMotionDriver,
                colors: discoveryHeroBackdropColors,
                selectedIndex: selectedDiscoveryHeroIndex
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private var sharedDiscoverySections: some View {
        tmdbRecommendationShelf(
            shelf: .top200,
            movies: movies(in: .top200)
        )
        discoveryPopularPeopleSection
        discoveryCompaniesSection
        tmdbRecommendationShelf(
            shelf: .shortDrama,
            movies: movies(in: .shortDrama)
        )
        discoveryCategoryCarousel
        discoveryRankedShowcaseCarousel
        discoveryPosterWallCarousel
    }

    private var discoveryCategoryPages: [RoveDiscoveryCategoryPage] {
        [
            RoveDiscoveryCategoryPage(
                shelf: .shortRomance,
                title: "爱情短剧",
                style: .featured
            ),
            RoveDiscoveryCategoryPage(
                shelf: .shortMystery,
                title: "悬疑短剧",
                style: .featured
            ),
            RoveDiscoveryCategoryPage(
                shelf: .shortComedy,
                title: "喜剧短剧",
                style: .featured
            )
        ]
    }

    private var discoveryPosterWallPages: [RoveDiscoveryCategoryPage] {
        [
            RoveDiscoveryCategoryPage(
                shelf: .top200,
                title: "Top 200",
                style: .posterMatrix
            ),
            RoveDiscoveryCategoryPage(
                shelf: .shortDrama,
                title: "热门短剧",
                style: .posterMatrix
            ),
            RoveDiscoveryCategoryPage(
                shelf: .shortAction,
                title: "动作短剧",
                style: .posterMatrix
            )
        ]
    }

    private var discoveryStreamingPlatformPages: [RoveStreamingPlatform] {
        [
            RoveStreamingPlatform(brand: .appleTV, shelf: .topSeries, movieOffset: 0),
            RoveStreamingPlatform(brand: .netflix, shelf: .trendingSeries, movieOffset: 3),
            RoveStreamingPlatform(brand: .disney, shelf: .animation, movieOffset: 1),
            RoveStreamingPlatform(brand: .hboMax, shelf: .popularSeries, movieOffset: 5)
        ]
    }

    private var discoveryRankedShowcasePages: [RoveRankedShowcasePage] {
        [
            RoveRankedShowcasePage(
                shelf: .top200,
                title: "Top 200 榜单",
                subtitle: "TMDB 高分剧集前 200",
                movieOffset: 0
            ),
            RoveRankedShowcasePage(
                shelf: .shortDrama,
                title: "热门短剧",
                subtitle: "20 分钟以内短剧精选",
                movieOffset: 2
            ),
            RoveRankedShowcasePage(
                shelf: .shortRomance,
                title: "爱情短剧榜",
                subtitle: "短篇爱情故事持续更新",
                movieOffset: 1
            )
        ]
    }

    private var discoveryCategoryCarousel: some View {
        GeometryReader { geometry in
            let cardWidth = max(286, geometry.size.width - 22)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(discoveryCategoryPages) { page in
                        discoveryCategoryCard(
                            page,
                            movies: Array(movies(in: page.shelf).prefix(15)),
                            width: cardWidth
                        )
                        .frame(width: cardWidth, height: 390)
                        .id(page.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .contentMargins(.trailing, 10, for: .scrollContent)
        }
        .frame(height: 390)
    }

    private var discoveryPosterWallCarousel: some View {
        GeometryReader { geometry in
            let cardWidth = max(286, geometry.size.width - 22)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(discoveryPosterWallPages) { page in
                        discoveryPosterMatrixCategoryCard(
                            page,
                            movies: discoveryPosterWallMovies(for: page.shelf),
                            width: cardWidth
                        )
                        .frame(width: cardWidth, height: 390)
                        .id("poster-wall-\(page.id)")
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .contentMargins(.trailing, 10, for: .scrollContent)
        }
        .frame(height: 390)
    }

    private var discoveryRankedShowcaseCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("精选榜单")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)

            GeometryReader { geometry in
                let cardWidth = max(286, geometry.size.width - 22)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(discoveryRankedShowcasePages) { page in
                            discoveryRankedShowcaseCard(
                                page,
                                movies: rankedShowcaseMovies(for: page),
                                width: cardWidth
                            )
                            .frame(width: cardWidth, height: 390)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .contentMargins(.trailing, 10, for: .scrollContent)
            }
            .frame(height: 390)
        }
    }

    private func discoveryRankedShowcaseCard(
        _ page: RoveRankedShowcasePage,
        movies: [TMDBFeaturedMovie],
        width: CGFloat
    ) -> some View {
        let hero = movies.first
        let posters = Array(movies.dropFirst())
        let posterWidth = (width - 50) / 4

        return VStack(spacing: 0) {
            Button {
                if let hero {
                    openTMDBMovie(
                        hero,
                        heroID: "home-ranked-\(page.id)-hero-\(hero.identity)"
                    )
                }
            } label: {
                ZStack(alignment: .bottom) {
                    if let hero {
                        TMDBRemoteArtwork(url: hero.backdropURL, title: hero.title)
                            .roveHeroTransitionSource(
                                id: "home-ranked-\(page.id)-hero-\(hero.identity)",
                                namespace: mediaHeroNamespace
                            )
                    } else {
                        RoveArtworkSkeleton()
                    }

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.1), .black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "laurel.leading")
                            Text(page.title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Image(systemName: "laurel.trailing")
                        }
                        .font(.system(size: 24, weight: .black))

                        Text(page.subtitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
                    .padding(.bottom, 18)
                }
                .frame(width: width, height: 235)
                .contentShape(Rectangle())
            }
            .buttonStyle(RoveMotionButtonStyle())
            .disabled(hero == nil)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(posters, id: \.identity) { movie in
                        let transitionID = "home-ranked-\(page.id)-poster-\(movie.identity)"
                        Button {
                            openTMDBMovie(movie, heroID: transitionID)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                                    .frame(width: posterWidth, height: 105)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .roveHeroTransitionSource(
                                        id: transitionID,
                                        namespace: mediaHeroNamespace
                                    )

                                Text(movie.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .frame(width: posterWidth, alignment: .leading)
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                    }
                }
                .padding(.horizontal, 10)
            }
            .padding(.top, 12)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(red: 0.045, green: 0.047, blue: 0.055))
        }
        .frame(width: width, height: 390)
        .background(Color(red: 0.045, green: 0.047, blue: 0.055))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var discoveryCompaniesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("出品商 / 播出平台")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(discoveryCompanies) { company in
                        Button { selectedDJHUBCompany = company } label: {
                            DJHUBCompanyCard(company: company)
                                .frame(width: 282, height: 142)
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                    }
                    ForEach(discoveryPlatformNames, id: \.self) { platform in
                        DJHUBPlatformCard(
                            name: platform,
                            movies: tmdbMovies.filter { $0.platformName == platform }
                        )
                        .frame(width: 282, height: 142)
                    }
                }
            }
        }
    }

    private var discoveryPopularPeopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("热门人物")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showingAllPopularPeople = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看全部热门人物")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(discoveryPopularPeople) { person in
                        Button { selectedTMDBPerson = person } label: {
                            VStack(spacing: 7) {
                                RovePopularPersonAvatar(person: person, size: 72)
                                Text(person.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text("演员")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                    }
                }
            }
        }
    }

    private var discoveryPlatformNames: [String] {
        var seen = Set<String>()
        return tmdbMovies.compactMap(\.platformName).filter { seen.insert($0).inserted }.prefix(6).map { $0 }
    }

    private func discoveryStreamingPlatformCard(
        _ platform: RoveStreamingPlatform,
        movies: [TMDBFeaturedMovie]
    ) -> some View {
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.96)

            HStack(spacing: 0) {
                streamingPlatformLogo(platform.brand)
                    .frame(width: 118)

                ZStack {
                    ForEach(Array(movies.prefix(4).enumerated()), id: \.element.identity) { index, movie in
                        let transitionID = "home-platform-\(platform.id)-\(index)-\(movie.identity)"
                        Button {
                            openTMDBMovie(movie, heroID: transitionID)
                        } label: {
                            TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                                .frame(width: 57, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .shadow(color: .black.opacity(0.24), radius: 4, y: 2)
                                .roveHeroTransitionSource(
                                    id: transitionID,
                                    namespace: mediaHeroNamespace
                                )
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                        .rotationEffect(.degrees(streamingPosterRotation(at: index)))
                        .offset(
                            x: streamingPosterOffset(at: index).width,
                            y: streamingPosterOffset(at: index).height
                        )
                        .zIndex(Double(index))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    @ViewBuilder
    private func streamingPlatformLogo(_ brand: RoveStreamingPlatform.Brand) -> some View {
        switch brand {
        case .appleTV:
            HStack(spacing: 2) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 34, weight: .semibold))
                Text("tv+")
                    .font(.system(size: 34, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.black)
        case .netflix:
            Text("NETFLIX")
                .font(.system(size: 27, weight: .black))
                .scaleEffect(x: 0.82, anchor: .center)
                .foregroundStyle(Color(red: 0.90, green: 0.03, blue: 0.09))
                .minimumScaleFactor(0.75)
        case .disney:
            Text("Disney+")
                .font(.system(size: 27, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(Color(red: 0.03, green: 0.45, blue: 0.60))
                .minimumScaleFactor(0.75)
        case .hboMax:
            HStack(spacing: 1) {
                Text("HBO")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                Text("max")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.33, green: 0.18, blue: 0.82))
            }
        }
    }

    private func streamingPlatformMovies(
        for platform: RoveStreamingPlatform
    ) -> [TMDBFeaturedMovie] {
        let candidates = movies(in: platform.shelf)
        guard !candidates.isEmpty else { return [] }
        return (0..<min(4, candidates.count)).map { index in
            candidates[(platform.movieOffset + index) % candidates.count]
        }
    }

    private func rankedShowcaseMovies(
        for page: RoveRankedShowcasePage
    ) -> [TMDBFeaturedMovie] {
        let candidates = movies(in: page.shelf)
        guard !candidates.isEmpty else { return [] }
        return candidates.indices.map { index in
            candidates[(page.movieOffset + index) % candidates.count]
        }
    }

    private func streamingPosterRotation(at index: Int) -> Double {
        [-12, 8, -7, 11][index % 4]
    }

    private func streamingPosterOffset(at index: Int) -> CGSize {
        [
            CGSize(width: -55, height: -25),
            CGSize(width: -8, height: -34),
            CGSize(width: -42, height: 41),
            CGSize(width: 15, height: 34)
        ][index % 4]
    }

    @ViewBuilder
    private func discoveryCategoryCard(
        _ page: RoveDiscoveryCategoryPage,
        movies: [TMDBFeaturedMovie],
        width: CGFloat
    ) -> some View {
        switch page.style {
        case .featured:
            discoveryFeaturedCategoryCard(page, movies: movies, width: width)
        case .posterMatrix:
            discoveryPosterMatrixCategoryCard(page, movies: movies, width: width)
        }
    }

    private func discoveryFeaturedCategoryCard(
        _ page: RoveDiscoveryCategoryPage,
        movies: [TMDBFeaturedMovie],
        width: CGFloat
    ) -> some View {
        let featured = movies.first
        let secondary = Array(movies.dropFirst().prefix(3))

        return VStack(spacing: 0) {
            Button {
                if let featured {
                    openTMDBMovie(
                        featured,
                        heroID: "home-category-\(page.id)-hero-\(featured.identity)"
                    )
                }
            } label: {
                ZStack(alignment: .bottom) {
                    if let featured {
                        TMDBRemoteArtwork(url: featured.backdropURL, title: featured.title)
                            .roveHeroTransitionSource(
                                id: "home-category-\(page.id)-hero-\(featured.identity)",
                                namespace: mediaHeroNamespace
                            )
                    } else {
                        RoveArtworkSkeleton()
                    }

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.08), .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            Image(systemName: "laurel.leading")
                            Text(page.title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Image(systemName: "laurel.trailing")
                        }
                        .font(.system(size: 23, weight: .black))

                        Text(featured?.title ?? page.shelf.rawValue)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(1)
                            .opacity(0.86)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(width: width, height: 246)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(RoveMotionButtonStyle())
            .disabled(featured == nil)

            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(secondary.enumerated()), id: \.element.identity) { _, movie in
                    let transitionID = "home-category-\(page.id)-secondary-\(movie.identity)"
                    Button {
                        openTMDBMovie(movie, heroID: transitionID)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            TMDBRemoteArtwork(url: movie.backdropURL, title: movie.title)
                                .frame(height: 66)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .roveHeroTransitionSource(
                                    id: transitionID,
                                    namespace: mediaHeroNamespace
                                )

                            Text(movie.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(discoveryCategoryMetadata(for: movie))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.58))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RoveMotionButtonStyle())
                }

                ForEach(secondary.count..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 7) {
                        RoveArtworkSkeleton()
                            .frame(height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        Color.clear.frame(height: 34)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)
        }
        .frame(width: width, height: 390, alignment: .top)
    }

    private func discoveryPosterMatrixCategoryCard(
        _ page: RoveDiscoveryCategoryPage,
        movies: [TMDBFeaturedMovie],
        width: CGFloat
    ) -> some View {
        let rowWidth = width + 38
        let posterWidth = max(58, (rowWidth - 4 * 10) / 5)

        return VStack(spacing: 0) {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { row in
                    let rowMovies = posterWallRowMovies(movies, row: row)
                    RoveAutoScrollingPosterRow(
                        movies: rowMovies,
                        posterWidth: posterWidth,
                        posterHeight: 98,
                        spacing: 10,
                        movesLeft: row.isMultiple(of: 2),
                        speed: row == 1 ? 12 : 15,
                        transitionIDPrefix: "home-poster-wall-\(page.id)-row-\(row)",
                        transitionNamespace: mediaHeroNamespace
                    ) { movie, transitionID in
                        openTMDBMovie(movie, heroID: transitionID)
                    }
                    .frame(width: rowWidth)
                    .offset(x: row.isMultiple(of: 2) ? 0 : -posterWidth * 0.48)
                }
            }
            .frame(width: width, height: 326)
            .clipped()

            Button { selectedTMDBShelf = page.shelf } label: {
                Text(page.title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .contentShape(Rectangle())
            }
            .buttonStyle(RoveMotionButtonStyle())
        }
        .frame(width: width, height: 390, alignment: .top)
    }

    private func posterWallRowMovies(
        _ movies: [TMDBFeaturedMovie],
        row: Int
    ) -> [TMDBFeaturedMovie] {
        guard !movies.isEmpty else { return [] }
        return (0..<5).map { offset in
            movies[(row * 5 + offset) % movies.count]
        }
    }

    private func discoveryCategoryMetadata(for movie: TMDBFeaturedMovie) -> String {
        let year = movie.year > 0 ? String(movie.year) : "即将上映"
        guard let genre = movie.genres.first else { return year }
        return "\(year) · \(genre)"
    }

    private func discoveryPosterWallMovies(
        for shelf: TMDBFeaturedMovie.Shelf
    ) -> [TMDBFeaturedMovie] {
        Array(
            movies(in: shelf)
                .sorted {
                    if $0.rating == $1.rating { return $0.identity < $1.identity }
                    return $0.rating > $1.rating
                }
                .prefix(15)
        )
    }

    private var discoveryHero: some View {
        GeometryReader { geometry in
            let pullDistance = max(
                0,
                geometry.frame(in: .named("rove-home-scroll")).minY
            )
            ZStack(alignment: .bottom) {
                RoveHeroThemeSurface(
                    motionDriver: discoveryHeroMotionDriver,
                    colors: discoveryHeroBackdropColors,
                    selectedIndex: selectedDiscoveryHeroIndex
                )

                RoveNativePagingSurface(
                    selectedIndex: $selectedDiscoveryHeroIndex,
                    itemCount: discoveryHeroMovies.count,
                    width: geometry.size.width,
                    height: homeHeroHeight,
                    contentIdentities: discoveryHeroContentIdentities,
                    motionDriver: discoveryHeroMotionDriver,
                    onTap: { index in
                        guard discoveryHeroMovies.indices.contains(index) else { return }
                        let movie = discoveryHeroMovies[index]
                        openTMDBMovie(
                            movie,
                            heroID: "home-discovery-hero-\(movie.identity)"
                        )
                    }
                ) { index, width in
                    let movie = discoveryHeroMovies[index]
                    discoveryHeroPage(movie, width: width)
                }

                RoveHeroPageIndicator(
                    motionDriver: discoveryHeroMotionDriver,
                    itemCount: discoveryHeroMovies.count,
                    selectedIndex: selectedDiscoveryHeroIndex,
                    inactiveAlpha: 0.42
                )
                .frame(height: 7)
                .padding(.bottom, 4)
                .allowsHitTesting(false)
            }
            .scaleEffect(
                1 + pullDistance / max(homeHeroHeight, 1),
                anchor: .bottom
            )
        }
        .frame(height: homeHeroHeight)
        .onAppear {
            let initialIndex = min(
                max(selectedDiscoveryHeroIndex, 0),
                discoveryHeroMovies.count - 1
            )
            discoveryHeroMotionDriver.update(from: initialIndex, to: initialIndex, progress: 0)
        }
    }

    private func discoveryHeroPage(
        _ movie: TMDBFeaturedMovie,
        width: CGFloat
    ) -> some View {
        ZStack(alignment: .bottom) {
            Group {
                if let image = discoveryHeroArtworkImages[movie.id] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                }
            }
            .frame(width: width, height: homeHeroHeight)
            .clipped()
            .mask(heroArtworkFadeMask)
            .roveHeroTransitionSource(
                id: "home-discovery-hero-\(movie.identity)",
                namespace: mediaHeroNamespace
            )

            heroPageShade

            discoveryHeroMetadata(
                movie,
                width: width,
                logo: discoveryHeroLogoImages[movie.id]
            )
        }
        .frame(width: width, height: homeHeroHeight)
        .background(Color.clear)
        .clipped()
    }

    private var heroArtworkFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.56),
                .init(color: .white.opacity(0.82), location: 0.72),
                .init(color: .white.opacity(0.30), location: 0.90),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var heroPageShade: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.03), location: 0),
                .init(color: Color.clear, location: 0.42),
                .init(color: Color.black.opacity(0.14), location: 0.64),
                .init(color: Color.black.opacity(0.44), location: 0.82),
                .init(color: Color.clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func discoveryHeroArtworkLayer(
        _ movie: TMDBFeaturedMovie,
        geometry: GeometryProxy,
        horizontalOffset: CGFloat,
        opacity: CGFloat
    ) -> some View {
        let verticalOffset = pinnedHeroArtworkOffset(in: geometry)
        Group {
            if let image = discoveryHeroArtworkImages[movie.id] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                    .id("discovery-hero-cover-\(movie.id)")
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
        .offset(x: horizontalOffset, y: verticalOffset)
        .opacity(pinnedHeroArtworkOpacity(for: verticalOffset) * opacity)
    }

    @ViewBuilder
    private func serverHeroArtworkLayer(
        _ channel: Channel,
        geometry: GeometryProxy,
        horizontalOffset: CGFloat,
        opacity: CGFloat
    ) -> some View {
        let verticalOffset = pinnedHeroArtworkOffset(in: geometry)
        Group {
            if let visual = serverHeroVisuals[channel.id] {
                Image(uiImage: visual.image)
                    .resizable()
                    .scaledToFill()
            } else if let tmdbArtwork = serverHeroTMDBArtwork[channel.id] {
                Image(uiImage: tmdbArtwork)
                    .resizable()
                    .scaledToFill()
            } else {
                RoveArtworkView(
                    channel: channel,
                    landscape: false,
                    animatesLoading: false
                )
            }
        }
        .id("server-hero-artwork-\(channel.id.uuidString)")
        .frame(width: geometry.size.width, height: geometry.size.height)
        .offset(x: horizontalOffset, y: verticalOffset)
        .opacity(pinnedHeroArtworkOpacity(for: verticalOffset) * opacity)
    }

    private func discoveryHeroMetadata(
        _ movie: TMDBFeaturedMovie,
        width: CGFloat,
        logo: UIImage?
    ) -> some View {
        VStack(spacing: 9) {
            Spacer()
            Group {
                if let logo {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: min(width * 0.72, 360), maxHeight: 84)
                } else {
                    Text(movie.title)
                        // English-only TMDB logos are intentionally skipped so
                        // the Chinese fallback remains readable.
                        .font(RovePosterTitleStyle.font(size: 212, seed: movie.title))
                        .foregroundStyle(RovePosterTitleStyle.color(seed: movie.title))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.18)
                }
            }
            .shadow(color: .black.opacity(0.32), radius: 3, y: 2)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .layoutPriority(1)
            HStack(spacing: 10) {
                if let rating = movie.displayRating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
                if movie.year > 0 { Text(String(movie.year)) }
                Text(movie.genres.joined(separator: " · "))
            }
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            Text(movie.overview)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 44, alignment: .top)
            Spacer().frame(height: 30)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.bottom, 4)
        .frame(width: width)
        .clipped()
    }

    private func movies(in shelf: TMDBFeaturedMovie.Shelf) -> [TMDBFeaturedMovie] {
        tmdbMovies.filter { $0.shelves.contains(shelf) }
    }

    @MainActor
    private func preloadServerHeroArtwork(
        around index: Int,
        loadsRemaining: Bool = true
    ) async {
        let channels = heroChannels
        let indices = heroPreloadIndices(count: channels.count, centeredAt: index)
        let visibleIndices = Array(indices.prefix(3))
        let visibleArtwork = await loadServerHeroArtworkBatch(
            channels: channels,
            indices: visibleIndices
        )
        guard !Task.isCancelled else { return }
        publishServerHeroArtwork(visibleArtwork)

        guard loadsRemaining, indices.count > visibleIndices.count else { return }
        let remainingArtwork = await loadServerHeroArtworkBatch(
            channels: channels,
            indices: Array(indices.dropFirst(visibleIndices.count))
        )
        guard !Task.isCancelled else { return }
        publishServerHeroArtwork(remainingArtwork)
    }

    private func loadServerHeroArtworkBatch(
        channels: [Channel],
        indices: [Int]
    ) async -> [RovePreloadedArtwork] {
        var loaded: [RovePreloadedArtwork] = []
        await withTaskGroup(of: RovePreloadedArtwork?.self) { group in
            for index in indices {
                let channel = channels[index]
                group.addTask {
                    guard let image = await ChannelArtworkLoader.shared.primaryImage(
                        for: channel,
                        maxWidth: 900
                    ) else { return nil }
                    return RovePreloadedArtwork(id: channel.id.uuidString, image: image)
                }
            }
            for await result in group {
                guard let result, !Task.isCancelled else { continue }
                loaded.append(result)
            }
        }
        return loaded
    }

    @MainActor
    private func publishServerHeroArtwork(_ loaded: [RovePreloadedArtwork]) {
        guard !loaded.isEmpty else { return }
        var visuals = serverHeroVisuals
        for result in loaded {
            guard let id = UUID(uuidString: result.id) else { continue }
            visuals[id] = RoveHeroVisual(image: result.image, color: result.color)
        }
        serverHeroVisuals = visuals
    }

    @MainActor
    private func preloadServerHeroDetails(around index: Int) async {
        let channels = heroChannels
        let indices = Array(
            heroPreloadIndices(count: channels.count, centeredAt: index).prefix(3)
        )
        var loadedDetails = serverHeroDetails
        var artworkByID = serverHeroTMDBArtwork
        var logosByID = serverHeroLogoImages
        var colorsByID = serverHeroTMDBThemeColors
        var overviewsByID = serverHeroTMDBOverviews
        var enrichedIDs = serverHeroEnrichedIDs
        var didChange = false

        for index in indices {
            guard !Task.isCancelled else { return }
            let channel = channels[index]
            guard !enrichedIDs.contains(channel.id) else { continue }
            guard let configurationID = mediaServerConfigurationID(for: channel),
                  let itemID = channel.tvgID else { continue }
            let cached = await library.cachedMetadataDetails(
                configurationID: configurationID,
                itemID: itemID
            )
            let details: MetadataDetails?
            if let cached {
                details = cached
            } else {
                details = try? await library.loadMetadataDetails(
                    configurationID: configurationID,
                    itemID: itemID
                )
            }
            guard let details else { continue }

            loadedDetails[channel.id] = details
            enrichedIDs.insert(channel.id)
            didChange = true

            if let assets = await fetchServerHeroTMDBAssets(for: channel, details: details) {
                if let artwork = assets.artwork { artworkByID[assets.id] = artwork }
                if let logo = assets.logo { logosByID[assets.id] = logo }
                if let color = assets.color { colorsByID[assets.id] = color }
                if let overview = assets.overview { overviewsByID[assets.id] = overview }
            }
        }
        guard didChange, !Task.isCancelled else { return }
        serverHeroDetails = loadedDetails
        serverHeroTMDBArtwork = artworkByID
        serverHeroLogoImages = logosByID
        serverHeroTMDBThemeColors = colorsByID
        serverHeroTMDBOverviews = overviewsByID
        serverHeroEnrichedIDs = enrichedIDs
        if let featuredChannel, let details = loadedDetails[featuredChannel.id] {
            featuredDetails = details
        }
    }

    @MainActor
    private func fetchServerHeroTMDBAssets(
        for channel: Channel,
        details: MetadataDetails
    ) async -> RoveServerHeroTMDBAssets? {
        guard let tmdb = await TMDBDiscoveryService.loadDetails(
            title: details.title,
            year: details.productionYear,
            isTV: channel.isMediaServerSeries || channel.isMediaServerEpisode
        ), !Task.isCancelled else { return nil }

        let artworkURL = tmdb.bestHeroArtworkPath.flatMap {
            RoveAPISettings.tmdbImageURL(size: "w780", path: $0)
        }
        let logoURL = tmdb.preferredChineseLogoPath.flatMap {
            RoveAPISettings.tmdbImageURL(size: "w500", path: $0)
        }
        async let artwork = TMDBArtworkLoader.shared.image(for: artworkURL)
        async let logo = TMDBArtworkLoader.shared.image(for: logoURL)
        let (loadedArtwork, loadedLogo) = await (artwork, logo)
        guard !Task.isCancelled else { return nil }
        let artworkBox = RoveUncheckedOptionalImage(value: loadedArtwork)
        let sampledColor = await Task.detached(priority: .utility) {
            RoveUncheckedOptionalColor(value: artworkBox.value?.roveImmersiveColor)
        }.value.value
        return RoveServerHeroTMDBAssets(
            id: channel.id,
            artwork: loadedArtwork,
            logo: loadedLogo,
            color: sampledColor,
            overview: tmdb.overview.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        )
    }

    @MainActor
    private func preloadDiscoveryHeroArtwork(around index: Int) async {
        let heroes = discoveryHeroMovies
        let indices = heroPreloadIndices(count: heroes.count, centeredAt: index)
        var loadedArtwork: [RovePreloadedArtwork] = []
        await withTaskGroup(of: RovePreloadedArtwork?.self) { group in
            for index in indices {
                let movie = heroes[index]
                group.addTask {
                    guard let image = await TMDBArtworkLoader.shared.image(for: movie.posterURL) else {
                        return nil
                    }
                    return RovePreloadedArtwork(id: String(movie.id), image: image)
                }
            }
            for await result in group {
                guard let result, !Task.isCancelled else { continue }
                loadedArtwork.append(result)
            }
        }
        guard !Task.isCancelled else { return }
        var artworkByID = discoveryHeroArtworkImages
        var colorsByID = discoveryHeroThemeColors
        for result in loadedArtwork {
            guard let id = Int(result.id) else { continue }
            artworkByID[id] = result.image
            colorsByID[id] = result.color
        }
        discoveryHeroArtworkImages = artworkByID
        discoveryHeroThemeColors = colorsByID
    }

    private func heroPreloadIndices(count: Int, centeredAt index: Int) -> [Int] {
        guard count > 0 else { return [] }
        let center = min(max(index, 0), count - 1)
        var result: [Int] = []
        for distance in 0..<count {
            for offset in distance == 0 ? [0] : [distance, -distance] {
                let candidate = (center + offset + count) % count
                if !result.contains(candidate) { result.append(candidate) }
                if result.count == count { return result }
            }
        }
        return result
    }

    private func pinnedHeroArtworkOffset(in geometry: GeometryProxy) -> CGFloat {
        max(0, -geometry.frame(in: .named("rove-home-scroll")).minY)
    }

    private func pinnedHeroArtworkOpacity(for offset: CGFloat) -> Double {
        let fadeDistance = max(1, homeHeroHeight * 0.76)
        return Double(max(0, 1 - offset / fadeDistance))
    }

    @ViewBuilder
    private func tmdbRecommendationShelf(
        shelf: TMDBFeaturedMovie.Shelf,
        movies: [TMDBFeaturedMovie]
    ) -> some View {
        if !movies.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(shelf.rawValue)
                        .font(.title2.weight(.heavy))
                    Spacer()
                    Button {
                        selectedTMDBShelf = shelf
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看全部\(shelf.rawValue)")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 18) {
                        ForEach(movies, id: \.identity) { movie in
                            let transitionID = "home-tmdb-\(shelf.id)-\(movie.identity)"
                            Button {
                                openTMDBMovie(movie, heroID: transitionID)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                                            .frame(width: 112, height: 168)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .roveHeroTransitionSource(
                                                id: transitionID,
                                                namespace: mediaHeroNamespace
                                            )
                                        if let rating = movie.displayRating {
                                            Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                                .labelStyle(.titleAndIcon)
                                                .font(.caption2.weight(.heavy))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 5)
                                                .background(.black.opacity(0.72), in: Capsule())
                                                .padding(7)
                                        }
                                    }
                                    Text(movie.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(movie.year > 0 ? String(movie.year) : "即将上映")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.58))
                                }
                                .frame(width: 112, alignment: .leading)
                            }
                            .buttonStyle(RoveMotionButtonStyle())
                        }
                    }
                }
            }
            .foregroundStyle(.white)
        }
    }

    @MainActor
    private func loadTMDBDiscovery(forceRefresh: Bool = false) async -> Bool {
        guard !isLoadingTMDB else { return false }
        isLoadingTMDB = true
        defer { isLoadingTMDB = false }
        var publishedCachedData = false
        if !forceRefresh,
           let cached = await DJHUBDiscoveryService.cachedMovies(),
           !cached.isEmpty {
            if tmdbMovies != cached {
                tmdbMovies = cached
            }
            publishedCachedData = true
        }
        let liveMovies = await DJHUBDiscoveryService.loadHome()
        guard !Task.isCancelled else { return false }
        guard !liveMovies.isEmpty else { return publishedCachedData }
        if tmdbMovies != liveMovies {
            tmdbMovies = liveMovies
        }
        return true
    }

    @MainActor
    private func loadDiscoveryPopularPeople() async {
        let people = await DJHUBDiscoveryService.popularPeople()
        if !people.isEmpty { discoveryPopularPeople = people }
    }

    @MainActor
    private func loadDiscoveryCompanies() async {
        let companies = await DJHUBDiscoveryService.companies()
        if !companies.isEmpty { discoveryCompanies = companies }
    }

    @ViewBuilder
    private var featuredHero: some View {
        let channels = heroChannels
        if !channels.isEmpty {
            GeometryReader { geometry in
                let pullDistance = max(
                    0,
                    geometry.frame(in: .named("rove-home-scroll")).minY
                )
                ZStack(alignment: .bottom) {
                    RoveHeroThemeSurface(
                        motionDriver: serverHeroMotionDriver,
                        colors: serverHeroBackdropColors,
                        selectedIndex: selectedHeroIndex
                    )

                    RoveNativePagingSurface(
                        selectedIndex: $selectedHeroIndex,
                        itemCount: channels.count,
                        width: geometry.size.width,
                        height: homeHeroHeight,
                        contentIdentities: serverHeroContentIdentities(for: channels),
                        motionDriver: serverHeroMotionDriver,
                        onTap: { index in
                            guard channels.indices.contains(index) else { return }
                            let channel = channels[index]
                            openChannel(
                                channel,
                                heroID: "home-server-hero-\(channel.id.uuidString)"
                            )
                        }
                    ) { index, width in
                        if channels.indices.contains(index) {
                            let channel = channels[index]
                            serverHeroPage(channel, width: width)
                        } else {
                            Color.clear
                        }
                    }

                    RoveHeroPageIndicator(
                        motionDriver: serverHeroMotionDriver,
                        itemCount: channels.count,
                        selectedIndex: selectedHeroIndex,
                        inactiveAlpha: 0.38
                    )
                    .frame(height: 7)
                    .padding(.bottom, 4)
                    .allowsHitTesting(false)
                }
                .scaleEffect(
                    1 + pullDistance / max(homeHeroHeight, 1),
                    anchor: .bottom
                )
            }
            .frame(height: homeHeroHeight)
            .task(id: "\(serverHeroDatasetTaskID):\(selectedHeroIndex)") {
                await preloadServerHeroArtwork(
                    around: selectedHeroIndex,
                    loadsRemaining: false
                )
                guard !Task.isCancelled else { return }
                await preloadServerHeroDetails(around: selectedHeroIndex)
            }
            .onAppear {
                let initialIndex = min(max(selectedHeroIndex, 0), channels.count - 1)
                serverHeroMotionDriver.update(from: initialIndex, to: initialIndex, progress: 0)
            }
        } else if activeMediaServer != nil {
            // Keep the media-server home geometry stable while its first page
            // is loading. Replacing discoveryHome with populatedHome here was
            // the source of the visible pause and the sudden immersive jump.
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                ProgressView()
                    .tint(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: homeHeroHeight)
        } else {
            Button(action: onAddSource) {
                ZStack(alignment: .bottomLeading) {
                    Color(uiColor: .secondarySystemBackground)
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Label("添加媒体来源", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(16)
                }
                .aspectRatio(1.82, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func serverHeroPage(_ channel: Channel, width: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Group {
                if let visual = serverHeroVisuals[channel.id] {
                    Image(uiImage: visual.image)
                        .resizable()
                        .scaledToFill()
                } else if let tmdbArtwork = serverHeroTMDBArtwork[channel.id] {
                    Image(uiImage: tmdbArtwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoveArtworkView(
                        channel: channel,
                        landscape: false,
                        animatesLoading: false
                    )
                }
            }
            .frame(width: width, height: homeHeroHeight)
            .clipped()
            .mask(heroArtworkFadeMask)
            .roveHeroTransitionSource(
                id: "home-server-hero-\(channel.id.uuidString)",
                namespace: mediaHeroNamespace
            )

            heroPageShade
            heroMetadata(channel)
        }
        .frame(width: width, height: homeHeroHeight)
        .background(Color.clear)
        .clipped()
    }

    private func heroMetadata(_ channel: Channel) -> some View {
        let details = serverHeroDetails[channel.id]
            ?? (featuredChannel?.id == channel.id ? featuredDetails : nil)
        let productionYear = details?.productionYear ?? channel.productionYear
        let genreText = (details?.genres.prefix(2).joined(separator: " · "))
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? library.displayGroup(for: channel)
        let subtitleText = channel.isMediaServerEpisode
            ? homeHeroEpisodeLabel(for: channel)
            : genreText
        let serverOverview = details?.overview?.trimmingCharacters(in: .whitespacesAndNewlines)
        let tmdbOverview = serverHeroTMDBOverviews[channel.id]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let overview = serverOverview?.nonEmpty ?? tmdbOverview?.nonEmpty
        let rating = details?.communityRating ?? channel.communityRating
        let logo = serverHeroLogoImages[channel.id]

        return VStack(spacing: 9) {
            Spacer()
            Group {
                if let logo {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: min(UIScreen.main.bounds.width * 0.68, 340), maxHeight: 82)
                        .shadow(color: .black.opacity(0.42), radius: 4, y: 2)
                } else {
                    Text(homeHeroDisplayTitle(for: channel))
                        .font(RovePosterTitleStyle.font(size: 202, seed: homeHeroDisplayTitle(for: channel)))
                        .foregroundStyle(RovePosterTitleStyle.color(seed: channel.id.uuidString))
                        .shadow(color: .black.opacity(0.32), radius: 3, y: 2)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.18)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .layoutPriority(1)
            HStack(spacing: 12) {
                Label(productionYear.map(String.init) ?? "0000", systemImage: "calendar")
                    .opacity(productionYear == nil ? 0 : 1)
                Label(subtitleText, systemImage: channel.isMediaServerEpisode ? "play.rectangle" : "square.grid.2x2")
            }
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(height: 22)
            if let overview {
                Text(overview)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56, alignment: .top)
            }
            Label(String(format: "%.1f", rating ?? 0), systemImage: "star.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(height: 22)
                .opacity(rating == nil ? 0 : 1)
            Spacer().frame(height: 18)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .frame(maxWidth: UIScreen.main.bounds.width)
        .clipped()
    }

    private func homeHeroTitle(for channel: Channel) -> String {
        guard channel.isMediaServerEpisode else { return channel.name }
        let seriesName = channel.group
            .replacingOccurrences(
                of: #"\s*[·•]\s*第\s*\d+\s*季.*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !seriesName.isEmpty, seriesName != AppLanguage.localized("剧集") else {
            return channel.name
        }
        return seriesName
    }

    private func homeHeroDisplayTitle(for channel: Channel) -> String {
        let candidates = [serverHeroDetails[channel.id]?.title, homeHeroTitle(for: channel)]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
        return candidates.first { title in
            title.unicodeScalars.contains { (0x4E00...0x9FFF).contains(Int($0.value)) }
        } ?? candidates.first ?? channel.name
    }

    private func homeHeroEpisodeLabel(for channel: Channel) -> String {
        guard let range = channel.name.range(
            of: #"第\s*\d+\s*集"#,
            options: .regularExpression
        ) else {
            return AppLanguage.localized("剧集")
        }
        return String(channel.name[range]).replacingOccurrences(of: " ", with: "")
    }

    private func mediaServerConfigurationID(for channel: Channel) -> UUID? {
        switch channel.resolver {
        case .legacyLibraryB(let id, _), .legacyLibraryA(let id, _), .movieClaw(let id, _), .legacyLibraryC(let id, _),
             .legacyLibraryD(let id, _): id
        default: nil
        }
    }

    private func posterShelf(
        title: String,
        category: RoveBrowseCategory,
        channels: [Channel],
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title2.weight(.heavy))
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer()
                Button {
                    browseCategory = category
                } label: {
                    Label("查看全部", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(Array(channels.prefix(12))) { channel in
                        let transitionID = "home-category-\(category.id)-channel-\(channel.id.uuidString)"
                        Button {
                            openChannel(channel, heroID: transitionID)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    RoveArtworkView(channel: channel, landscape: false)
                                        .frame(width: 112, height: 168)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .roveHeroTransitionSource(
                                            id: transitionID,
                                            namespace: mediaHeroNamespace
                                        )
                                    if let rating = channel.communityRating {
                                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(.black.opacity(0.72), in: Capsule())
                                            .padding(8)
                                    }
                                }
                                Text(channel.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(metadataText(for: channel))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                                    .lineLimit(1)
                            }
                            .frame(width: 112, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                        .roveMediaActions(
                            for: channel,
                            onOpen: { openChannel(channel, heroID: transitionID) },
                            onStateChange: { mediaStateRevision += 1 }
                        )
                    }
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func shelf(_ category: RoveBrowseCategory) -> [Channel] {
        if category == .recent {
            return Array(library.recentChannels.prefix(40))
        }
        let matched = allChannels.filter { category.matches($0, group: library.displayGroup(for: $0)) }
        return Array(matched.prefix(40))
    }

    private func metadataText(for channel: Channel) -> String {
        var values: [String] = []
        if let year = channel.productionYear { values.append(String(year)) }
        values.append(library.displayGroup(for: channel))
        return values.joined(separator: " · ")
    }
}

private struct RoveLuckyTicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(15, rect.height * 0.12)
        let edgeNotch = min(11, rect.height * 0.09)
        let stubNotch = min(9, rect.height * 0.075)
        let middleY = rect.midY
        let stubX = rect.minX + rect.width * 0.78
        var path = Path()
        path.move(to: CGPoint(x: radius, y: rect.minY))
        path.addLine(to: CGPoint(x: stubX - stubNotch, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: stubX + stubNotch, y: rect.minY),
            control1: CGPoint(x: stubX - stubNotch, y: rect.minY + stubNotch),
            control2: CGPoint(x: stubX + stubNotch, y: rect.minY + stubNotch)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: middleY - edgeNotch))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - edgeNotch, y: middleY),
            control: CGPoint(x: rect.maxX - edgeNotch, y: middleY - edgeNotch)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: middleY + edgeNotch),
            control: CGPoint(x: rect.maxX - edgeNotch, y: middleY + edgeNotch)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: stubX + stubNotch, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: stubX - stubNotch, y: rect.maxY),
            control1: CGPoint(x: stubX + stubNotch, y: rect.maxY - stubNotch),
            control2: CGPoint(x: stubX - stubNotch, y: rect.maxY - stubNotch)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: middleY + edgeNotch))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + edgeNotch, y: middleY),
            control: CGPoint(x: rect.minX + edgeNotch, y: middleY + edgeNotch)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: middleY - edgeNotch),
            control: CGPoint(x: rect.minX + edgeNotch, y: middleY - edgeNotch)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct RoveLuckyWalletPocketShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(24, rect.height * 0.16)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 8))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + 48),
            control1: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + 10),
            control2: CGPoint(x: rect.midX - rect.width * 0.16, y: rect.minY + 44)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 8),
            control1: CGPoint(x: rect.midX + rect.width * 0.16, y: rect.minY + 44),
            control2: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY + 10)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

private struct RoveLuckyWallet: View {
    enum Layer: Equatable {
        case back
        case pocket
    }

    let width: CGFloat
    let candidateCount: Int
    let layer: Layer

    private let leatherDark = Color(red: 0.20, green: 0.035, blue: 0.075)
    private let leather = Color(red: 0.31, green: 0.060, blue: 0.115)
    private let leatherLight = Color(red: 0.40, green: 0.085, blue: 0.145)
    private let thread = Color(red: 0.72, green: 0.43, blue: 0.35)
    private let gold = Color(red: 0.93, green: 0.74, blue: 0.46)

    var body: some View {
        let backShape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let pocketShape = RoveLuckyWalletPocketShape()
        ZStack(alignment: .bottom) {
            if layer == .back {
                backShape
                    .fill(
                        LinearGradient(
                            colors: [leatherLight, leatherDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 194)
                    .overlay {
                        backShape
                            .stroke(thread.opacity(0.78), style: StrokeStyle(lineWidth: 1.2, dash: [3, 5]))
                            .padding(12)
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                            .frame(width: width - 42, height: 27)
                            .blur(radius: 2)
                            .offset(y: 19)
                    }
            } else {
                pocketShape
                    .fill(
                        LinearGradient(
                            colors: [leatherLight, leather, leatherDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 156)
                    .overlay {
                        pocketShape
                            .stroke(thread.opacity(0.82), style: StrokeStyle(lineWidth: 1.25, dash: [3, 5]))
                            .padding(12)
                    }
                    .overlay(alignment: .top) {
                        RoveLuckyWalletPocketShape()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            .frame(height: 156)
                    }
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 4) {
                            Capsule().fill(Color.black.opacity(0.24)).frame(height: 1)
                            Capsule().fill(Color.white.opacity(0.07)).frame(height: 1)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 9)
                    }
                    .overlay {
                        VStack(spacing: 7) {
                            HStack(spacing: 7) {
                                Capsule().fill(gold.opacity(0.64)).frame(width: 56, height: 1)
                                Image(systemName: "shuffle")
                                    .font(.system(size: 18, weight: .bold))
                                Capsule().fill(gold.opacity(0.64)).frame(width: 56, height: 1)
                            }
                            Text("待看票库")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                            Text("\(max(candidateCount, 1)) 张票券")
                                .font(.system(size: 12, weight: .bold))
                                .opacity(0.72)
                        }
                        .foregroundStyle(gold)
                        .padding(.top, 42)
                    }
            }
        }
        .frame(width: width, height: 194)
        .shadow(color: layer == .back ? .black.opacity(0.38) : .clear, radius: 22, y: 14)
    }
}

private struct RoveLuckyPickArtwork: View {
    let pick: RoveLuckyPick
    let heroNamespace: Namespace.ID?

    var body: some View {
        Group {
            if let heroNamespace {
                artwork
                    .roveHeroTransitionSource(id: pick.heroID, namespace: heroNamespace)
            } else {
                artwork
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        switch pick {
        case .channel(let channel):
            RoveArtworkView(channel: channel, landscape: false)
        case .tmdb(let movie):
            TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
        }
    }
}

private struct RoveLuckyPickTicket: View {
    let pick: RoveLuckyPick
    let width: CGFloat
    var heroNamespace: Namespace.ID?

    private var ticketHeight: CGFloat { width * 0.425 }
    private var artworkWidth: CGFloat { ticketHeight * 0.62 }
    private var stubWidth: CGFloat { width * 0.22 }

    var body: some View {
        let shape = RoveLuckyTicketShape()
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                RoveLuckyPickArtwork(pick: pick, heroNamespace: heroNamespace)
                    .frame(width: artworkWidth, height: ticketHeight)
                    .clipped()

                VStack(alignment: .leading, spacing: 5) {
                    Text(pick.title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.black.opacity(0.86))
                        .lineLimit(2)
                        .minimumScaleFactor(0.68)

                    HStack(spacing: 4) {
                        Text(pick.categoryText)
                        if let yearText = pick.yearText {
                            Text("·")
                            Text(yearText)
                        }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))
                    .lineLimit(1)

                    if let rating = pick.rating {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color(red: 0.78, green: 0.43, blue: 0.06))
                    }

                    Text(pick.ticketSummary)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.black.opacity(0.56))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 2)

                    Text("ROVE PLAYER · 私人放映票")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(.black.opacity(0.43))
                        .lineLimit(1)
                }
                .padding(.leading, 11)
                .padding(.trailing, 8)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: width - stubWidth, height: ticketHeight)

            VStack(spacing: 0) {
                Text("为你抽到")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black.opacity(0.55))

                Spacer(minLength: 5)

                Image(systemName: "bookmark.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.48, green: 0.28, blue: 0.10))

                Spacer(minLength: 4)

                Image(systemName: "barcode")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.black.opacity(0.62))

                Text("查看详情")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black.opacity(0.48))
            }
            .padding(.vertical, 14)
            .frame(width: stubWidth, height: ticketHeight)
        }
        .frame(width: width, height: ticketHeight)
        .background {
            shape.fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.90, blue: 0.76),
                        Color(red: 0.90, green: 0.82, blue: 0.66)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .clipShape(shape)
        .overlay {
            shape.stroke(Color(red: 0.62, green: 0.49, blue: 0.30).opacity(0.72), lineWidth: 1.2)
        }
        .overlay {
            Path { path in
                let x = width * 0.78
                path.move(to: CGPoint(x: x, y: 12))
                path.addLine(to: CGPoint(x: x, y: ticketHeight - 12))
            }
            .stroke(
                Color(red: 0.48, green: 0.37, blue: 0.23).opacity(0.48),
                style: StrokeStyle(lineWidth: 1, dash: [4, 5])
            )
        }
        .shadow(color: .black.opacity(0.34), radius: 18, y: 11)
    }
}

private struct RoveWatchlistTicket: View {
    let pick: RoveLuckyPick
    let width: CGFloat

    private var height: CGFloat { width * 0.38 }
    private var stubWidth: CGFloat { width * 0.22 }

    var body: some View {
        let shape = RoveLuckyTicketShape()
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                RoveLuckyPickArtwork(pick: pick, heroNamespace: nil)
                    .frame(width: height * 0.60, height: height)
                    .clipped()

                VStack(alignment: .leading, spacing: 5) {
                    Text(pick.title)
                        .font(.system(size: 15, weight: .black))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(pick.categoryText)
                        if let yearText = pick.yearText {
                            Text("·")
                            Text(yearText)
                        }
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)

                    Text(pick.ticketSummary)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    HStack(spacing: 5) {
                        if let rating = pick.rating {
                            Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.24))
                        }
                        Text("ROVE 待看票")
                    }
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.58))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: width - stubWidth, height: height)

            VStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 20, weight: .bold))
                Image(systemName: "barcode")
                    .font(.system(size: 28))
                Text("已加入")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color(red: 0.91, green: 0.71, blue: 0.44))
            .frame(width: stubWidth, height: height)
        }
        .frame(width: width, height: height)
        .background {
            shape.fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.27, green: 0.11, blue: 0.09),
                        Color(red: 0.14, green: 0.055, blue: 0.048)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .clipShape(shape)
        .overlay {
            shape.stroke(Color(red: 0.84, green: 0.54, blue: 0.31).opacity(0.72), lineWidth: 1)
        }
        .overlay {
            Path { path in
                let x = width * 0.78
                path.move(to: CGPoint(x: x, y: 10))
                path.addLine(to: CGPoint(x: x, y: height - 10))
            }
            .stroke(
                Color(red: 0.90, green: 0.67, blue: 0.43).opacity(0.52),
                style: StrokeStyle(lineWidth: 1, dash: [3, 4])
            )
        }
        .shadow(color: .black.opacity(0.48), radius: 18, y: 10)
    }
}

private struct RoveWatchlistTicketAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pick: RoveLuckyPick
    let onFinished: () -> Void

    @State private var phase = 0
    @State private var dropProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let width = min(332, geometry.size.width - 42)
            ZStack(alignment: .top) {
                RoveWatchlistTicket(pick: pick, width: width)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                    .opacity(opacity)
                    .offset(
                        x: xOffset(in: geometry.size.width),
                        y: yOffset(in: geometry.size.height)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(1)

                if hasDynamicIsland || geometry.safeAreaInsets.top > 51 {
                    Capsule(style: .continuous)
                        .fill(.black)
                        .frame(width: islandWidth, height: islandHeight)
                        .shadow(color: .black.opacity(0.72), radius: 9, y: 5)
                        .padding(.top, 8)
                        .opacity(islandOpacity)
                        .zIndex(2)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .task {
            if reduceMotion {
                dropProgress = 1
                phase = 4
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                onFinished()
                return
            }

            let lightImpact = UIImpactFeedbackGenerator(style: .light)
            let softImpact = UIImpactFeedbackGenerator(style: .soft)
            let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
            let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
            lightImpact.prepare()
            softImpact.prepare()
            rigidImpact.prepare()
            mediumImpact.prepare()

            await Task.yield()
            withAnimation(.easeOut(duration: 0.18)) {
                phase = 1
            }
            softImpact.impactOccurred(intensity: 0.48)
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }

            withAnimation(.timingCurve(0.22, 0.02, 0.56, 1, duration: 1.12)) {
                dropProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(360))
            guard !Task.isCancelled else { return }
            lightImpact.impactOccurred(intensity: 0.52)
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            softImpact.impactOccurred(intensity: 0.62)
            try? await Task.sleep(for: .milliseconds(430))
            guard !Task.isCancelled else { return }

            rigidImpact.impactOccurred(intensity: 0.92)
            withAnimation(.spring(response: 0.62, dampingFraction: 0.74)) {
                phase = 4
            }
            mediumImpact.impactOccurred(intensity: 0.88)
            try? await Task.sleep(for: .milliseconds(820))
            guard !Task.isCancelled else { return }

            withAnimation(.easeIn(duration: 0.58)) {
                phase = 5
            }
            try? await Task.sleep(for: .milliseconds(620))
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }

    private var scale: CGFloat {
        switch phase {
        case 0, 1: 0.68
        case 4: 1
        default: 0.72
        }
    }

    private var rotation: Double {
        switch phase {
        case 0, 1: 90
        case 4: -5
        default: 20
        }
    }

    private var islandWidth: CGFloat {
        switch phase {
        case 1: 152
        default: 126
        }
    }

    private var islandHeight: CGFloat {
        switch phase {
        case 1: 42
        default: 37
        }
    }

    private var islandOpacity: Double {
        phase <= 1 ? 1 : 0
    }

    private var hasDynamicIsland: Bool {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
        return topInset > 51
    }

    private var opacity: Double {
        phase == 0 || phase == 5 ? 0 : 1
    }

    private func xOffset(in width: CGFloat) -> CGFloat {
        switch phase {
        case 5: width * 0.18
        default: 0
        }
    }

    private func yOffset(in height: CGFloat) -> CGFloat {
        switch phase {
        case 0:
            return -height * 0.53
        case 1:
            let islandOrigin = -height * 0.53
            let restingPoint = -height * 0.20
            return islandOrigin + ((restingPoint - islandOrigin) * dropProgress)
        case 4:
            return -height * 0.08
        default:
            return height * 0.46
        }
    }
}

private struct RoveLuckyPickOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let selection: RoveLuckyPick
    let deck: [RoveLuckyPick]
    let candidateCount: Int
    let heroNamespace: Namespace.ID
    let onClose: () -> Void
    let onOpen: (RoveLuckyPick) -> Void

    @State private var walletVisible = false
    @State private var ticketVisible = false
    @State private var walletDismissed = false
    @State private var walletShakeX: CGFloat = 0
    @State private var walletShakeAngle = 0.0
    @State private var isOpening = false

    var body: some View {
        GeometryReader { geometry in
            let ticketWidth = min(356, max(304, geometry.size.width - 34))
            let walletWidth = min(350, max(300, geometry.size.width - 40))
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay(Color.black.opacity(0.66))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)

                ZStack(alignment: .bottom) {
                    RoveLuckyWallet(
                        width: walletWidth,
                        candidateCount: candidateCount,
                        layer: .back
                    )
                    .offset(x: walletShakeX, y: walletDismissed ? 250 : 0)
                    .rotationEffect(.degrees(walletShakeAngle), anchor: .bottom)
                    .opacity(walletDismissed ? 0 : 1)
                    .zIndex(1)

                    ForEach(Array(deck.dropFirst().prefix(3).enumerated()), id: \.element.id) { index, pick in
                        RoveLuckyPickTicket(
                            pick: pick,
                            width: ticketWidth * 0.84,
                            heroNamespace: nil
                        )
                        .scaleEffect(0.91 - CGFloat(index) * 0.035)
                        .rotationEffect(.degrees(Double(index - 1) * 4.2))
                        .offset(
                            x: CGFloat(index - 1) * 18 + walletShakeX,
                            y: -102 - CGFloat(index) * 8 + (walletDismissed ? 280 : 0)
                        )
                        .rotationEffect(.degrees(walletShakeAngle), anchor: .bottom)
                        .opacity(walletDismissed ? 0 : 0.94 - Double(index) * 0.16)
                        .zIndex(2 + Double(index) * 0.1)
                    }

                    Button {
                        openSelection()
                    } label: {
                        RoveLuckyPickTicket(
                            pick: selection,
                            width: ticketWidth,
                            heroNamespace: heroNamespace
                        )
                    }
                    .buttonStyle(RoveMotionButtonStyle())
                    .scaleEffect(ticketVisible ? 1 : 0.88)
                    .rotationEffect(.degrees(ticketVisible ? 0 : -4))
                    .offset(y: ticketVisible ? -292 : -72)
                    .opacity(walletVisible ? 1 : 0)
                    .zIndex(4)
                    .disabled(!ticketVisible || isOpening)
                    .accessibilityLabel("查看\(selection.title)详情")

                    RoveLuckyWallet(
                        width: walletWidth,
                        candidateCount: candidateCount,
                        layer: .pocket
                    )
                    .offset(x: walletShakeX, y: walletDismissed ? 250 : 0)
                    .rotationEffect(.degrees(walletShakeAngle), anchor: .bottom)
                    .opacity(walletDismissed ? 0 : 1)
                    .zIndex(5)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 420, alignment: .bottom)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom + 72, 104))
                .offset(y: walletVisible ? 0 : 260)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .task {
            if reduceMotion {
                walletVisible = true
                ticketVisible = true
                walletDismissed = true
                return
            }
            await Task.yield()
            withAnimation(.spring(response: 0.52, dampingFraction: 0.74)) {
                walletVisible = true
            }
            try? await Task.sleep(for: .milliseconds(430))
            guard !Task.isCancelled else { return }
            await shakeWallet()
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.spring(response: 0.66, dampingFraction: 0.68)) {
                ticketVisible = true
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.82)
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.54, dampingFraction: 0.86)) {
                walletDismissed = true
            }
        }
    }

    @MainActor
    private func shakeWallet() async {
        let frames: [(CGFloat, Double)] = [(-10, -1.8), (9, 1.5), (-7, -1.1), (5, 0.7), (0, 0)]
        for (offset, angle) in frames {
            withAnimation(.easeInOut(duration: 0.075)) {
                walletShakeX = offset
                walletShakeAngle = angle
            }
            UISelectionFeedbackGenerator().selectionChanged()
            try? await Task.sleep(for: .milliseconds(75))
            guard !Task.isCancelled else { return }
        }
    }

    private func openSelection() {
        guard !isOpening else { return }
        isOpening = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.88)
        onOpen(selection)
    }
}

private struct RoveMediaCollectionDropDelegate: DropDelegate {
    let targetID: String
    @Binding var sections: [RoveServerHomeSection]
    @Binding var draggedID: String?
    let configurationID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggedID,
              draggedID != targetID,
              let sourceIndex = sections.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = sections.firstIndex(where: { $0.id == targetID }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            sections.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
            )
        }
        RoveServerHomeSectionStore.save(sections, configurationID: configurationID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}

private struct RoveMediaCollectionsBrowseOverlay: View {
    let collections: [RoveHomeMediaCollection]
    let onClose: () -> Void
    let onSelect: (RoveHomeMediaCollection) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Keep the home artwork visible through the dimmed backdrop so
                // the sheet reads as a native frosted-glass presentation.
                Rectangle()
                    .fill(Color.black.opacity(0.18))
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)

                VStack(spacing: 0) {
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 22, weight: .bold))
                                .frame(width: 52, height: 52)
                                .background(.regularMaterial, in: Circle())
                                .overlay {
                                    Circle().stroke(.white.opacity(0.22), lineWidth: 0.8)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("关闭我的媒体")

                        Spacer()
                        Text("我的媒体")
                            .font(.title2.weight(.heavy))
                        Spacer()

                        Color.clear.frame(width: 52, height: 52)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 10)

                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)
                            ],
                            spacing: 20
                        ) {
                            ForEach(collections) { item in
                                Button {
                                    onSelect(item)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        EmbyCollectionCard(
                                            configurationID: item.configurationID,
                                            collection: item.collection,
                                            width: max(130, (geometry.size.width - 68) / 2),
                                            displaysPosterStrip: item.displaysPosterStrip
                                        )
                                        Text(item.collection.name)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .frame(height: min(geometry.size.height * 0.86, 760))
                .roveLiquidGlass(in: UnevenRoundedRectangle(
                    topLeadingRadius: 28,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 28,
                    style: .continuous
                ))
                .shadow(color: .black.opacity(0.28), radius: 28, y: -8)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

private struct RoveSourceCardDropDelegate: DropDelegate {
    let targetID: String
    @Binding var order: [String]
    @Binding var draggedID: String?

    func dropEntered(info: DropInfo) {
        guard let draggedID,
              draggedID != targetID,
              let sourceIndex = order.firstIndex(of: draggedID),
              let targetIndex = order.firstIndex(of: targetID) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            order.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
            )
        }
        RoveSourceCardOrderStore.save(order)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        RoveSourceCardOrderStore.save(order)
        return true
    }

    func dropExited(info: DropInfo) {
        RoveSourceCardOrderStore.save(order)
    }
}

private struct RoveServerContinueWatchingCard: View {
    let item: MetadataContinueItem
    @State private var artwork: UIImage?

    private var displayedArtwork: UIImage? {
        artwork ?? ChannelArtworkLoader.shared.cachedLandscapeImage(
            for: item.channel,
            maxWidth: 600
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.white.opacity(0.08)

                if let displayedArtwork {
                    Image(uiImage: displayedArtwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 113)
                        .clipped()
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 200, height: 113)
            .clipped()
            .overlay {
                Circle()
                    .fill(.black.opacity(0.38))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Circle().stroke(.white, lineWidth: 2)
                    }
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                    }
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 8) {
                    ProgressView(value: item.progress)
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                    Text("\(durationText(item.positionSeconds)) / \(durationText(item.durationSeconds))")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .fixedSize()
                }
                .padding(10)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(item.channel.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            if let year = item.channel.productionYear {
                Text(String(year))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .frame(width: 200, alignment: .leading)
        .task(id: item.id) {
            artwork = await ChannelArtworkLoader.shared.landscapeImage(
                for: item.channel,
                maxWidth: 600
            )
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        let hours = value / 3_600
        let minutes = (value % 3_600) / 60
        let remainingSeconds = value % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

@MainActor
private final class TMDBArtworkLoader {
    static let shared = TMDBArtworkLoader()

    private let memory = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private let session: URLSession
    private var activeDownloads = 0
    private var downloadWaiters: [CheckedContinuation<Void, Never>] = []
    private let maximumConcurrentDownloads = 4

    private init() {
        memory.countLimit = 180
        memory.totalCostLimit = 72 * 1_024 * 1_024
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 8 * 1_024 * 1_024, diskCapacity: 64 * 1_024 * 1_024)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 18
        configuration.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: configuration)
    }

    func image(for url: URL?) async -> UIImage? {
        guard let url else { return nil }
        let key = url.absoluteString
        if let cached = memory.object(forKey: key as NSString) { return cached }
        if let task = inFlight[key] { return await task.value }
        if url.host == "themdjhub.org",
           let bundledURL = Bundle.main.url(
               forResource: url.lastPathComponent,
               withExtension: nil,
               subdirectory: "DJHUBPosters"
           ),
           let bundled = UIImage(contentsOfFile: bundledURL.path) {
            let prepared = bundled.preparingForDisplay() ?? bundled
            memory.setObject(prepared, forKey: key as NSString)
            return prepared
        }
        if let disk = await readDisk(key: key) {
            memory.setObject(disk, forKey: key as NSString)
            return disk
        }

        let task = Task<UIImage?, Never> {
            await self.acquireDownloadSlot()
            defer { self.releaseDownloadSlot() }
            guard let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false else {
                return nil
            }
            let diskURL = self.diskURL(key: key)
            return await Task.detached(priority: .utility) {
                try? FileManager.default.createDirectory(
                    at: diskURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? data.write(to: diskURL, options: .atomic)
                let image = UIImage(data: data)
                return image?.preparingForDisplay() ?? image
            }.value
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { memory.setObject(image, forKey: key as NSString) }
        return image
    }

    private func acquireDownloadSlot() async {
        if activeDownloads < maximumConcurrentDownloads {
            activeDownloads += 1
            return
        }
        await withCheckedContinuation { continuation in
            downloadWaiters.append(continuation)
        }
    }

    private func releaseDownloadSlot() {
        if downloadWaiters.isEmpty {
            activeDownloads = max(0, activeDownloads - 1)
        } else {
            downloadWaiters.removeFirst().resume()
        }
    }

    func cachedImage(for url: URL?) -> UIImage? {
        guard let url else { return nil }
        return memory.object(forKey: url.absoluteString as NSString)
    }

    private func diskURL(key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TuboTMDBArtwork", isDirectory: true)
            .appendingPathComponent(digest + ".image", isDirectory: false)
    }

    private func readDisk(key: String) async -> UIImage? {
        let url = diskURL(key: key)
        let data = await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value
        return await Task.detached(priority: .utility) {
            guard let image = data.flatMap(UIImage.init(data:)) else { return nil }
            return image.preparingForDisplay() ?? image
        }.value
    }

    private func writeDisk(_ data: Data, key: String) async {
        let url = diskURL(key: key)
        await Task.detached(priority: .utility) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }.value
    }
}

#if !DJHUB_METADATA_ONLY
private struct RoveLocalHomeView: View {
    @EnvironmentObject private var playback: PlaybackCoordinator
    @StateObject private var library = LocalVideoLibrary.shared
    let onAddSource: () -> Void
    let onShowSaved: (RoveSavedFilter) -> Void

    @State private var query = ""
    @State private var selectedChannel: Channel?
    @State private var selectedFolderID: UUID?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @State private var showingImportOptions = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var isSelecting = false
    @State private var selectedVideoIDs = Set<UUID>()
    @State private var showingDeleteConfirmation = false
    @State private var lockedFolderID: UUID?
    @State private var unlockPassword = ""
    @State private var showingUnlockPrompt = false
    @State private var passwordFolderID: UUID?
    @State private var folderPassword = ""
    @State private var showingPasswordPrompt = false
    @State private var pendingBiometricFolderID: UUID?
    @State private var showingNewFolderPrompt = false
    @State private var newFolderName = ""
    @State private var sort = Sort.name
    @State private var extensionFilter: String?
    @AppStorage("rove.local-home.layout.v2") private var layoutRawValue = Layout.grid.rawValue

    private enum Layout: String { case list, grid, large }
    private enum Sort: String, CaseIterable {
        case name, size, date
        var title: String {
            switch self {
            case .name: "名称"
            case .size: "大小"
            case .date: "日期"
            }
        }
    }

    private var videos: [LocalVideo] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = library.videos(in: selectedFolderID).filter { video in
            (text.isEmpty || video.name.localizedCaseInsensitiveContains(text))
                && (extensionFilter == nil || fileExtension(video) == extensionFilter)
        }
        switch sort {
        case .name:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size:
            return filtered.sorted { $0.fileSize > $1.fileSize }
        case .date:
            return filtered.sorted { $0.importedAt > $1.importedAt }
        }
    }

    private var folders: [LocalVideoFolder] {
        guard selectedFolderID == nil else { return [] }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return library.folders
            .filter { text.isEmpty || $0.name.localizedCaseInsensitiveContains(text) }
            .sorted { lhs, rhs in
                switch sort {
                case .date: lhs.createdAt > rhs.createdAt
                case .name, .size: lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            }
    }

    private var selectedFolder: LocalVideoFolder? {
        selectedFolderID.flatMap(library.folder(withID:))
    }

    private var selectedLayout: Layout {
        Layout(rawValue: layoutRawValue) ?? .grid
    }

    private var availableExtensions: [String] {
        Array(Set(library.videos.map(fileExtension).filter { !$0.isEmpty })).sorted()
    }

    private func fileExtension(_ video: LocalVideo) -> String {
        URL(fileURLWithPath: video.fileName).pathExtension.lowercased()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                topBar

                if selectedFolder == nil {
                    Text("本地")
                        .font(.system(size: 36, weight: .black))
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                    TextField("搜索", text: $query)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 17)
                .frame(height: 40)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                if videos.isEmpty, folders.isEmpty {
                    ContentUnavailableView {
                        Label(query.isEmpty ? "还没有本地视频" : "没有搜索结果", systemImage: "film.stack")
                    } description: {
                        Text(query.isEmpty ? "从相册、文件或 U 盘导入视频。" : "请尝试其他名称或文件类型。")
                    } actions: {
                        if query.isEmpty {
                            Button("导入视频") { showingImportOptions = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 330)
                } else if selectedLayout == .list {
                    LazyVStack(spacing: 12) {
                        ForEach(folders) { folder in
                            localFolderListRow(folder)
                        }
                        ForEach(videos) { video in
                            localVideoListRow(video)
                        }
                    }
                } else {
                    LazyVGrid(
                        columns: selectedLayout == .large
                            ? [GridItem(.flexible())]
                            : [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                        spacing: 16
                    ) {
                        ForEach(folders) { folder in
                            localFolderCard(folder)
                        }
                        ForEach(videos) { video in localGridCard(video) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemBackground))
        .fullScreenCover(item: $selectedChannel) { channel in
            PlayerDetailView(channel: channel)
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: nil,
            matching: .videos,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        )
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImporter(result)
        }
        .popover(
            isPresented: $showingImportOptions,
            attachmentAnchor: .point(.center),
            arrowEdge: .top
        ) {
            importOptionsPopover
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
        .overlay {
            if isImporting || library.isImporting {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                    ProgressView("正在导入视频…")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
        .alert("新建文件夹", isPresented: $showingNewFolderPrompt) {
            TextField("文件夹名称", text: $newFolderName)
            Button("取消", role: .cancel) {}
            Button("创建") {
                _ = library.createFolder(name: newFolderName)
            }
        }
        .alert("导入失败", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .alert("解锁文件夹", isPresented: $showingUnlockPrompt) {
            SecureField("文件夹密码", text: $unlockPassword)
            Button("取消", role: .cancel) {
                lockedFolderID = nil
                pendingBiometricFolderID = nil
                unlockPassword = ""
            }
            Button("解锁") { unlockFolder() }
        } message: {
            Text("请输入此文件夹的密码。")
        }
        .alert("设置访问密码", isPresented: $showingPasswordPrompt) {
            SecureField("文件夹密码", text: $folderPassword)
            Button("取消", role: .cancel) {
                passwordFolderID = nil
                folderPassword = ""
            }
            Button("保存") { saveFolderPassword() }
                .disabled(folderPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("密码用于保护此文件夹，也可在设置密码后启用面容 ID。")
        }
        .confirmationDialog(
            "删除选中的本地视频？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) { deleteSelectedVideos() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已本地保存的视频会释放空间；从文件导入的条目不会删除原文件。")
        }
    }

    private var topBar: some View {
        ZStack {
            if isSelecting {
                Text("已选择 \(selectedVideoIDs.count) 项")
                    .font(.headline.weight(.bold))
            } else if let selectedFolder {
                Text(selectedFolder.name)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .padding(.horizontal, 104)
            }
            HStack {
                Button {
                    if isSelecting {
                        isSelecting = false
                        selectedVideoIDs.removeAll()
                    } else if let folderID = selectedFolderID {
                        library.lockFolder(folderID)
                        selectedFolderID = nil
                        query = ""
                    } else {
                        onAddSource()
                    }
                } label: {
                    Image(systemName: isSelecting ? "xmark" : (selectedFolderID == nil ? "sidebar.left" : "chevron.left"))
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelecting ? "取消选择" : (selectedFolderID == nil ? "资源库" : "返回"))

                Spacer()

                if isSelecting {
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedVideoIDs.isEmpty ? Color.secondary : Color.red)
                    .disabled(selectedVideoIDs.isEmpty)
                    .accessibilityLabel("删除所选视频")
                } else {
                    HStack(spacing: 1) {
                    Button { showingImportOptions = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("导入视频")

                    Button { playAll() } label: {
                        Image(systemName: "play.circle")
                    }
                    .disabled(videos.isEmpty)
                    .accessibilityLabel("播放全部")

                    Menu {
                        Button("选择", systemImage: "checkmark.circle") {
                            isSelecting = true
                            selectedVideoIDs.removeAll()
                        }
                        if selectedFolderID == nil {
                            Button("新建文件夹", systemImage: "folder.badge.plus") {
                                newFolderName = ""
                                showingNewFolderPrompt = true
                            }
                        } else if let selectedFolder {
                            Divider()
                            folderSecurityActions(selectedFolder)
                        }
                        Divider()
                        layoutButton(.list, title: "列表", icon: "list.bullet")
                        layoutButton(.grid, title: "网格", icon: "square.grid.2x2")
                        layoutButton(.large, title: "大图", icon: "rectangle")
                        Divider()
                        ForEach(Sort.allCases, id: \.self) { value in
                            Button {
                                sort = value
                            } label: {
                                Label(value.title, systemImage: sort == value ? "checkmark" : sortIcon(value))
                            }
                        }
                        Menu("类型筛选") {
                            Button {
                                extensionFilter = nil
                            } label: {
                                Label("全部", systemImage: extensionFilter == nil ? "checkmark" : "film")
                            }
                            ForEach(availableExtensions, id: \.self) { value in
                                Button {
                                    extensionFilter = value
                                } label: {
                                    Label(value.uppercased(), systemImage: extensionFilter == value ? "checkmark" : "film")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("更多")
                }
                .font(.system(size: 20, weight: .semibold))
                .buttonStyle(.plain)
                .frame(height: 40)
                .padding(.horizontal, 10)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.primary.opacity(0.08)))
                }
            }
        }
        .frame(height: 44)
    }

    private func localFolderCard(_ folder: LocalVideoFolder) -> some View {
        Button {
            openFolder(folder)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)
                    Image(systemName: folder.isProtected ? "folder.fill.badge.person.crop" : "folder.fill")
                        .font(.system(size: 45, weight: .medium))
                        .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.08))
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(folder.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("打开", systemImage: "folder") {
                openFolder(folder)
            }
            folderSecurityActions(folder)
            Button("删除文件夹", systemImage: "trash", role: .destructive) {
                library.deleteFolder(folder.id)
                playback.updateQueue(library.channels)
            }
        }
    }

    private func localFolderListRow(_ folder: LocalVideoFolder) -> some View {
        Button {
            openFolder(folder)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: folder.isProtected ? "folder.fill.badge.person.crop" : "folder.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.08))
                    .frame(width: 76, height: 58)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(library.videos(in: folder.id).count) 个视频")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("打开", systemImage: "folder") {
                openFolder(folder)
            }
            folderSecurityActions(folder)
            Button("删除文件夹", systemImage: "trash", role: .destructive) {
                library.deleteFolder(folder.id)
                playback.updateQueue(library.channels)
            }
        }
    }

    private func localVideoListRow(_ video: LocalVideo) -> some View {
        Button { selectOrPlay(video) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoveLocalVideoThumbnail(video: video, library: library)
                    RoveLocalVideoBadgeOverlay(video: video, library: library)
                }
                .frame(width: 116, height: 65)
                VStack(alignment: .leading, spacing: 5) {
                    Text(video.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    RoveLocalVideoFacts(video: video, library: library)
                }
                Spacer(minLength: 0)
                if isSelecting {
                    Image(systemName: selectedVideoIDs.contains(video.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selectedVideoIDs.contains(video.id) ? Color.accentColor : Color.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { deleteVideoButton(video) }
    }

    private func localGridCard(_ video: LocalVideo) -> some View {
        Button { selectOrPlay(video) } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack {
                    RoveLocalVideoThumbnail(video: video, library: library)
                    RoveLocalVideoBadgeOverlay(video: video, library: library)
                    if isSelecting {
                        Image(systemName: selectedVideoIDs.contains(video.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                selectedVideoIDs.contains(video.id) ? Color.accentColor : Color.white,
                                Color.black.opacity(0.34)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(7)
                    }
                }
                .aspectRatio(CGSize(width: 16, height: 9), contentMode: .fit)
                Text(video.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contextMenu {
            deleteVideoButton(video)
        }
    }

    private var importOptionsPopover: some View {
        VStack(spacing: 12) {
            Text("导入视频")
                .font(.headline)

            Button {
                showingImportOptions = false
                DispatchQueue.main.async { showingPhotoPicker = true }
            } label: {
                Label("从相册选择", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showingImportOptions = false
                DispatchQueue.main.async { showingFilePicker = true }
            } label: {
                Label("从文件导入", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("取消") { showingImportOptions = false }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 280)
    }

    private func openFolder(_ folder: LocalVideoFolder) {
        guard folder.isProtected, !library.isFolderUnlocked(folder.id) else {
            selectedFolderID = folder.id
            query = ""
            return
        }
        if folder.biometricEnabled {
            authenticateFolderWithBiometrics(folder)
            return
        }
        lockedFolderID = folder.id
        unlockPassword = ""
        showingUnlockPrompt = true
    }

    private func unlockFolder() {
        guard let folderID = lockedFolderID else { return }
        if library.unlockFolder(folderID, password: unlockPassword) {
            let shouldEnableBiometrics = pendingBiometricFolderID == folderID
            lockedFolderID = nil
            pendingBiometricFolderID = nil
            unlockPassword = ""
            showingUnlockPrompt = false
            if shouldEnableBiometrics, let folder = library.folder(withID: folderID) {
                enableBiometricUnlock(for: folder)
            } else {
                selectedFolderID = folderID
            }
        } else {
            unlockPassword = ""
            importError = "文件夹密码不正确。"
        }
    }

    @ViewBuilder
    private func folderSecurityActions(_ folder: LocalVideoFolder) -> some View {
        if !folder.isProtected || library.isFolderUnlocked(folder.id) {
            Button(folder.isProtected ? "更改密码" : "设置密码", systemImage: "lock") {
                passwordFolderID = folder.id
                folderPassword = ""
                showingPasswordPrompt = true
            }
            if folder.isProtected {
                Button("移除密码", systemImage: "lock.open") {
                    library.setFolderPassword(folder.id, password: nil)
                }
                Button(folder.biometricEnabled ? "关闭面容解锁" : "启用面容解锁", systemImage: "faceid") {
                    if folder.biometricEnabled {
                        library.setFolderBiometricEnabled(folder.id, enabled: false)
                    } else {
                        enableBiometricUnlock(for: folder)
                    }
                }
            }
        } else {
            Button("输入密码后管理", systemImage: "lock.fill") {
                openFolder(folder)
            }
            Button(folder.biometricEnabled ? "关闭面容解锁" : "启用面容解锁", systemImage: "faceid") {
                if folder.biometricEnabled {
                    library.setFolderBiometricEnabled(folder.id, enabled: false)
                } else {
                    pendingBiometricFolderID = folder.id
                    lockedFolderID = folder.id
                    unlockPassword = ""
                    showingUnlockPrompt = true
                }
            }
        }
    }

    private func saveFolderPassword() {
        guard let folderID = passwordFolderID else { return }
        library.setFolderPassword(folderID, password: folderPassword)
        if selectedFolderID == folderID {
            selectedFolderID = nil
            query = ""
        }
        passwordFolderID = nil
        folderPassword = ""
        showingPasswordPrompt = false
    }

    private func enableBiometricUnlock(for folder: LocalVideoFolder) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            importError = error?.localizedDescription ?? "此设备暂不支持面容解锁。"
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "使用面容解锁此文件夹"
        ) { success, _ in
            Task { @MainActor in
                if success {
                    library.setFolderBiometricEnabled(folder.id, enabled: true)
                }
            }
        }
    }

    private func authenticateFolderWithBiometrics(_ folder: LocalVideoFolder) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            lockedFolderID = folder.id
            unlockPassword = ""
            showingUnlockPrompt = true
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "解锁文件夹"
        ) { success, _ in
            Task { @MainActor in
                if success {
                    _ = library.unlockFolderUsingBiometrics(folder.id)
                    selectedFolderID = folder.id
                    query = ""
                } else {
                    lockedFolderID = folder.id
                    unlockPassword = ""
                    showingUnlockPrompt = true
                }
            }
        }
    }

    private func selectOrPlay(_ video: LocalVideo) {
        if isSelecting {
            if selectedVideoIDs.contains(video.id) {
                selectedVideoIDs.remove(video.id)
            } else {
                selectedVideoIDs.insert(video.id)
            }
        } else {
            play(video)
        }
    }

    @ViewBuilder
    private func deleteVideoButton(_ video: LocalVideo) -> some View {
        Button(role: .destructive) {
            library.delete(video)
            selectedVideoIDs.remove(video.id)
            playback.updateQueue(library.channels)
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private func deleteSelectedVideos() {
        let selected = library.videos.filter { selectedVideoIDs.contains($0.id) }
        selected.forEach(library.delete)
        selectedVideoIDs.removeAll()
        isSelecting = false
        playback.updateQueue(library.channels)
    }

    private func handleFileImporter(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard !urls.isEmpty else { return }
            Task {
                isImporting = true
                defer { isImporting = false }
                do {
                    let count = try await library.addExternalFiles(urls, folderID: selectedFolderID)
                    playback.updateQueue(library.channels)
                    if count == 0 { importError = "没有找到可播放的视频文件。" }
                } catch {
                    importError = error.localizedDescription
                }
            }
        case let .failure(error):
            if (error as NSError).code != NSUserCancelledError {
                importError = error.localizedDescription
            }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        isImporting = true
        defer {
            isImporting = false
            selectedPhotoItems = []
            playback.updateQueue(library.channels)
        }
        var failures: [String] = []
        for (index, item) in items.enumerated() {
            do {
                guard let imported = try await item.loadTransferable(type: RoveImportedPhotoVideo.self) else {
                    throw LocalVideoImportError.photoUnavailable
                }
                defer { try? FileManager.default.removeItem(at: imported.url) }
                try await library.importVideo(
                    from: imported.url,
                    suggestedName: imported.suggestedName ?? "相册视频 \(index + 1)",
                    folderID: selectedFolderID
                )
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        if !failures.isEmpty {
            importError = failures.prefix(3).joined(separator: "\n")
        }
    }

    private func sortIcon(_ value: Sort) -> String {
        switch value {
        case .name: "arrow.up"
        case .size: "internaldrive"
        case .date: "calendar"
        }
    }

    @ViewBuilder
    private func layoutButton(_ value: Layout, title: String, icon: String) -> some View {
        Button {
            layoutRawValue = value.rawValue
        } label: {
            Label(title, systemImage: selectedLayout == value ? "checkmark" : icon)
        }
    }

    private func playAll() {
        guard let first = videos.first else { return }
        play(first)
    }

    private func play(_ video: LocalVideo) {
        guard let channel = library.channel(for: video) else { return }
        playback.updateQueue(videos.compactMap(library.channel(for:)))
        selectedChannel = channel
    }
}

private struct RoveImportedPhotoVideo: Transferable, Sendable {
    let url: URL
    let suggestedName: String?

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { value in
            SentTransferredFile(value.url)
        } importing: { received in
            let manager = FileManager.default
            let directory = manager.temporaryDirectory.appendingPathComponent(
                "RovePhotoImports",
                isDirectory: true
            )
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let pathExtension = received.file.pathExtension.isEmpty
                ? "mp4"
                : received.file.pathExtension.lowercased()
            let destination = directory.appendingPathComponent(
                "\(UUID().uuidString).\(pathExtension)"
            )
            try manager.copyItem(at: received.file, to: destination)
            return RoveImportedPhotoVideo(
                url: destination,
                suggestedName: received.file.deletingPathExtension().lastPathComponent
            )
        }
    }
}

private struct RoveLocalVideoBadgeOverlay: View {
    let video: LocalVideo
    let library: LocalVideoLibrary
    @State private var quality = ""
    @State private var duration = ""

    private var isNew: Bool {
        video.importedAt >= Date().addingTimeInterval(-14 * 24 * 60 * 60)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.clear, .black.opacity(0.38)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack {
                HStack(alignment: .top) {
                    if isNew {
                        Text("NEW")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(Color.pink, in: Capsule())
                    }
                    Spacer()
                    if !quality.isEmpty {
                        Text(quality)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }
                Spacer()
                HStack(alignment: .bottom) {
                    Text(duration)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: video.fileSize, countStyle: .file))
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 2)
            }
            .padding(7)
        }
        .allowsHitTesting(false)
        .task(id: video.id) { await loadMetadata() }
    }

    private func loadMetadata() async {
        guard let url = library.channel(for: video)?.streamURL else { return }
        let asset = AVURLAsset(url: url)
        async let loadedDuration = try? asset.load(.duration)
        async let loadedTrack = try? asset.loadTracks(withMediaType: .video).first
        let (mediaDuration, track) = await (loadedDuration, loadedTrack)

        if let mediaDuration, mediaDuration.isNumeric {
            let seconds = max(0, Int(mediaDuration.seconds.rounded()))
            duration = seconds >= 3600
                ? String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
                : String(format: "%02d:%02d", seconds / 60, seconds % 60)
        }
        guard let track else { return }
        let naturalSize = try? await track.load(.naturalSize)
        let transform = try? await track.load(.preferredTransform)
        let frameRate = try? await track.load(.nominalFrameRate)
        var values: [String] = []
        if let naturalSize {
            let renderedSize = naturalSize.applying(transform ?? .identity)
            let verticalPixels = Int(min(abs(renderedSize.width), abs(renderedSize.height)).rounded())
            if verticalPixels > 0 { values.append("\(verticalPixels)P") }
        }
        if let frameRate, frameRate > 0 {
            values.append("\(Int(frameRate.rounded()))FPS")
        }
        quality = values.joined(separator: " ")
    }
}

private struct RoveLocalVideoThumbnail: View {
    let video: LocalVideo
    let library: LocalVideoLibrary
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    Image(systemName: "film.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .task(id: video.id) {
            image = library.thumbnailImage(for: video)
            if image == nil {
                await library.ensureThumbnail(for: video)
                image = library.thumbnailImage(for: video)
            }
        }
    }
}

private struct RoveLocalVideoFacts: View {
    let video: LocalVideo
    let library: LocalVideoLibrary
    var compact = false
    @State private var facts: String?

    var body: some View {
        Text(facts ?? fallback)
            .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .task(id: video.id) { await loadFacts() }
    }

    private var fallback: String {
        "\(URL(fileURLWithPath: video.fileName).pathExtension.uppercased()) · \(ByteCountFormatter.string(fromByteCount: video.fileSize, countStyle: .file))"
    }

    private func loadFacts() async {
        guard let url = library.channel(for: video)?.streamURL else { return }
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        let track = try? await asset.loadTracks(withMediaType: .video).first
        let naturalSize = try? await track?.load(.naturalSize)
        let transform = try? await track?.load(.preferredTransform)
        let frameRate = try? await track?.load(.nominalFrameRate)

        var values: [String] = []
        if let naturalSize {
            let transformed = naturalSize.applying(transform ?? .identity)
            let width = abs(transformed.width)
            let height = abs(transformed.height)
            let resolution = Int(min(width, height).rounded())
            if resolution > 0 { values.append("\(resolution)P") }
        }
        if let frameRate, frameRate > 0 {
            values.append("\(Int(frameRate.rounded()))FPS")
        }
        if let duration, duration.isNumeric {
            let seconds = max(0, Int(duration.seconds.rounded()))
            values.append(String(format: "%02d:%02d", seconds / 60, seconds % 60))
        }
        values.append(ByteCountFormatter.string(fromByteCount: video.fileSize, countStyle: .file))
        facts = values.joined(separator: " · ")
    }
}
#endif

private struct RoveAutoScrollingPosterRow: UIViewControllerRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let movies: [TMDBFeaturedMovie]
    let posterWidth: CGFloat
    let posterHeight: CGFloat
    let spacing: CGFloat
    let movesLeft: Bool
    let speed: CGFloat
    let transitionIDPrefix: String
    let transitionNamespace: Namespace.ID
    let onSelect: (TMDBFeaturedMovie, AnyHashable) -> Void

    func makeUIViewController(context: Context) -> PosterRowController {
        PosterRowController()
    }

    func updateUIViewController(_ controller: PosterRowController, context: Context) {
        controller.update(
            signature: movies.map(\.identity).joined(separator: "|")
                + "|\(posterWidth)|\(posterHeight)|\(spacing)|\(movesLeft)",
            contentWidth: CGFloat(movies.count) * (posterWidth + spacing),
            height: posterHeight,
            speed: speed,
            movesLeft: movesLeft,
            reduceMotion: reduceMotion,
            content: AnyView(rowContent)
        )
    }

    static func dismantleUIViewController(_ controller: PosterRowController, coordinator: ()) {
        controller.tearDown()
    }

    @ViewBuilder
    private var rowContent: some View {
        if movies.isEmpty {
            HStack(spacing: spacing) {
                ForEach(0..<5, id: \.self) { _ in
                    RoveArtworkSkeleton()
                        .frame(width: posterWidth, height: posterHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(0..<2, id: \.self) { copyIndex in
                    HStack(spacing: spacing) {
                        ForEach(movies, id: \.identity) { movie in
                            let transitionID = "\(transitionIDPrefix)-copy-\(copyIndex)-\(movie.identity)"
                            Button { onSelect(movie, transitionID) } label: {
                                TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                                    .frame(width: posterWidth, height: posterHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                                    .roveHeroTransitionSource(
                                        id: transitionID,
                                        namespace: transitionNamespace
                                    )
                            }
                            .buttonStyle(RoveMotionButtonStyle())
                        }
                    }
                    .padding(.trailing, spacing)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    @MainActor
    final class PosterRowController: UIViewController, UIScrollViewDelegate {
        private let scrollView = UIScrollView()
        private let host = UIHostingController(rootView: AnyView(Color.clear))
        private var displayLink: CADisplayLink?
        private var contentWidth: CGFloat = 0
        private var contentHeight: CGFloat = 0
        private var speed: CGFloat = 0
        private var movesLeft = true
        private var reduceMotion = false
        private var signature = ""
        private var lastTimestamp: CFTimeInterval = 0
        private var needsInitialPosition = true

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            scrollView.backgroundColor = .clear
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.alwaysBounceHorizontal = false
            scrollView.alwaysBounceVertical = false
            scrollView.bounces = false
            scrollView.decelerationRate = .fast
            scrollView.delegate = self
            scrollView.clipsToBounds = true
            view.addSubview(scrollView)

            host.view.backgroundColor = .clear
            addChild(host)
            scrollView.addSubview(host.view)
            host.didMove(toParent: self)

            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 20,
                maximum: 60,
                preferred: 30
            )
            link.add(to: .main, forMode: .common)
            link.isPaused = true
            displayLink = link
        }

        func tearDown() {
            displayLink?.invalidate()
            displayLink = nil
            scrollView.delegate = nil
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            scrollView.frame = view.bounds
            host.view.frame = CGRect(
                x: 0,
                y: 0,
                width: max(contentWidth * 2, view.bounds.width),
                height: max(contentHeight, view.bounds.height)
            )
            scrollView.contentSize = host.view.bounds.size
            applyInitialPositionIfNeeded()
            updateAnimationState()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            updateAnimationState()
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            displayLink?.isPaused = true
            lastTimestamp = 0
        }

        func update(
            signature: String,
            contentWidth: CGFloat,
            height: CGFloat,
            speed: CGFloat,
            movesLeft: Bool,
            reduceMotion: Bool,
            content: AnyView
        ) {
            let contentChanged = self.signature != signature
            let directionChanged = self.movesLeft != movesLeft
            self.contentWidth = contentWidth
            contentHeight = height
            self.speed = max(0, speed)
            self.movesLeft = movesLeft
            self.reduceMotion = reduceMotion
            if contentChanged {
                self.signature = signature
                host.rootView = content
                needsInitialPosition = true
            } else if directionChanged {
                needsInitialPosition = true
            }
            view.setNeedsLayout()
            updateAnimationState()
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            displayLink?.isPaused = true
            lastTimestamp = 0
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { normalizeOffsetAndResume() }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            normalizeOffsetAndResume()
        }

        @objc private func step(_ link: CADisplayLink) {
            guard contentWidth > 0, !scrollView.isTracking, !scrollView.isDecelerating else {
                lastTimestamp = 0
                return
            }
            guard lastTimestamp > 0 else {
                lastTimestamp = link.timestamp
                return
            }
            let delta = min(link.timestamp - lastTimestamp, 1.0 / 15.0)
            lastTimestamp = link.timestamp
            var x = scrollView.contentOffset.x
                + (movesLeft ? 1 : -1) * speed * CGFloat(delta)
            if x >= contentWidth { x -= contentWidth }
            if x < 0 { x += contentWidth }
            scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: false)
        }

        private func applyInitialPositionIfNeeded() {
            guard needsInitialPosition, contentWidth > 0 else { return }
            needsInitialPosition = false
            scrollView.setContentOffset(
                CGPoint(x: movesLeft || reduceMotion ? 0 : contentWidth, y: 0),
                animated: false
            )
        }

        private func normalizeOffsetAndResume() {
            guard contentWidth > 0 else { return }
            var x = scrollView.contentOffset.x.truncatingRemainder(dividingBy: contentWidth)
            if x < 0 { x += contentWidth }
            scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: false)
            updateAnimationState()
        }

        private func updateAnimationState() {
            let shouldAnimate = view.window != nil
                && !reduceMotion
                && contentWidth > 0
                && speed > 0
                && !scrollView.isTracking
                && !scrollView.isDecelerating
            displayLink?.isPaused = !shouldAnimate
            if !shouldAnimate { lastTimestamp = 0 }
        }
    }
}

private struct TMDBRemoteArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let url: URL?
    let title: String
    let contentMode: ContentMode
    @State private var image: UIImage?

    init(url: URL?, title: String, contentMode: ContentMode = .fill) {
        self.url = url
        self.title = title
        self.contentMode = contentMode
    }

    private var displayedImage: UIImage? {
        image ?? TMDBArtworkLoader.shared.cachedImage(for: url)
    }

    var body: some View {
        Group {
            if let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                RoveArtworkSkeleton()
            }
        }
        .clipped()
        .animation(reduceMotion ? nil : RoveMotion.quick, value: displayedImage != nil)
        .task(id: url?.absoluteString) {
            guard image == nil, url != nil else { return }
            image = await TMDBArtworkLoader.shared.image(for: url)
        }
    }

}

private struct RoveArtworkSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoveCoreAnimationShimmer(
            cornerRadius: 0,
            backgroundOpacity: 0.075,
            highlightOpacity: 0.22,
            reduceMotion: reduceMotion
        )
        .accessibilityHidden(true)
    }
}

private enum RoveArtworkPhotoSaver {
    nonisolated static func save(_ data: Data) async throws {}
}

private struct RoveActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ viewController: UIActivityViewController, context: Context) {}
}

private struct RoveArtworkViewerRequest: Identifiable {
    let id = UUID()
    let urls: [URL]
    let titles: [String]
    let initialIndex: Int
}

private struct RoveArtworkViewer: View {
    @Environment(\.dismiss) private var dismiss
    let urls: [URL]
    let titles: [String]
    let initialIndex: Int
    let onSetAsStill: (UIImage) -> Void

    @State private var selectedIndex: Int
    @State private var images: [String: UIImage] = [:]
    @State private var isSharing = false
    @State private var isSaving = false
    @State private var message: String?

    init(
        urls: [URL],
        titles: [String],
        initialIndex: Int,
        onSetAsStill: @escaping (UIImage) -> Void
    ) {
        self.urls = urls
        self.titles = titles
        self.initialIndex = initialIndex
        self.onSetAsStill = onSetAsStill
        _selectedIndex = State(initialValue: initialIndex)
    }

    private var selectedURL: URL? {
        guard urls.indices.contains(selectedIndex) else { return nil }
        return urls[selectedIndex]
    }

    private var selectedImage: UIImage? {
        guard let selectedURL else { return nil }
        return images[selectedURL.absoluteString]
    }

    private var selectedTitle: String {
        guard titles.indices.contains(selectedIndex) else { return "图片" }
        return titles[selectedIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    ZStack {
                        if let image = images[url.absoluteString] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.15)
                        }
                    }
                    .tag(index)
                    .task(id: url.absoluteString) {
                        await loadImage(url)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.bold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("返回")

                    Spacer()

                    Text("\(min(selectedIndex + 1, max(urls.count, 1))) / \(urls.count)")
                        .font(.headline.weight(.semibold))
                        .monospacedDigit()

                    Spacer()

                    Color.clear.frame(width: 44, height: 44)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .background(.black.opacity(0.28))

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        guard selectedImage != nil else {
                            message = "图片仍在加载，请稍后再试。"
                            return
                        }
                        isSharing = true
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    .disabled(selectedImage == nil)

                    Button {
                        saveSelectedImage()
                    } label: {
                        Label(isSaving ? "保存中" : "保存到相册", systemImage: "arrow.down.to.line")
                    }
                    .disabled(selectedImage == nil || isSaving)

                    Button {
                        guard let selectedImage else {
                            message = "图片仍在加载，请稍后再试。"
                            return
                        }
                        onSetAsStill(selectedImage)
                        message = "已设为当前详情页剧照。"
                    } label: {
                        Label("设为剧照", systemImage: "photo.badge.checkmark")
                    }
                    .disabled(selectedImage == nil)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isSharing) {
            if let selectedImage {
                RoveActivityView(items: [selectedImage])
                    .ignoresSafeArea()
            }
        }
        .alert("图片", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func loadImage(_ url: URL) async {
        let key = url.absoluteString
        guard images[key] == nil else { return }
        guard let image = await TMDBArtworkLoader.shared.image(for: url) else { return }
        images[key] = image
    }

    private func saveSelectedImage() {
        message = "DJHUB 不写入系统相册。"
    }
}

private struct RoveHomeManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftBlocks: [RoveHomeBlock]
    @State private var draftSections: [RoveServerHomeSection]
    let onSave: ([RoveHomeBlock], [RoveServerHomeSection]) -> Void

    init(
        blocks: [RoveHomeBlock],
        sections: [RoveServerHomeSection],
        onSave: @escaping ([RoveHomeBlock], [RoveServerHomeSection]) -> Void
    ) {
        _draftBlocks = State(initialValue: blocks)
        _draftSections = State(initialValue: sections)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(draftBlocks) { block in
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: block.kind))
                                .foregroundStyle(Color.roveAccent)
                                .frame(width: 24)
                            TextField("区块标题", text: binding(for: block.id).title)
                            Spacer(minLength: 8)
                            Toggle("显示", isOn: binding(for: block.id).isEnabled)
                                .labelsHidden()
                                .tint(.green)
                        }
                    }
                    .onMove { offsets, destination in
                        draftBlocks.move(fromOffsets: offsets, toOffset: destination)
                    }
                } header: {
                    Text("首页区块")
                } footer: {
                    Text("拖动调整顺序，关闭后该区块不会出现在首页。标题可以按你的习惯修改。")
                }

                Section {
                    Button("恢复默认顺序", systemImage: "arrow.counterclockwise") {
                        let defaultOrder = ["continue-watching", "ai-recommendations", "media-collections"]
                            + draftSections.map { "media-shelf:\($0.id)" }
                        let byID = Dictionary(uniqueKeysWithValues: draftBlocks.map { ($0.id, $0) })
                        draftBlocks = defaultOrder.compactMap { byID[$0] }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("首页管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let orderedShelfIDs = draftBlocks.compactMap { block -> String? in
                            guard block.kind == .mediaShelf else { return nil }
                            return block.id.replacingOccurrences(of: "media-shelf:", with: "")
                        }
                        var updatedSections = draftSections
                        let sectionByID = Dictionary(uniqueKeysWithValues: updatedSections.map { ($0.id, $0) })
                        let reordered = orderedShelfIDs.compactMap { sectionByID[$0] }
                        if !reordered.isEmpty {
                            updatedSections = reordered + updatedSections.filter { section in
                                !reordered.contains(where: { $0.id == section.id })
                            }
                        }
                        onSave(draftBlocks, updatedSections)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func binding(for id: String) -> Binding<RoveHomeBlock> {
        guard let index = draftBlocks.firstIndex(where: { $0.id == id }) else {
            return .constant(RoveHomeBlock(id: id, kind: .mediaShelf, title: "", isEnabled: false))
        }
        return $draftBlocks[index]
    }

    private func icon(for kind: RoveHomeBlock.Kind) -> String {
        switch kind {
        case .continueWatching: "play.circle"
        case .aiRecommendations: "sparkles"
        case .mediaCollections: "rectangle.3.group"
        case .mediaShelf: "film"
        }
    }
}

private struct RoveTMDBShelfGridView: View {
    let shelf: TMDBFeaturedMovie.Shelf
    let movies: [TMDBFeaturedMovie]
    let navigationTitleText: String?
    let isLoadingMore: Bool
    let onLoadMore: (() -> Void)?
    @State private var selectedMovie: TMDBFeaturedMovie?
    @State private var selectedMovieHeroID: AnyHashable?
    @Namespace private var mediaHeroNamespace

    init(
        shelf: TMDBFeaturedMovie.Shelf,
        movies: [TMDBFeaturedMovie],
        navigationTitleText: String? = nil,
        isLoadingMore: Bool = false,
        onLoadMore: (() -> Void)? = nil
    ) {
        self.shelf = shelf
        self.movies = movies
        self.navigationTitleText = navigationTitleText
        self.isLoadingMore = isLoadingMore
        self.onLoadMore = onLoadMore
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 3
    )

    var body: some View {
        ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                    ForEach(Array(movies.enumerated()), id: \.element.identity) { index, movie in
                        let transitionID = "tmdb-\(movie.identity)"
                        Button { openMovie(movie, heroID: transitionID) } label: {
                            RovePosterGridCard(
                                title: movie.title,
                                yearText: movie.year > 0 ? String(movie.year) : "即将上映",
                                rating: movie.displayRating,
                                transitionID: nil,
                                transitionNamespace: nil
                            ) {
                                TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                                    .roveHeroTransitionSource(
                                        id: transitionID,
                                        namespace: mediaHeroNamespace
                                    )
                            }
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                        .onAppear {
                            if index >= max(0, movies.count - 6) {
                                onLoadMore?()
                            }
                        }
                    }

                    if isLoadingMore {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .gridCellColumns(columns.count)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(Color.black)
            .navigationTitle(navigationTitleText ?? shelf.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $selectedMovie) { movie in
                RoveMediaDetailView(recommendation: movie)
                    .roveHeroNavigationTransition(
                        id: selectedMovieHeroID,
                        namespace: mediaHeroNamespace
                    )
            }
            .onChange(of: selectedMovie) { _, movie in
                if movie == nil { selectedMovieHeroID = nil }
            }
    }

    private func openMovie(_ movie: TMDBFeaturedMovie, heroID: AnyHashable) {
        selectedMovieHeroID = heroID
        Task { @MainActor in
            await Task.yield()
            guard selectedMovieHeroID == heroID else { return }
            selectedMovie = movie
        }
    }
}

@MainActor
private final class RoveShortDramaCatalogStore: ObservableObject {
    static let shared = RoveShortDramaCatalogStore()

    @Published private(set) var movies: [TMDBFeaturedMovie] = []
    @Published private(set) var isLoading = false

    func movies(in shelf: TMDBFeaturedMovie.Shelf) -> [TMDBFeaturedMovie] {
        movies.filter { $0.shelves.contains(shelf) }
    }

    func load() async {
        guard !isLoading else { return }
        if movies.isEmpty, let cached = await DJHUBDiscoveryService.cachedMovies(), !cached.isEmpty {
            movies = cached
        }
        guard movies(in: .top200).isEmpty || movies(in: .shortDrama).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        let loaded = await DJHUBDiscoveryService.loadHome()
        if !loaded.isEmpty { movies = loaded }
    }
}

private struct RoveTop200TabView: View {
    @ObservedObject private var catalog = RoveShortDramaCatalogStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if catalog.movies(in: .top200).isEmpty, catalog.isLoading {
                    ProgressView("正在加载 Top 200…")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    RoveTMDBShelfGridView(
                        shelf: .top200,
                        movies: catalog.movies(in: .top200),
                        navigationTitleText: "Top 200"
                    )
                }
            }
        }
        .task { await catalog.load() }
    }
}

private struct RoveLegacyShortDramaCategoriesTab: View {
    @ObservedObject private var catalog = RoveShortDramaCatalogStore.shared

    private let categories: [(TMDBFeaturedMovie.Shelf, String, String)] = [
        (.shortDrama, "热门短剧", "bolt.fill"),
        (.shortRomance, "爱情短剧", "heart.fill"),
        (.shortComedy, "喜剧短剧", "face.smiling.fill"),
        (.shortMystery, "悬疑短剧", "eye.fill"),
        (.shortAction, "动作短剧", "flame.fill"),
        (.top200, "Top 200", "trophy.fill")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 16
                ) {
                    ForEach(categories, id: \.0) { shelf, title, icon in
                        NavigationLink {
                            RoveTMDBShelfGridView(
                                shelf: shelf,
                                movies: catalog.movies(in: shelf),
                                navigationTitleText: title
                            )
                        } label: {
                            categoryCard(shelf: shelf, title: title, icon: icon)
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                    }
                }
                .padding(16)
                .padding(.bottom, 80)
            }
            .background(Color.black)
            .navigationTitle("短剧分类")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await catalog.load() }
    }

    private func categoryCard(
        shelf: TMDBFeaturedMovie.Shelf,
        title: String,
        icon: String
    ) -> some View {
        let posters = Array(catalog.movies(in: shelf).prefix(4))
        return ZStack(alignment: .bottomLeading) {
            HStack(spacing: 2) {
                ForEach(posters, id: \.identity) { movie in
                    TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                }
            }
            .frame(height: 190)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.86)],
                startPoint: .center,
                endPoint: .bottom
            )

            Label(title, systemImage: icon)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .padding(13)
        }
        .frame(height: 190)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.8)
        }
    }
}

private struct RoveShortDramaCategoriesTab: View {
    @State private var taxonomy = DJHUBDiscoveryService.defaultTaxonomy
    @State private var hasRefreshedTaxonomy = false

    private var genres: [TaxonomyItem] {
        taxonomy.genres.filter { $0.name != "综艺" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    categorySection(title: "内容形态", items: taxonomy.contentTypes, isGenre: false)
                    categorySection(title: "题材分类", items: genres, isGenre: true)
                }
                .padding(.vertical, 18)
                .padding(.bottom, 80)
            }
            .background(Color.black)
            .navigationTitle("短剧分类")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            guard !hasRefreshedTaxonomy else { return }
            hasRefreshedTaxonomy = true
            if let refreshed = await DJHUBDiscoveryService.taxonomy() {
                taxonomy = refreshed
            }
        }
    }

    private func categorySection(
        title: String,
        items: [TaxonomyItem],
        isGenre: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(items) { item in
                    NavigationLink {
                        RoveDJHUBCategoryResultsView(
                            title: item.name,
                            genre: isGenre ? item.name : nil,
                            contentType: isGenre ? nil : item.id
                        )
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: isGenre ? "theatermasks.fill" : "rectangle.stack.fill")
                                .foregroundStyle(Color.roveAccent)
                            Text(item.name)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(.white.opacity(0.12), lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(RoveMotionButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct RoveDJHUBCategoryResultsView: View {
    let title: String
    let genre: String?
    let contentType: String?
    @State private var movies: [TMDBFeaturedMovie] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = 0
    @State private var hasMore = true

    var body: some View {
        Group {
            if isLoading && movies.isEmpty {
                ProgressView("正在加载 \(title)…")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                RoveTMDBShelfGridView(
                    shelf: .shortDrama,
                    movies: movies,
                    navigationTitleText: title,
                    isLoadingMore: isLoadingMore,
                    onLoadMore: {
                        Task { await loadNextPage() }
                    }
                )
            }
        }
        .task {
            guard currentPage == 0 else { return }
            let cached = await DJHUBDiscoveryService.cachedDramas(
                genre: genre,
                contentType: contentType,
                page: 1
            )
            if !cached.isEmpty { movies = cached }
            isLoading = movies.isEmpty
            let refreshed = await DJHUBDiscoveryService.dramaPage(
                genre: genre,
                contentType: contentType,
                page: 1
            )
            if !refreshed.movies.isEmpty { movies = refreshed.movies }
            currentPage = 1
            hasMore = refreshed.hasMore
            isLoading = false
        }
    }

    @MainActor
    private func loadNextPage() async {
        guard currentPage > 0, hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        let result = await DJHUBDiscoveryService.dramaPage(
            genre: genre,
            contentType: contentType,
            page: nextPage
        )
        guard !Task.isCancelled else { return }

        if !result.movies.isEmpty {
            let existing = Set(movies.map(\.identity))
            movies.append(contentsOf: result.movies.filter { !existing.contains($0.identity) })
            currentPage = nextPage
        }
        hasMore = result.hasMore
    }
}

private struct RoveTMDBSearchTab: View {
    @State private var query = ""
    @State private var results: [TMDBFeaturedMovie] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("搜索短剧", systemImage: "magnifyingglass")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else if isSearching && results.isEmpty {
                    ProgressView("正在搜索…")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    RoveTMDBShelfGridView(
                        shelf: .shortDrama,
                        movies: results,
                        navigationTitleText: "搜索结果"
                    )
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索")
            .task(id: query) {
                let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    results = []
                    return
                }
                isSearching = true
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                results = await DJHUBDiscoveryService.search(query: text)
                isSearching = false
            }
        }
    }
}

struct RovePosterGridCard<Artwork: View>: View {
    let title: String
    let yearText: String
    let rating: Double?
    let transitionID: AnyHashable?
    let transitionNamespace: Namespace.ID?
    @ViewBuilder let artwork: () -> Artwork

    init(
        title: String,
        yearText: String,
        rating: Double?,
        transitionID: AnyHashable? = nil,
        transitionNamespace: Namespace.ID? = nil,
        @ViewBuilder artwork: @escaping () -> Artwork
    ) {
        self.title = title
        self.yearText = yearText
        self.rating = rating
        self.transitionID = transitionID
        self.transitionNamespace = transitionNamespace
        self.artwork = artwork
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Color.white.opacity(0.08)
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay { artwork() }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(6)
                }
            }
            .roveHeroTransitionSource(id: transitionID, namespace: transitionNamespace)

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 40, alignment: .topLeading)

            Text(yearText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private enum RoveBrowseCategory: String, Identifiable {
    case recent, movies, series, animation, documentaries, related

    var id: String { rawValue }
    var title: String {
        switch self {
        case .recent: "最近播放"
        case .movies: "热门电影"
        case .series: "热门剧集"
        case .animation: "动画"
        case .documentaries: "纪录片"
        case .related: "你可能也喜欢"
        }
    }
    var fallbackOffset: Int {
        switch self {
        case .recent: 0
        case .movies: 0
        case .series: 5
        case .animation: 10
        case .documentaries: 15
        case .related: 0
        }
    }
    func matches(_ channel: Channel, group: String) -> Bool {
        let itemType = channel.mediaServerItemType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let haystack = "\(group) \(channel.name)".lowercased()
        switch self {
        case .recent:
            return true
        case .movies:
            if channel.isMediaServerItem {
                return ["movie", "video", "musicvideo", "program"].contains(itemType)
            }
            return haystack.contains("movie") || haystack.contains("电影")
        case .series:
            if channel.isMediaServerItem { return channel.isMediaServerSeries }
            return haystack.contains("series") || haystack.contains("剧集") || haystack.contains("电视")
        case .animation:
            return ["animation", "anime", "动画", "动漫", "cartoon"].contains { haystack.contains($0) }
        case .documentaries:
            return ["documentary", "纪录", "访谈", "talk"].contains { haystack.contains($0) }
        case .related:
            return true
        }
    }

    func matchesCollection(_ collection: MetadataLibraryCollection) -> Bool {
        let name = collection.name.lowercased()
        let type = collection.collectionType?.lowercased() ?? ""
        switch self {
        case .recent:
            return false
        case .movies:
            return type == "movies" && !["动画", "动漫", "anime", "animation"].contains {
                name.contains($0)
            }
        case .series:
            return ["tvshows", "series", "shows"].contains(type)
                && !["动画", "动漫", "anime", "animation"].contains { name.contains($0) }
        case .animation:
            return ["动画", "动漫", "anime", "animation", "cartoon"].contains {
                name.contains($0)
            }
        case .documentaries:
            return ["纪录", "documentary"].contains { name.contains($0) }
        case .related:
            return false
        }
    }
}

private struct RoveImmersiveBackground: View {
    let channel: Channel

    var body: some View {
        GeometryReader { proxy in
            RoveArtworkView(channel: channel, landscape: true)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(1.08)
                .blur(radius: 8)
                .overlay(Color.black.opacity(0.46))
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.12), .black.opacity(0.52), .black.opacity(0.28)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }
}

private struct RoveCategoryGridView: View {
    @EnvironmentObject private var library: ChannelLibrary
    let category: RoveBrowseCategory
    let channels: [Channel]
    @State private var selectedChannel: Channel?
    @State private var selectedChannelHeroID: AnyHashable?
    @State private var loadedChannels: [Channel] = []
    @State private var isLoading = false
    @State private var mediaStateRevision = 0
    @Namespace private var mediaHeroNamespace
    @AppStorage("rove.category-grid.sort.v1") private var sortRaw = RoveCategorySort.dateAdded.rawValue
    @AppStorage("rove.category-grid.sort-descending.v1") private var sortDescending = true

    private var displayedChannels: [Channel] {
        sorted(loadedChannels.isEmpty ? channels : loadedChannels)
    }

    private var selectedSort: RoveCategorySort {
        RoveCategorySort(rawValue: sortRaw) ?? .dateAdded
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 3
    )

    var body: some View {
        ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                    ForEach(displayedChannels) { channel in
                        let transitionID = "channel-\(channel.id.uuidString)"
                        Button { openChannel(channel, heroID: transitionID) } label: {
                            RovePosterGridCard(
                                title: channel.name,
                                yearText: channel.productionYear.map(String.init) ?? "年份未知",
                                rating: channel.communityRating,
                                transitionID: nil,
                                transitionNamespace: nil
                            ) {
                                RoveArtworkView(channel: channel, landscape: false)
                                    .roveHeroTransitionSource(
                                        id: transitionID,
                                        namespace: mediaHeroNamespace
                                    )
                            }
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                        .roveMediaActions(
                            for: channel,
                            onOpen: { openChannel(channel, heroID: transitionID) },
                            onStateChange: { mediaStateRevision += 1 }
                        )
                    }
                }
                .roveEntrance(distance: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(Color.black)
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section("排序") {
                            ForEach(RoveCategorySort.allCases) { option in
                                Button {
                                    sortRaw = option.rawValue
                                } label: {
                                    Label(
                                        option.title,
                                        systemImage: selectedSort == option ? "checkmark" : option.systemImage
                                    )
                                }
                            }
                        }
                        Divider()
                        Button {
                            sortDescending.toggle()
                        } label: {
                            Label(
                                sortDescending ? "从高到低" : "从低到高",
                                systemImage: sortDescending ? "arrow.down" : "arrow.up"
                            )
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                    .accessibilityLabel("排序")
                }
            }
            .navigationDestination(item: $selectedChannel) { channel in
                RoveMediaDetailView(channel: channel)
                    .roveHeroNavigationTransition(
                        id: selectedChannelHeroID,
                        namespace: mediaHeroNamespace
                    )
            }
            .onChange(of: selectedChannel) { _, channel in
                if channel == nil { selectedChannelHeroID = nil }
            }
            .task(id: "\(category.id)-\(sortRaw)-\(sortDescending)") {
                await loadMediaServerCategory()
            }
            .id(mediaStateRevision)
    }

    private func openChannel(_ channel: Channel, heroID: AnyHashable) {
        selectedChannelHeroID = heroID
        Task { @MainActor in
            await Task.yield()
            guard selectedChannelHeroID == heroID else { return }
            selectedChannel = channel
        }
    }

    @MainActor
    private func loadMediaServerCategory() async {
        guard category != .recent, category != .related else { return }
        let requestedSort = selectedSort
        let requestedDescending = sortDescending
        isLoading = true
        defer {
            if selectedSort == requestedSort, sortDescending == requestedDescending {
                isLoading = false
            }
        }
        loadedChannels = []

        var result: [Channel] = []
        var seen = Set<String>()
        for configuration in library.configurations where configuration.kind.usesMediaLibraryBrowser {
            guard !Task.isCancelled else { return }
            let collections = (try? await library.loadEmbyCollections(
                configurationID: configuration.id
            )) ?? []
            for collection in collections where category.matchesCollection(collection) {
                guard !Task.isCancelled else { return }
                let prefersSeries = ["tvshows", "series", "shows"].contains(
                    collection.collectionType?.lowercased() ?? ""
                )
                var startIndex = 0
                repeat {
                    guard let page = try? await library.loadEmbyPage(
                        configurationID: configuration.id,
                        parentID: collection.id,
                        startIndex: startIndex,
                        limit: 100,
                        prefersSeries: prefersSeries,
                        sortBy: requestedSort.serverSortKey,
                        sortDescending: requestedDescending,
                        includesMediaSources: requestedSort.requiresMediaSources
                    ) else { break }
                    for channel in page.channels where category.matches(
                        channel,
                        group: library.displayGroup(for: channel)
                    ) {
                        let key = channel.tvgID ?? channel.streamURL.absoluteString
                        if seen.insert("\(configuration.id)|\(key)").inserted {
                            result.append(channel)
                        }
                    }
                    guard page.hasMore, page.nextStartIndex > startIndex else { break }
                    startIndex = page.nextStartIndex
                } while startIndex < 2_000
            }
        }
        guard !Task.isCancelled,
              selectedSort == requestedSort,
              sortDescending == requestedDescending else { return }
        if !result.isEmpty { loadedChannels = result }
    }

    private func sorted(_ values: [Channel]) -> [Channel] {
        values.enumerated().sorted { lhs, rhs in
            let comparison = compare(lhs.element, rhs.element)
            if comparison == .orderedSame { return lhs.offset < rhs.offset }
            return comparison == .orderedAscending
        }.map(\.element)
    }

    private func compare(_ lhs: Channel, _ rhs: Channel) -> ComparisonResult {
        let result: ComparisonResult = switch selectedSort {
        case .dateAdded:
            compareOptional(lhs.dateAdded, rhs.dateAdded)
        case .releaseDate:
            compareOptional(
                lhs.releaseDate ?? lhs.productionYear.map(String.init),
                rhs.releaseDate ?? rhs.productionYear.map(String.init)
            )
        case .communityRating:
            compareOptional(lhs.communityRating, rhs.communityRating)
        case .criticRating:
            compareOptional(lhs.criticRating, rhs.criticRating)
        case .officialRating:
            compareLocalized(lhs.officialRating, rhs.officialRating)
        case .playCount:
            compareOptional(lhs.playCount, rhs.playCount)
        case .lastPlayedDate:
            compareOptional(lhs.lastPlayedDate, rhs.lastPlayedDate)
        case .fileName:
            compareLocalized(lhs.name, rhs.name)
        case .runtime:
            compareOptional(lhs.runtimeSeconds, rhs.runtimeSeconds)
        case .fileSize:
            compareOptional(lhs.fileSize, rhs.fileSize)
        case .format:
            compareLocalized(lhs.container ?? inferredFormat(lhs), rhs.container ?? inferredFormat(rhs))
        }
        if result != .orderedSame { return result }
        return lhs.name.localizedStandardCompare(rhs.name)
    }

    private func compareOptional<T: Comparable>(_ lhs: T?, _ rhs: T?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if lhs == rhs { return .orderedSame }
            let isAscending = sortDescending ? lhs > rhs : lhs < rhs
            return isAscending ? .orderedAscending : .orderedDescending
        case (_?, nil): return .orderedAscending
        case (nil, _?): return .orderedDescending
        case (nil, nil): return .orderedSame
        }
    }

    private func compareLocalized(_ lhs: String?, _ rhs: String?) -> ComparisonResult {
        switch (lhs?.trimmingCharacters(in: .whitespacesAndNewlines),
                rhs?.trimmingCharacters(in: .whitespacesAndNewlines)) {
        case let (lhs?, rhs?) where !lhs.isEmpty && !rhs.isEmpty:
            let comparison = lhs.localizedStandardCompare(rhs)
            if comparison == .orderedSame { return comparison }
            if sortDescending {
                return comparison == .orderedAscending ? .orderedDescending : .orderedAscending
            }
            return comparison
        case let (lhs?, _) where !lhs.isEmpty: return .orderedAscending
        case let (_, rhs?) where !rhs.isEmpty: return .orderedDescending
        default: return .orderedSame
        }
    }

    private func inferredFormat(_ channel: Channel) -> String? {
        let value = channel.streamURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value.uppercased()
    }
}

private enum RoveCategorySort: String, CaseIterable, Identifiable {
    case dateAdded
    case releaseDate
    case communityRating
    case criticRating
    case officialRating
    case playCount
    case lastPlayedDate
    case fileName
    case runtime
    case fileSize
    case format

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateAdded: "添加日期"
        case .releaseDate: "发行日期"
        case .communityRating: "公众评分"
        case .criticRating: "影评人评分"
        case .officialRating: "分级"
        case .playCount: "播放次数"
        case .lastPlayedDate: "播放日期"
        case .fileName: "文件名"
        case .runtime: "文件时长"
        case .fileSize: "文件大小"
        case .format: "文件格式"
        }
    }

    var systemImage: String {
        switch self {
        case .dateAdded: "calendar.badge.plus"
        case .releaseDate: "calendar"
        case .communityRating: "star"
        case .criticRating: "quote.bubble"
        case .officialRating: "checkmark.seal"
        case .playCount: "play.circle"
        case .lastPlayedDate: "clock.arrow.circlepath"
        case .fileName: "textformat"
        case .runtime: "timer"
        case .fileSize: "internaldrive"
        case .format: "doc"
        }
    }

    var serverSortKey: String? {
        switch self {
        case .dateAdded: "DateCreated"
        case .releaseDate: "PremiereDate"
        case .communityRating: "CommunityRating"
        case .criticRating: "CriticRating"
        case .officialRating: "OfficialRating"
        case .playCount: "PlayCount"
        case .lastPlayedDate: "DatePlayed"
        case .fileName: "SortName"
        case .runtime: "Runtime"
        case .fileSize, .format: nil
        }
    }

    var requiresMediaSources: Bool {
        self == .fileSize || self == .format
    }
}

private struct RoveArtworkView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let channel: Channel
    var landscape: Bool
    var animatesLoading = true
    @State private var image: UIImage?

    private var displayedImage: UIImage? {
        if let image { return image }
        guard landscape else { return nil }
        return ChannelArtworkLoader.shared.cachedLandscapeImage(for: channel, maxWidth: 900)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            if let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(animatesLoading ? .opacity : .identity)
            } else {
                if landscape {
                    ZStack {
                        Color(red: 0.08, green: 0.09, blue: 0.11)
                        RoveShimmerBlock(cornerRadius: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ChannelLogoView(
                        channel: channel,
                        placeholderSystemName: "film.fill"
                    )
                    .padding(24)
                }
            }
        }
        .clipped()
        .animation(
            animatesLoading && !reduceMotion ? RoveMotion.quick : nil,
            value: displayedImage != nil
        )
        .task(id: "\(channel.id)-\(landscape)") {
            var loadedImage: UIImage?
            for attempt in 0..<4 {
                loadedImage = landscape
                    ? await ChannelArtworkLoader.shared.landscapeImage(for: channel, maxWidth: 900)
                    : await ChannelArtworkLoader.shared.image(for: channel, maxWidth: 600)
                if loadedImage != nil || attempt == 3 { break }
                try? await Task.sleep(for: .milliseconds(900))
            }
#if DEBUG
            NSLog("RoveArtworkView %@ image for %@", loadedImage == nil ? "missing" : "loaded", channel.name)
#endif
            image = loadedImage
        }
    }
}

enum RoveWatchedStore {
    private static let key = "rove.watched.media.v1"
    private static let unwatchedKey = "rove.unwatched.media.v1"

    static func contains(_ channel: Channel) -> Bool {
        let values = identifiers
        let stableIdentifier = identifier(for: channel)
        if unwatchedIdentifiers.contains(stableIdentifier) { return false }
        return values.contains(stableIdentifier)
            || values.contains(channel.id.uuidString)
            || channel.mediaServerPlayed == true
    }

    @discardableResult
    static func toggle(_ channel: Channel) -> Bool {
        let value = !contains(channel)
        set(value, for: channel)
        return value
    }

    @discardableResult
    static func mark(_ channel: Channel) -> Bool {
        guard !contains(channel) else { return false }
        set(true, for: channel)
        return true
    }

    static func set(_ watched: Bool, for channel: Channel) {
        var values = identifiers
        var unwatched = unwatchedIdentifiers
        let stableIdentifier = identifier(for: channel)
        values.remove(channel.id.uuidString)
        if watched {
            values.insert(stableIdentifier)
            unwatched.remove(stableIdentifier)
        } else {
            values.remove(stableIdentifier)
            if channel.mediaServerPlayed == true {
                unwatched.insert(stableIdentifier)
            } else {
                unwatched.remove(stableIdentifier)
            }
        }
        UserDefaults.standard.set(Array(values), forKey: key)
        UserDefaults.standard.set(Array(unwatched), forKey: unwatchedKey)
    }

    private static func identifier(for channel: Channel) -> String {
        if let itemID = channel.tvgID, !itemID.isEmpty {
            return "media:\(channel.streamURL.host ?? "local"):\(itemID)"
        }
        return "url:\(channel.streamURL.absoluteString)"
    }

    private static var identifiers: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private static var unwatchedIdentifiers: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: unwatchedKey) ?? [])
    }
}

private enum RoveContinueWatchingStore {
    private static let key = "rove.continue-watching.hidden.v1"

    static func contains(_ channel: Channel) -> Bool {
        identifiers.contains(identifier(for: channel))
    }

    static func remove(_ channel: Channel) {
        var values = identifiers
        values.insert(identifier(for: channel))
        UserDefaults.standard.set(Array(values), forKey: key)
    }

    private static func identifier(for channel: Channel) -> String {
        let source: String
        switch channel.resolver {
        case .legacyLibraryB(let configurationID, _),
             .legacyLibraryA(let configurationID, _),
             .movieClaw(let configurationID, _),
             .legacyLibraryC(let configurationID, _),
             .legacyLibraryD(let configurationID, _):
            source = configurationID.uuidString.lowercased()
        default:
            source = channel.streamURL.host ?? "local"
        }
        let itemID = channel.tvgID?.nonEmpty ?? channel.id.uuidString.lowercased()
        return "\(source):\(itemID)"
    }

    private static var identifiers: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
}

#if !DJHUB_METADATA_ONLY
private struct RoveMediaActionsModifier: ViewModifier {
    @EnvironmentObject private var library: ChannelLibrary
    @EnvironmentObject private var playback: PlaybackCoordinator

    let channel: Channel
    let onOpen: () -> Void
    let onStateChange: () -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                if channel.isMediaServerSeries {
                    onOpen()
                } else {
                    playback.play(channel)
                }
            } label: {
                Label("播放", systemImage: "play")
            }

            Button {
                let watched = RoveWatchedStore.toggle(channel)
                Task {
                    _ = await library.setMediaServerPlayed(watched, for: channel)
                    await MetadataSyncA.shared.setWatched(watched, channel: channel)
                    await MetadataSyncB.shared.setWatched(watched, channel: channel)
                }
                onStateChange()
            } label: {
                Label(
                    RoveWatchedStore.contains(channel) ? "标记为未观看" : "标记为已观看",
                    systemImage: RoveWatchedStore.contains(channel) ? "flag.slash" : "flag.fill"
                )
            }

            Button {
                library.toggleFavorite(channel)
                onStateChange()
            } label: {
                Label(
                    library.isFavorite(channel) ? "从收藏夹移除" : "添加到收藏夹",
                    systemImage: library.isFavorite(channel) ? "star.slash" : "star.fill"
                )
            }

            if let configurationID = channel.roveMediaServerConfigurationID {
                Button {
                    Task { await library.refreshConfiguration(configurationID) }
                } label: {
                    Label("更新鉴权", systemImage: "key.viewfinder")
                }
            }
        }
    }
}

private extension View {
    func roveMediaActions(
        for channel: Channel,
        onOpen: @escaping () -> Void,
        onStateChange: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            RoveMediaActionsModifier(
                channel: channel,
                onOpen: onOpen,
                onStateChange: onStateChange
            )
        )
    }
}
#else
private extension View {
    func roveMediaActions(
        for channel: Channel,
        onOpen: @escaping () -> Void,
        onStateChange: @escaping () -> Void = {}
    ) -> some View {
        contextMenu {
            Button {
                ChannelLibrary.shared.toggleFavorite(channel)
                onStateChange()
            } label: {
                Label(
                    ChannelLibrary.shared.isFavorite(channel) ? "从收藏夹移除" : "添加到收藏夹",
                    systemImage: ChannelLibrary.shared.isFavorite(channel) ? "star.slash" : "star.fill"
                )
            }
        }
    }
}
#endif

#if !DJHUB_METADATA_ONLY
struct RoveDownloadItem: Identifiable, Codable, Equatable {
    enum State: String, Codable {
        case queued
        case downloading
        case completed
        case failed

        var title: String {
            switch self {
            case .queued: "等待下载"
            case .downloading: "正在下载"
            case .completed: "已完成"
            case .failed: "下载失败"
            }
        }
    }

    let id: UUID
    let channel: Channel
    var state: State
    var fileName: String?
    var fileSize: Int64
    var errorMessage: String?
    let createdAt: Date
}

@MainActor
final class RoveDownloadManager: ObservableObject {
    static let shared = RoveDownloadManager()
    static let maximumConcurrentKey = "rove.download.maximumConcurrent.v1"
    static let allowsCellularKey = "rove.download.allowsCellular.v1"

    @Published private(set) var items: [RoveDownloadItem] = []
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private let itemsKey = "rove.download.items.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([RoveDownloadItem].self, from: data) {
            items = decoded.map { item in
                var restored = item
                if restored.state == .downloading { restored.state = .queued }
                return restored
            }
        }
        if UserDefaults.standard.object(forKey: Self.maximumConcurrentKey) == nil {
            UserDefaults.standard.set(2, forKey: Self.maximumConcurrentKey)
        }
        startAvailableDownloads()
    }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.fileSize } }

    func enqueue(_ channel: Channel) {
        guard !items.contains(where: { $0.channel.id == channel.id && $0.state != .failed }) else { return }
        items.insert(
            RoveDownloadItem(
                id: UUID(),
                channel: channel,
                state: .queued,
                fileName: nil,
                fileSize: 0,
                errorMessage: nil,
                createdAt: Date()
            ),
            at: 0
        )
        persist()
        startAvailableDownloads()
    }

    func retry(_ id: UUID) {
        update(id) { item in
            item.state = .queued
            item.errorMessage = nil
        }
        startAvailableDownloads()
    }

    func remove(_ ids: Set<UUID>) {
        for id in ids {
            tasks[id]?.cancel()
            tasks[id] = nil
            if let fileName = items.first(where: { $0.id == id })?.fileName {
                try? FileManager.default.removeItem(at: downloadsDirectory.appendingPathComponent(fileName))
            }
        }
        items.removeAll { ids.contains($0.id) }
        persist()
        startAvailableDownloads()
    }

    func settingsDidChange() {
        startAvailableDownloads()
    }

    func playbackChannel(for item: RoveDownloadItem) -> Channel? {
        guard item.state == .completed,
              let fileName = item.fileName else { return nil }
        let fileURL = downloadsDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        var channel = item.channel
        channel.streamURL = fileURL
        channel.resolver = nil
        channel.httpHeaders = [:]
        channel.playbackKind = .onDemand
        return channel
    }

    private func startAvailableDownloads() {
        let maximum = max(1, UserDefaults.standard.integer(forKey: Self.maximumConcurrentKey))
        let activeCount = items.filter { $0.state == .downloading }.count
        guard activeCount < maximum else { return }
        for item in items.filter({ $0.state == .queued }).prefix(maximum - activeCount) {
            start(item)
        }
    }

    private func start(_ item: RoveDownloadItem) {
        update(item.id) { $0.state = .downloading }
        tasks[item.id] = Task { [weak self] in
            guard let self else { return }
            do {
                let resolvedURL = try await ChannelLibrary.shared.resolveStream(for: item.channel)
                var request = URLRequest(url: resolvedURL)
                for (name, value) in item.channel.httpHeaders where !name.hasPrefix("X-Tubo-") {
                    request.setValue(value, forHTTPHeaderField: name)
                }
                let configuration = URLSessionConfiguration.default
                configuration.allowsCellularAccess = UserDefaults.standard.bool(forKey: Self.allowsCellularKey)
                let (temporaryURL, response) = try await URLSession(configuration: configuration).download(for: request)
                try Task.checkCancellation()
                let fileName = self.destinationName(for: item.channel, response: response)
                let destination = self.downloadsDirectory.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                let values = try destination.resourceValues(forKeys: [.fileSizeKey])
                self.update(item.id) { updated in
                    updated.state = .completed
                    updated.fileName = fileName
                    updated.fileSize = Int64(values.fileSize ?? 0)
                    updated.errorMessage = nil
                }
            } catch is CancellationError {
                self.update(item.id) { $0.state = .queued }
            } catch {
                self.update(item.id) { updated in
                    updated.state = .failed
                    updated.errorMessage = error.localizedDescription
                }
            }
            self.tasks[item.id] = nil
            self.startAvailableDownloads()
        }
    }

    private func update(_ id: UUID, mutation: (inout RoveDownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutation(&items[index])
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: itemsKey)
    }

    private var downloadsDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("RoveDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func destinationName(for channel: Channel, response: URLResponse) -> String {
        let proposed = response.suggestedFilename ?? channel.streamURL.lastPathComponent
        let ext = URL(fileURLWithPath: proposed).pathExtension.isEmpty ? "mp4" : URL(fileURLWithPath: proposed).pathExtension
        let base = channel.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "\(base.isEmpty ? channel.id.uuidString : base)-\(channel.id.uuidString.prefix(8)).\(ext)"
    }
}
#endif

private struct RoveServerPersonSelection: Identifiable, Hashable {
    let person: MetadataCreditPerson
    let configurationID: UUID

    var id: String { "\(configurationID.uuidString)|\(person.id)" }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct RoveMediaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var library: ChannelLibrary
#if !DJHUB_METADATA_ONLY
    @EnvironmentObject private var playback: PlaybackCoordinator
    @StateObject private var castService = DLNACastService.shared
    @StateObject private var downloadManager = RoveDownloadManager.shared
#endif
    @ObservedObject private var badgeLibrary = RoveBadgeLibrary.shared
    @ObservedObject private var watchlistStore = RoveWatchlistStore.shared
    private let channel: Channel?
    private let recommendation: TMDBFeaturedMovie?

    @State private var details: MetadataDetails?
    @State private var tmdbDetails: TMDBMovieDetails?
    @State private var isLoadingTMDBDetails = false
    @State private var heroImage: UIImage?
    @State private var heroLogoImage: UIImage?
    @State private var detailThemeColor = UIColor.black
    @State private var episodes: [Channel] = []
    @State private var serverRelatedChannels: [Channel] = []
    @State private var selectedSeason = 1
    @State private var episodeRangeStart = 0
    @State private var showsAllEpisodesDestination = false
#if !DJHUB_METADATA_ONLY
    @State private var playbackChannel: Channel?
    @State private var showingCastDevices = false
#endif
    @State private var isRefreshing = false
    @State private var watched = false
    @State private var notice: String?
    @State private var recommendationMatch: Channel?
    @State private var selectedRelatedRecommendation: TMDBFeaturedMovie?
    @State private var selectedRelatedChannel: Channel?
    @State private var selectedRelatedHeroID: AnyHashable?
    @State private var showingAllRelated = false
    @State private var showingAllPeople = false
    @State private var selectedPerson: TMDBMoviePerson?
    @State private var selectedServerPerson: RoveServerPersonSelection?
    @State private var isResolvingRecommendation = false
    @State private var didResolveRecommendation = false
    @State private var selectedMediaSourceID: String?
    @State private var selectedMediaConfigurationID: UUID?
    @State private var selectedMediaItemID: String?
    @State private var showingMediaVersionPicker = false
#if !DJHUB_METADATA_ONLY
    @State private var resumeSavedProgressOnNextOpen = false
    @State private var playbackProgressRevision = 0
#endif
    @State private var selectedArtworkTab: RoveDetailArtworkTab = .stills
    @State private var artworkViewerRequest: RoveArtworkViewerRequest?
#if !DJHUB_METADATA_ONLY
    @State private var isPlaybackCoverTransitioning = false
#endif
    @State private var watchlistTicketPick: RoveLuckyPick?
    @Namespace private var relatedHeroNamespace

    init(channel: Channel) {
        self.channel = channel
        self.recommendation = nil
    }

    fileprivate init(recommendation: TMDBFeaturedMovie) {
        self.channel = nil
        self.recommendation = recommendation
        _isLoadingTMDBDetails = State(initialValue: true)
    }

    private var detailChannel: Channel {
        guard let channel else {
            if let recommendationMatch { return recommendationMatch }
            let movie = recommendation!
            return Channel(
                id: stableRecommendationUUID(for: movie),
                name: movie.title,
                streamURL: URL(string: "rove-djhub://drama/\(movie.djhubID ?? String(movie.id))")!,
                group: "DJHUB 短剧",
                tvgName: movie.originalTitle,
                playbackKind: .onDemand,
                productionYear: movie.year,
                communityRating: movie.rating,
                mediaServerItemType: movie.isTV ? "Series" : "Movie"
            )
        }
        guard channel.isMediaServerEpisode,
              let seriesID = channel.mediaServerSeriesID,
              !seriesID.isEmpty else { return channel }
        if let series = library.channels.first(where: {
            $0.tvgID == seriesID && $0.isMediaServerSeries
        }) {
            return series
        }
        var series = channel
        series.id = UUID()
        series.name = channel.group.components(separatedBy: " · 第").first ?? channel.group
        series.tvgID = seriesID
        series.tvgName = series.name
        series.mediaServerItemType = "Series"
        series.mediaServerSeriesID = nil
        series.resolver = switch channel.resolver {
        case .legacyLibraryB(let configurationID, _):
            .legacyLibraryB(configurationID: configurationID, itemID: seriesID)
        case .legacyLibraryA(let configurationID, _):
            .legacyLibraryA(configurationID: configurationID, itemID: seriesID)
        case .movieClaw(let configurationID, _):
            .movieClaw(configurationID: configurationID, itemID: seriesID)
        case .legacyLibraryC(let configurationID, _):
            .legacyLibraryC(configurationID: configurationID, itemID: seriesID)
        case .legacyLibraryD(let configurationID, _):
            .legacyLibraryD(configurationID: configurationID, itemID: seriesID)
        default:
            channel.resolver
        }
        return series
    }

    private func stableRecommendationUUID(for movie: TMDBFeaturedMovie) -> UUID {
        let digest = SHA256.hash(data: Data(movie.identity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let value = "\(digest.prefix(8))-\(digest.dropFirst(8).prefix(4))-\(digest.dropFirst(12).prefix(4))-\(digest.dropFirst(16).prefix(4))-\(digest.dropFirst(20).prefix(12))"
        return UUID(uuidString: value) ?? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }

    private var watchlistEntry: RoveWatchlistEntry {
        if let recommendation {
            return RoveWatchlistEntry(recommendation: recommendation)
        }
        return RoveWatchlistEntry(channel: detailChannel)
    }

    private var isInWatchlist: Bool {
        watchlistStore.contains(watchlistEntry)
    }

    private var watchlistPick: RoveLuckyPick {
        if let recommendation { return .tmdb(recommendation) }
        return .channel(detailChannel)
    }

    private var relatedChannels: [Channel] {
        guard recommendation == nil else { return [] }
        if !serverRelatedChannels.isEmpty { return serverRelatedChannels }
        if tmdbDetails?.relatedMovies.isEmpty == false { return [] }
        let group = library.displayGroup(for: detailChannel)
        let sameGroup = library.channels.filter {
            $0.id != detailChannel.id && library.displayGroup(for: $0) == group
        }
        let fallback = library.channels.filter { $0.id != detailChannel.id && !sameGroup.contains($0) }
        return Array((sameGroup + fallback).prefix(10))
    }

    private var configurationID: UUID? {
        switch detailChannel.resolver {
        case .legacyLibraryB(let id, _), .legacyLibraryA(let id, _), .movieClaw(let id, _), .legacyLibraryC(let id, _),
             .legacyLibraryD(let id, _): id
        default: nil
        }
    }

    private var mediaConfigurations: [PlaylistConfiguration] {
        library.configurations.filter {
            $0.kind.usesMediaLibraryBrowser && !$0.isExpired
        }
    }

    private var detailTaskID: String {
        recommendation.map { "tmdb-\($0.id)" } ?? channel?.id.uuidString ?? "detail"
    }

#if !DJHUB_METADATA_ONLY
    private var playbackPreloadCandidate: Channel? {
        let candidate: Channel?
        if let recommendationMatch {
            candidate = recommendationMatch
        } else if let episode = selectedSeasonEpisodes.first(where: {
            PlaybackProgressStore.resumePosition(for: $0) != nil
        }) ?? selectedSeasonEpisodes.first {
            candidate = episode
        } else {
            candidate = detailChannel.isMediaServerSeries ? nil : detailChannel
        }
        guard var candidate else { return nil }
        candidate = applyingSelectedMediaVersion(to: candidate)
        return candidate
    }

    private func applyingSelectedMediaVersion(to original: Channel) -> Channel {
        var candidate = original
        candidate.mediaServerSourceID = selectedMediaSourceID
        guard let configurationID = selectedMediaConfigurationID,
              let itemID = selectedMediaItemID else { return candidate }
        switch details?.mediaVersions?.first(where: {
            $0.serverConfigurationID == configurationID && $0.serverItemID == itemID
        })?.serverKind {
        case PlaylistConfigurationKind.legacyLibraryB.rawValue:
            candidate.resolver = .legacyLibraryB(configurationID: configurationID, itemID: itemID)
        case PlaylistConfigurationKind.legacyLibraryA.rawValue:
            candidate.resolver = .legacyLibraryA(configurationID: configurationID, itemID: itemID)
        case PlaylistConfigurationKind.movieClaw.rawValue:
            candidate.resolver = .movieClaw(configurationID: configurationID, itemID: itemID)
        case PlaylistConfigurationKind.legacyLibraryC.rawValue:
            candidate.resolver = .legacyLibraryC(configurationID: configurationID, itemID: itemID)
        case PlaylistConfigurationKind.legacyLibraryD.rawValue:
            candidate.resolver = .legacyLibraryD(configurationID: configurationID, itemID: itemID)
        default:
            break
        }
        return candidate
    }

    private var playbackPreloadTaskID: String {
        "\(detailTaskID)-season-\(selectedSeason)-\(playbackPreloadCandidate?.id.uuidString ?? "none")-\(selectedMediaSourceID ?? "auto")"
    }
#endif

    private var heroHeight: CGFloat {
        min(700, max(620, UIScreen.main.bounds.width * 1.5))
    }

    private var displayTitle: String {
        if let tmdbTitle = tmdbDetails?.title.trimmingCharacters(in: .whitespacesAndNewlines),
           !tmdbTitle.isEmpty {
            return tmdbTitle
        }
        if let recommendation { return recommendation.title }
        let serverTitle = details?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let serverTitle, !serverTitle.isEmpty { return serverTitle }
        return detailChannel.name
    }

    private var displayOverview: String? {
        let tmdbOverview = tmdbDetails?.overview.trimmingCharacters(in: .whitespacesAndNewlines)
        if let tmdbOverview, !tmdbOverview.isEmpty { return tmdbOverview }
        let recommendationOverview = recommendation?.overview.trimmingCharacters(in: .whitespacesAndNewlines)
        if let recommendationOverview, !recommendationOverview.isEmpty { return recommendationOverview }
        let serverOverview = details?.overview?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let serverOverview, !serverOverview.isEmpty { return serverOverview }
        return nil
    }

    private var displayRating: Double? {
        let tmdbRating = tmdbDetails?.rating ?? recommendation?.rating
        if recommendation != nil, let tmdbRating, tmdbRating > 0 { return tmdbRating }
        return details?.communityRating ?? detailChannel.communityRating ?? tmdbRating
    }

    var body: some View {
        ZStack(alignment: .top) {
                Color(uiColor: detailThemeColor).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero
                        VStack(alignment: .leading, spacing: 26) {
                            mediaBadgeSection
                            parentGuideSection
                            episodesSection
                            trailerShelf
                            artworkShelf
                            peopleShelf
                            studiosSection
                            relatedShelf
                            djhubSourceAttribution
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                        .padding(.bottom, 52)
                        .background(Color(uiColor: detailThemeColor))
                        .roveEntrance(delay: 0.06, distance: 12)
                    }
                }
                .scrollIndicators(.hidden)
                .coordinateSpace(name: "rove-detail-scroll")
                .ignoresSafeArea(edges: .top)
                topControls
                    .roveEntrance(delay: 0.10, distance: -8)

                if let watchlistTicketPick {
                    RoveWatchlistTicketAnimation(
                        pick: watchlistTicketPick,
                        onFinished: {
                            guard self.watchlistTicketPick?.id == watchlistTicketPick.id else { return }
                            self.watchlistTicketPick = nil
                        }
                    )
                    .zIndex(200)
                }

            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .background {
                RoveNativeInteractivePopGestureEnabler()
                    .frame(width: 0, height: 0)
            }
#if !DJHUB_METADATA_ONLY
            .allowsHitTesting(!isPlaybackCoverTransitioning)
#endif
            .navigationDestination(item: $selectedRelatedRecommendation) { movie in
                RoveMediaDetailView(recommendation: movie)
                    .roveHeroNavigationTransition(
                        id: selectedRelatedHeroID,
                        namespace: relatedHeroNamespace
                    )
            }
            .navigationDestination(item: $selectedRelatedChannel) { channel in
                RoveMediaDetailView(channel: channel)
                    .roveHeroNavigationTransition(
                        id: selectedRelatedHeroID,
                        namespace: relatedHeroNamespace
                    )
            }
            .navigationDestination(item: $selectedPerson) { person in
                if person.tmdbID < 0 {
                    DJHUBPersonDetailView(person: person)
                } else {
                    TMDBPersonDetailView(person: person)
                }
            }
            .navigationDestination(item: $selectedServerPerson) { selection in
                RoveServerPersonDetailView(
                    person: selection.person,
                    configurationID: selection.configurationID
                )
            }
            .navigationDestination(isPresented: $showingAllRelated) {
                RoveRelatedGridPage(
                    movies: tmdbDetails?.relatedMovies ?? [],
                    channels: tmdbDetails?.relatedMovies.isEmpty == false ? [] : relatedChannels
                )
            }
            .navigationDestination(isPresented: $showingAllPeople) {
                if let people = tmdbDetails?.people, !people.isEmpty {
                    RovePeopleGridPage(people: people)
                } else if let details, let configurationID, !details.people.isEmpty {
                    RoveServerPeopleGridPage(
                        people: details.people,
                        configurationID: configurationID
                    ) { person in
                        openServerPerson(person)
                    }
                } else {
                    Color.black
                        .ignoresSafeArea()
                        .navigationTitle("演职人员")
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { showsAllEpisodesDestination },
                set: { showsAllEpisodesDestination = $0 }
            )) {
                RoveEpisodeListView(
                    title: displayTitle,
                    episodes: episodes,
                    initialSeason: selectedSeason,
                    onPlay: { episode in
                        showsAllEpisodesDestination = false
                        openPlayback(episode)
                    }
                )
            }
#if !DJHUB_METADATA_ONLY
            .sheet(isPresented: $showingCastDevices) {
                RoveCastDeviceSheet(channel: detailChannel, service: castService)
                    .roveLiquidGlassSheet()
            }
#endif
            .sheet(isPresented: $showingMediaVersionPicker) {
                MediaVersionSelectionSheet(
                    versions: details?.mediaVersions ?? [],
                    selectedKey: selectedMediaVersionKey,
                    badgeText: badgeMatchText,
                    backgroundImage: heroImage,
                    backgroundColor: detailThemeColor,
                    onSelect: selectMediaVersion
                )
                .presentationDetents([.height(mediaVersionPickerHeight)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
            }
            .alert("提示", isPresented: Binding(
                get: { notice != nil },
                set: { if !$0 { notice = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(notice ?? "")
            }
            .fullScreenCover(item: $artworkViewerRequest) { request in
                RoveArtworkViewer(
                    urls: request.urls,
                    titles: request.titles,
                    initialIndex: request.initialIndex,
                    onSetAsStill: { image in
                        applyHeroArtwork(image)
                    }
                )
            }
        .preferredColorScheme(.dark)
#if !DJHUB_METADATA_ONLY
        .fullScreenCover(
            item: $playbackChannel,
            onDismiss: {
                isPlaybackCoverTransitioning = false
                resumeSavedProgressOnNextOpen = false
                playbackProgressRevision += 1
                Task { @MainActor in
                    // PlayerDetailView performs a short deferred teardown after
                    // the cover animation. Refresh once more after that save.
                    try? await Task.sleep(for: .milliseconds(500))
                    playbackProgressRevision += 1
                }
            }
        ) { item in
            PlayerDetailView(
                channel: item,
                resumeSavedProgress: resumeSavedProgressOnNextOpen,
                // The detail page already resolved the canonical season list.
                // Some Jellyfin-compatible servers label a playable episode as
                // Video rather than Episode, so the item's type is not a safe
                // gate for whether the player should receive its episode queue.
                episodeQueue: selectedSeasonEpisodes.count > 1 ? selectedSeasonEpisodes : [],
                launchBackdropImage: heroImage,
                detailBadgeMatchText: badgeMatchText,
                onPlaybackDismissReady: {
                    // The player has already committed portrait geometry. Keep
                    // the detail page rendered behind the cover so its final
                    // layout is revealed by the native dismissal animation,
                    // instead of flashing a black transition layer.
                    isPlaybackCoverTransitioning = false
                }
            )
        }
        .onChange(of: playbackChannel) { _, channel in
            if channel != nil {
                isPlaybackCoverTransitioning = true
            }
        }
#endif
        .task(id: detailTaskID) {
            if recommendation != nil {
                await loadTMDBDetails()
                await resolveRecommendationResource()
                watched = recommendationMatch.map(RoveWatchedStore.contains) ?? false
                if recommendationMatch != nil {
                    await loadDetails()
                }
            } else {
                watched = RoveWatchedStore.contains(detailChannel)
                await loadDetails()
            }
        }
        .task(id: "detail-hero-\(detailTaskID)") {
            await loadDetailHeroArtwork()
        }
#if !DJHUB_METADATA_ONLY
        .task(id: playbackPreloadTaskID) {
            guard let playbackPreloadCandidate else { return }
            await library.preloadEmbyPlaybackInfo(for: playbackPreloadCandidate)
        }
#endif
    }

    private func loadRecommendationArtwork() async {
        guard let url = recommendation?.posterURL,
              let image = await TMDBArtworkLoader.shared.image(for: url) else { return }
        applyHeroArtwork(image)
    }

    private func loadDetailHeroArtwork() async {
        if recommendation != nil {
            await loadRecommendationArtwork()
            return
        }

        let target = detailChannel
        if target.isMediaServerItem,
           let preview = await ChannelArtworkLoader.shared.cachedDetailPreview(for: target),
           !Task.isCancelled {
            applyHeroArtwork(preview)
        }

        guard target.isMediaServerItem else {
            guard let image = await ChannelArtworkLoader.shared.landscapeImage(
                for: target,
                maxWidth: 1200
            ), !Task.isCancelled else { return }
            applyHeroArtwork(image)
            return
        }

        let posterTask = Task { @MainActor in
            await ChannelArtworkLoader.shared.primaryImage(for: target, maxWidth: 900)
        }
        let landscapeTask = Task { @MainActor in
            await ChannelArtworkLoader.shared.landscapeImage(for: target, maxWidth: 1200)
        }

        if let poster = await posterTask.value, !Task.isCancelled {
            applyHeroArtwork(poster)
        } else if let landscape = await landscapeTask.value, !Task.isCancelled {
            applyHeroArtwork(landscape)
        }
    }

    private func loadTMDBDetails() async {
        guard let recommendation else { return }
        isLoadingTMDBDetails = true
        defer { isLoadingTMDBDetails = false }
        if recommendation.djhubID != nil {
            tmdbDetails = await DJHUBDiscoveryService.details(for: recommendation)
            await loadHeroLogo()
            return
        }
        if let cached = await TMDBDiscoveryService.cachedDetails(
            movieID: recommendation.id,
            isTV: recommendation.isTV
        ) {
            tmdbDetails = cached
            await loadHeroLogo()
        }
        // A transient TMDB failure must not replace already-rendered metadata
        // with an empty detail page. Retry briefly and only commit a success.
        for attempt in 0..<3 {
            if let loaded = await TMDBDiscoveryService.loadDetails(
                movieID: recommendation.id,
                isTV: recommendation.isTV
            ) {
                tmdbDetails = loaded
                await loadHeroLogo()
                return
            }
            guard attempt < 2, !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
        }
    }

    private func loadDetails() async {
        let targetChannel = detailChannel
        let targetConfigurationID = configurationID
        let targetItemID = targetChannel.tvgID
        let shouldLoadEpisodes = targetChannel.isMediaServerSeries
        let shouldResolveTMDB = targetChannel.isMediaServerItem && tmdbDetails == nil

        if !shouldLoadEpisodes {
            episodes = []
            selectedSeason = 1
            episodeRangeStart = 0
        }

        async let loadedEpisodes = loadEpisodesIfNeeded(
            configurationID: targetConfigurationID,
            seriesID: targetItemID,
            enabled: shouldLoadEpisodes
        )
        async let loadedServerRelated = loadServerRelatedItemsIfNeeded(
            channel: targetChannel,
            enabled: targetChannel.isMediaServerItem
        )
        async let initiallyResolvedTMDB = resolveServerTMDBDetails(
            titles: [targetChannel.name],
            year: targetChannel.productionYear,
            isTV: shouldLoadEpisodes,
            enabled: shouldResolveTMDB
        )

        if let configurationID = targetConfigurationID,
           let itemID = targetItemID,
           targetChannel.isMediaServerItem {
            // Reuse the media-server cache populated by the existing Tubo
            // library pipeline before asking the server again. A transient
            // request failure must never replace a complete page with nil.
            var shouldRefreshServerDetails = false
            if let cached = await library.cachedMetadataDetails(
                configurationID: configurationID,
                itemID: itemID
            ) {
                details = cached
                // Older cached payloads were saved before People/Studios and
                // complete stream metadata were requested. Keep the cached
                // page visible, but refresh once when it is clearly partial
                // so the detail page does not silently lose these sections.
                shouldRefreshServerDetails = cached.people.isEmpty
                    && (cached.studios ?? []).isEmpty
                    && cached.streams.isEmpty
            }
            if details == nil || shouldRefreshServerDetails,
               let loadedDetails = try? await library.loadMetadataDetails(
                configurationID: configurationID,
                itemID: itemID
            ) {
                details = loadedDetails
            }
            let baseDetails = details
            async let aggregatedDetails = aggregateDetailsIfAvailable(
                channel: targetChannel,
                base: baseDetails
            )

            let (episodesResult, initialTMDBResult, aggregateResult, relatedResult) = await (
                loadedEpisodes,
                initiallyResolvedTMDB,
                aggregatedDetails,
                loadedServerRelated
            )
            serverRelatedChannels = relatedResult
            if let aggregateResult {
                details = aggregateResult
            }
            if !episodesResult.isEmpty {
                episodes = episodesResult
                selectedSeason = availableSeasons.first ?? 1
                episodeRangeStart = 0
            }

            if shouldResolveTMDB {
                var resolvedTMDB = initialTMDBResult
                let serverTitle = details?.title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                if resolvedTMDB == nil,
                   let serverTitle,
                   serverTitle.caseInsensitiveCompare(targetChannel.name) != .orderedSame {
                    resolvedTMDB = await resolveServerTMDBDetails(
                        titles: [serverTitle],
                        year: details?.productionYear ?? targetChannel.productionYear,
                        isTV: shouldLoadEpisodes,
                        enabled: true
                    )
                }
                if let resolvedTMDB {
                    tmdbDetails = resolvedTMDB
                }
                isLoadingTMDBDetails = false
            }
            await loadHeroLogo()
            return
        }
        _ = await loadedEpisodes
        _ = await initiallyResolvedTMDB
        _ = await loadedServerRelated
    }

    private func loadEpisodesIfNeeded(
        configurationID: UUID?,
        seriesID: String?,
        enabled: Bool
    ) async -> [Channel] {
        guard enabled, let configurationID, let seriesID else { return [] }
        return await loadEpisodes(configurationID: configurationID, seriesID: seriesID)
    }

    private func loadServerRelatedItemsIfNeeded(
        channel: Channel,
        enabled: Bool
    ) async -> [Channel] {
        guard enabled else { return [] }
        return (try? await library.loadSimilarItems(for: channel, limit: 20)) ?? []
    }

    private func aggregateDetailsIfAvailable(
        channel: Channel,
        base: MetadataDetails?
    ) async -> MetadataDetails? {
        guard let base else { return nil }
        return await library.loadAggregatedMediaDetails(for: channel, base: base)
    }

    private func resolveServerTMDBDetails(
        titles: [String],
        year: Int?,
        isTV: Bool,
        enabled: Bool
    ) async -> TMDBMovieDetails? {
        guard enabled else { return nil }
        let candidates = titles
            .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
            .reduce(into: [String]()) { result, title in
                if !result.contains(where: { $0.caseInsensitiveCompare(title) == .orderedSame }) {
                    result.append(title)
                }
            }
        guard !candidates.isEmpty else { return nil }
        isLoadingTMDBDetails = true
        for title in candidates {
            guard !Task.isCancelled else { return nil }
            if let resolved = await TMDBDiscoveryService.loadDetails(
                title: title,
                year: year,
                isTV: isTV
            ) {
                return resolved
            }
        }
        return nil
    }

    private func loadHeroLogo() async {
        guard let path = tmdbDetails?.preferredChineseLogoPath else {
            heroLogoImage = nil
            return
        }
        let url = path.hasPrefix("http")
            ? URL(string: path)
            : RoveAPISettings.tmdbImageURL(size: "w500", path: path)
        guard let url,
              let image = await TMDBArtworkLoader.shared.image(for: url) else {
            heroLogoImage = nil
            return
        }
        heroLogoImage = image
    }

    private func applyHeroArtwork(_ image: UIImage) {
        let themeColor = image.roveImmersiveColor
        withAnimation(reduceMotion ? nil : RoveMotion.carousel) {
            heroImage = image
            detailThemeColor = themeColor
        }
    }

    private func loadEpisodes(configurationID: UUID, seriesID: String) async -> [Channel] {
        var result: [Channel] = []
        var startIndex = 0
        repeat {
            guard let page = try? await library.loadEmbyPage(
                configurationID: configurationID,
                parentID: seriesID,
                startIndex: startIndex,
                limit: 200,
                prefersSeries: false
            ) else { break }
            let pageEpisodes = page.channels.filter(\.isMediaServerEpisode)
            result.append(contentsOf: pageEpisodes)
            guard page.hasMore, page.nextStartIndex > startIndex else { break }
            startIndex = page.nextStartIndex
        } while startIndex < 1_000
        return result.sorted {
            let lhsSeason = seasonNumber(for: $0)
            let rhsSeason = seasonNumber(for: $1)
            if lhsSeason != rhsSeason { return lhsSeason < rhsSeason }
            let lhsEpisode = episodeNumber(for: $0)
            let rhsEpisode = episodeNumber(for: $1)
            if lhsEpisode != rhsEpisode { return lhsEpisode < rhsEpisode }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            if recommendation != nil {
                await loadTMDBDetails()
                await loadRecommendationArtwork()
                await resolveRecommendationResource()
                watched = recommendationMatch.map(RoveWatchedStore.contains) ?? false
                if recommendationMatch != nil {
                    await loadDetails()
                }
                isRefreshing = false
                notice = recommendationMatch == nil ? "没有可用资源" : "已匹配媒体库资源"
                return
            }
            if let configurationID { await library.refreshConfiguration(configurationID) }
            await loadDetails()
            isRefreshing = false
            notice = "刷新完成"
        }
    }

    private var hero: some View {
        GeometryReader { heroProxy in
            let pullDistance = max(
                0,
                heroProxy.frame(in: .named("rove-detail-scroll")).minY
            )
            ZStack(alignment: .bottom) {
                GeometryReader { proxy in
                    let artworkOffset = max(
                        0,
                        -proxy.frame(in: .named("rove-detail-scroll")).minY
                    )
                    ZStack {
                        if let heroImage {
                            Image(uiImage: heroImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .offset(y: artworkOffset)
                                .opacity(detailHeroArtworkOpacity(for: artworkOffset))
                        } else {
                            // Artwork is a background state only. The fixed
                            // GeometryReader keeps the same slot before and after
                            // the image arrives.
                            Color.black.opacity(0.18)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }
                    .clipped()
                }
                .frame(height: heroHeight)
                .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.24),
                        .init(color: .black.opacity(0.16), location: 0.42),
                        .init(color: .black.opacity(0.64), location: 0.70),
                        .init(color: Color(uiColor: detailThemeColor), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 11) {
                    Group {
                        if let heroLogoImage {
                            Image(uiImage: heroLogoImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: min(UIScreen.main.bounds.width * 0.72, 360), maxHeight: 92)
                                .shadow(color: .black.opacity(0.42), radius: 4, y: 2)
                        } else {
                            Text(displayTitle)
                                .font(RovePosterTitleStyle.font(size: 252, seed: displayTitle))
                                .foregroundStyle(RovePosterTitleStyle.color(seed: displayTitle))
                                .shadow(color: .black.opacity(0.32), radius: 3, y: 2)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .allowsTightening(true)
                                .minimumScaleFactor(0.18)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 104, alignment: .center)
                    metadata
                    mediaVersionPicker
                    if !episodes.isEmpty {
                        Text("共 \(availableSeasons.count) 季")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                    }
#if !DJHUB_METADATA_ONLY
                    if recommendation?.djhubID == nil {
                        playButton
                    }
#endif
                    HStack(spacing: 22) {
                        Button {
                            guard recommendation?.djhubID != nil || recommendation == nil || recommendationMatch != nil else {
                                notice = "当前推荐还没有匹配到媒体库资源"
                                return
                            }
                            library.toggleFavorite(detailChannel)
                        } label: {
                            Label(
                                library.isFavorite(detailChannel) ? "已喜欢" : "喜欢",
                                systemImage: library.isFavorite(detailChannel) ? "heart.fill" : "heart"
                            )
                            .font(.headline.weight(.semibold))
                            .frame(minWidth: 88, minHeight: 46)
                        }
                        .contentShape(Rectangle())
                        Button {
                            let added = watchlistStore.toggle(watchlistEntry)
                            if added {
                                watchlistTicketPick = watchlistPick
                            } else {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        } label: {
                            Label(
                                isInWatchlist ? "已加入" : "待看",
                                systemImage: isInWatchlist ? "ticket.fill" : "ticket"
                            )
                            .font(.headline.weight(.semibold))
                            .frame(minWidth: 82, minHeight: 46)
                        }
                        .contentShape(Rectangle())
                        if recommendation?.djhubID == nil {
                            Button {
                                guard recommendation == nil || recommendationMatch != nil else {
                                    notice = "当前推荐还没有匹配到媒体库资源"
                                    return
                                }
                                watched = RoveWatchedStore.toggle(detailChannel)
                                Task {
                                    _ = await library.setMediaServerPlayed(watched, for: detailChannel)
                                    await MetadataSyncA.shared.setWatched(watched, channel: detailChannel)
                                    await MetadataSyncB.shared.setWatched(watched, channel: detailChannel)
                                }
                            } label: {
                                Image(systemName: watched ? "flag.fill" : "flag")
                                    .font(.system(size: 28, weight: .medium))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Text(displayOverview ?? " ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(displayOverview == nil ? 0 : 0.94))
                        .lineSpacing(2)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .offset(y: 18)
                .roveEntrance(delay: 0.16, distance: 10)
            }
            .frame(width: heroProxy.size.width, height: heroHeight)
            .scaleEffect(
                1 + pullDistance / max(heroHeight, 1),
                anchor: .bottom
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
    }

    private func detailHeroArtworkOpacity(for offset: CGFloat) -> Double {
        let fadeDistance = max(1, heroHeight * 0.76)
        return Double(max(0, 1 - offset / fadeDistance))
    }

    private var metadata: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Group {
                if let rating = displayRating {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.clear)
                    Text("0.0")
                        .foregroundStyle(.clear)
                }
            }
            .frame(width: 58, alignment: .leading)
            Text(metadataValues.isEmpty ? " " : metadataValues.joined(separator: " · "))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity)
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 48)
    }

    private var metadataValues: [String] {
        var values: [String] = []
        if let date = tmdbDetails?.releaseDate, !date.isEmpty {
            values.append(String(date.prefix(10)))
        } else if recommendation == nil, let date = details?.premiereDate, !date.isEmpty {
            values.append(String(date.prefix(10)))
        } else if let year = details?.productionYear ?? detailChannel.productionYear ?? recommendation?.year {
            values.append(String(year))
        }
        if let runtimeMinutes = tmdbDetails?.runtimeMinutes ?? details?.runtimeSeconds.map({ Int($0 / 60) }),
           runtimeMinutes > 0 {
            values.append("\(runtimeMinutes) 分钟")
        }
        if let certification = tmdbDetails?.certification, !certification.isEmpty {
            values.append(certification)
        }
        let studio = tmdbDetails?.studios.first ?? details?.studios?.first
        if let studio, !studio.isEmpty { values.append(studio) }
        if !genres.isEmpty { values.append(genres.prefix(2).joined(separator: ", ")) }
        return values
    }

    private var genres: [String] {
        if let tmdbGenres = tmdbDetails?.genres, !tmdbGenres.isEmpty { return tmdbGenres }
        if recommendation != nil { return recommendation?.genres ?? [] }
        if let serverGenres = details?.genres, !serverGenres.isEmpty { return serverGenres }
        return []
    }

    private var badgeMatchText: String {
        var values = [displayTitle]
        values.append(contentsOf: [
            displayOverview,
            tmdbDetails?.originalTitle,
            tmdbDetails?.keywords?.joined(separator: " "),
            genres.joined(separator: " "),
            details?.officialRating,
            details?.streams.map(\.title).joined(separator: " "),
            details?.streams.compactMap(\.codec).joined(separator: " ")
        ].compactMap { $0 })
        return values.joined(separator: " ")
    }

    private var badgeRules: [RoveBadgeRule] {
        badgeLibrary.matchingRules(in: badgeMatchText)
    }

    @ViewBuilder
    private var mediaBadgeSection: some View {
        if let recommendation, recommendation.djhubID != nil {
            VStack(alignment: .leading, spacing: 8) {
                if isLoadingTMDBDetails, tmdbDetails == nil {
                    detailBadgeSkeleton
                } else if let badges = tmdbDetails?.djhubBadges, !badges.isEmpty {
                    DJHUBAssignedBadgeStrip(badges: badges)
                }
                if !isLoadingTMDBDetails || tmdbDetails != nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            ForEach(tmdbDetails?.djhubBadges ?? []) { badge in
                                djhubBadge(badge.name, systemImage: djhubBadgeIcon(for: badge))
                            }
                            if tmdbDetails?.djhubBadges?.isEmpty != false {
                                djhubBadge("短剧", systemImage: "play.rectangle.fill")
                            }
                            if let platform = recommendation.platformName?.nonEmpty {
                                djhubBadge(platform, systemImage: "tv.fill")
                            }
                            if let episodes = recommendation.episodeCount {
                                djhubBadge("\(episodes) 集", systemImage: "rectangle.stack.fill")
                            }
                            if let rating = recommendation.displayRating {
                                djhubBadge(String(format: "%.1f", rating), systemImage: "star.fill")
                            }
                        }
                    }
                }
            }
        } else if !badgeRules.isEmpty {
            RoveBadgeStrip(matchText: badgeMatchText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var detailBadgeSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoveShimmerBlock(cornerRadius: 6)
                            .frame(width: 92, height: 32)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach([76.0, 104.0, 72.0], id: \.self) { width in
                        RoveShimmerBlock(cornerRadius: 17)
                            .frame(width: width, height: 34)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func djhubBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.white.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.8))
    }

    private func djhubBadgeIcon(for badge: DJHUBBadge) -> String {
        if badge.groupID.contains("episode") { return "rectangle.stack.fill" }
        if badge.name.contains("真人") { return "person.2.fill" }
        if badge.name.contains("漫") { return "paintbrush.fill" }
        return "play.rectangle.fill"
    }

    private var parentGuideText: String {
        [
            displayTitle,
            displayOverview,
            tmdbDetails?.keywords?.joined(separator: " "),
            genres.joined(separator: " "),
            details?.streams.map(\.title).joined(separator: " ")
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }

    private var parentGuideItems: [RoveParentGuideItem] {
        let rating = (details?.officialRating ?? tmdbDetails?.certification)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var items: [RoveParentGuideItem] = []

        if let rating, !rating.isEmpty {
            let normalized = rating.uppercased().replacingOccurrences(of: " ", with: "")
            let adultRatings = ["R", "NC-17", "TV-MA", "18", "18+", "R18+", "MA15+"]
            let elevatedRatings = ["16", "16+", "TV-14", "PG-13"]
            let isAdult = adultRatings.contains(normalized)
            let isElevated = elevatedRatings.contains(normalized)
            items.append(RoveParentGuideItem(
                id: "rating",
                title: "年龄分级",
                level: isAdult ? "成人内容" : (isElevated ? "建议陪同" : rating),
                color: isAdult ? .red : (isElevated ? .orange : .green),
                evidence: "媒体分级：\(rating)。播放前建议家长结合孩子年龄判断。"
            ))
        }

        let categories: [(String, String, [String], Color, String)] = [
            ("sexual", "性与裸露", ["nudity", "nude", "sex", "sexual", "erotic", "intimate", "裸露", "情色", "性内容"], .pink, "可能包含性或裸露相关内容"),
            ("violence", "暴力与血腥", ["violence", "violent", "gore", "murder", "assassin", "war", "action", "crime", "暴力", "血腥", "谋杀", "杀手", "战争", "动作", "犯罪"], .red, "可能包含暴力、犯罪或血腥场景"),
            ("language", "粗俗语言", ["profanity", "strong language", "vulgar", "粗俗", "脏话", "不雅用语"], .orange, "可能包含粗俗或不雅用语"),
            ("substance", "酒精与毒品", ["drug", "drugs", "alcohol", "smoking", "酒精", "毒品", "吸烟"], .purple, "可能出现酒精、吸烟或毒品内容"),
            ("fear", "惊吓与紧张", ["horror", "terror", "thriller", "suspense", "惊悚", "恐怖", "惊吓", "悬疑"], .yellow, "可能包含惊吓或持续紧张场景"),
            ("relationship", "情感与婚恋", ["爱情", "甜宠", "情感", "婚恋", "家庭", "复仇"], .blue, "包含情感、婚恋或家庭冲突题材")
        ]

        for (id, title, signals, color, evidence) in categories
        where signals.contains(where: parentGuideText.contains) {
            items.append(RoveParentGuideItem(
                id: id,
                title: title,
                level: "请留意",
                color: color,
                evidence: "\(evidence)，依据影片题材与可用元数据提示。"
            ))
        }
        if items.isEmpty, recommendation?.djhubID != nil {
            items.append(RoveParentGuideItem(
                id: "metadata",
                title: "内容提示",
                level: "建议了解",
                color: .green,
                evidence: "DJHUB 当前可用题材与关键词未标记明显风险内容，建议家长结合剧情简介判断。"
            ))
        }
        return items
    }

    private var parentGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "figure.and.child.holdinghands")
                Text("家长指南")
                    .font(.title2.weight(.heavy))
            }

            if parentGuideItems.isEmpty {
                Label("暂无可用的家长指南数据", systemImage: "info.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.14)))
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150, maximum: 360), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(parentGuideItems) { item in
                        HStack(spacing: 0) {
                            item.color
                                .frame(width: 5)
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.title)
                                        .font(.headline.weight(.bold))
                                    Spacer(minLength: 8)
                                    Text(item.level)
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(item.color)
                                }
                                Text(item.evidence)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.76))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                        }
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                        .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.14)))
                    }
                }
            }
        }
        .foregroundStyle(.white)
    }

#if !DJHUB_METADATA_ONLY
    private var playButton: some View {
        let _ = playbackProgressRevision
        let isUnavailable = recommendation != nil && didResolveRecommendation && recommendationMatch == nil
        let isResolving = recommendation != nil && isResolvingRecommendation
        let resumeChannel = playbackPreloadCandidate ?? detailChannel
        let resumePosition = isUnavailable || isResolving
            ? nil
            : PlaybackProgressStore.resumePosition(for: resumeChannel)
        let totalDuration = resumeChannel.runtimeSeconds
            ?? details?.runtimeSeconds
            ?? tmdbDetails?.runtimeMinutes.map { TimeInterval($0 * 60) }
            ?? PlaybackProgressStore.duration(for: resumeChannel)
        let progress = resumePosition.map { position -> Double in
            guard let totalDuration, totalDuration > 0 else { return 0 }
            return min(max(position / totalDuration, 0), 1)
        }
        return Button {
            if isUnavailable, let recommendation {
                notice = mediaConfigurations.isEmpty
                    ? "请先添加 Emby、Jellyfin 或旧版资料库；添加后会自动匹配同名影片。"
                    : "已检查连接的媒体库，没有找到《\(recommendation.title)》。"
            } else if !isResolving {
                var selected = recommendationMatch ?? selectedSeasonEpisodes.first ?? detailChannel
                if recommendationMatch == nil,
                   let resumeEpisode = selectedSeasonEpisodes.first(where: {
                       PlaybackProgressStore.resumePosition(for: $0) != nil
                   }) {
                    selected = resumeEpisode
                }
                selected = applyingSelectedMediaVersion(to: selected)
                resumeSavedProgressOnNextOpen = resumePosition != nil
                openPlayback(selected)
            }
        } label: {
            ZStack {
                GeometryReader { geometry in
                    let capsuleWidth = max(0, geometry.size.width)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(
                                isUnavailable
                                    ? Color.white.opacity(0.06)
                                    : Color.white.opacity(resumePosition == nil ? 0.08 : 0.05)
                            )

                        if resumePosition != nil, let progress, progress > 0 {
                            Rectangle()
                                .fill(Color.white.opacity(0.38))
                                .frame(width: min(capsuleWidth, max(8, capsuleWidth * progress)))
                        }
                    }
                    .clipShape(Capsule())
                    .background {
                        if #available(iOS 26.0, *) {
                            Color.clear
                                .glassEffect(.regular, in: Capsule())
                        } else {
                            Capsule()
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .overlay(Capsule().stroke(.white.opacity(isUnavailable ? 0.24 : 0.34), lineWidth: 0.8))
                }

                Group {
                    if let resumePosition {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("继续播放")
                                    .font(.subheadline.weight(.heavy))
                                Text("上次播放到 \(resumeTimeText(resumePosition))")
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        HStack(spacing: 10) {
                            if isResolving {
                                ProgressView().tint(.white.opacity(0.86))
                                Text("查找资源")
                            } else {
                                Image(systemName: isUnavailable ? "play.slash" : "play.fill")
                                Text(isUnavailable ? "暂无资源" : "播放")
                            }
                        }
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .foregroundStyle(isUnavailable ? .white.opacity(0.48) : .white.opacity(0.96))
            .frame(width: detailActionButtonWidth)
            .frame(height: resumePosition == nil ? 48 : 56)
            .contentShape(Capsule())
        }
        .buttonStyle(RoveMotionButtonStyle())
        .frame(maxWidth: .infinity)
    }

    private func openPlayback(_ channel: Channel) {
        isPlaybackCoverTransitioning = true
        playbackChannel = channel
    }
#else
    private func openPlayback(_ channel: Channel) {}
#endif

    /// Keep the resource-version capsule and the primary play capsule on the
    /// same vertical edges, including on compact iPhones and iPad split view.
    private var detailActionButtonWidth: CGFloat {
        min(max(UIScreen.main.bounds.width - 96, 260), 340)
    }

    private func resumeTimeText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let remainingSeconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
            : String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private var topControls: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background {
                        if #available(iOS 26.0, *) {
                            Color.clear.glassEffect(.regular, in: Circle())
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                    .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 0.8))
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var mediaVersionPicker: some View {
        let versions = details?.mediaVersions ?? []
        if versions.count > 1 {
            Button {
                showingMediaVersionPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                    Text(selectedMediaVersionTitle(versions))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(width: detailActionButtonWidth, height: 40)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.8))
            }
            .accessibilityLabel("选择资源版本")
        }
    }

    private var selectedMediaVersionKey: String? {
        guard let selectedMediaSourceID else { return nil }
        return "\(selectedMediaConfigurationID?.uuidString ?? "local")|\(selectedMediaSourceID)"
    }

    private var mediaVersionPickerHeight: CGFloat {
        let count = details?.mediaVersions?.count ?? 0
        // Keep the picker compact for the common one-version case. More
        // versions still scroll inside the sheet instead of leaving a large
        // empty area below the content.
        let desired = 230 + CGFloat(min(count, 6)) * 100
        return min(max(desired, 350), UIScreen.main.bounds.height * 0.84)
    }

    private func selectMediaVersion(_ version: MetadataVersion?) {
        guard let version else {
            selectedMediaSourceID = nil
            selectedMediaConfigurationID = nil
            selectedMediaItemID = nil
            return
        }
        selectedMediaSourceID = version.id
        selectedMediaConfigurationID = version.serverConfigurationID
        selectedMediaItemID = version.serverItemID
    }

    private func selectedMediaVersionTitle(_ versions: [MetadataVersion]) -> String {
        guard let selectedKey = selectedMediaVersionKey,
              let selected = versions.first(where: { $0.selectionKey == selectedKey }) else {
            return "资源版本 · 自动选择"
        }
        let server = selected.serverName.map { " · \($0)" } ?? ""
        return "资源版本 · \(selected.displayName)\(server)"
    }

    @ViewBuilder
    private var episodesSection: some View {
        if !episodes.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Menu {
                        ForEach(availableSeasons, id: \.self) { season in
                            Button("第 \(season) 季") {
                                selectedSeason = season
                                episodeRangeStart = 0
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("第 \(selectedSeason) 季")
                            Image(systemName: "chevron.down")
                                .font(.subheadline.weight(.bold))
                        }
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                    }
                    Spacer()
                    Button {
                        withAnimation(reduceMotion ? nil : RoveMotion.quick) {
                            showsAllEpisodesDestination = true
                        }
                    } label: {
                        Text("查看全部")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(visibleEpisodes) { episode in
                            RoveDetailEpisodeCard(channel: episode) {
                                openPlayback(episode)
                            }
                        }
                    }
                }

                if selectedSeasonEpisodes.count > 10 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(stride(from: 0, to: selectedSeasonEpisodes.count, by: 10).map { $0 }, id: \.self) { start in
                                Button("\(start + 1)-\(min(start + 10, selectedSeasonEpisodes.count))") {
                                    episodeRangeStart = start
                                }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(episodeRangeStart == start ? .black : .white.opacity(0.78))
                                .padding(.horizontal, 18)
                                .frame(height: 42)
                                .background(
                                    episodeRangeStart == start ? Color.white.opacity(0.90) : Color.white.opacity(0.10),
                                    in: Capsule()
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var availableSeasons: [Int] {
        Array(Set(episodes.map(seasonNumber(for:)))).sorted()
    }

    private var selectedSeasonEpisodes: [Channel] {
        episodes.filter { seasonNumber(for: $0) == selectedSeason }
    }

    private var visibleEpisodes: [Channel] {
        let start = min(episodeRangeStart, max(0, selectedSeasonEpisodes.count - 1))
        return Array(selectedSeasonEpisodes.dropFirst(start).prefix(10))
    }

    private func seasonNumber(for item: Channel) -> Int {
        number(in: item.group, pattern: #"第\s*(\d+)\s*季"#) ?? 1
    }

    private func episodeNumber(for item: Channel) -> Int {
        number(in: item.name, pattern: #"第\s*(\d+)\s*集"#) ?? Int.max
    }

    private func number(in value: String, pattern: String) -> Int? {
        guard let range = value.range(of: pattern, options: .regularExpression) else { return nil }
        return Int(value[range].filter(\.isNumber))
    }

    @ViewBuilder
    private var trailerShelf: some View {
        if let trailers = tmdbDetails?.trailers, !trailers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("预告片")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(trailers) { trailer in
                            Button {
                                guard let url = trailer.playbackURL else { return }
                                openURL(url)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack {
                                        TMDBRemoteArtwork(
                                            url: trailer.thumbnailURL,
                                            title: trailer.name
                                        )
                                        .frame(width: 276, height: 155)

                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .offset(x: 1)
                                            }
                                            .overlay {
                                                Circle()
                                                    .stroke(.white.opacity(0.28), lineWidth: 0.8)
                                            }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(.white.opacity(0.12), lineWidth: 1)
                                    }

                                    Text(trailer.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .frame(width: 276, alignment: .leading)
                                }
                            }
                            .buttonStyle(RoveMotionButtonStyle())
                            .accessibilityLabel("播放预告片：\(trailer.name)")
                        }
                    }
                }
            }
        } else if isLoadingTMDBDetails {
            VStack(alignment: .leading, spacing: 12) {
                Text("预告片")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoveArtworkSkeleton()
                                .frame(width: 276, height: 155)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var artworkShelf: some View {
        if let tmdbDetails {
            let hasArtwork = !(tmdbDetails.backdropPaths ?? []).isEmpty
                || !(tmdbDetails.posterPaths ?? []).isEmpty
                || !(tmdbDetails.logoPaths ?? []).isEmpty
            if hasArtwork {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 4) {
                        ForEach(RoveDetailArtworkTab.allCases) { tab in
                            Button {
                                withAnimation(reduceMotion ? nil : RoveMotion.quick) {
                                    selectedArtworkTab = tab
                                }
                            } label: {
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(selectedArtworkTab == tab ? .white : .white.opacity(0.72))
                                    .frame(minWidth: tab == .logos ? 62 : 58, minHeight: 36)
                                    .padding(.horizontal, 4)
                                    .background(
                                        selectedArtworkTab == tab
                                            ? Color.white.opacity(0.22)
                                            : .clear,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .roveLiquidGlass(in: Capsule())

                    let paths = artworkPaths(for: selectedArtworkTab, details: tmdbDetails)
                    if paths.isEmpty {
                        Text("暂无此类图片")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.60))
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(Array(paths.prefix(24).enumerated()), id: \.element) { index, path in
                                    Button {
                                        openArtworkViewer(paths: paths, selectedIndex: index)
                                    } label: {
                                        TMDBRemoteArtwork(
                                            url: artworkURL(path: path, tab: selectedArtworkTab),
                                            title: displayTitle,
                                            contentMode: selectedArtworkTab == .logos ? .fit : .fill
                                        )
                                        .frame(
                                            width: artworkWidth(for: selectedArtworkTab),
                                            height: artworkHeight(for: selectedArtworkTab)
                                        )
                                        .background(.white.opacity(selectedArtworkTab == .logos ? 0.08 : 0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(.white.opacity(0.12), lineWidth: 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .accessibilityLabel("查看\(selectedArtworkTab.rawValue)")
                                }
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
            }
        } else if isLoadingTMDBDetails {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(RoveDetailArtworkTab.allCases) { tab in
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(minWidth: tab == .logos ? 62 : 58, minHeight: 36)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(4)
                .roveLiquidGlass(in: Capsule())

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoveArtworkSkeleton()
                                .frame(
                                    width: artworkWidth(for: selectedArtworkTab),
                                    height: artworkHeight(for: selectedArtworkTab)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(.white.opacity(0.10), lineWidth: 1)
                                }
                        }
                    }
                }
            }
        }
    }

    private func artworkPaths(
        for tab: RoveDetailArtworkTab,
        details: TMDBMovieDetails
    ) -> [String] {
        switch tab {
        case .stills: details.backdropPaths ?? []
        case .posters: details.posterPaths ?? []
        case .logos: details.logoPaths ?? []
        }
    }

    private func artworkURL(path: String, tab: RoveDetailArtworkTab) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        return RoveAPISettings.tmdbImageURL(
            size: tab == .posters ? "w500" : (tab == .logos ? "w500" : "w780"),
            path: path
        )
    }

    private func openArtworkViewer(paths: [String], selectedIndex: Int) {
        let values = paths.prefix(24).compactMap { artworkURL(path: $0, tab: selectedArtworkTab) }
        guard !values.isEmpty else { return }
        artworkViewerRequest = RoveArtworkViewerRequest(
            urls: values,
            titles: values.map { _ in selectedArtworkTab.rawValue },
            initialIndex: min(max(selectedIndex, 0), values.count - 1)
        )
    }

    private func artworkWidth(for tab: RoveDetailArtworkTab) -> CGFloat {
        switch tab {
        case .stills: 276
        case .posters: 148
        case .logos: 232
        }
    }

    private func artworkHeight(for tab: RoveDetailArtworkTab) -> CGFloat {
        switch tab {
        case .stills: 155
        case .posters: 220
        case .logos: 110
        }
    }

    @ViewBuilder
    private var peopleShelf: some View {
        if let tmdbPeople = tmdbDetails?.people, !tmdbPeople.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("演职人员")
                        .font(.title2.weight(.heavy))
                    Spacer()
                    Button("全部") {
                        showingAllPeople = true
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(tmdbPeople.prefix(20)) { person in
                            Button {
                                selectedPerson = person
                            } label: {
                                TMDBPersonCard(person: person)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .foregroundStyle(.white)
        } else if recommendation != nil, isLoadingTMDBDetails {
            detailPeopleSkeleton
        } else if let details, !details.people.isEmpty, let configurationID {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("演职人员")
                        .font(.title2.weight(.heavy))
                    Spacer()
                    Button("全部") {
                        showingAllPeople = true
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(details.people.prefix(16)) { person in
                            Button {
                                openServerPerson(person)
                            } label: {
                                ZStack {
                                    RovePersonCard(configurationID: configurationID, person: person)
                                }
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .foregroundStyle(.white)
        }
    }

    private var detailPeopleSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("演职人员")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 7) {
                            RoveArtworkSkeleton()
                                .frame(width: 112, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            RoveShimmerBlock(cornerRadius: 5)
                                .frame(width: 82, height: 14)
                            RoveShimmerBlock(cornerRadius: 4)
                                .frame(width: 56, height: 11)
                        }
                        .frame(width: 112, alignment: .leading)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func openServerPerson(_ person: MetadataCreditPerson) {
        guard let configurationID else { return }
        selectedServerPerson = RoveServerPersonSelection(
            person: person,
            configurationID: configurationID
        )
    }

    @ViewBuilder
    private var streamInformationSection: some View {
        if let streams = details?.streams, !streams.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("音视频字幕信息")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(streams) { stream in
                            VStack(alignment: .leading, spacing: 9) {
                                Label(streamTypeTitle(stream.type), systemImage: streamTypeIcon(stream.type))
                                    .font(.headline.weight(.bold))
                                Text(stream.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                streamValue("语言", stream.language)
                                streamValue("编码", stream.codec?.uppercased())
                                if let width = stream.width, let height = stream.height {
                                    streamValue("分辨率", "\(width)x\(height)")
                                }
                                if let frameRate = stream.frameRate {
                                    streamValue("帧率", String(format: "%.3g fps", frameRate))
                                }
                                if let channels = stream.channels {
                                    streamValue("声道", "\(channels) ch")
                                }
                                if let sampleRate = stream.sampleRate {
                                    streamValue("采样率", "\(sampleRate) Hz")
                                }
                                if let bitRate = stream.bitRate {
                                    streamValue("比特率", "\(bitRate / 1000) kbps")
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(16)
                            .frame(width: 250, alignment: .topLeading)
                            .frame(minHeight: 220, alignment: .topLeading)
                            .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.14)))
                        }
                    }
                }
            }
        } else if recommendation != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("音视频字幕信息")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                Label(
                    isResolvingRecommendation
                        ? "正在匹配媒体库资源，匹配后显示真实视频、声道和字幕参数"
                        : "TMDB 不提供文件声道；匹配到 Emby、Jellyfin 或旧版资料库资源后显示真实参数",
                    systemImage: isResolvingRecommendation ? "magnifyingglass" : "waveform"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
                .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.14)))
            }
            .foregroundStyle(.white)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("音视频字幕信息")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                Label(
                    "加载媒体文件后显示真实视频、声道和字幕参数",
                    systemImage: "waveform"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
                .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.14)))
            }
            .foregroundStyle(.white)
        }
    }

    private func streamTypeTitle(_ type: String) -> String {
        switch type.lowercased() {
        case "video": "视频"
        case "audio": "音频"
        default: "字幕"
        }
    }

    private func streamTypeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "video": "video.fill"
        case "audio": "music.note"
        default: "captions.bubble.fill"
        }
    }

    @ViewBuilder
    private func streamValue(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            Text("\(title)：\(value)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.74))
        }
    }

    @ViewBuilder
    private var studiosSection: some View {
        let studios = tmdbDetails?.studios ?? details?.studios ?? []
        if !studios.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(recommendation?.djhubID != nil ? "出品商 / 播出平台" : "制片方")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(studios, id: \.self) { studio in
                            Text(studio)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 190, height: 92)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var relatedShelf: some View {
        if serverRelatedChannels.isEmpty,
           let relatedMovies = tmdbDetails?.relatedMovies,
           !relatedMovies.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("相关内容")
                        .font(.title2.weight(.heavy))
                    Spacer()
                    Button("全部") {
                        showingAllRelated = true
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(relatedMovies, id: \.identity) { movie in
                            let transitionID = "detail-related-tmdb-\(movie.identity)"
                            Button {
                                selectedRelatedHeroID = transitionID
                                Task { @MainActor in
                                    await Task.yield()
                                    guard selectedRelatedHeroID == AnyHashable(transitionID) else { return }
                                    selectedRelatedRecommendation = movie
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    TMDBRemoteArtwork(url: movie.backdropURL, title: movie.title)
                                        .frame(width: 250, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .roveHeroTransitionSource(
                                            id: transitionID,
                                            namespace: relatedHeroNamespace
                                        )
                                    Text(movie.title)
                                        .font(.subheadline.weight(.bold))
                                        .lineLimit(1)
                                    Text(movie.year > 0 ? String(movie.year) : movie.genres.prefix(2).joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.70))
                                }
                                .frame(width: 250, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .foregroundStyle(.white)
        } else if recommendation != nil, isLoadingTMDBDetails {
            detailRelatedSkeleton
        } else if !relatedChannels.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("相关内容")
                        .font(.title2.weight(.heavy))
                    Spacer()
                    Button("全部") {
                        showingAllRelated = true
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 88, minHeight: 44)
                    .contentShape(Rectangle())
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(relatedChannels) { item in
                            let transitionID = "detail-related-channel-\(item.id.uuidString)"
                            Button {
                                selectedRelatedHeroID = transitionID
                                selectedRelatedChannel = item
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    RoveArtworkView(channel: item, landscape: true)
                                        .frame(width: 250, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .roveHeroTransitionSource(
                                            id: transitionID,
                                            namespace: relatedHeroNamespace
                                        )
                                    Text(item.name)
                                        .font(.subheadline.weight(.bold))
                                        .lineLimit(1)
                                    Text(item.productionYear.map(String.init) ?? library.displayGroup(for: item))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.70))
                                }
                                .frame(width: 250, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .foregroundStyle(.white)
        }
    }

    private var detailRelatedSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("相关内容")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 7) {
                            RoveArtworkSkeleton()
                                .frame(width: 250, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            RoveShimmerBlock(cornerRadius: 5)
                                .frame(width: 164, height: 14)
                            RoveShimmerBlock(cornerRadius: 4)
                                .frame(width: 72, height: 11)
                        }
                        .frame(width: 250, alignment: .leading)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var djhubDetailURL: URL? {
        guard let id = recommendation?.djhubID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty else { return nil }
        return DJHUBAPIClient.baseURL
            .appendingPathComponent("drama", isDirectory: true)
            .appendingPathComponent(id, isDirectory: false)
    }

    @ViewBuilder
    private var djhubSourceAttribution: some View {
        if let url = djhubDetailURL {
            Link(destination: url) {
                HStack(spacing: 5) {
                    Text("数据来源：DJHUB")
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.bold))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.70))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开这部短剧在 DJHUB 网站的详情页")
        }
    }

    @MainActor
    private func resolveRecommendationResource() async {
        guard let recommendation else { return }
        guard recommendation.djhubID == nil else {
            isResolvingRecommendation = false
            didResolveRecommendation = true
            recommendationMatch = nil
            return
        }
        isResolvingRecommendation = true
        didResolveRecommendation = false
        recommendationMatch = nil
        defer {
            isResolvingRecommendation = false
            didResolveRecommendation = true
        }

        var providerIDs = ["tmdb.\(recommendation.id)"]
        if let imdbID = tmdbDetails?.imdbID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !imdbID.isEmpty {
            providerIDs.append("imdb.\(imdbID)")
        }
        if let tvdbID = tmdbDetails?.tvdbID {
            providerIDs.append("tvdb.\(tvdbID)")
        }

        let providerMatches = await library.searchMediaServersByProviderIDs(
            providerIDs,
            // Most servers store provider IDs on the Series item, but some
            // Emby libraries only expose them on an Episode. Query both so a
            // TMDB TV page never loses its playable server relationship.
            includeItemTypes: recommendation.isTV ? "Series,Episode" : "Movie"
        )

        var matchesByConfiguration: [UUID: Channel] = [:]
        for configuration in mediaConfigurations {
            let matches = providerMatches.filter {
                mediaConfigurationID(for: $0) == configuration.id
            }
            if let match = bestProviderRecommendationMatch(
                in: matches,
                year: recommendation.year,
                isTV: recommendation.isTV
            ) {
                matchesByConfiguration[configuration.id] = match
            }
        }

        // Provider IDs are the strongest match, but not every server exposes
        // them in its cached home page. Fill any missing server from its
        // locally cached items before issuing remote title searches.
        for configuration in mediaConfigurations
        where matchesByConfiguration[configuration.id] == nil {
            if let match = bestRecommendationMatch(
                for: recommendation,
                in: configuration.channels,
                isTV: recommendation.isTV
            ) {
                matchesByConfiguration[configuration.id] = match
            }
        }

        let unresolvedConfigurations = mediaConfigurations.filter {
            matchesByConfiguration[$0.id] == nil
        }
        let searchTasks = unresolvedConfigurations.map { configuration in
            Task { @MainActor () -> (UUID, Channel?) in
                for title in recommendation.searchableTitles {
                    guard !Task.isCancelled else { return (configuration.id, nil) }
                    if let results = try? await library.searchAllEmbyItems(
                        configurationID: configuration.id,
                        searchTerm: title
                    ), let match = bestRecommendationMatch(
                        for: recommendation,
                        in: results,
                        isTV: recommendation.isTV
                    ) {
                        return (configuration.id, match)
                    }
                }
                return (configuration.id, nil)
            }
        }
        for task in searchTasks {
            let (configurationID, match) = await task.value
            guard !Task.isCancelled else {
                searchTasks.forEach { $0.cancel() }
                return
            }
            if let match {
                matchesByConfiguration[configurationID] = match
            }
        }

        let allMatches = mediaConfigurations.compactMap {
            matchesByConfiguration[$0.id]
        }
        guard let match = bestProviderRecommendationMatch(
            in: allMatches,
            year: recommendation.year,
            isTV: recommendation.isTV
        ) else { return }

        let orderedLines = [match] + allMatches.filter { $0.id != match.id }
        library.registerTransientPlaybackLines(orderedLines)
        recommendationMatch = match
    }

    private func mediaConfigurationID(for channel: Channel) -> UUID? {
        switch channel.resolver {
        case .legacyLibraryB(let configurationID, _),
             .legacyLibraryA(let configurationID, _),
             .movieClaw(let configurationID, _),
             .legacyLibraryC(let configurationID, _),
             .legacyLibraryD(let configurationID, _):
            configurationID
        default:
            nil
        }
    }

    private func bestProviderRecommendationMatch(
        in channels: [Channel],
        year: Int,
        isTV: Bool
    ) -> Channel? {
        channels
            .filter { channel in
                guard channel.isMediaServerItem else { return false }
                return isTV
                    ? (channel.isMediaServerSeries || channel.isMediaServerEpisode)
                    : !channel.isMediaServerSeries
            }
            .max { lhs, rhs in
                recommendationResourceScore(lhs, year: year, isTV: isTV)
                    < recommendationResourceScore(rhs, year: year, isTV: isTV)
            }
    }

    private func bestRecommendationMatch(
        for recommendation: TMDBFeaturedMovie,
        in channels: [Channel],
        isTV: Bool
    ) -> Channel? {
        let acceptedTitles = Set(
            recommendation.searchableTitles
                .map(normalizedMediaTitle)
                .filter { !$0.isEmpty }
        )
        return channels
            .filter { channel in
                channel.isMediaServerItem
                    && (isTV
                        ? (channel.isMediaServerSeries || channel.isMediaServerEpisode)
                        : !channel.isMediaServerSeries)
                    && acceptedTitles.contains(normalizedMediaTitle(channel.name))
            }
            .max { lhs, rhs in
                recommendationResourceScore(lhs, year: recommendation.year, isTV: isTV)
                    < recommendationResourceScore(rhs, year: recommendation.year, isTV: isTV)
            }
    }

    private func recommendationResourceScore(
        _ channel: Channel,
        year: Int,
        isTV: Bool = false
    ) -> Int {
        var score = 100
        if let productionYear = channel.productionYear {
            score += productionYear == year ? 30 : -abs(productionYear - year) * 10
        }
        if channel.mediaServerItemType?.caseInsensitiveCompare("Movie") == .orderedSame {
            score += 10
        }
        // Prefer a Series node because it carries the parent ID needed to
        // load every season. An Episode remains a valid fallback for servers
        // that only expose provider IDs on episode records.
        if isTV {
            if channel.isMediaServerSeries { score += 24 }
            else if channel.isMediaServerEpisode { score += 8 }
        }
        return score
    }

    private func normalizedMediaTitle(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }
}

private struct MediaVersionSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ChannelLibrary
    @ObservedObject private var badgeLibrary = RoveBadgeLibrary.shared
    let versions: [MetadataVersion]
    let selectedKey: String?
    let badgeText: String
    let backgroundImage: UIImage?
    let backgroundColor: UIColor
    let onSelect: (MetadataVersion?) -> Void

    @State private var qualityFilter = "全部"
    @State private var rangeFilter = "全部"
    @State private var bitRateFilter = "全部"
    @State private var frameRateFilter = "全部"
    @State private var subtitleFilter = "全部"
    @State private var scrollOffset: CGFloat = 0

    private var qualities: [String] {
        ["全部"] + Array(Set(versions.compactMap(\.qualityLabel))).sorted {
            $0.localizedStandardCompare($1) == .orderedDescending
        }
    }

    private var ranges: [String] {
        ["全部"] + Array(Set(versions.map(dynamicRangeLabel))).sorted()
    }

    private var subtitles: [String] {
        ["全部", "有字幕", "无字幕"]
    }

    private var bitRates: [String] {
        ["全部"] + Array(Set(versions.compactMap(\.bitRateLabel))).sorted {
            $0.localizedStandardCompare($1) == .orderedDescending
        }
    }

    private var frameRates: [String] {
        ["全部"] + Array(Set(versions.compactMap { version in
            version.frameRate.map { String(format: "%.0f fps", $0) }
        })).sorted {
            $0.localizedStandardCompare($1) == .orderedDescending
        }
    }

    private var filteredVersions: [MetadataVersion] {
        versions.filter { version in
            (qualityFilter == "全部" || version.qualityLabel == qualityFilter)
                && (rangeFilter == "全部" || dynamicRangeLabel(version) == rangeFilter)
                && (bitRateFilter == "全部" || version.bitRateLabel == bitRateFilter)
                && (frameRateFilter == "全部" || version.frameRate.map { String(format: "%.0f fps", $0) } == frameRateFilter)
                && (subtitleFilter == "全部" || (subtitleFilter == "有字幕") == hasSubtitles(version))
        }
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let fade = min(max(-scrollOffset / 110, 0), 1)
                ZStack {
                    if let backgroundImage {
                        Image(uiImage: backgroundImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .blur(radius: 30)
                            .opacity(0.34 * (1 - fade))
                            .scaleEffect(1.12)
                    }
                    Color.black.opacity(0.42 + 0.42 * fade)
                    Color(uiColor: backgroundColor).opacity(0.18 * (1 - fade))
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.28 * (1 - fade)),
                            Color(uiColor: backgroundColor).opacity(0.42 * (1 - fade))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Color.black.opacity(0.96 * fade)
                }
                .clipped()
                .ignoresSafeArea()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: RoveMediaVersionScrollOffsetKey.self,
                                value: proxy.frame(in: .named("rove-media-version-scroll")).minY
                            )
                    }
                    .frame(height: 0)

                    HStack {
                        Text("资源")
                            .font(.system(size: 20, weight: .bold))
                        Spacer()
                        Button {
                            qualityFilter = "全部"
                            rangeFilter = "全部"
                            bitRateFilter = "全部"
                            frameRateFilter = "全部"
                            subtitleFilter = "全部"
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("刷新资源筛选")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    filterBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedKey == nil ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedKey == nil ? .white : .white.opacity(0.45))
                            Text("自动选择")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(versions.count) 个版本")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.52))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    LazyVStack(spacing: 8) {
                        ForEach(filteredVersions, id: \.selectionKey) { version in
                            versionRow(version)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 20)
                }
                .roveDarkLiquidGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 7)
                .padding(.top, 7)
                .padding(.bottom, 8)
            }
            .coordinateSpace(name: "rove-media-version-scroll")
            .scrollIndicators(.hidden)
            .onPreferenceChange(RoveMediaVersionScrollOffsetKey.self) { value in
                scrollOffset = min(0, value)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterMenu(title: "画质", value: qualityFilter, options: qualities) { qualityFilter = $0 }
                filterMenu(title: "动态范围", value: rangeFilter, options: ranges) { rangeFilter = $0 }
                filterMenu(title: "比特率", value: bitRateFilter, options: bitRates) { bitRateFilter = $0 }
                filterMenu(title: "帧率", value: frameRateFilter, options: frameRates) { frameRateFilter = $0 }
                filterMenu(title: "字幕", value: subtitleFilter, options: subtitles) { subtitleFilter = $0 }
            }
        }
    }

    private func filterMenu(
        title: String,
        value: String,
        options: [String],
        onChange: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    onChange(option)
                } label: {
                    if option == value {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.62))
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
    }

    private func versionRow(_ version: MetadataVersion) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                onSelect(version)
                dismiss()
            } label: {
                HStack(alignment: .top, spacing: 9) {
                    serverIcon(for: version)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(version.serverName ?? "媒体服务器")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        metricLine(version)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: selectedKey == version.selectionKey ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedKey == version.selectionKey ? .white : .white.opacity(0.28))
                        .font(.title3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Keep the badge strip outside the selection button so its
            // embedded web view receives horizontal drag gestures.
            if !badgeLibrary.matchingRules(in: badgeMatchText(for: version)).isEmpty {
                RoveBadgeStrip(matchText: badgeMatchText(for: version), height: 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .roveDarkLiquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selectedKey == version.selectionKey ? .white.opacity(0.34) : .white.opacity(0.035), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func serverIcon(for version: MetadataVersion) -> some View {
        if let id = version.serverConfigurationID,
           let configuration = library.configurations.first(where: { $0.id == id }) {
            RoveServerBrandIcon(configuration: configuration, size: 28)
        } else {
            let kind = version.serverKind?.lowercased() ?? ""
            let symbol = kind.contains("jelly") ? "film.fill" : (kind.contains("feiniu") ? "cloud.fill" : "play.tv.fill")
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.14), in: Circle())
        }
    }

    private func badgeMatchText(for version: MetadataVersion) -> String {
        let audioText: String? = version.audioTracks.map { tracks in
            tracks.joined(separator: " ")
        }
        let subtitleText: String? = version.subtitleTracks.map { tracks in
            tracks.joined(separator: " ")
        }
        let technicalValues: [String] = [
            badgeText,
            version.name,
            version.serverName,
            version.container,
            version.qualityLabel,
            dynamicRangeLabel(version),
            version.bitRateLabel,
            version.frameRate.map { String(format: "%.0f fps", $0) },
            audioText,
            subtitleText
        ].compactMap { $0 }
        return technicalValues.joined(separator: " ")
    }

    private func metricLine(_ version: MetadataVersion) -> some View {
        let values = [
            version.qualityLabel,
            dynamicRangeLabel(version),
            version.bitRateLabel,
            version.frameRate.map { String(format: "%.0f fps", $0) },
            version.sizeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) },
            hasSubtitles(version) ? "字幕 \(version.subtitleTracks?.count ?? 1)" : "无字幕"
        ].compactMap { $0 }
        return Text(values.joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(.white.opacity(0.64))
            .lineLimit(2)
    }

    private func dynamicRangeLabel(_ version: MetadataVersion) -> String {
        guard let value = version.dynamicRange?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return "SDR"
        }
        return value.localizedCaseInsensitiveContains("hdr") ? value.uppercased() : value
    }

    private func hasSubtitles(_ version: MetadataVersion) -> Bool {
        !(version.subtitleTracks ?? []).isEmpty
    }
}

private struct RoveMediaVersionScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Full-screen related-content page. This intentionally uses the same fixed
/// three-column poster grid as the category pages instead of overlaying the
/// detail hero and tab bar.
private struct RoveRelatedGridPage: View {
    let movies: [TMDBFeaturedMovie]
    let channels: [Channel]
    @State private var selectedMovie: TMDBFeaturedMovie?
    @State private var selectedChannel: Channel?
    @Namespace private var mediaHeroNamespace

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 12),
        count: 3
    )

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                if !movies.isEmpty {
                    ForEach(movies, id: \.identity) { movie in
                        Button { selectedMovie = movie } label: {
                            RovePosterGridCard(
                                title: movie.title,
                                yearText: movie.year > 0 ? String(movie.year) : "即将上映",
                                rating: movie.displayRating,
                                transitionID: "tmdb-\(movie.identity)",
                                transitionNamespace: mediaHeroNamespace
                            ) {
                                TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                            }
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                    }
                } else {
                    ForEach(channels) { channel in
                        Button { selectedChannel = channel } label: {
                            RovePosterGridCard(
                                title: channel.name,
                                yearText: channel.productionYear.map(String.init) ?? "年份未知",
                                rating: channel.communityRating,
                                transitionID: "channel-\(channel.id.uuidString)",
                                transitionNamespace: mediaHeroNamespace
                            ) {
                                RoveArtworkView(channel: channel, landscape: false)
                            }
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color.black)
        .navigationTitle("相关内容")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $selectedMovie) { movie in
            RoveMediaDetailView(recommendation: movie)
                .roveHeroNavigationTransition(
                    id: "tmdb-\(movie.identity)",
                    namespace: mediaHeroNamespace
                )
        }
        .navigationDestination(item: $selectedChannel) { channel in
            RoveMediaDetailView(channel: channel)
                .roveHeroNavigationTransition(
                    id: "channel-\(channel.id.uuidString)",
                    namespace: mediaHeroNamespace
                )
        }
    }
}

private struct RovePeopleGridPage: View {
    let people: [TMDBMoviePerson]
    @State private var selectedPerson: TMDBMoviePerson?

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 12),
        count: 3
    )

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 30) {
                ForEach(people) { person in
                    Button { selectedPerson = person } label: {
                        VStack(spacing: 8) {
                            TMDBPersonCircle(person: person)
                            Text(person.name)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity)
                            Text(person.role)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.66))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color.black)
        .navigationTitle("演职人员")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $selectedPerson) { person in
                if person.tmdbID < 0 {
                    DJHUBPersonDetailView(person: person)
                } else {
                    TMDBPersonDetailView(person: person)
                }
        }
    }
}

private struct RoveServerPeopleGridPage: View {
    let people: [MetadataCreditPerson]
    let configurationID: UUID
    let onSelect: (MetadataCreditPerson) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 12),
        count: 3
    )

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 30) {
                ForEach(people) { person in
                    Button { onSelect(person) } label: {
                        RoveServerPersonCircleCard(
                            configurationID: configurationID,
                            person: person
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color.black)
        .navigationTitle("演职人员")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct RoveServerPersonDetailView: View {
    @EnvironmentObject private var library: ChannelLibrary
    let person: MetadataCreditPerson
    let configurationID: UUID
    @State private var channels: [Channel] = []
    @State private var selectedChannel: Channel?
    @State private var isLoading = true
    @State private var loadFailed = false

    private let columns = [GridItem(.adaptive(minimum: 105), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 18) {
                    RovePersonCard(configurationID: configurationID, person: person)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(person.name)
                            .font(.title2.weight(.heavy))
                        if let role = person.role ?? person.type, !role.isEmpty {
                            Text(role)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !isLoading {
                            Text("\(channels.count) 部服务器作品")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }

                if isLoading {
                    ProgressView("正在读取服务器作品")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if channels.isEmpty {
                    ContentUnavailableView(
                        loadFailed ? "读取失败" : "暂无作品",
                        systemImage: loadFailed ? "exclamationmark.triangle" : "film.stack",
                        description: Text(loadFailed ? "无法从当前媒体服务器读取人物作品" : "当前服务器没有返回该人物的影视作品")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("服务器作品")
                            .font(.title3.weight(.bold))
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                            ForEach(channels) { channel in
                                Button { selectedChannel = channel } label: {
                                    RovePosterGridCard(
                                        title: channel.name,
                                        yearText: channel.productionYear.map(String.init) ?? "年份未知",
                                        rating: channel.communityRating
                                    ) {
                                        RoveArtworkView(channel: channel, landscape: false)
                                    }
                                }
                                .buttonStyle(RoveMotionButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedChannel) { channel in
            RoveMediaDetailView(channel: channel)
        }
        .task(id: "\(configurationID.uuidString)|\(person.id)") {
            isLoading = true
            loadFailed = false
            do {
                channels = try await library.loadItemsForPerson(
                    configurationID: configurationID,
                    personID: person.id,
                    limit: 60
                )
            } catch {
                channels = []
                loadFailed = true
            }
            isLoading = false
        }
    }
}

private struct RoveRelatedBrowseOverlay: View {
    enum SortOption: String, CaseIterable {
        case rating = "评分"
        case date = "最后更新时间"
        case year = "年份"
        case title = "标题"
    }

    let title: String
    let movies: [TMDBFeaturedMovie]
    let channels: [Channel]
    let backgroundImage: UIImage?
    let onClose: () -> Void
    let onMovie: (TMDBFeaturedMovie) -> Void
    let onChannel: (Channel) -> Void
    @State private var sortOption: SortOption = .rating
    @State private var descending = true

    private var sortedMovies: [TMDBFeaturedMovie] {
        movies.sorted { lhs, rhs in
            switch sortOption {
            case .rating: return descending ? lhs.rating > rhs.rating : lhs.rating < rhs.rating
            case .date, .year: return descending ? lhs.year > rhs.year : lhs.year < rhs.year
            case .title: return descending
                ? lhs.title.localizedStandardCompare(rhs.title) == .orderedDescending
                : lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }

    private var sortedChannels: [Channel] {
        channels.sorted { lhs, rhs in
            switch sortOption {
            case .rating: return descending ? (lhs.communityRating ?? 0) > (rhs.communityRating ?? 0) : (lhs.communityRating ?? 0) < (rhs.communityRating ?? 0)
            case .date, .year: return descending ? (lhs.productionYear ?? 0) > (rhs.productionYear ?? 0) : (lhs.productionYear ?? 0) < (rhs.productionYear ?? 0)
            case .title: return descending
                ? lhs.name.localizedStandardCompare(rhs.name) == .orderedDescending
                : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                if let backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .overlay(.black.opacity(0.74))
                }

                ScrollView {
                    Color.clear.frame(height: 1).id("related-top")
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(
                                .fixed(max(1, (UIScreen.main.bounds.width - 32 - 24) / 3)),
                                spacing: 12
                            ),
                            count: 3
                        ),
                        alignment: .leading,
                        spacing: 22
                    ) {
                        if !movies.isEmpty {
                            ForEach(sortedMovies, id: \.identity) { movie in
                                Button { onMovie(movie) } label: {
                                    RovePosterGridCard(
                                        title: movie.title,
                                        yearText: movie.year > 0 ? String(movie.year) : "即将上映",
                                        rating: movie.displayRating
                                    ) {
                                        TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                                    }
                                }
                                .buttonStyle(RoveMotionButtonStyle())
                            }
                        } else {
                            ForEach(sortedChannels) { item in
                                Button { onChannel(item) } label: {
                                    RovePosterGridCard(
                                        title: item.name,
                                        yearText: item.productionYear.map(String.init) ?? "年份未知",
                                        rating: item.communityRating
                                    ) {
                                        RoveArtworkView(channel: item, landscape: false)
                                    }
                                }
                                .buttonStyle(RoveMotionButtonStyle())
                            }
                        }
                    }
                    .frame(width: max(1, UIScreen.main.bounds.width - 32), alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 108)
                    .padding(.bottom, 44)
                }
                .scrollIndicators(.hidden)

                RoveBrowseHeader(title: title, onClose: onClose) {
                    withAnimation(.easeOut(duration: 0.24)) {
                        scrollProxy.scrollTo("related-top", anchor: .top)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .ignoresSafeArea()
        }
    }
}

private struct RovePeopleBrowseOverlay: View {
    let people: [TMDBMoviePerson]
    let backgroundImage: UIImage?
    let onClose: () -> Void
    let onSelect: (TMDBMoviePerson) -> Void

    var body: some View {
        RovePeopleBrowseChrome(title: "演职人员", backgroundImage: backgroundImage, onClose: onClose) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 30) {
                ForEach(people) { person in
                    Button { onSelect(person) } label: {
                        VStack(spacing: 8) {
                            TMDBPersonCircle(person: person)
                            Text(person.name)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(minWidth: 0, maxWidth: .infinity)
                            Text(person.role)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.66))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(minWidth: 0, maxWidth: .infinity)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RoveServerPeopleBrowseOverlay: View {
    let people: [MetadataCreditPerson]
    let configurationID: UUID
    let backgroundImage: UIImage?
    let onClose: () -> Void
    let onSelect: (MetadataCreditPerson) -> Void

    var body: some View {
        RovePeopleBrowseChrome(title: "演职人员", backgroundImage: backgroundImage, onClose: onClose) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 30) {
                ForEach(people) { person in
                    Button { onSelect(person) } label: {
                        RoveServerPersonCircleCard(configurationID: configurationID, person: person)
                            .frame(minWidth: 0, maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RovePeopleBrowseChrome<Content: View>: View {
    let title: String
    let backgroundImage: UIImage?
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                if let backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .overlay(.black.opacity(0.74))
                }
                ScrollView {
                    Color.clear.frame(height: 1).id("people-top")
                    content()
                        .frame(width: max(1, UIScreen.main.bounds.width - 32), alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 108)
                        .padding(.bottom, 44)
                }
                .scrollIndicators(.hidden)
                RoveBrowseHeader(title: title, onClose: onClose) {
                    withAnimation(.easeOut(duration: 0.24)) {
                        scrollProxy.scrollTo("people-top", anchor: .top)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .ignoresSafeArea()
        }
    }
}

private struct RoveBrowseHeader: View {
    let title: String
    let onClose: () -> Void
    let onScrollTop: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 52, height: 52)
                    .roveLiquidGlass(in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text(title)
                .font(.title2.weight(.heavy))
            Spacer()
            Button(action: onScrollTop) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 52, height: 52)
                    .roveLiquidGlass(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("回到顶部")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .background(Color.black.opacity(0.20).ignoresSafeArea(edges: .top))
    }
}

private struct RovePopularPersonAvatar: View {
    let person: TMDBMoviePerson
    let size: CGFloat
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.11))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.34, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .task(id: person.profileURL?.absoluteString) {
            image = await TMDBArtworkLoader.shared.image(for: person.profileURL)
        }
    }
}

private struct RovePopularPeopleGridView: View {
    let people: [TMDBMoviePerson]

    private let columns = [
        GridItem(.adaptive(minimum: 82, maximum: 104), spacing: 18, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: 24) {
                ForEach(people) { person in
                    NavigationLink {
                        if person.tmdbID < 0 {
                            DJHUBPersonDetailView(person: person)
                        } else {
                            TMDBPersonDetailView(person: person)
                        }
                    } label: {
                        VStack(spacing: 9) {
                            RovePopularPersonAvatar(person: person, size: 88)
                            Text(person.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("演员")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .buttonStyle(RoveMotionButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("热门人物")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct DJHUBCompanyCard: View {
    let company: DJHUBCompany
    @State private var details: DJHUBCompany?

    var body: some View {
        let value = details ?? company
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.96)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    DJHUBRemoteLogo(url: URL(string: value.logo))
                        .frame(width: 112, height: 56)
                    Text(value.name)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                    Text("\(value.workCount) 部短剧")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.56))
                }
                .frame(width: 118, alignment: .leading)

                DJHUBPosterFan(movies: value.works.map {
                    DJHUBDiscoveryService.featuredMovie(from: $0, shelves: [.shortDrama])
                })
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.08)))
        .task(id: company.id) {
            details = await DJHUBDiscoveryService.company(id: company.id)
        }
    }
}

private struct DJHUBPlatformCard: View {
    let name: String
    let movies: [TMDBFeaturedMovie]

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.96)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(red: 0.03, green: 0.45, blue: 0.60))
                    Text(name)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                    Text("播出平台")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.55))
                }
                .frame(width: 118, alignment: .leading)
                DJHUBPosterFan(movies: movies)
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.08)))
    }
}

private struct DJHUBPosterFan: View {
    let movies: [TMDBFeaturedMovie]

    var body: some View {
        ZStack {
            ForEach(Array(movies.prefix(4).enumerated()), id: \.element.identity) { index, movie in
                TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                    .frame(width: 52, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .rotationEffect(.degrees([-11, 7, -6, 10][index % 4]))
                    .offset(
                        x: [-38, 7, -26, 21][index % 4],
                        y: [-22, -30, 30, 24][index % 4]
                    )
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DJHUBRemoteLogo: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image("MediaDeckBrandMark").resizable().scaledToFit()
            }
        }
        .task(id: url?.absoluteString) {
            image = await TMDBArtworkLoader.shared.image(for: url)
        }
    }
}

private struct DJHUBPersonDetailView: View {
    let person: TMDBMoviePerson
    @State private var details: DJHUBPerson?
    @State private var profileImage: UIImage?
    @State private var selectedMovie: TMDBFeaturedMovie?
    @State private var isLoadingDetails = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 18) {
                    Group {
                        if let profileImage {
                            Image(uiImage: profileImage).resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 42))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.secondary.opacity(0.16))
                        }
                    }
                    .frame(width: 128, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 9) {
                        Text(details?.name ?? person.name).font(.title2.weight(.heavy))
                        Text("演员").foregroundStyle(.secondary)
                        Text(details?.biography.nonEmpty ?? (isLoadingDetails ? "正在加载人物介绍…" : "暂无人物介绍"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(6)
                    }
                    Spacer(minLength: 0)
                }

                if let works = details?.works, !works.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("参演短剧").font(.title3.weight(.bold))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 14)], spacing: 18) {
                            ForEach(works) { drama in
                                let movie = DJHUBDiscoveryService.featuredMovie(from: drama, shelves: [.shortDrama])
                                Button { selectedMovie = movie } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                                            .frame(height: 158)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        Text(movie.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else if isLoadingDetails {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在加载关联作品…")
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text("暂无关联作品")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedMovie) { RoveMediaDetailView(recommendation: $0) }
        .task(id: person.id) {
            async let image = TMDBArtworkLoader.shared.image(for: person.profileURL)
            profileImage = await image
            for attempt in 0..<3 {
                if let loaded = await DJHUBDiscoveryService.person(id: person.id) {
                    details = loaded
                    break
                }
                guard attempt < 2, !Task.isCancelled else { break }
                try? await Task.sleep(for: .milliseconds(700 * (attempt + 1)))
            }
            isLoadingDetails = false
        }
    }
}

private struct DJHUBCompanyDetailView: View {
    let company: DJHUBCompany
    @State private var details: DJHUBCompany?
    @State private var selectedMovie: TMDBFeaturedMovie?

    var body: some View {
        let value = details ?? company
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DJHUBRemoteLogo(url: URL(string: value.logo))
                    .frame(maxWidth: 220, minHeight: 90, maxHeight: 120, alignment: .leading)
                Text(value.name).font(.title.weight(.heavy))
                if let description = value.description.nonEmpty {
                    Text(description).foregroundStyle(.secondary)
                }
                if !value.works.isEmpty {
                    Text("出品短剧").font(.title3.weight(.bold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 14)], spacing: 18) {
                        ForEach(value.works) { drama in
                            let movie = DJHUBDiscoveryService.featuredMovie(from: drama, shelves: [.shortDrama])
                            Button { selectedMovie = movie } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    TMDBRemoteArtwork(url: movie.posterURL, title: movie.title)
                                        .frame(height: 158)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Text(movie.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(value.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedMovie) { RoveMediaDetailView(recommendation: $0) }
        .task { details = await DJHUBDiscoveryService.company(id: company.id) }
    }
}

private struct TMDBPersonCircle: View {
    let person: TMDBMoviePerson
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.white.opacity(0.12)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .task(id: person.profileURL?.absoluteString) {
            image = await TMDBArtworkLoader.shared.image(for: person.profileURL)
        }
    }
}

private struct RoveServerPersonCircleCard: View {
    let configurationID: UUID
    let person: MetadataCreditPerson
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Color.white.opacity(0.12)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            Text(person.name)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            Text(person.role ?? person.type ?? "")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .task(id: person.id) {
            guard let itemID = person.imageItemID else { return }
            image = await ChannelArtworkLoader.shared.embyImage(
                configurationID: configurationID,
                itemID: itemID,
                maxWidth: 260
            )
        }
    }
}

private struct RoveEpisodeBrowseOverlay: View {
    let title: String
    let episodes: [Channel]
    @Binding var selectedSeason: Int
    let backgroundImage: UIImage?
    let onClose: () -> Void
    let onPlay: (Channel) -> Void

    private var seasons: [Int] {
        Array(Set(episodes.map { seasonNumber(for: $0) })).sorted()
    }

    private var visibleEpisodes: [Channel] {
        episodes
            .filter { seasonNumber(for: $0) == selectedSeason }
            .sorted { episodeNumber(for: $0) < episodeNumber(for: $1) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(.black.opacity(0.68))
            } else {
                Color.black.ignoresSafeArea()
            }

            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(visibleEpisodes) { episode in
                        RoveEpisodeBrowseRow(channel: episode) {
                            onPlay(episode)
                        }
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 116)
                .padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 16) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 52, height: 52)
                        .background(.black.opacity(0.56), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭剧集列表")

                Spacer()

                Text(title)
                    .font(.title3.weight(.heavy))
                    .lineLimit(1)

                Spacer()

                if seasons.count > 1 {
                    Menu {
                        ForEach(seasons, id: \.self) { season in
                            Button("第 \(season) 季") {
                                selectedSeason = season
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 52, height: 52)
                            .background(.black.opacity(0.56), in: Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 52, height: 52)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 34)
            .padding(.top, 18)
            .background {
                Color.black.opacity(0.18)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }

    private func seasonNumber(for item: Channel) -> Int {
        numericValue(in: item.group, pattern: #"第\s*(\d+)\s*季"#) ?? 1
    }

    private func episodeNumber(for item: Channel) -> Int {
        numericValue(in: item.name, pattern: #"第\s*(\d+)\s*集"#) ?? Int.max
    }

    private func numericValue(in value: String, pattern: String) -> Int? {
        guard let range = value.range(of: pattern, options: .regularExpression) else { return nil }
        return Int(value[range].filter(\.isNumber))
    }
}

private struct RoveEpisodeBrowseRow: View {
    let channel: Channel
    let action: () -> Void
    @State private var artwork: UIImage?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 26) {
                ZStack {
                    Color.white.opacity(0.10)
                    if let artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "play.rectangle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
                .frame(width: 316, height: 178)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(episodeLabel)
                        .font(.title3.weight(.heavy))
                        .lineLimit(2)
                    Text(channel.group)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: channel.id) {
            artwork = await ChannelArtworkLoader.shared.landscapeImage(for: channel, maxWidth: 700)
        }
    }

    private var episodeLabel: String {
        if let range = channel.name.range(of: #"第\s*\d+\s*集"#, options: .regularExpression) {
            return String(channel.name[range]).replacingOccurrences(of: " ", with: "")
        }
        return channel.name
    }
}

private struct RoveEpisodeListView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let episodes: [Channel]
    let initialSeason: Int
    let onPlay: (Channel) -> Void
    @State private var selectedSeason: Int

    // The all-episodes screen is intentionally always two columns. Keep this
    // explicit instead of letting the grid infer its column count from the
    // card content or the available width.
    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 14, alignment: .top),
        GridItem(.flexible(minimum: 0), spacing: 14, alignment: .top),
    ]

    init(title: String, episodes: [Channel], initialSeason: Int, onPlay: @escaping (Channel) -> Void) {
        self.title = title
        self.episodes = episodes
        self.initialSeason = initialSeason
        self.onPlay = onPlay
        _selectedSeason = State(initialValue: initialSeason)
    }

    private var seasons: [Int] {
        Array(Set(episodes.map { seasonNumber(for: $0) })).sorted()
    }

    private var visibleEpisodes: [Channel] {
        episodes
            .filter { seasonNumber(for: $0) == selectedSeason }
            .sorted { episodeNumber(for: $0) < episodeNumber(for: $1) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                    ForEach(visibleEpisodes) { episode in
                        RoveEpisodeListCard(channel: episode) {
                            onPlay(episode)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "剧集列表" : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black.opacity(0.94), for: .navigationBar)
        .toolbar {
            if seasons.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(seasons, id: \.self) { season in
                            Button("第 \(season) 季") {
                                selectedSeason = season
                            }
                        }
                    } label: {
                        Label("第 \(selectedSeason) 季", systemImage: "chevron.down")
                    }
                }
            }
        }
    }

    private func seasonNumber(for item: Channel) -> Int {
        numericValue(in: item.group, pattern: #"第\s*(\d+)\s*季"#) ?? 1
    }

    private func episodeNumber(for item: Channel) -> Int {
        numericValue(in: item.name, pattern: #"第\s*(\d+)\s*集"#) ?? Int.max
    }

    private func numericValue(in value: String, pattern: String) -> Int? {
        guard let range = value.range(of: pattern, options: .regularExpression) else { return nil }
        return Int(value[range].filter(\.isNumber))
    }
}

private struct RoveEpisodeListCard: View {
    let channel: Channel
    let action: () -> Void
    @State private var artwork: UIImage?

    // Keep the all-episodes page on the same cache size as the detail-page
    // cards. This lets a cover that was already rendered on the detail page
    // appear immediately when the user opens "查看全部".
    private let artworkMaxWidth = 520

    init(channel: Channel, action: @escaping () -> Void) {
        self.channel = channel
        self.action = action
        _artwork = State(initialValue: ChannelArtworkLoader.shared.cachedLandscapeImage(
            for: channel,
            maxWidth: artworkMaxWidth
        ))
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Color.roadCard
                    if let artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "play.rectangle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }

                Text(episodeLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .task(id: channel.id) {
            artwork = await ChannelArtworkLoader.shared.landscapeImage(
                for: channel,
                maxWidth: artworkMaxWidth
            )
        }
    }

    private var episodeLabel: String {
        if let range = channel.name.range(of: #"第\s*\d+\s*集"#, options: .regularExpression) {
            return String(channel.name[range]).replacingOccurrences(of: " ", with: "")
        }
        let name = channel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let group = channel.group.trimmingCharacters(in: .whitespacesAndNewlines)
        return group.isEmpty ? "剧集" : group
    }
}

private struct RoveDetailEpisodeCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let channel: Channel
    let action: () -> Void
    @State private var artwork: UIImage?

    init(channel: Channel, action: @escaping () -> Void) {
        self.channel = channel
        self.action = action
        _artwork = State(initialValue: ChannelArtworkLoader.shared.cachedLandscapeImage(
            for: channel,
            maxWidth: 520
        ))
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                ZStack {
                    Color.white.opacity(0.10)
                    if let artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    } else {
                        Image(systemName: "play.rectangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                .frame(width: 220, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .animation(reduceMotion ? nil : RoveMotion.quick, value: artwork != nil)

                Text(channel.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(width: 220, alignment: .leading)
            }
        }
        .buttonStyle(RoveMotionButtonStyle())
        .task(id: channel.id) {
            artwork = await ChannelArtworkLoader.shared.landscapeImage(for: channel, maxWidth: 520)
        }
    }
}

#if !DJHUB_METADATA_ONLY
private struct RoveCastDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ChannelLibrary
    @EnvironmentObject private var playback: PlaybackCoordinator
    let channel: Channel
    @ObservedObject var service: DLNACastService
    @State private var castingDeviceID: String?

    var body: some View {
        NavigationStack {
            Group {
                if service.devices.isEmpty {
                    ContentUnavailableView {
                        Label(
                            service.state == .searching ? "正在搜索设备…" : "未发现投屏设备",
                            systemImage: "dot.radiowaves.left.and.right"
                        )
                    } description: {
                        Text("请确认手机和电视连接到同一局域网。")
                    }
                } else {
                    List(service.devices) { device in
                        Button {
                            cast(to: device)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "tv")
                                    .font(.title2)
                                    .foregroundStyle(Color.roveAccent)
                                    .frame(width: 38)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if !device.detail.isEmpty {
                                        Text(device.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if castingDeviceID == device.id {
                                    ProgressView()
                                } else if service.castingDeviceID == device.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "play.circle")
                                        .foregroundStyle(Color.roveAccent)
                                }
                            }
                        }
                        .disabled(castingDeviceID != nil)
                    }
                }
            }
            .navigationTitle("投屏设备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("刷新", systemImage: "arrow.clockwise") { service.search() }
                        .labelStyle(.iconOnly)
                        .disabled(service.state == .searching)
                }
            }
            .task {
                if service.devices.isEmpty { service.search() }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func cast(to device: DLNADevice) {
        castingDeviceID = device.id
        Task {
            defer { castingDeviceID = nil }
            do {
                let url = try await library.resolveStream(for: channel)
                var resolved = channel
                resolved.streamURL = url
                resolved.resolver = nil
                guard await service.cast(channel: resolved, queue: [resolved], to: device) else { return }
                playback.pause()
                dismiss()
            } catch {
                return
            }
        }
    }
}
#endif

private struct RovePersonCard: View {
    let configurationID: UUID
    let person: MetadataCreditPerson
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                Color.white.opacity(0.12)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: 112, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(person.name)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            Text(person.role ?? person.type ?? "")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
        }
        .frame(width: 112, alignment: .leading)
        .task(id: person.id) {
            guard let itemID = person.imageItemID else { return }
            image = await ChannelArtworkLoader.shared.embyImage(
                configurationID: configurationID,
                itemID: itemID,
                maxWidth: 260
            )
        }
    }
}

private struct TMDBPersonDetailView: View {
    let person: TMDBMoviePerson
    @State private var details: TMDBPersonDetails?
    @State private var profileImage: UIImage?
    @State private var isLoading = true
    @State private var selectedMovie: TMDBFeaturedMovie?

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 18) {
                        Group {
                            if let profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 42))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.secondary.opacity(0.16))
                            }
                        }
                        .frame(width: 128, height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 9) {
                            Text(details?.name ?? person.name)
                                .font(.title2.weight(.heavy))
                            if let department = details?.knownForDepartment, !department.isEmpty {
                                Text(department)
                                    .foregroundStyle(.secondary)
                            }
                            if let birthday = details?.birthday, !birthday.isEmpty {
                                Text("出生：\(birthday)")
                                    .font(.subheadline)
                            }
                            if let place = details?.placeOfBirth, !place.isEmpty {
                                Text(place)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    if isLoading && details == nil {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                    if let biography = details?.biography.trimmingCharacters(in: .whitespacesAndNewlines), !biography.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("简介").font(.title3.weight(.bold))
                            Text(biography).foregroundStyle(.secondary)
                        }
                    }
                    if let credits = details?.credits, !credits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("参演作品").font(.title3.weight(.bold))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 14)], spacing: 18) {
                                ForEach(credits) { credit in
                                    Button {
                                        selectedMovie = movie(from: credit)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Group {
                                                if let url = credit.posterURL {
                                                    AsyncImage(url: url) { phase in
                                                        if let image = phase.image { image.resizable().scaledToFill() }
                                                        else { Color.secondary.opacity(0.16) }
                                                    }
                                                } else {
                                                    Color.secondary.opacity(0.16)
                                                }
                                            }
                                            .frame(height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            Text(credit.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                            if !credit.role.isEmpty { Text(credit.role).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                                            if let year = credit.year { Text(String(year)).font(.caption2).foregroundStyle(.tertiary) }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedMovie) { movie in
            RoveMediaDetailView(recommendation: movie)
        }
        .task {
            profileImage = await TMDBArtworkLoader.shared.image(for: person.profileURL)
            if let cached = await TMDBDiscoveryService.cachedPersonDetails(personID: person.tmdbID) {
                details = cached
            }
            if let loaded = await TMDBDiscoveryService.loadPersonDetails(personID: person.tmdbID) {
                details = loaded
            }
            isLoading = false
        }
    }

    private func movie(from credit: TMDBPersonCredit) -> TMDBFeaturedMovie {
        TMDBFeaturedMovie(
            id: credit.id,
            title: credit.title,
            originalTitle: credit.title,
            aliases: [],
            overview: "",
            year: credit.year ?? 0,
            rating: 0,
            genres: [],
            posterPath: credit.posterPath ?? "",
            backdropPath: credit.posterPath ?? "",
            shelves: []
        )
    }
}

private struct RoveNativeInteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ObserverViewController {
        ObserverViewController()
    }

    func updateUIViewController(_ controller: ObserverViewController, context: Context) {
        controller.enableInteractivePopIfAvailable()
    }

    final class ObserverViewController: UIViewController {
        private weak var previousDelegate: UIGestureRecognizerDelegate?
        private var previousIsEnabled = false
        private var configuredRecognizer: UIGestureRecognizer?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableInteractivePopIfAvailable()
        }

        override func viewDidDisappear(_ animated: Bool) {
            restoreInteractivePopIfNeeded()
            super.viewDidDisappear(animated)
        }

        func enableInteractivePopIfAvailable() {
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let navigationController,
                      navigationController.viewControllers.count > 1,
                      let recognizer = navigationController.interactivePopGestureRecognizer
                else { return }
                if configuredRecognizer !== recognizer {
                    previousDelegate = recognizer.delegate
                    previousIsEnabled = recognizer.isEnabled
                    configuredRecognizer = recognizer
                }
                recognizer.delegate = nil
                recognizer.isEnabled = true
            }
        }

        private func restoreInteractivePopIfNeeded() {
            guard let recognizer = configuredRecognizer else { return }
            recognizer.delegate = previousDelegate
            recognizer.isEnabled = previousIsEnabled
            configuredRecognizer = nil
        }
    }
}

private struct TMDBPersonCard: View {
    let person: TMDBMoviePerson
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                Color.white.opacity(0.12)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: 112, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(person.name)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            Text(person.role)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
        }
        .frame(width: 112, alignment: .leading)
        .task(id: person.profileURL?.absoluteString) {
            image = await TMDBArtworkLoader.shared.image(for: person.profileURL)
        }
    }
}

#if !DJHUB_METADATA_ONLY
private enum RoveLibraryFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case recent = "最近"
    case favorites = "收藏"

    var id: String { rawValue }
}

private struct RoveLibraryView: View {
    @EnvironmentObject private var library: ChannelLibrary
    @State private var filter = RoveLibraryFilter.all
    @State private var query = ""
    @State private var selectedChannel: Channel?

    private var channels: [Channel] {
        let base: [Channel]
        switch filter {
        case .all: base = library.channels
        case .recent: base = library.recentChannels
        case .favorites: base = library.favoriteChannels
        }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(text)
                || library.displayGroup(for: $0).localizedCaseInsensitiveContains(text)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    Picker("媒体筛选", selection: $filter) {
                        ForEach(RoveLibraryFilter.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if channels.isEmpty {
                        ContentUnavailableView(
                            query.isEmpty ? "这里还没有媒体" : "没有找到结果",
                            systemImage: query.isEmpty ? "rectangle.stack" : "magnifyingglass",
                            description: Text(query.isEmpty ? "前往来源页连接媒体服务。" : "试试其他名称或分组。")
                        )
                        .frame(maxWidth: .infinity, minHeight: 380)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 148, maximum: 230), spacing: 12)],
                            spacing: 18
                        ) {
                            ForEach(channels) { channel in
                                libraryTile(channel)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(RoveBackdrop())
            .navigationTitle("媒体库")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Text("\(channels.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, prompt: "搜索名称或分组")
            .navigationDestination(item: $selectedChannel) { channel in
                RoveMediaDetailView(channel: channel)
            }
        }
    }

    private var activeSourceSubtitle: String {
        guard let id = library.activeConfigurationID,
              let configuration = library.configurations.first(where: { $0.id == id })
        else { return "来自所有已连接来源" }
        return "当前来源 · \(configuration.name)"
    }

    private func libraryTile(_ channel: Channel) -> some View {
        Button { selectedChannel = channel } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ChannelLogoView(channel: channel, placeholderSystemName: "film.fill")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(18)
                    if library.isFavorite(channel) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                }
                .frame(height: 118)
                .background(Color.roveInk)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(channel.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(library.displayGroup(for: channel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                library.toggleFavorite(channel)
            } label: {
                Label(
                    library.isFavorite(channel) ? "取消收藏" : "加入收藏",
                    systemImage: library.isFavorite(channel) ? "bookmark.slash" : "bookmark"
                )
            }

            if let configurationID = channel.roveMediaServerConfigurationID {
                Button {
                    Task { await library.refreshConfiguration(configurationID) }
                } label: {
                    Label("更新鉴权", systemImage: "key.viewfinder")
                }
            }
        }
    }
}

private extension Channel {
    /// The source server that owns this media item. Keeping this on Channel
    /// lets every media-card context menu refresh the correct server without
    /// exposing resolver details in each card view.
    var roveMediaServerConfigurationID: UUID? {
        switch resolver {
        case .legacyLibraryB(let configurationID, _),
             .legacyLibraryA(let configurationID, _),
             .movieClaw(let configurationID, _),
             .legacyLibraryC(let configurationID, _),
             .legacyLibraryD(let configurationID, _):
            configurationID
        default:
            nil
        }
    }
}

private extension PlaylistConfiguration {
    var roveIsFileSource: Bool {
        if kind == .legacySourceC { return true }
        guard kind == .single,
              let scheme = sourceAddress.flatMap(URL.init(string:))?.scheme?.lowercased()
        else { return false }
        return ["smb", "sftp"].contains(scheme)
    }

    var roveIsIPTVSource: Bool {
        if roveIsFileSource || kind.usesMediaLibraryBrowser { return false }
        if name.localizedCaseInsensitiveContains("Plex") { return false }
        return [.subscription, .rss, .single, .local, .aggregate, .legacySourceB, .legacySourceA].contains(kind)
    }
}

private struct RoveDiscoverView: View {
    @EnvironmentObject private var library: ChannelLibrary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(RoveDeepSeekService.recommendationsEnabledKey) private var recommendationsEnabled = false
    @State private var aiRecommendations: [Channel] = []
    @State private var isLoadingRecommendations = false
    @State private var recommendationError: String?
    @State private var selectedChannel: Channel?
    @State private var selectedChannelHeroID: AnyHashable?
    @State private var selectedTMDBMovie: TMDBFeaturedMovie?
    @State private var selectedTMDBHeroID: AnyHashable?
    @State private var selectedFeaturedIndex = 0
    @State private var showingHistory = false
    @State private var showingLuckyPicker = false
    @State private var luckyPickDeck: [RoveLuckyPick] = []
    @State private var luckyPickSelection: RoveLuckyPick?
    @State private var didLoadRecommendations = false
    @State private var isRefreshingDiscovery = false
    @Namespace private var mediaHeroNamespace

    let onAddSource: () -> Void
    let onOpenSource: (RoveSourceSheet) -> Void
    let onOpenSettings: () -> Void

    private var recommendationCandidates: [Channel] {
        let candidates = library.channels.filter {
            $0.isExplicitlyOnDemand || $0.isMediaServerItem
        }
        return Array(normalizedRecommendations(candidates).prefix(120))
    }

    private var fallbackRecommendations: [Channel] {
        Array(normalizedRecommendations(
            library.favoriteChannels + library.recentChannels + recommendationCandidates
        ).prefix(12))
    }

    private var displayedRecommendations: [Channel] {
        aiRecommendations.isEmpty
            ? fallbackRecommendations
            : normalizedRecommendations(aiRecommendations)
    }

    private var featuredRecommendations: [Channel] {
        Array(displayedRecommendations.prefix(3))
    }

    private var recommendationFeed: [Channel] {
        let featuredIDs = Set(featuredRecommendations.map(\.id))
        let remaining = displayedRecommendations.filter { !featuredIDs.contains($0.id) }
        return remaining.isEmpty ? displayedRecommendations : remaining
    }

    private var hasAIConfiguration: Bool {
        RoveDeepSeekService.shared.hasAPIKey
    }

    /// Discovery recommends a show, not an arbitrary episode. The detail page
    /// then starts with S01E01, or the earliest episode that the server has.
    private func normalizedRecommendations(_ channels: [Channel]) -> [Channel] {
        let libraryItems = library.channels
        var seriesByKey: [String: Channel] = [:]
        var earliestEpisodeByKey: [String: Channel] = [:]

        for item in libraryItems {
            if item.isMediaServerSeries,
               let key = recommendationSeriesKey(for: item) {
                seriesByKey[key] = seriesByKey[key] ?? item
            } else if item.isMediaServerEpisode,
                      let key = recommendationSeriesKey(for: item) {
                if let current = earliestEpisodeByKey[key] {
                    if isEarlierEpisode(item, than: current) {
                        earliestEpisodeByKey[key] = item
                    }
                } else {
                    earliestEpisodeByKey[key] = item
                }
            }
        }

        var result: [Channel] = []
        var seenItems = Set<UUID>()
        var seenSeries = Set<String>()

        for item in channels {
            guard item.isMediaServerEpisode || item.isMediaServerSeries else {
                if seenItems.insert(item.id).inserted { result.append(item) }
                continue
            }

            guard let key = recommendationSeriesKey(for: item) else {
                if seenItems.insert(item.id).inserted { result.append(item) }
                continue
            }
            guard seenSeries.insert(key).inserted else { continue }

            if let series = seriesByKey[key] {
                result.append(series)
            } else if let episode = earliestEpisodeByKey[key] ?? (item.isMediaServerEpisode ? item : nil) {
                result.append(seriesRecommendation(from: episode))
            } else {
                result.append(item)
            }
        }
        return result
    }

    private func recommendationSeriesKey(for channel: Channel) -> String? {
        guard let configurationID = channel.roveMediaServerConfigurationID else { return nil }
        let seriesID = channel.isMediaServerEpisode
            ? channel.mediaServerSeriesID
            : channel.tvgID
        guard let seriesID = seriesID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !seriesID.isEmpty else { return nil }
        return "\(configurationID.uuidString.lowercased())|\(seriesID.lowercased())"
    }

    private func isEarlierEpisode(_ lhs: Channel, than rhs: Channel) -> Bool {
        let lhsOrder = (discoverySeasonNumber(for: lhs), discoveryEpisodeNumber(for: lhs))
        let rhsOrder = (discoverySeasonNumber(for: rhs), discoveryEpisodeNumber(for: rhs))
        if lhsOrder.0 != rhsOrder.0 { return lhsOrder.0 < rhsOrder.0 }
        if lhsOrder.1 != rhsOrder.1 { return lhsOrder.1 < rhsOrder.1 }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func discoverySeasonNumber(for channel: Channel) -> Int {
        discoveryNumber(in: channel.group, pattern: #"第\s*(\d+)\s*季"#) ?? 1
    }

    private func discoveryEpisodeNumber(for channel: Channel) -> Int {
        discoveryNumber(in: channel.name, pattern: #"第\s*(\d+)\s*集"#) ?? Int.max
    }

    private func discoveryNumber(in value: String, pattern: String) -> Int? {
        guard let range = value.range(of: pattern, options: .regularExpression) else { return nil }
        return Int(value[range].filter(\.isNumber))
    }

    private func seriesRecommendation(from episode: Channel) -> Channel {
        guard let seriesID = episode.mediaServerSeriesID else { return episode }
        var series = episode
        series.name = episode.group.components(separatedBy: " · 第").first?.nonEmpty
            ?? episode.group.nonEmpty
            ?? episode.name
        series.tvgID = seriesID
        series.tvgName = series.name
        series.mediaServerItemType = "Series"
        series.mediaServerSeriesID = nil
        series.resolver = switch episode.resolver {
        case .legacyLibraryB(let configurationID, _):
            .legacyLibraryB(configurationID: configurationID, itemID: seriesID)
        case .legacyLibraryA(let configurationID, _):
            .legacyLibraryA(configurationID: configurationID, itemID: seriesID)
        case .movieClaw(let configurationID, _):
            .movieClaw(configurationID: configurationID, itemID: seriesID)
        case .legacyLibraryC(let configurationID, _):
            .legacyLibraryC(configurationID: configurationID, itemID: seriesID)
        case .legacyLibraryD(let configurationID, _):
            .legacyLibraryD(configurationID: configurationID, itemID: seriesID)
        default:
            episode.resolver
        }
        return series
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    discoveryHeader
                        .roveEntrance()
                    featuredSection
                        .roveEntrance(delay: 0.04)
                    aiRecommendationSection
                        .roveEntrance(delay: 0.06)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .background(RoveBackdrop())
            .navigationDestination(item: $selectedChannel) { channel in
                RoveMediaDetailView(channel: channel)
                    .roveHeroNavigationTransition(
                        id: selectedChannelHeroID,
                        namespace: mediaHeroNamespace
                    )
            }
            .navigationDestination(item: $selectedTMDBMovie) { movie in
                RoveMediaDetailView(recommendation: movie)
                    .roveHeroNavigationTransition(
                        id: selectedTMDBHeroID,
                        namespace: mediaHeroNamespace
                    )
            }
            .navigationDestination(isPresented: $showingHistory) {
                RoveSavedView(initialFilter: .recent)
            }
            // Load once when the Discover tab is first presented. Subsequent
            // recommendation requests are explicit through the refresh button.
            .task {
                guard !didLoadRecommendations else { return }
                didLoadRecommendations = true
                await loadRecommendations()
            }
        }
        .overlay {
            if showingLuckyPicker, let luckyPickSelection {
                RoveLuckyPickOverlay(
                    selection: luckyPickSelection,
                    deck: luckyPickDeck,
                    candidateCount: luckyPickCandidates.count,
                    heroNamespace: mediaHeroNamespace,
                    onClose: closeLuckyPicker,
                    onOpen: openLuckyPick
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .toolbar(showingLuckyPicker ? .hidden : .visible, for: .tabBar)
    }

    private var discoveryHeader: some View {
        HStack(alignment: .center) {
            Text("发现")
                .font(.system(size: 38, weight: .black))
            Spacer(minLength: 8)
            Button {
                Task { await refreshDiscovery() }
            } label: {
                if isRefreshingDiscovery {
                    ProgressView()
                        .frame(width: 42, height: 42)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline.weight(.bold))
                        .frame(width: 42, height: 42)
                }
            }
            .buttonStyle(RoveMotionButtonStyle())
            .disabled(isRefreshingDiscovery)
            .accessibilityLabel("刷新发现")
            Button {
                showingHistory = true
            } label: {
                Label("观看历史", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(RoveMotionButtonStyle())
        }
    }

    @ViewBuilder
    private var luckyPickLauncher: some View {
        if !luckyPickCandidates.isEmpty {
            Button(action: presentLuckyPicker) {
                Label("帮我选一部", systemImage: "shuffle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .roveLiquidGlass(in: Capsule())
            }
            .buttonStyle(RoveMotionButtonStyle())
            .accessibilityHint("从发现内容中随机推荐")
        }
    }

    private var luckyPickCandidates: [RoveLuckyPick] {
        var seen = Set<UUID>()
        let serverPicks = recommendationCandidates.compactMap { channel -> RoveLuckyPick? in
            guard !channel.isMediaServerEpisode,
                  seen.insert(channel.id).inserted else { return nil }
            return .channel(channel)
        }
        let tmdbPicks = TMDBFeaturedCatalog.movies.compactMap { movie -> RoveLuckyPick? in
            guard !movie.posterPath.isEmpty else { return nil }
            return .tmdb(movie)
        }
        return serverPicks + tmdbPicks
    }

    @ViewBuilder
    private var featuredSection: some View {
        if !featuredRecommendations.isEmpty {
            ZStack(alignment: .bottomTrailing) {
                TabView(selection: $selectedFeaturedIndex) {
                    ForEach(Array(featuredRecommendations.enumerated()), id: \.element.id) { index, channel in
                        let transitionID = "discover-featured-\(index)-\(channel.id.uuidString)"
                        Button {
                            openDiscoveryChannel(channel, heroID: transitionID)
                        } label: {
                            GeometryReader { geometry in
                                ZStack(alignment: .bottomLeading) {
                                    RoveArtworkView(channel: channel, landscape: true)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .roveHeroTransitionSource(
                                            id: transitionID,
                                            namespace: mediaHeroNamespace
                                        )
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.88)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(aiRecommendations.isEmpty ? "精选推荐" : "AI 精选")
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(.black.opacity(0.46), in: Capsule())
                                        Text(channel.name)
                                            .font(.system(size: 28, weight: .black))
                                            .lineLimit(1)
                                        Text(featuredMetadata(channel))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.82))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(18)
                                }
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottomLeading)
                                .clipped()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : RoveMotion.carousel, value: selectedFeaturedIndex)

                HStack(spacing: 7) {
                    ForEach(featuredRecommendations.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == selectedFeaturedIndex ? .white : .white.opacity(0.42))
                            .frame(width: index == selectedFeaturedIndex ? 24 : 7, height: 7)
                    }
                }
                .animation(reduceMotion ? nil : RoveMotion.carousel, value: selectedFeaturedIndex)
                .padding(16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: min(300, UIScreen.main.bounds.width * 0.62), alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var aiRecommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("精选推荐")
                    .font(.title2.weight(.heavy))
                Spacer()
                luckyPickLauncher
                if isLoadingRecommendations {
                    ProgressView()
                } else if hasAIConfiguration, recommendationsEnabled {
                    Button {
                        Task { await loadRecommendations(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(RoveMotionButtonStyle())
                    .accessibilityLabel("刷新推荐")
                }
            }

            if displayedRecommendations.isEmpty, !hasAIConfiguration {
                discoverPrompt(
                    title: "配置 AI 推荐",
                    message: "添加 \(RoveDeepSeekService.shared.provider.title) API Key 后即可生成个性化推荐。",
                    actionTitle: "去设置 AI 服务",
                    action: onOpenSettings
                )
            } else if displayedRecommendations.isEmpty, !recommendationsEnabled {
                discoverPrompt(
                    title: "开启 AI 推荐",
                    message: "打开推荐开关后即可生成精选内容。",
                    actionTitle: "打开 AI 服务",
                    action: onOpenSettings
                )
            } else if displayedRecommendations.isEmpty, !isLoadingRecommendations {
                discoverPrompt(
                    title: "暂时没有可推荐内容",
                    message: recommendationError ?? "添加媒体资源后即可生成推荐。",
                    actionTitle: "刷新",
                    action: { Task { await loadRecommendations(force: true) } }
                )
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(recommendationFeed) { channel in
                        let transitionID = "discover-feed-\(channel.id.uuidString)"
                        Button {
                            openDiscoveryChannel(channel, heroID: transitionID)
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                ZStack(alignment: .topLeading) {
                                    RoveArtworkView(channel: channel, landscape: true)
                                        .frame(
                                            width: recommendationArtworkWidth,
                                            height: recommendationArtworkWidth * 9 / 16
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .roveHeroTransitionSource(
                                            id: transitionID,
                                            namespace: mediaHeroNamespace
                                        )
                                    Text(mediaTypeLabel(channel))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(Color.roveAccent.opacity(0.92), in: Capsule())
                                        .padding(8)
                                }
                                .frame(
                                    width: recommendationArtworkWidth,
                                    height: recommendationArtworkWidth * 9 / 16
                                )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(channel.name)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text(featuredMetadata(channel))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(recommendationReason(channel))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(.primary.opacity(0.06), lineWidth: 1)
                            }
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                    }
                }
            }
        }
    }

    private var recommendationArtworkWidth: CGFloat {
        min(190, max(150, UIScreen.main.bounds.width * 0.44))
    }

    private func openDiscoveryChannel(_ channel: Channel, heroID: AnyHashable) {
        selectedChannelHeroID = heroID
        Task { @MainActor in
            await Task.yield()
            guard selectedChannelHeroID == heroID else { return }
            selectedChannel = channel
        }
    }

    private func presentLuckyPicker() {
        let candidates = luckyPickCandidates.shuffled()
        guard let selection = candidates.first else { return }
        luckyPickDeck = Array(candidates.prefix(6))
        luckyPickSelection = selection
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.86)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
            showingLuckyPicker = true
        }
    }

    private func closeLuckyPicker() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            showingLuckyPicker = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            guard !showingLuckyPicker else { return }
            luckyPickDeck = []
            luckyPickSelection = nil
        }
    }

    private func openLuckyPick(_ pick: RoveLuckyPick) {
        switch pick {
        case .channel(let channel):
            openDiscoveryChannel(channel, heroID: pick.heroID)
        case .tmdb(let movie):
            selectedTMDBHeroID = pick.heroID
            Task { @MainActor in
                await Task.yield()
                guard selectedTMDBHeroID == AnyHashable(pick.heroID) else { return }
                selectedTMDBMovie = movie
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            closeLuckyPicker()
        }
    }

    private func featuredMetadata(_ channel: Channel) -> String {
        [channel.productionYear.map(String.init), library.displayGroup(for: channel)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func mediaTypeLabel(_ channel: Channel) -> String {
        channel.isMediaServerSeries || channel.isMediaServerEpisode ? "电视剧" : "电影"
    }

    private func recommendationReason(_ channel: Channel) -> String {
        if library.favoriteChannels.contains(where: { $0.id == channel.id }) {
            return "来自你的收藏偏好"
        }
        if library.recentChannels.contains(where: { $0.id == channel.id }) {
            return "根据最近观看继续发现"
        }
        let group = library.displayGroup(for: channel)
        return group.isEmpty ? "来自已连接资源库" : "来自 \(group)"
    }

    private func discoverPrompt(
        title: String,
        message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @MainActor
    private func refreshDiscovery() async {
        guard !isRefreshingDiscovery else { return }
        isRefreshingDiscovery = true
        defer { isRefreshingDiscovery = false }

        // Discovery is built from the local channel snapshot. Refresh each
        // source explicitly so this page stays stable until the user asks for
        // new data, instead of reloading every time the tab becomes visible.
        for configuration in library.configurations {
            await library.refreshConfiguration(configuration.id)
        }
        await loadRecommendations(force: true)
    }

    @MainActor
    private func loadRecommendations(force: Bool = false) async {
        guard hasAIConfiguration, recommendationsEnabled,
              !recommendationCandidates.isEmpty else {
            if !hasAIConfiguration || !recommendationsEnabled { aiRecommendations = [] }
            return
        }
        guard force || !isLoadingRecommendations else { return }
        isLoadingRecommendations = true
        recommendationError = nil
        defer { isLoadingRecommendations = false }
        do {
            let names = try await RoveDeepSeekService.shared.recommendedNames(
                history: library.recentChannels,
                favorites: library.favoriteChannels,
                candidates: recommendationCandidates
            )
            // A connected library can contain the same title more than once
            // across servers or versions. Grouping instead of constructing a
            // unique-key dictionary prevents Swift's duplicate-key trap.
            let candidatesByName = Dictionary(
                grouping: recommendationCandidates,
                by: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            )
            var selected: [Channel] = []
            var selectedIDs = Set<UUID>()
            for name in names {
                let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard let match = candidatesByName[normalized]?.first
                    ?? recommendationCandidates.first(where: {
                        $0.name.localizedCaseInsensitiveContains(name)
                            || name.localizedCaseInsensitiveContains($0.name)
                    }), selectedIDs.insert(match.id).inserted else { continue }
                selected.append(match)
                if selected.count == 12 { break }
            }
            aiRecommendations = selected
        } catch {
            recommendationError = "推荐服务暂时不可用：\(error.localizedDescription)"
            aiRecommendations = []
        }
    }
}

private struct RoveFileSourcesView: View {
    @EnvironmentObject private var library: ChannelLibrary
    let onAddSource: () -> Void
    let onOpenSource: (RoveSourceSheet) -> Void

    @State private var selectedWebDAV: PlaylistConfiguration?
    @State private var selectedChannel: Channel?

    private var fileConfigurations: [PlaylistConfiguration] {
        library.configurations.filter(\.roveIsFileSource)
    }

    var body: some View {
        NavigationStack {
            Group {
                List {
                    Section("设备") {
                        Button {
                            onOpenSource(.localFiles)
                        } label: {
                            fileSourceRow(
                                title: "本地文件",
                                subtitle: "设备中的视频",
                                systemImage: "folder.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if !fileConfigurations.isEmpty {
                        Section("网络文件源") {
                            ForEach(fileConfigurations) { configuration in
                                Button {
                                    openFileConfiguration(configuration)
                                } label: {
                                    fileSourceRow(
                                        title: configuration.name,
                                        subtitle: fileSourceSubtitle(configuration),
                                        systemImage: configuration.kind.systemImage
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await library.deleteConfiguration(configuration.id) }
                                    } label: {
                                        Label("移除文件源", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("文件源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("使用教程") { }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("导入本地视频", systemImage: "folder") {
                            onOpenSource(.localFiles)
                        }
                        Button("添加 SMB", systemImage: "externaldrive.connected.to.line.below") {
                            onOpenSource(.networkShare("smb"))
                        }
                        Button("添加 WebDAV", systemImage: "externaldrive") {
                            onOpenSource(.webDAV)
                        }
                        Button("添加 SFTP", systemImage: "network") {
                            onOpenSource(.networkShare("sftp"))
                        }
                        Divider()
                        Button("更多来源", systemImage: "plus", action: onAddSource)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .navigationDestination(item: $selectedWebDAV) { configuration in
                WebDAVConfigurationBrowser(configuration: configuration)
            }
            .navigationDestination(item: $selectedChannel) { channel in
                RoveMediaDetailView(channel: channel)
            }
        }
    }

    private func fileSourceRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.roveAccent)
                .frame(width: 36, height: 36)
                .background(Color.roveAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func fileSourceSubtitle(_ configuration: PlaylistConfiguration) -> String {
        if configuration.kind == .legacySourceC { return "WebDAV 文件服务器" }
        let scheme = configuration.sourceAddress.flatMap(URL.init(string:))?.scheme?.uppercased() ?? "网络文件"
        return "\(scheme) 文件源"
    }

    private func openFileConfiguration(_ configuration: PlaylistConfiguration) {
        if configuration.kind == .legacySourceC {
            selectedWebDAV = configuration
        } else if let channel = configuration.channels.first {
            selectedChannel = channel
        }
    }
}

private struct RoveEmptySourceView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)
            Image("MediaDeckBrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 142, height: 142)
            Text(title)
                .font(.largeTitle.bold())
                .padding(.top, 42)
            Text(message)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Button(buttonTitle, action: action)
                .font(.title3.weight(.semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .frame(maxWidth: 330)
                .padding(.top, 34)
            Spacer(minLength: 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

private struct RoveIPTVLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ChannelLibrary
    let onAddOnline: () -> Void
    let onAddRSS: () -> Void

    @State private var importingFile = false
    @State private var showingSettings = false
    @State private var refreshing = false
    @State private var editingConfiguration: PlaylistConfiguration?
    @State private var pendingDeletion: PlaylistConfiguration?
    @AppStorage(RoveHomeModeStore.defaultsKey) private var homeMode = RoveHomeModeStore.server

    private var configurations: [PlaylistConfiguration] {
        library.configurations.filter(\.roveIsIPTVSource)
    }

    var body: some View {
        Group {
            if configurations.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(configurations) { configuration in
                            configurationCard(configuration)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("IPTV")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "rectangle.stack")
                }
                .accessibilityLabel("返回资源库")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("本地导入", systemImage: "rectangle.inset.filled.and.person.filled") {
                        importingFile = true
                    }
                    Button("在线订阅", systemImage: "link") {
                        onAddOnline()
                    }
                    Button("RSS 视频订阅", systemImage: "dot.radiowaves.left.and.right") {
                        onAddRSS()
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加 IPTV")

                Button { refreshAll() } label: {
                    if refreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(refreshing || configurations.isEmpty)
                .accessibilityLabel("刷新 IPTV")

                Menu {
                    Button("IPTV 配置", systemImage: "slider.horizontal.3") {
                        showingSettings = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("更多")
            }
        }
        .sheet(isPresented: $showingSettings) {
            RoveIPTVSettingsView()
        }
        .sheet(item: $editingConfiguration) { configuration in
            ConfigurationEditorView(configuration: configuration)
        }
        .fileImporter(
            isPresented: $importingFile,
            allowedContentTypes: [.plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            importLocalPlaylist(result)
        }
        .alert(
            "删除 IPTV",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { configuration in
            Button("取消", role: .cancel) { pendingDeletion = nil }
            Button("删除", role: .destructive) {
                pendingDeletion = nil
                Task { await library.deleteConfiguration(configuration.id) }
            }
        } message: { configuration in
            Text("确定删除“\(configuration.name)”吗？")
        }
        .libraryErrorAlert(library)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 120)
            Image(systemName: "tv.and.mediabox")
                .font(.system(size: 72, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.roveViolet)
            Text("支持 M3U、M3U8、TXT 格式直播源")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 26)
            Spacer(minLength: 180)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 90)
    }

    private func configurationCard(_ configuration: PlaylistConfiguration) -> some View {
        Button {
            library.selectConfiguration(configuration.id)
            homeMode = RoveHomeModeStore.server
        } label: {
            HStack(spacing: 14) {
                Image(systemName: configuration.kind.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.roveViolet)
                    .frame(width: 44, height: 44)
                    .background(Color.roveViolet.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(configuration.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(configuration.kind.title) · \(configuration.totalItemCount ?? configuration.channels.count) 个项目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                if library.activeConfigurationID == configuration.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.roveViolet)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background {
                RoveSourceGlassCardBackground(tint: Color.roveViolet)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if (configuration.kind == .subscription || configuration.kind == .rss),
               configuration.isWebImportProtected != true {
                Button("编辑", systemImage: "pencil") {
                    editingConfiguration = configuration
                }
            }
            if configuration.kind == .subscription || configuration.kind == .rss {
                Button("刷新", systemImage: "arrow.clockwise") {
                    Task { await library.refreshConfiguration(configuration.id) }
                }
            }
            Button("删除", systemImage: "trash", role: .destructive) {
                pendingDeletion = configuration
            }
        }
    }

    private func refreshAll() {
        guard !refreshing else { return }
        refreshing = true
        Task {
            for configuration in configurations {
                await library.refreshConfiguration(configuration.id)
            }
            refreshing = false
        }
    }

    private func importLocalPlaylist(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else {
            if case let .failure(error) = result {
                library.reportPlaylistImportError(error)
            }
            return
        }
        Task {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try await PlaylistFileReader.read(from: url)
                await library.importLocalConfiguration(
                    data: data,
                    name: url.deletingPathExtension().lastPathComponent,
                    baseURL: url
                )
            } catch {
                library.reportPlaylistImportError(error)
            }
        }
    }
}

private struct RoveIPTVSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PlaybackRequestPreferences.customUserAgentEnabledDefaultsKey)
    private var userAgentEnabled = true
    @AppStorage(PlaybackRequestPreferences.customUserAgentDefaultsKey)
    private var userAgent = PlaybackRequestPreferences.defaultUserAgent
    @AppStorage(ChannelPreviewPreferences.concurrencyModeDefaultsKey)
    private var previewConcurrencyMode = ChannelPreviewPreferences.Mode.defaultValue.rawValue
    @AppStorage(ChannelPreviewPreferences.customConcurrencyDefaultsKey)
    private var previewThreadCount = 4

    private var userAgentBinding: Binding<String> {
        Binding(
            get: { userAgentEnabled ? userAgent : "" },
            set: { value in
                userAgent = value
                userAgentEnabled = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        )
    }

    private var previewThreadBinding: Binding<Int> {
        Binding(
            get: {
                if previewConcurrencyMode == ChannelPreviewPreferences.Mode.custom.rawValue {
                    return min(8, max(0, previewThreadCount))
                }
                return ChannelPreviewPreferences.maximumConcurrentLoads ?? 0
            },
            set: { value in
                previewConcurrencyMode = ChannelPreviewPreferences.Mode.custom.rawValue
                previewThreadCount = min(8, max(0, value))
                ChannelPreviewService.shared.reloadPreferences()
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 18) {
                        Text("User-Agent")
                            .font(.headline)
                        TextField("可选", text: userAgentBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section {
                    Stepper(value: previewThreadBinding, in: 0...8) {
                        LabeledContent("预览图线程数", value: "\(previewThreadBinding.wrappedValue)")
                            .font(.headline)
                    }
                } footer: {
                    Text("0 代表不自动生成缩略图")
                }
            }
            .navigationTitle("IPTV 配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("关闭")
                }
            }
        }
        .presentationDetents([.large])
    }
}

private enum RoveSourceViewMode: String, CaseIterable, Identifiable {
    case grid
    case compactGrid
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid: "网格视图"
        case .compactGrid: "小网格视图"
        case .list: "列表视图"
        }
    }

    var systemImage: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .compactGrid: "square.grid.3x3"
        case .list: "list.bullet"
        }
    }
}

private enum RoveSourceSortMode: String, CaseIterable, Identifiable {
    case custom
    case latencyAscending
    case seriesDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .custom: "自定义顺序"
        case .latencyAscending: "Ping 从低到高"
        case .seriesDescending: "剧集从多到少"
        }
    }

    var systemImage: String {
        switch self {
        case .custom: "hand.draw"
        case .latencyAscending: "gauge.with.dots.needle.33percent"
        case .seriesDescending: "arrow.down.to.line.compact"
        }
    }
}

private struct RoveSourcesView: View {
    private struct VisibleSourceSections: Equatable {
        let all: [String]
        let builtIn: [String]
        let cloudDrives: [String]
        let mediaServers: [String]
        let subscriptions: [String]
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var library: ChannelLibrary
    @StateObject private var moviePilotStore = MoviePilotConnectionStore.shared
    @StateObject private var googleDrive = GoogleDriveService.shared
    @StateObject private var baiduNetdisk = BaiduNetdiskService.shared
    @StateObject private var pan115 = Pan115DriveService.shared
    @StateObject private var pan123 = Pan123DriveService.shared
    @StateObject private var aliyunDrive = AliyunDriveService.shared
    @StateObject private var cloud139 = Cloud139DriveService.shared
    @StateObject private var cloud189 = Cloud189DriveService.shared
    @StateObject private var lanzouDrive = LanzouDriveService.shared
    @StateObject private var quarkDrive = QuarkDriveService.shared
    @StateObject private var thunderDrive = ThunderDriveService.shared
    @StateObject private var guangYaDrive = GuangYaDriveService.shared
    @Binding var selectedTab: RootTab
    let onAddSource: () -> Void
    let onOpenSource: (RoveSourceSheet) -> Void
    @State private var openedServer: PlaylistConfiguration?
    @State private var selectedServerChannel: Channel?
    @State private var editingServer: PlaylistConfiguration?
    @State private var changingServerIcon: PlaylistConfiguration?
    @State private var remarkingServer: PlaylistConfiguration?
    @State private var managingRoutes: PlaylistConfiguration?
    @State private var statisticsConfiguration: PlaylistConfiguration?
    @State private var openedMoviePilot: MoviePilotConnection?
    @State private var editingMoviePilot: MoviePilotConnection?
    @State private var moviePilotPendingDeletion: MoviePilotConnection?
    @State private var serverPendingDeletion: PlaylistConfiguration?
    @State private var deletingServerID: UUID?
    @State private var sourceLatencies: [UUID: Int] = [:]
    @State private var measuredSourceIDs: Set<UUID> = []
    @State private var sourceStatistics: [UUID: MediaLibraryStatistics] = [:]
    @State private var sourceStatisticsFailures: Set<UUID> = []
    @State private var showingIPTVLibrary = false
    @State private var showingPrivateLocalLibrary = false
    @State private var showsPrivateServers = false
    @State private var sourceCardOrder: [String] = []
    @State private var draggedSourceCardID: String?
    @AppStorage(RoveDefaultHomeStore.defaultsKey) private var defaultHomeRaw = ""
    @AppStorage(RoveHomeModeStore.defaultsKey) private var homeMode = RoveHomeModeStore.server
    @AppStorage("rove.sources.view-mode.v1") private var sourceViewModeRaw = RoveSourceViewMode.grid.rawValue
    @AppStorage("rove.sources.sort-mode.v1") private var sourceSortModeRaw = RoveSourceSortMode.custom.rawValue

    private let quickSources: [(String, String, String, RoveSourceSheet)] = [
        ("Emby", "家庭媒体服务器", "server.rack", .mediaServer(.legacyLibraryB, nil)),
        ("极影视", "连接极空间影视库", "externaldrive.fill", .mediaServer(.zspaceVideo, nil)),
        ("Jellyfin", "开源媒体中心", "play.rectangle.on.rectangle", .mediaServer(.legacyLibraryA, nil)),
        ("MovieClaw", "连接 MovieClaw 媒体库", "movieclapper.fill", .mediaServer(.movieClaw, nil)),
        ("旧版资料库", "连接飞牛 NAS 影视库", "film.stack.fill", .mediaServer(.legacyLibraryC, nil)),
        ("WebDAV", "远程文件目录", "externaldrive", .webDAV),
        ("M3U", "直播与订阅列表", "list.and.film", .playlist(nil)),
        ("RSS", "视频播客与 Atom 订阅", "dot.radiowaves.left.and.right", .rss),
        ("MoviePilot", "电影与剧集订阅管理", "sparkles.tv", .moviePilot(nil)),
        ("网盘", "连接云端文件", "cloud", .cloudDrives),
        ("本地", "设备中的视频", "folder", .localFiles)
    ]

    private var allServerConfigurations: [PlaylistConfiguration] {
        library.configurations.filter {
            ($0.kind.usesMediaLibraryBrowser
                || $0.roveIsIPTVSource
                || $0.name.localizedCaseInsensitiveContains("Plex"))
        }
    }

    private var serverConfigurations: [PlaylistConfiguration] {
        allServerConfigurations.filter { showsPrivateServers || !$0.isPrivateServer }
    }

    private var sourceViewMode: RoveSourceViewMode {
        RoveSourceViewMode(rawValue: sourceViewModeRaw) ?? .grid
    }

    private var sourceSortMode: RoveSourceSortMode {
        RoveSourceSortMode(rawValue: sourceSortModeRaw) ?? .custom
    }

    private var gridColumns: [GridItem] {
        switch sourceViewMode {
        case .grid:
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        case .compactGrid:
            return Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        case .list:
            return [GridItem(.flexible())]
        }
    }

    private var sourceCardHeight: CGFloat { 132 }

    private let builtInSources: [(String, String, String, RoveSourceSheet, Color)] = [
        ("本地文件", "本地", "folder.fill", .localFiles, .yellow),
        ("本地私密", "私密", "folder.fill.badge.person.crop", .privateLocalFiles, .pink),
        ("网络链接", "链接", "link", .directStream, .blue),
        ("IPTV", "IPTV", "tv", .playlist(nil), .cyan)
    ]

    private var availableSourceCardIDs: [String] {
        builtInSources.map { sourceCardID(for: $0.3) }
            + allServerConfigurations.map { "server:\($0.id.uuidString.lowercased())" }
            + moviePilotStore.connections.map { "moviepilot:\($0.id.uuidString.lowercased())" }
            + connectedCloudDriveProviders.map { "clouddrive:\($0.rawValue)" }
    }

    private var visibleSourceSections: VisibleSourceSections {
        let builtInIDs = builtInSources.map { sourceCardID(for: $0.3) }
        let allServers = allServerConfigurations
        let visibleServers = allServers.filter { showsPrivateServers || !$0.isPrivateServer }
        let visibleServerIDs = visibleServers.map { "server:\($0.id.uuidString.lowercased())" }
        let moviePilotIDs = moviePilotStore.connections.map { "moviepilot:\($0.id.uuidString.lowercased())" }
        let cloudDriveIDs = connectedCloudDriveProviders.map { "clouddrive:\($0.rawValue)" }
        let availableIDs = builtInIDs
            + allServers.map { "server:\($0.id.uuidString.lowercased())" }
            + moviePilotIDs
            + cloudDriveIDs
        let visibleIDs = Set(builtInIDs + visibleServerIDs + moviePilotIDs + cloudDriveIDs)
        var ordered = RoveSourceCardOrderStore.merged(
            saved: sourceCardOrder,
            available: availableIDs
        ).filter { visibleIDs.contains($0) }

        if sourceSortMode != .custom {
            let visibleServersByID = Dictionary(uniqueKeysWithValues: visibleServers.map {
                ("server:\($0.id.uuidString.lowercased())", $0)
            })
            let sortedServers = ordered.compactMap { visibleServersByID[$0] }.sorted(by: compareServers)
            let sortedServerIDs = sortedServers.map { "server:\($0.id.uuidString.lowercased())" }
            let serverIDSet = Set(sortedServerIDs)
            ordered = sortedServerIDs + ordered.filter { !serverIDSet.contains($0) }
        }

        let builtInIDSet = Set(builtInIDs)
        let cloudDriveIDSet = Set(cloudDriveIDs)
        let mediaServerIDSet = Set(visibleServers.compactMap { configuration -> String? in
            guard configuration.kind.usesMediaLibraryBrowser
                    || configuration.name.localizedCaseInsensitiveContains("Plex") else { return nil }
            return "server:\(configuration.id.uuidString.lowercased())"
        })
        let visibleServerIDSet = Set(visibleServerIDs)

        return VisibleSourceSections(
            all: ordered,
            builtIn: ordered.filter { builtInIDSet.contains($0) },
            cloudDrives: ordered.filter { cloudDriveIDSet.contains($0) },
            mediaServers: ordered.filter { mediaServerIDSet.contains($0) },
            subscriptions: ordered.filter {
                $0.hasPrefix("moviepilot:")
                    || (visibleServerIDSet.contains($0) && !mediaServerIDSet.contains($0))
            }
        )
    }

    private func compareServers(_ lhs: PlaylistConfiguration, _ rhs: PlaylistConfiguration) -> Bool {
        switch sourceSortMode {
        case .custom:
            return false
        case .latencyAscending:
            let left = sourceLatencies[lhs.id] ?? Int.max
            let right = sourceLatencies[rhs.id] ?? Int.max
            if left != right { return left < right }
        case .seriesDescending:
            let left = sourceStatistics[lhs.id]?.series.unique ?? -1
            let right = sourceStatistics[rhs.id]?.series.unique ?? -1
            if left != right { return left > right }
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    var body: some View {
        let sections = visibleSourceSections

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    sourceSection(title: "设备内容", sourceIDs: sections.builtIn)
                    sourceSection(title: "网盘", sourceIDs: sections.cloudDrives)
                    sourceSection(title: "媒体服务器", sourceIDs: sections.mediaServers)
                    sourceSection(title: "订阅服务", sourceIDs: sections.subscriptions)

                    LazyVGrid(columns: gridColumns, spacing: sourceViewMode == .compactGrid ? 8 : 12) {
                        Button { onAddSource() } label: {
                            addSourceCard
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                        .frame(
                            maxWidth: .infinity,
                            minHeight: sourceCardHeight,
                            maxHeight: sourceCardHeight
                        )
                    }
                }
                .animation(reduceMotion ? nil : RoveMotion.layout, value: sections.all)
                .padding(.horizontal, sourceViewMode == .compactGrid ? 10 : 16)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .background(RoveBackdrop())
            .onAppear {
                synchronizeSourceCardOrder()
            }
            .onChange(of: availableSourceCardIDs) { _, _ in
                synchronizeSourceCardOrder()
            }
            .onChange(of: sourceSortModeRaw) { _, rawValue in
                guard let mode = RoveSourceSortMode(rawValue: rawValue) else { return }
                switch mode {
                case .custom:
                    break
                case .latencyAscending:
                    Task { await measureAllServerLatencies() }
                case .seriesDescending:
                    Task { await loadAllServerStatistics() }
                }
            }
            .navigationTitle("资源库")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: onAddSource) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加资源库")
                    Menu {
                        Section("视图") {
                            ForEach(RoveSourceViewMode.allCases) { mode in
                                Button {
                                    sourceViewModeRaw = mode.rawValue
                                } label: {
                                    if sourceViewMode == mode {
                                        Label(mode.title, systemImage: "checkmark")
                                    } else {
                                        Label(mode.title, systemImage: mode.systemImage)
                                    }
                                }
                            }
                        }

                        Section("排序") {
                            ForEach(RoveSourceSortMode.allCases) { mode in
                                Button {
                                    sourceSortModeRaw = mode.rawValue
                                } label: {
                                    if sourceSortMode == mode {
                                        Label(mode.title, systemImage: "checkmark")
                                    } else {
                                        Label(mode.title, systemImage: mode.systemImage)
                                    }
                                }
                            }
                            Button("重新检测全部 Ping", systemImage: "arrow.clockwise") {
                                Task { await measureAllServerLatencies(force: true) }
                            }
                        }

                        Button {
                            showsPrivateServers.toggle()
                        } label: {
                            Label(
                                showsPrivateServers ? "隐藏隐私服务器" : "显示隐私服务器",
                                systemImage: showsPrivateServers ? "eye.slash" : "eye"
                            )
                        }

                        Divider()

                        Button("添加 Emby", systemImage: "server.rack") {
                            onOpenSource(.mediaServer(.legacyLibraryB, nil))
                        }
                        Button("添加极影视", systemImage: "externaldrive.fill") {
                            onOpenSource(.mediaServer(.zspaceVideo, nil))
                        }
                        Button("添加 Jellyfin", systemImage: "play.rectangle.on.rectangle") {
                            onOpenSource(.mediaServer(.legacyLibraryA, nil))
                        }
                        Button("添加 MovieClaw", systemImage: "movieclapper.fill") {
                            onOpenSource(.mediaServer(.movieClaw, nil))
                        }
                        Button("添加旧版资料库", systemImage: "film.stack.fill") {
                            onOpenSource(.mediaServer(.legacyLibraryC, nil))
                        }
                        Button("添加 MoviePilot", systemImage: "sparkles.tv") {
                            onOpenSource(.moviePilot(nil))
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .navigationDestination(item: $openedServer) { configuration in
                EmbyLibraryBrowserView(
                    configurationID: configuration.id,
                    serverKind: configuration.kind,
                    selectedChannel: $selectedServerChannel,
                    onSwitchSource: { openedServer = nil }
                )
                .navigationTitle(configuration.name)
                .navigationBarTitleDisplayMode(.inline)
            }
            .navigationDestination(isPresented: $showingIPTVLibrary) {
                RoveIPTVLibraryView(
                    onAddOnline: { onOpenSource(.playlist(nil)) },
                    onAddRSS: { onOpenSource(.rss) }
                )
            }
            .navigationDestination(isPresented: $showingPrivateLocalLibrary) {
                PrivateLocalVideoLibraryView()
            }
            .navigationDestination(item: $openedMoviePilot) { connection in
                MoviePilotSubscriptionsView(connection: connection)
            }
            .navigationDestination(item: $selectedServerChannel) { channel in
                RoveMediaDetailView(channel: channel)
            }
            .sheet(item: $editingServer) { configuration in
                if configuration.kind.usesMediaLibraryBrowser {
                    RoveServerSettingsView(configuration: configuration)
                } else {
                    ConfigurationEditorView(configuration: configuration)
                }
            }
            .sheet(item: $changingServerIcon) { configuration in
                RoveServerIconPicker(configuration: configuration)
            }
            .sheet(item: $remarkingServer) { configuration in
                RoveServerRemarkEditor(configuration: configuration)
            }
            .sheet(item: $managingRoutes) { configuration in
                RoveServerRouteManager(configuration: configuration)
            }
            .sheet(item: $statisticsConfiguration) { configuration in
                RoveResourceStatisticsSheet(configuration: configuration)
            }
            .sheet(item: $editingMoviePilot) { connection in
                MoviePilotConnectionForm(connection: connection)
            }
            .alert(
                "删除影视服务器",
                isPresented: Binding(
                    get: { serverPendingDeletion != nil },
                    set: { if !$0 { serverPendingDeletion = nil } }
                ),
                presenting: serverPendingDeletion
            ) { configuration in
                Button("取消", role: .cancel) {
                    serverPendingDeletion = nil
                }
                Button("删除", role: .destructive) {
                    deleteServer(configuration)
                }
            } message: { configuration in
                Text("确定删除“\(configuration.name)”吗？服务器登录信息和缓存数据也会一并移除。")
            }
            .alert(
                "删除 MoviePilot",
                isPresented: Binding(
                    get: { moviePilotPendingDeletion != nil },
                    set: { if !$0 { moviePilotPendingDeletion = nil } }
                ),
                presenting: moviePilotPendingDeletion
            ) { connection in
                Button("取消", role: .cancel) {
                    moviePilotPendingDeletion = nil
                }
                Button("删除", role: .destructive) {
                    moviePilotStore.delete(connection)
                    moviePilotPendingDeletion = nil
                }
            } message: { connection in
                Text("确定删除“\(connection.name)”吗？保存的 Token 也会从钥匙串移除。")
            }
            .libraryErrorAlert(library)
        }
    }

    @ViewBuilder
    private func sourceSection(title: String, sourceIDs: [String]) -> some View {
        if !sourceIDs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.bold))
                    Rectangle()
                        .fill(.primary.opacity(0.10))
                        .frame(height: 1)
                }

                LazyVGrid(columns: gridColumns, spacing: sourceViewMode == .compactGrid ? 8 : 12) {
                    ForEach(sourceIDs, id: \.self) { sourceID in
                        sourceGridCard(sourceID)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: sourceCardHeight,
                                maxHeight: sourceCardHeight,
                                alignment: .topLeading
                            )
                            .opacity(draggedSourceCardID == sourceID ? 0.55 : 1)
                            .scaleEffect(draggedSourceCardID == sourceID ? 0.97 : 1)
                            .onDrag {
                                sourceSortModeRaw = RoveSourceSortMode.custom.rawValue
                                draggedSourceCardID = sourceID
                                return NSItemProvider(object: sourceID as NSString)
                            }
                            .onDrop(
                                of: [UTType.plainText],
                                delegate: RoveSourceCardDropDelegate(
                                    targetID: sourceID,
                                    order: $sourceCardOrder,
                                    draggedID: $draggedSourceCardID
                                )
                            )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sourceGridCard(_ sourceID: String) -> some View {
        if let item = builtInSources.first(where: { sourceCardID(for: $0.3) == sourceID }) {
            Button { openBuiltInSource(item.3) } label: {
                builtInSourceCard(item)
            }
            .buttonStyle(.plain)
            .contextMenu {
                if let id = builtInID(for: item.3) {
                    Button { setDefaultHome(RoveDefaultHomeStore.builtIn(id)) } label: {
                        Label(
                            defaultHomeRaw == RoveDefaultHomeStore.builtIn(id) ? "取消默认首页" : "设为默认首页",
                            systemImage: "house"
                        )
                    }
                }
            }
        } else if let configuration = allServerConfigurations.first(where: {
            "server:\($0.id.uuidString.lowercased())" == sourceID
        }) {
            sourceCard(configuration)
        } else if let connection = moviePilotStore.connections.first(where: {
            "moviepilot:\($0.id.uuidString.lowercased())" == sourceID
        }) {
            moviePilotCard(connection)
        } else if let provider = connectedCloudDriveProviders.first(where: {
            "clouddrive:\($0.rawValue)" == sourceID
        }) {
            cloudDriveCard(provider)
        }
    }

    private var connectedCloudDriveProviders: [NativeCloudDriveProvider] {
        NativeCloudDriveProvider.allCases.filter { provider in
            switch provider {
            case .google: googleDrive.isAuthorized
            case .baidu: baiduNetdisk.isAuthorized
            case .pan115: pan115.isAuthorized
            case .pan123: pan123.isAuthorized
            case .aliyun: aliyunDrive.isAuthorized
            case .cloud139: cloud139.isAuthorized
            case .cloud189: cloud189.isAuthorized
            case .lanzou: lanzouDrive.isAuthorized
            case .quark: quarkDrive.isAuthorized
            case .thunder: thunderDrive.isAuthorized
            case .guangya: guangYaDrive.isAuthorized
            }
        }
    }

    private func sourceCardID(for source: RoveSourceSheet) -> String {
        switch source {
        case .localFiles: "builtin:local-files"
        case .privateLocalFiles: "builtin:private-local-files"
        case .directStream: "builtin:direct-stream"
        case .playlist: "builtin:iptv"
        case .cloudDrives: "builtin:cloud-drives"
        default: "builtin:\(String(describing: source))"
        }
    }

    private func synchronizeSourceCardOrder() {
        let merged = RoveSourceCardOrderStore.merged(
            saved: sourceCardOrder.isEmpty
                ? RoveSourceCardOrderStore.load(available: availableSourceCardIDs)
                : sourceCardOrder,
            available: availableSourceCardIDs
        )
        guard merged != sourceCardOrder else { return }
        sourceCardOrder = merged
        RoveSourceCardOrderStore.save(merged)
    }

    private func openBuiltInSource(_ source: RoveSourceSheet) {
        if case .localFiles = source {
            homeMode = RoveHomeModeStore.local
            selectedTab = .home
        } else if case .privateLocalFiles = source {
            showingPrivateLocalLibrary = true
        } else if case .playlist = source {
            showingIPTVLibrary = true
        } else {
            onOpenSource(source)
        }
    }

    private func builtInID(for source: RoveSourceSheet) -> String? {
        switch source {
        case .localFiles: "localFiles"
        case .directStream: "directStream"
        case .playlist: "playlist"
        default: nil
        }
    }

    private func setDefaultHome(_ rawValue: String) {
        defaultHomeRaw = defaultHomeRaw == rawValue ? "" : rawValue
    }

    private func builtInSourceCard(
        _ item: (String, String, String, RoveSourceSheet, Color)
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: item.2)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.4)
                    .frame(width: 26, height: 26)
                    .background(item.4.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.0)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.1)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if let id = builtInID(for: item.3),
                   defaultHomeRaw == RoveDefaultHomeStore.builtIn(id) {
                    Image(systemName: "house.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(item.4)
                }
            }

            Text("设备内容")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("从未访问")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding(12)
        .background {
            RoveSourceGlassCardBackground(tint: item.4)
        }
    }

    private func sourceCard(_ configuration: PlaylistConfiguration) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                openServer(configuration)
            } label: {
                serverCardContent(configuration)
                .background {
                    RoveSourceGlassCardBackground(tint: sourceColor(configuration.kind))
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(RoveMotionButtonStyle())

            Menu {
                sourceActions(configuration)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 7)
            .padding(.trailing, 5)
            .accessibilityLabel("管理 \(configuration.name)")
        }
        .contextMenu {
            sourceActions(configuration)
        }
        .disabled(deletingServerID == configuration.id)
        .task(id: "\(configuration.id.uuidString)-\(configuration.sourceAddress ?? "")") {
            async let serverName: Void = library.refreshServerReportedName(configuration.id)
            async let latency: Void = measureLatency(for: configuration)
            async let statistics: Void = loadStatistics(for: configuration)
            _ = await (serverName, latency, statistics)
        }
    }

    @ViewBuilder
    private func serverCardContent(_ configuration: PlaylistConfiguration) -> some View {
        switch sourceViewMode {
        case .list:
            HStack(spacing: 12) {
                RoveServerBrandIcon(configuration: configuration, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    serverTitle(configuration, font: .headline)
                    Text(sourceServerType(configuration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    sourceLatencyLabel(configuration)
                        .font(.caption2.weight(.medium))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(sourceUpdatedText(configuration.updatedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    sourceStatisticsText(configuration, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .leading)
            .padding(.leading, 12)
            .padding(.trailing, 44)
            .padding(.vertical, 10)

        case .compactGrid:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    RoveServerBrandIcon(configuration: configuration, size: 32)
                    Spacer(minLength: 2)
                    Text(sourceUpdatedText(configuration.updatedAt))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.trailing, 22)
                }
                serverTitle(configuration, font: .caption.weight(.semibold))
                Text(sourceServerType(configuration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                sourceStatisticsText(configuration, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .leading)
            .padding(10)

        case .grid:
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 8) {
                    RoveServerBrandIcon(configuration: configuration, size: 34)
                    Spacer(minLength: 2)
                    Text(sourceUpdatedText(configuration.updatedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.trailing, 24)
                }
                serverTitle(configuration, font: .subheadline.weight(.semibold))
                Text(sourceServerType(configuration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                sourceStatisticsText(configuration, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 108, maxHeight: 108, alignment: .leading)
            .padding(12)
        }
    }

    private func serverTitle(
        _ configuration: PlaylistConfiguration,
        font: Font
    ) -> some View {
        HStack(spacing: 5) {
            Text(serverDisplayName(configuration))
                .font(font)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Circle()
                .fill(sourceLatencies[configuration.id] == nil ? Color.secondary.opacity(0.45) : Color.green)
                .frame(width: 6, height: 6)
            if defaultHomeRaw == RoveDefaultHomeStore.server(configuration.id) {
                Image(systemName: "house.fill")
                    .font(.caption2)
                    .foregroundStyle(sourceColor(configuration.kind))
            }
        }
    }

    private func serverDisplayName(_ configuration: PlaylistConfiguration) -> String {
        let remark = configuration.serverRemark?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !remark.isEmpty { return remark }
        let reportedName = configuration.serverReportedName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return reportedName.isEmpty ? configuration.name : reportedName
    }

    private func sourceServerType(_ configuration: PlaylistConfiguration) -> String {
        let hasCustomName = !(configuration.serverRemark?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
        return hasCustomName ? configuration.name : configuration.kind.title
    }

    private func sourceStatusLine(_ configuration: PlaylistConfiguration) -> some View {
        HStack(spacing: 5) {
            sourceLatencyLabel(configuration)
            Text("·").foregroundStyle(.tertiary)
            Text(sourceUpdatedText(configuration.updatedAt))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption2.weight(.medium))
    }

    @ViewBuilder
    private func sourceStatisticsView(
        _ configuration: PlaylistConfiguration,
        vertical: Bool
    ) -> some View {
        if configuration.isPrivateServer {
            Label("统计已隐藏", systemImage: "eye.slash")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if configuration.kind.usesMediaLibraryBrowser,
                  let statistics = sourceStatistics[configuration.id] {
            if vertical {
                VStack(alignment: .leading, spacing: 3) {
                    sourceCount("电影", statistics.movies.unique, systemImage: "film")
                    sourceCount("剧集", statistics.series.unique, systemImage: "rectangle.stack")
                    sourceCount("集", statistics.episodes.unique, systemImage: "play.rectangle")
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow {
                        sourceCount("电影", statistics.movies.unique, systemImage: "film")
                        sourceCount("剧集", statistics.series.unique, systemImage: "rectangle.stack")
                    }
                    GridRow {
                        sourceCount("集", statistics.episodes.unique, systemImage: "play.rectangle")
                        Color.clear.frame(height: 1)
                    }
                }
            }
        } else if configuration.kind.usesMediaLibraryBrowser {
            Label("正在统计", systemImage: "ellipsis")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            sourceCount(
                "频道",
                configuration.totalItemCount ?? configuration.channels.count,
                systemImage: "tv"
            )
        }
    }

    @ViewBuilder
    private func sourceStatisticsText(
        _ configuration: PlaylistConfiguration,
        alignment: TextAlignment
    ) -> some View {
        if configuration.isPrivateServer {
            Text("统计已隐藏")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if configuration.kind.usesMediaLibraryBrowser,
                  let statistics = sourceStatistics[configuration.id] {
            Text("电影: \(statistics.movies.unique.formatted(.number.grouping(.automatic)))  剧集: \(statistics.series.unique.formatted(.number.grouping(.automatic)))  分集: \(statistics.episodes.unique.formatted(.number.grouping(.automatic)))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignment)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } else if configuration.kind.usesMediaLibraryBrowser {
            Text(sourceStatisticsFailures.contains(configuration.id) ? "统计暂不可用" : "正在读取资源数量")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text("频道: \((configuration.totalItemCount ?? configuration.channels.count).formatted(.number.grouping(.automatic)))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func cloudDriveCard(_ provider: NativeCloudDriveProvider) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                onOpenSource(.cloudDrive(provider))
            } label: {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 9) {
                        Image(provider.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(provider.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("网盘")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 30)
                    }

                    Text("已登录")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)

                    Text("云端文件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle.fill")
                        Text("打开网盘")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
                .padding(12)
                .background {
                    RoveSourceGlassCardBackground(tint: .mint)
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    onOpenSource(.cloudDrive(provider))
                } label: {
                    Label("打开网盘", systemImage: "folder")
                }
                Button(role: .destructive) {
                    signOutCloudDrive(provider)
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 7)
            .padding(.trailing, 5)
            .accessibilityLabel("管理 \(provider.title)")
        }
        .contextMenu {
            Button {
                onOpenSource(.cloudDrive(provider))
            } label: {
                Label("打开网盘", systemImage: "folder")
            }
            Button(role: .destructive) {
                signOutCloudDrive(provider)
            } label: {
                Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private func signOutCloudDrive(_ provider: NativeCloudDriveProvider) {
        switch provider {
        case .google: googleDrive.signOut()
        case .baidu: baiduNetdisk.signOut()
        case .pan115: pan115.logout()
        case .pan123: pan123.logout()
        case .aliyun: aliyunDrive.signOut()
        case .cloud139: cloud139.logout()
        case .cloud189: cloud189.logout()
        case .lanzou: lanzouDrive.logout()
        case .quark: quarkDrive.signOut()
        case .thunder: thunderDrive.logout()
        case .guangya: guangYaDrive.logout()
        }
    }

    private func moviePilotCard(_ connection: MoviePilotConnection) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                openedMoviePilot = connection
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 9) {
                        Image(systemName: "sparkles.tv.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.orange)
                            .frame(width: 26, height: 26)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(connection.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("MoviePilot")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 30)
                    }

                    HStack(spacing: 5) {
                        if let latency = sourceLatencies[connection.id] {
                            Text("\(latency)ms")
                                .foregroundStyle(sourceLatencyColor(latency))
                        } else if measuredSourceIDs.contains(connection.id) {
                            Text("无法访问")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("检测中")
                                .foregroundStyle(.secondary)
                        }
                        Text("·").foregroundStyle(.tertiary)
                        Text(sourceUpdatedText(connection.updatedAt))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.weight(.medium))

                    Text("电影与剧集订阅")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        Image(systemName: connection.authenticationMode == .account ? "person.crop.circle" : "key")
                        Text(connection.authenticationMode.title)
                        Spacer()
                        Text("管理订阅")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
                .padding(12)
                .background {
                    RoveSourceGlassCardBackground(tint: .orange)
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    openedMoviePilot = connection
                } label: {
                    Label("查看订阅", systemImage: "list.bullet.rectangle")
                }
                Button {
                    editingMoviePilot = connection
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    moviePilotPendingDeletion = connection
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 7)
            .padding(.trailing, 5)
            .accessibilityLabel("管理 \(connection.name)")
        }
        .contextMenu {
            Button { openedMoviePilot = connection } label: {
                Label("查看订阅", systemImage: "list.bullet.rectangle")
            }
            Button { editingMoviePilot = connection } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) { moviePilotPendingDeletion = connection } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .task(id: "moviepilot-\(connection.id.uuidString)-\(connection.server)") {
            guard !measuredSourceIDs.contains(connection.id) else { return }
            let latency = await RoveSourceLatencyProbe.measure(connection.server)
            guard !Task.isCancelled else { return }
            measuredSourceIDs.insert(connection.id)
            sourceLatencies[connection.id] = latency
        }
    }

    private func openServer(_ configuration: PlaylistConfiguration) {
        library.selectConfiguration(configuration.id)
        homeMode = RoveHomeModeStore.server
        selectedTab = .home
    }

    @ViewBuilder
    private func sourceActions(_ configuration: PlaylistConfiguration) -> some View {
            Button { openServer(configuration) } label: {
                Label("打开服务器", systemImage: "play.rectangle")
            }
            if configuration.kind.usesMediaLibraryBrowser {
                Button { changingServerIcon = configuration } label: {
                    Label("更换图标", systemImage: "photo")
                }
                Button { remarkingServer = configuration } label: {
                    Label("重命名", systemImage: "square.and.pencil")
                }
                Button { editingServer = configuration } label: {
                    Label("服务器设置", systemImage: "gearshape")
                }
                Button {
                    Task { await library.refreshConfiguration(configuration.id) }
                } label: {
                    Label("更新鉴权", systemImage: "key.viewfinder")
                }
            } else if configuration.isWebImportProtected != true {
                Button { editingServer = configuration } label: {
                    Label("编辑", systemImage: "pencil")
                }
            }
            Button { setDefaultHome(RoveDefaultHomeStore.server(configuration.id)) } label: {
                Label(
                    defaultHomeRaw == RoveDefaultHomeStore.server(configuration.id) ? "取消默认首页" : "设为默认首页",
                    systemImage: "house"
                )
            }
            Button {
                Task {
                    await library.refreshConfiguration(configuration.id)
                    if configuration.kind.usesMediaLibraryBrowser {
                        await loadStatistics(for: configuration, force: true)
                    }
                }
            } label: {
                Label(configuration.kind.usesMediaLibraryBrowser ? "刷新详情数据" : "刷新来源", systemImage: "arrow.clockwise.circle")
            }
            if configuration.kind.usesMediaLibraryBrowser {
                Button {
                    statisticsConfiguration = configuration
                } label: {
                    Label("资源统计", systemImage: "chart.bar.xaxis")
                }
            }
            if configuration.kind.usesMediaLibraryBrowser {
                Divider()
                Button {
                    library.setPrivateServer(
                        configuration.id,
                        isPrivate: !configuration.isPrivateServer
                    )
                } label: {
                    Label(
                        configuration.isPrivateServer ? "取消隐私服务器" : "设为隐私服务器",
                        systemImage: configuration.isPrivateServer ? "eye" : "eye.slash"
                    )
                }
            }
            Button(role: .destructive) {
                serverPendingDeletion = configuration
            } label: {
                Label("删除", systemImage: "trash")
            }
    }

    @ViewBuilder
    private func sourceLatencyLabel(_ configuration: PlaylistConfiguration) -> some View {
        if let latency = sourceLatencies[configuration.id] {
            Text("\(latency)ms")
                .foregroundStyle(sourceLatencyColor(latency))
        } else if measuredSourceIDs.contains(configuration.id) {
            Text("无法访问")
                .foregroundStyle(.secondary)
        } else {
            Text("检测中")
                .foregroundStyle(.secondary)
        }
    }

    private func sourceLibrarySummary(_ configuration: PlaylistConfiguration) -> String {
        if configuration.isPrivateServer { return "隐私服务器" }
        if configuration.roveIsIPTVSource {
            switch configuration.kind {
            case .rss: return "RSS 视频订阅"
            case .legacySourceB: return "Xtream 频道"
            case .legacySourceA: return "Stalker 频道"
            case .single: return "网络播放地址"
            default: return "IPTV 频道"
            }
        }
        if let statistics = sourceStatistics[configuration.id] {
            return "剧集 \(statistics.series.unique.formatted(.number.grouping(.automatic)))"
        }
        let host = configuration.sourceAddress.flatMap(URL.init(string:))?.host ?? ""
        return host.isEmpty ? "媒体库" : host
    }

    private func sourceUpdatedText(_ date: Date) -> String {
        let calendar = Calendar.current
        let updatedDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        let elapsedDays = calendar.dateComponents([.day], from: updatedDay, to: today).day ?? 0
        return "\(max(0, elapsedDays))天前"
    }

    private func sourceCount(
        _ title: String,
        _ value: Int,
        systemImage: String
    ) -> some View {
        Label("\(title) \(value.formatted(.number.grouping(.automatic)))", systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private func loadStatistics(
        for configuration: PlaylistConfiguration,
        force: Bool = false
    ) async {
        guard configuration.kind.usesMediaLibraryBrowser,
              force
                || (sourceStatistics[configuration.id] == nil
                    && !sourceStatisticsFailures.contains(configuration.id)) else { return }
        do {
            let loaded = try await library.loadMediaLibraryStatistics(
                configurationID: configuration.id
            )
            guard !Task.isCancelled else { return }
            sourceStatistics[configuration.id] = loaded
            sourceStatisticsFailures.remove(configuration.id)
        } catch {
            guard !Task.isCancelled else { return }
            // Never present the initial 60 loaded cards as the server total.
            // Keep a previous successful value during a forced refresh, and
            // show an explicit unavailable state when no value exists yet.
            sourceStatisticsFailures.insert(configuration.id)
        }
    }

    private func measureLatency(for configuration: PlaylistConfiguration, force: Bool = false) async {
        guard force || !measuredSourceIDs.contains(configuration.id),
              let address = configuration.sourceAddress else { return }
        if force {
            measuredSourceIDs.remove(configuration.id)
            sourceLatencies[configuration.id] = nil
        }
        let latency = await RoveSourceLatencyProbe.measure(address)
        guard !Task.isCancelled else { return }
        measuredSourceIDs.insert(configuration.id)
        sourceLatencies[configuration.id] = latency
    }

    private func measureAllServerLatencies(force: Bool = false) async {
        let configurations = serverConfigurations.filter { $0.sourceAddress != nil }
        if force {
            measuredSourceIDs.subtract(configurations.map(\.id))
            for configuration in configurations {
                sourceLatencies[configuration.id] = nil
            }
        }
        await withTaskGroup(of: (UUID, Int?).self) { group in
            for configuration in configurations {
                guard force || !measuredSourceIDs.contains(configuration.id),
                      let address = configuration.sourceAddress else { continue }
                group.addTask {
                    (configuration.id, await RoveSourceLatencyProbe.measure(address))
                }
            }
            for await (id, latency) in group {
                guard !Task.isCancelled else { return }
                measuredSourceIDs.insert(id)
                sourceLatencies[id] = latency
            }
        }
    }

    private func loadAllServerStatistics() async {
        await withTaskGroup(of: Void.self) { group in
            for configuration in serverConfigurations where configuration.kind.usesMediaLibraryBrowser {
                group.addTask { await loadStatistics(for: configuration) }
            }
            await group.waitForAll()
        }
    }

    private func sourceLatencyColor(_ milliseconds: Int) -> Color {
        switch milliseconds {
        case ..<600: .green
        case ..<1_800: .orange
        default: .red
        }
    }

    private func deleteServer(_ configuration: PlaylistConfiguration) {
        guard deletingServerID == nil else { return }
        deletingServerID = configuration.id
        serverPendingDeletion = nil
        Task { @MainActor in
            _ = await library.deleteConfiguration(configuration.id)
            deletingServerID = nil
        }
    }

    @ViewBuilder
    private func sourceBrandIcon(_ configuration: PlaylistConfiguration) -> some View {
        RoveServerBrandIcon(configuration: configuration, size: 26)
    }

    private var addSourceCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.roveAccent)
            Text("添加资源库")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: sourceCardHeight,
            maxHeight: sourceCardHeight
        )
        .background {
            RoveSourceGlassCardBackground(tint: Color.roveAccent)
        }
    }

    private func sourceAddRow(
        _ item: (String, String, String, RoveSourceSheet)
    ) -> some View {
        Button { onOpenSource(item.3) } label: {
            HStack(spacing: 12) {
                Image(systemName: item.2)
                    .font(.headline)
                    .foregroundStyle(Color.roveAccent)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(item.1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var connectedSources: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoveSectionHeader(title: "已连接")

            if library.configurations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有来源")
                        .font(.headline)
                    Text("添加后，RovePlayer 会把媒体、最近播放和收藏统一整理。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("添加来源", action: onAddSource)
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(library.configurations) { configuration in
                        sourceRow(configuration)
                        if configuration.id != library.configurations.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func sourceRow(_ configuration: PlaylistConfiguration) -> some View {
        Button {
            library.selectConfiguration(configuration.id)
            selectedTab = .channels
        } label: {
            HStack(spacing: 12) {
                Image(systemName: configuration.kind.systemImage)
                    .font(.headline)
                    .foregroundStyle(sourceColor(configuration.kind))
                    .frame(width: 36, height: 36)
                    .background(sourceColor(configuration.kind).opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(configuration.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if library.activeConfigurationID == configuration.id {
                            Text("当前")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.roveAccent)
                        }
                    }
                    Text("\(configuration.kind.title) · \(configuration.totalItemCount ?? configuration.channels.count) 项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await library.refreshConfiguration(configuration.id) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("刷新 \(configuration.name)")

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await library.deleteConfiguration(configuration.id) }
            } label: {
                Label("移除来源", systemImage: "trash")
            }
        }
    }

    private var addSourceGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoveSectionHeader(title: "添加来源")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(quickSources.enumerated()), id: \.offset) { _, item in
                    Button { onOpenSource(item.3) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: item.2)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.roveAccent)
                            Text(item.0)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(item.1)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button { onOpenSource(.directStream) } label: {
                Label("打开网络直链", systemImage: "link")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    private func sourceColor(_ kind: PlaylistConfigurationKind) -> Color {
        switch kind {
        case .legacyLibraryB, .zspaceVideo, .legacyLibraryA, .movieClaw, .legacyLibraryC: .green
        case .legacyLibraryD: .orange
        case .legacySourceC: .blue
        case .subscription, .rss, .legacySourceB, .legacySourceA: .cyan
        case .single, .local: .yellow
        case .aggregate: Color.roveAccent
        }
    }
}

private struct RoveSourceGlassCardBackground: View {
    let tint: Color

    @Environment(\.colorScheme) private var colorScheme

    private let shape = RoundedRectangle(cornerRadius: 27, style: .continuous)

    var body: some View {
        shape
            .fill(.regularMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.58),
                        tint.opacity(colorScheme == .dark ? 0.18 : 0.22),
                        tint.opacity(colorScheme == .dark ? 0.08 : 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.30 : 0.72),
                                tint.opacity(colorScheme == .dark ? 0.26 : 0.34),
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.24)
                    : tint.opacity(0.10),
                radius: 14,
                y: 6
            )
    }
}

private enum RoveSourceLatencyProbe {
    static func measure(_ rawAddress: String) async -> Int? {
        let trimmed = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: normalized), url.host != nil else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let configuration = ProxyNetworkConfiguration.configured(.ephemeral)
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        let started = ContinuousClock.now
        do {
            _ = try await URLSession(configuration: configuration).data(for: request)
            let elapsed = started.duration(to: .now)
            return max(1, Int(elapsed.components.seconds * 1_000)
                + Int(elapsed.components.attoseconds / 1_000_000_000_000_000))
        } catch {
            return nil
        }
    }
}

private struct RoveResourceStatisticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ChannelLibrary
    let configuration: PlaylistConfiguration
    @State private var statistics: MediaLibraryStatistics?
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Image(systemName: configuration.kind.systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.roveAccent)
                        .frame(width: 44, height: 44)
                        .background(Color.roveAccent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(configuration.name)
                            .font(.headline.weight(.bold))
                        Text(configuration.kind.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let statistics {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 20) {
                        GridRow {
                            Color.clear.frame(width: 52, height: 1)
                            Text("不含多版本")
                            Text("包含多版本")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        statisticsRow("电影", statistics.movies)
                        statisticsRow("剧集", statistics.series)
                        statisticsRow("集", statistics.episodes)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在读取服务器统计")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else if loadFailed {
                    Text("服务器暂时不可用，统计数量暂时无法读取。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(22)
            .navigationTitle("资源统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task(id: configuration.id) {
            do {
                statistics = try await library.loadMediaLibraryStatistics(
                    configurationID: configuration.id
                )
            } catch {
                loadFailed = true
            }
            isLoading = false
        }
    }

    private func statisticsRow(
        _ title: String,
        _ count: MediaLibraryStatistics.ItemCount
    ) -> some View {
        GridRow {
            Text(title).font(.headline.weight(.bold))
            Text(count.unique.formatted(.number.grouping(.automatic)))
            Text(count.allVersions.formatted(.number.grouping(.automatic)))
        }
        .font(.title2.weight(.medium))
    }
}

private struct RoveServerBrandIcon: View {
    let configuration: PlaylistConfiguration
    let size: CGFloat
    @State private var remoteImage: UIImage?

    var body: some View {
        Group {
            switch configuration.serverIcon?.kind {
            case .preset:
                Image(systemName: configuration.serverIcon?.value ?? configuration.kind.systemImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
                    .foregroundStyle(Color.roveAccent)
                    .background(Color.roveAccent.opacity(0.12))
            case .remote:
                if let remoteImage {
                    Image(uiImage: remoteImage).resizable().scaledToFill()
                } else { defaultIcon }
            case .local:
                if let image = RoveServerIconStore.image(configurationID: configuration.id) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    defaultIcon
                }
            case nil:
                defaultIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(6, size * 0.23), style: .continuous))
        .task(id: configuration.serverIcon?.value) {
            guard configuration.serverIcon?.kind == .remote else { remoteImage = nil; return }
            remoteImage = await RoveRemoteImageCache.shared.image(
                for: configuration.serverIcon?.value.flatMap(URL.init(string:))
            )
        }
    }

    @ViewBuilder
    private var defaultIcon: some View {
        if let brandImage = configuration.kind.brandImage {
            Image(brandImage).resizable().scaledToFit()
        } else {
            Image(systemName: configuration.kind.systemImage)
                .resizable()
                .scaledToFit()
                .padding(size * 0.18)
                .foregroundStyle(Color.roveAccent)
                .background(Color.roveAccent.opacity(0.12))
        }
    }
}

private struct RoveCatalogIconImage: View {
    let url: String
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if failed {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .task(id: url) {
            guard let imageURL = URL(string: url) else {
                failed = true
                return
            }
            let loaded = await RoveRemoteImageCache.shared.image(for: imageURL)
            guard !Task.isCancelled else { return }
            image = loaded
            failed = loaded == nil
        }
    }
}

private struct RoveServerIconPicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ChannelLibrary
    let configuration: PlaylistConfiguration

    @State private var photoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var remoteURL = ""
    @State private var catalogURLs: [String] = []
    @State private var catalogAddress = ""
    @State private var catalogs: [RoveIconCatalog] = []
    @State private var loadingCatalogAddress: String?
    @State private var refreshingCatalogSources: Set<String> = []
    @State private var iconSearchText = ""
    @State private var catalogDisplayLimits: [String: Int] = [:]
    @State private var errorMessage: String?
    @State private var catalogFeedback: String?

    private let iconPageSize = 64

    private let presets = [
        "server.rack", "play.square.stack.fill", "film.stack.fill", "sparkles",
        "cloud.fill", "house.fill", "bolt.fill", "leaf.fill", "externaldrive.fill",
        "globe.asia.australia.fill", "person.2.fill", "star.fill"
    ]

    private var current: PlaylistConfiguration {
        library.configurations.first(where: { $0.id == configuration.id }) ?? configuration
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("实时预览") {
                    HStack(spacing: 14) {
                        RoveServerBrandIcon(configuration: current, size: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(current.name).font(.headline)
                            Text(current.kind.title).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("预设图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 18) {
                        ForEach(presets, id: \.self) { name in
                            Button {
                                library.setServerIcon(
                                    configuration.id,
                                    selection: .init(kind: .preset, value: name)
                                )
                            } label: {
                                Image(systemName: name)
                                    .font(.title2)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        current.serverIcon?.kind == .preset
                                            && current.serverIcon?.value == name
                                            ? Color.roveAccent.opacity(0.18) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("自定义图片") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("从相册选择", systemImage: "photo.on.rectangle")
                    }
                    Button("从文件选择", systemImage: "folder") {
                        showingFileImporter = true
                    }
                }

                Section("图片直链") {
                    TextField("https://example.com/icon.png", text: $remoteURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button("使用图片直链", systemImage: "link") { applyRemoteURL() }
                        .disabled(validRemoteURL == nil)
                }

                Section("图标库地址") {
                    Text("粘贴 JSON 图标库地址，加载后点选具体图标。可添加多个地址。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(catalogURLs, id: \.self) { address in
                        HStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.up")
                                .foregroundStyle(Color.roveAccent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(RoveIconCatalogStore.isBuiltIn(address) ? "良友媒体图标库 · 默认" : address)
                                    .font(.caption.monospaced())
                                    .lineLimit(2)
                                if RoveIconCatalogStore.isBuiltIn(address),
                                   let description = catalogs.first(where: { $0.source == address })?.description,
                                   !description.isEmpty {
                                    Text(description)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                            if !RoveIconCatalogStore.isBuiltIn(address) {
                                Button {
                                    removeCatalog(address)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    TextField("https://example.com/icons.json", text: $catalogAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button(
                        loadingCatalogAddress == normalizedCatalogAddress ? "加载中…" : "添加并加载图标库",
                        systemImage: "plus"
                    ) {
                        addCatalog()
                    }
                    .disabled(normalizedCatalogAddress == nil || loadingCatalogAddress != nil)
                }

                if !catalogs.isEmpty {
                    Section {
                        TextField("搜索图标", text: $iconSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                ForEach(catalogs) { catalog in
                    let matchingIcons = filteredIcons(in: catalog)
                    let displayLimit = catalogDisplayLimits[catalog.source] ?? iconPageSize
                    let visibleIcons = Array(matchingIcons.prefix(displayLimit))
                    Section {
                        if let description = catalog.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 4)
                        }
                        if matchingIcons.isEmpty {
                            ContentUnavailableView("没有匹配的图标", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                                ForEach(visibleIcons) { icon in
                                    Button {
                                        applyCatalogIcon(icon)
                                    } label: {
                                        VStack(spacing: 6) {
                                            RoveCatalogIconImage(url: icon.url)
                                                .frame(width: 50, height: 50)
                                                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                                            Text(icon.name)
                                                .font(.caption2)
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)

                            if visibleIcons.count < matchingIcons.count {
                                Button {
                                    catalogDisplayLimits[catalog.source, default: iconPageSize] += iconPageSize
                                } label: {
                                    Label(
                                        "加载更多（还剩 \(matchingIcons.count - visibleIcons.count) 个）",
                                        systemImage: "arrow.down.circle"
                                    )
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 4)
                            }
                        }
                    } header: {
                        HStack {
                            Text(catalog.name)
                            Spacer(minLength: 8)
                            Text("\(visibleIcons.count)/\(matchingIcons.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                refreshCatalog(catalog)
                            } label: {
                                if refreshingCatalogSources.contains(catalog.source) {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(refreshingCatalogSources.contains(catalog.source))
                            .accessibilityLabel("刷新 \(catalog.name)")
                        }
                    }
                }

                Section {
                    Button("恢复默认图标", systemImage: "arrow.uturn.backward") {
                        RoveServerIconStore.remove(configurationID: configuration.id)
                        library.setServerIcon(configuration.id, selection: nil)
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("更换图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                if current.serverIcon?.kind == .remote { remoteURL = current.serverIcon?.value ?? "" }
                catalogURLs = RoveIconCatalogStore.urls
                loadStoredCatalogs()
            }
            .alert("图标库", isPresented: Binding(
                get: { catalogFeedback != nil },
                set: { if !$0 { catalogFeedback = nil } }
            )) {
                Button("好", role: .cancel) { catalogFeedback = nil }
            } message: {
                Text(catalogFeedback ?? "")
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        errorMessage = "无法读取所选图片"
                        return
                    }
                    saveLocalImage(data)
                }
            }
            .onChange(of: iconSearchText) { _, _ in
                // A new query starts at the first page for every catalog.
                catalogDisplayLimits = [:]
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else {
                    errorMessage = "无法读取所选文件"
                    return
                }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do { saveLocalImage(try Data(contentsOf: url)) }
                catch { errorMessage = error.localizedDescription }
            }
        }
    }

    private var validRemoteURL: URL? {
        guard let url = URL(string: remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false else { return nil }
        return url
    }

    private var normalizedCatalogAddress: String? {
        let value = catalogAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false,
              !catalogURLs.contains(value) else { return nil }
        return value
    }

    private func applyRemoteURL() {
        guard let url = validRemoteURL else { return }
        if url.pathExtension.lowercased() == "json" {
            catalogAddress = url.absoluteString
            addCatalog()
            return
        }
        library.setServerIcon(
            configuration.id,
            selection: .init(kind: .remote, value: url.absoluteString)
        )
        errorMessage = nil
    }

    private func applyCatalogIcon(_ icon: RoveIconCatalogEntry) {
        library.setServerIcon(
            configuration.id,
            selection: .init(kind: .remote, value: icon.url)
        )
        remoteURL = icon.url
        errorMessage = nil
    }

    private func filteredIcons(in catalog: RoveIconCatalog) -> [RoveIconCatalogEntry] {
        let query = iconSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return catalog.icons }
        return catalog.icons.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.url.localizedCaseInsensitiveContains(query)
        }
    }

    private func addCatalog() {
        guard let address = normalizedCatalogAddress else { return }
        loadingCatalogAddress = address
        errorMessage = nil
        Task {
            do {
                let catalog = try await RoveIconCatalogService.load(from: address)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if !catalogURLs.contains(address) { catalogURLs.append(address) }
                    if let index = catalogs.firstIndex(where: { $0.source == address }) {
                        catalogs[index] = catalog
                    } else {
                        catalogs.append(catalog)
                    }
                    RoveIconCatalogStore.save(urls: catalogURLs)
                    catalogDisplayLimits[address] = iconPageSize
                    catalogAddress = ""
                    loadingCatalogAddress = nil
                    errorMessage = nil
                    catalogFeedback = "已加载“\(catalog.name)”，共 \(catalog.icons.count) 个图标。向下滚动即可选择。"
                }
            } catch {
                await MainActor.run {
                    loadingCatalogAddress = nil
                    errorMessage = error.localizedDescription
                    catalogFeedback = "加载失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func removeCatalog(_ address: String) {
        catalogURLs.removeAll { $0 == address }
        catalogs.removeAll { $0.source == address }
        catalogDisplayLimits.removeValue(forKey: address)
        RoveIconCatalogStore.save(urls: catalogURLs)
    }

    private func refreshCatalog(_ catalog: RoveIconCatalog) {
        guard !refreshingCatalogSources.contains(catalog.source) else { return }
        refreshingCatalogSources.insert(catalog.source)
        Task {
            do {
                let refreshed = try await RoveIconCatalogService.load(from: catalog.source)
                await MainActor.run {
                    if let index = catalogs.firstIndex(where: { $0.source == catalog.source }) {
                        catalogs[index] = refreshed
                    } else {
                        catalogs.append(refreshed)
                    }
                    refreshingCatalogSources.remove(catalog.source)
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    refreshingCatalogSources.remove(catalog.source)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadStoredCatalogs() {
        for address in catalogURLs {
            Task {
                guard let catalog = try? await RoveIconCatalogService.load(from: address),
                      !Task.isCancelled else { return }
                await MainActor.run {
                    guard !catalogs.contains(where: { $0.source == catalog.source }) else { return }
                    catalogs.append(catalog)
                }
            }
        }
    }

    private func saveLocalImage(_ data: Data) {
        do {
            try RoveServerIconStore.save(data, configurationID: configuration.id)
            library.setServerIcon(configuration.id, selection: .init(kind: .local, value: nil))
            errorMessage = nil
        } catch {
            errorMessage = "图片保存失败：\(error.localizedDescription)"
        }
    }
}

private struct RoveServerRemarkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ChannelLibrary
    let configuration: PlaylistConfiguration

    @State private var remark: String

    init(configuration: PlaylistConfiguration) {
        self.configuration = configuration
        _remark = State(initialValue: configuration.serverRemark ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(originalServerName, text: $remark)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("卡片名称")
                } footer: {
                    Text("自定义名称会直接显示为卡片主标题；留空则显示服务器名称“\(originalServerName)”。")
                }

                if !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Button("恢复原服务器名称", role: .destructive) {
                            remark = ""
                        }
                    }
                }
            }
            .navigationTitle("重命名服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        library.setServerRemark(configuration.id, remark: remark)
                        dismiss()
                    }
                }
            }
        }
    }

    private var originalServerName: String {
        let value = configuration.serverReportedName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? configuration.name : value
    }
}

private struct RoveServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ChannelLibrary
    let configuration: PlaylistConfiguration

    @State private var showingConnectionEditor = false
    @State private var showingIconPicker = false
    @State private var showingRemarkEditor = false
    @State private var showingRoutes = false
    @State private var preloadPreference: RoveServerPreloadPreference
    @State private var notifications: RoveLibraryNotificationPreferences

    init(configuration: PlaylistConfiguration) {
        self.configuration = configuration
        _preloadPreference = State(initialValue: configuration.preloadPreference)
        _notifications = State(initialValue: configuration.libraryNotifications)
    }

    private var current: PlaylistConfiguration {
        library.configurations.first(where: { $0.id == configuration.id }) ?? configuration
    }

    private var currentRemark: String {
        let value = current.serverRemark?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? current.name : value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    Button { showingIconPicker = true } label: {
                        HStack(spacing: 12) {
                            RoveServerBrandIcon(configuration: current, size: 36)
                            LabeledContent("更换图标", value: current.name)
                        }
                    }
                    .foregroundStyle(.primary)
                    Button { showingRemarkEditor = true } label: {
                        LabeledContent(
                            "卡片名称",
                            value: currentRemark
                        )
                    }
                    .foregroundStyle(.primary)
                    if configuration.isWebImportProtected != true {
                        Button("登录与地址", systemImage: "person.crop.circle") {
                            showingConnectionEditor = true
                        }
                    }
                    Button("线路与反代", systemImage: "point.3.connected.trianglepath.dotted") {
                        showingRoutes = true
                    }
                }

                Section {
                    Picker("预加载", selection: $preloadPreference) {
                        ForEach(RoveServerPreloadPreference.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } header: {
                    Text("播放")
                } footer: {
                    Text("跟随全局时使用播放设置中的缓冲模式；关闭会跳过额外启动缓冲，磁盘模式会保留可继续查看的缓存。")
                }

                Section {
                    NavigationLink {
                        RoveLibraryPushSettingsView(configuration: current)
                    } label: {
                        Label("实时入库推送", systemImage: "paperplane.fill")
                    }
                    Toggle("新电影", isOn: $notifications.movies)
                    Toggle("新剧集", isOn: $notifications.series)
                    Toggle("新分集 / 订阅内容", isOn: $notifications.episodes)
                } header: {
                    Text("入库通知")
                } footer: {
                    Text("本地检测在服务器刷新后工作；实时推送可通过 Telegram 机器人生成口令，在 App 彻底退出时仍接收服务器 Webhook 通知。")
                }
            }
            .navigationTitle("服务器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .onChange(of: preloadPreference) { _, value in
                library.setServerPreloadPreference(configuration.id, preference: value)
            }
            .onChange(of: notifications) { oldValue, value in
                library.setLibraryNotificationPreferences(configuration.id, preferences: value)
                if !oldValue.isEnabled, value.isEnabled {
                    Task { _ = await RoveLibraryNotificationService.shared.requestAuthorization() }
                }
            }
            .sheet(isPresented: $showingConnectionEditor) {
                ConfigurationEditorView(configuration: current)
            }
            .sheet(isPresented: $showingIconPicker) {
                RoveServerIconPicker(configuration: current)
            }
            .sheet(isPresented: $showingRemarkEditor) {
                RoveServerRemarkEditor(configuration: current)
            }
            .sheet(isPresented: $showingRoutes) {
                RoveServerRouteManager(configuration: current)
            }
        }
    }
}

private struct RoveLibraryPushSettingsView: View {
    let configuration: PlaylistConfiguration

    @Environment(\.openURL) private var openURL
    @ObservedObject private var pushService = RoveRemotePushService.shared
    @State private var pushCode = ""
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    private var currentBindings: [RoveRemotePushBinding] {
        pushService.bindings(for: configuration.id)
    }

    var body: some View {
        Form {
            Section {
                Button {
                    openURL(RoveRemotePushService.telegramBotURL)
                } label: {
                    Label("打开 @rovepush_bot", systemImage: "paperplane.circle.fill")
                }

                HStack(spacing: 10) {
                    TextField("输入推送口令", text: $pushCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())

                    Button("添加") {
                        bindPushCode()
                    }
                    .fontWeight(.semibold)
                    .disabled(pushCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pushService.isWorking)
                }

                if pushService.isWorking {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在绑定设备…")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("入库通知")
            } footer: {
                Text("在 Telegram 机器人发送 /new，登记媒体服务器地址并取得推送口令；再把口令粘贴到这里。首次添加会请求系统通知权限。")
            }

            if !currentBindings.isEmpty {
                Section("已绑定") {
                    ForEach(currentBindings) { binding in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(binding.serverName)
                                    .font(.body.weight(.medium))
                                Text(binding.maskedCode)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete(perform: removeBindings)
                }
            }

            Section {
                LabeledContent("通知权限", value: authorizationTitle)
                if pushService.authorizationStatus == .denied {
                    Button("打开系统通知设置") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                }
            } header: {
                Text("状态")
            } footer: {
                Text("Bot Token 与 Apple 推送密钥只保存在 RovePlayer 服务端，不会写入 App 或同步到 iCloud。")
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("入库推送")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await pushService.refreshAuthorizationStatus()
        }
        .alert("无法添加推送口令", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private var authorizationTitle: String {
        switch pushService.authorizationStatus {
        case .authorized: "已允许"
        case .provisional: "临时允许"
        case .ephemeral: "本次允许"
        case .denied: "未允许"
        case .notDetermined: "尚未请求"
        @unknown default: "未知"
        }
    }

    private func bindPushCode() {
        let code = pushCode
        statusMessage = nil
        Task {
            do {
                try await pushService.bind(code: code, to: configuration)
                pushCode = ""
                statusMessage = "推送口令已绑定"
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func removeBindings(at offsets: IndexSet) {
        let targets = offsets.compactMap { index in
            currentBindings.indices.contains(index) ? currentBindings[index] : nil
        }
        Task {
            for binding in targets {
                do {
                    try await pushService.remove(binding)
                } catch {
                    errorMessage = error.localizedDescription
                    return
                }
            }
        }
    }
}

private struct RoveServerRouteManager: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ChannelLibrary

    let configuration: PlaylistConfiguration
    @State private var routes: [String]
    @State private var routeNames: [String: String]
    @State private var selectedRoute: String
    @State private var newRoute = ""
    @State private var newRouteName = ""
    @State private var isSaving = false
    @State private var automaticallySelectBestRoute: Bool
    @State private var automaticallyFetchBackupRoutes: Bool
    @State private var routeLatencies: [String: Int] = [:]
    @State private var isProbing = false

    init(configuration: PlaylistConfiguration) {
        self.configuration = configuration
        let current = configuration.sourceAddress ?? ""
        var initialRoutes = configuration.serverRoutes
        if !current.isEmpty, !initialRoutes.contains(current) {
            initialRoutes.insert(current, at: 0)
        }
        _routes = State(initialValue: initialRoutes)
        _routeNames = State(initialValue: configuration.serverRouteNames)
        _selectedRoute = State(initialValue: current)
        _automaticallySelectBestRoute = State(
            initialValue: configuration.automaticallySelectBestServerRoute
        )
        _automaticallyFetchBackupRoutes = State(
            initialValue: configuration.automaticallyFetchBackupRoutes
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(routes, id: \.self) { route in
                        Button {
                            selectedRoute = route
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedRoute == route ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedRoute == route ? Color.roveAccent : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    if let name = routeNames[route], !name.isEmpty {
                                        Text(name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                    Text(route)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                if let latency = routeLatencies[route] {
                                    Text("\(latency) ms")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(latency < 600 ? .green : (latency < 1_800 ? .orange : .red))
                                }
                            }
                        }
                        .swipeActions {
                            if routes.count > 1 {
                                Button("删除", role: .destructive) {
                                    removeRoute(route)
                                }
                            }
                        }
                    }
                } header: {
                    Text("服务器线路")
                } footer: {
                    Text("选择线路并保存后会立即连接验证；连接失败时自动恢复原线路。")
                }

                Section {
                    Toggle("自动获取备用线路", isOn: $automaticallyFetchBackupRoutes)
                    Toggle("自动选择延迟最低线路", isOn: $automaticallySelectBestRoute)
                    Button("立即获取备用线路", systemImage: "arrow.triangle.2.circlepath") {
                        fetchBackupRoutes()
                    }
                    .disabled(isProbing || isSaving)
                    Button(isProbing ? "检测中…" : "检测全部线路", systemImage: "gauge.with.dots.needle.33percent") {
                        probeRoutes()
                    }
                    .disabled(isProbing || routes.isEmpty)
                } footer: {
                    Text("自动获取使用服务器发布的线路接口，并与手动线路合并；检测结果仅用于选择入口地址。")
                }

                Section("添加线路") {
                    TextField("线路名称（可选）", text: $newRouteName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("https://example.com:8096", text: $newRoute)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button("添加线路", systemImage: "plus") {
                        addRoute()
                    }
                    .disabled(normalizedNewRoute == nil)
                }
            }
            .navigationTitle("线路与反代")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中…" : "保存") {
                        save()
                    }
                    .disabled(isSaving || routes.isEmpty || !routes.contains(selectedRoute))
                }
            }
            .libraryErrorAlert(library)
            .onChange(of: automaticallyFetchBackupRoutes) { wasEnabled, isEnabled in
                if isEnabled, !wasEnabled {
                    fetchBackupRoutes()
                }
            }
            .task {
                if automaticallyFetchBackupRoutes {
                    fetchBackupRoutes()
                } else if automaticallySelectBestRoute {
                    probeRoutes()
                }
            }
        }
    }

    private var normalizedNewRoute: String? {
        let trimmed = newRoute.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host?.isEmpty == false,
              !routes.contains(trimmed) else { return nil }
        return trimmed
    }

    private func addRoute() {
        guard let route = normalizedNewRoute else { return }
        routes.append(route)
        let name = newRouteName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { routeNames[route] = String(name.prefix(100)) }
        selectedRoute = route
        newRoute = ""
        newRouteName = ""
    }

    private func removeRoute(_ route: String) {
        routes.removeAll { $0 == route }
        routeNames.removeValue(forKey: route)
        if selectedRoute == route {
            selectedRoute = routes.first ?? ""
        }
    }

    private func save() {
        guard !isSaving else { return }
        if automaticallySelectBestRoute,
           let fastest = routeLatencies.min(by: { $0.value < $1.value })?.key {
            selectedRoute = fastest
        }
        isSaving = true
        Task { @MainActor in
            let saved = await library.updateServerRoutes(
                configuration.id,
                routes: routes,
                activeRoute: selectedRoute,
                routeNames: routeNames,
                automaticallySelectBestRoute: automaticallySelectBestRoute,
                automaticallyFetchBackupRoutes: automaticallyFetchBackupRoutes
            )
            isSaving = false
            if saved { dismiss() }
        }
    }

    private func fetchBackupRoutes() {
        guard !isSaving, !isProbing else { return }
        isProbing = true
        Task { @MainActor in
            if let merged = await library.fetchAndMergeServerRoutes(configuration.id) {
                routes = merged
                routeNames = routeNames.filter { merged.contains($0.key) }
                if !routes.contains(selectedRoute) {
                    selectedRoute = routes.first ?? ""
                }
                isProbing = false
                if automaticallySelectBestRoute {
                    probeRoutes()
                }
            } else {
                isProbing = false
            }
        }
    }

    private func probeRoutes() {
        guard !isProbing else { return }
        isProbing = true
        Task {
            let measured = await withTaskGroup(of: (String, Int?).self) { group in
                for route in routes {
                    group.addTask { (route, await RoveSourceLatencyProbe.measure(route)) }
                }
                var values: [String: Int] = [:]
                for await (route, latency) in group {
                    if let latency { values[route] = latency }
                }
                return values
            }
            routeLatencies = measured
            if automaticallySelectBestRoute,
               let fastest = measured.min(by: { $0.value < $1.value })?.key {
                selectedRoute = fastest
            }
            isProbing = false
        }
    }
}

#endif

private enum RoveSavedFilter: String, CaseIterable, Identifiable, Hashable {
    case watchlist = "待看"
    case favorites = "收藏"
    case recent = "记录"

    var id: String { rawValue }
}

private struct RoveSavedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var library: ChannelLibrary
    @State private var selectedChannel: Channel?
    @State private var selectedTMDBMovie: TMDBFeaturedMovie?
    @State private var themeColor = UIColor.systemTeal
    @State private var mediaStateRevision = 0
    @Namespace private var mediaHeroNamespace
    let showsBackButton: Bool

    init(initialFilter: RoveSavedFilter = .favorites, showsBackButton: Bool = true) {
        _ = initialFilter
        self.showsBackButton = showsBackButton
    }

    private var channels: [Channel] {
        library.favoriteChannels
    }

    private var sections: [RoveSavedSection] {
        let grouped = Dictionary(grouping: channels, by: RoveSavedMediaKind.init(channel:))
        return RoveSavedMediaKind.allCases.compactMap { kind in
            guard let values = grouped[kind], !values.isEmpty else { return nil }
            return RoveSavedSection(kind: kind, channels: values)
        }
    }

    private var profileTitle: String {
        "DJHUB"
    }

    var body: some View {
        ZStack {
            RoveSavedBackdrop(tint: Color(uiColor: themeColor))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    topBar
                        .roveEntrance(distance: 8)

                    if channels.isEmpty {
                        ContentUnavailableView(
                            emptyTitle,
                            systemImage: emptySystemImage,
                            description: Text(emptyDescription)
                        )
                        .frame(maxWidth: .infinity, minHeight: 380)
                    } else {
                        ForEach(sections) { section in
                            savedSection(section)
                                .roveEntrance(delay: 0.04, distance: 10)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .id(mediaStateRevision)
        .toolbar(.hidden, for: .navigationBar)
        .background {
            // This screen uses a custom top bar. Re-enable NavigationStack's
            // native edge-pop gesture that is normally installed by the
            // visible navigation bar.
            RoveNativeInteractivePopGestureEnabler()
                .frame(width: 0, height: 0)
        }
        .navigationDestination(item: $selectedChannel) { channel in
            RoveMediaDetailView(channel: channel)
                .roveHeroNavigationTransition(
                    id: "saved-channel-\(channel.id.uuidString)",
                    namespace: mediaHeroNamespace
                )
        }
        .navigationDestination(item: $selectedTMDBMovie) { movie in
            RoveMediaDetailView(recommendation: movie)
                .roveHeroNavigationTransition(
                    id: "saved-channel-\(movie.identity)",
                    namespace: mediaHeroNamespace
                )
        }
        .task(id: channels.first?.id) {
            guard let first = channels.first,
                  let image = await ChannelArtworkLoader.shared.image(for: first, maxWidth: 420)
            else { return }
            withAnimation(reduceMotion ? nil : RoveMotion.carousel) {
                themeColor = image.roveImmersiveColor
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            if showsBackButton {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.42), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
            }

            HStack(spacing: 9) {
                Image("MediaDeckBrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.78), in: Circle())

                Text(profileTitle)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
            }
            .padding(.leading, 8)
            .padding(.trailing, 15)
            .frame(height: 48)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.46), lineWidth: 1))

            Spacer(minLength: 0)
        }
    }

    private func savedSection(_ section: RoveSavedSection) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text(sectionTitle(for: section.kind))
                    .font(.title2.weight(.heavy))
                Spacer()
                NavigationLink {
                    RoveSavedCollectionView(
                        title: sectionTitle(for: section.kind),
                        channels: section.channels,
                        tint: Color(uiColor: themeColor)
                    )
                } label: {
                    HStack(spacing: 3) {
                        Text("查看全部")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: 3),
                alignment: .leading,
                spacing: 18
            ) {
                ForEach(Array(section.channels.prefix(3))) { channel in
                    savedPoster(channel, kind: section.kind)
                }
            }
        }
    }

    @ViewBuilder
    private func savedPoster(_ channel: Channel, kind: RoveSavedMediaKind) -> some View {
        Button { openSavedChannel(channel) } label: {
            RoveSavedPosterCard(
                channel: channel,
                kind: kind,
                group: library.displayGroup(for: channel),
                transitionID: "saved-channel-\(channel.id.uuidString)",
                transitionNamespace: mediaHeroNamespace
            )
        }
        .buttonStyle(RoveMotionButtonStyle())
    }

    private var emptyTitle: String {
        "还没有收藏"
    }

    private var emptySystemImage: String {
        "bookmark"
    }

    private var emptyDescription: String {
        "在短剧详情页点击收藏，作品会收进这里。"
    }

    private func openSavedChannel(_ channel: Channel) {
        selectedChannel = channel
    }

    private func sectionTitle(for kind: RoveSavedMediaKind) -> String {
        _ = kind
        return "收藏的短剧"
    }
}

private enum RoveSavedMediaKind: String, CaseIterable, Identifiable {
    case series
    case movies
    case other

    var id: String { rawValue }

    init(channel: Channel) {
        let type = channel.mediaServerItemType?.lowercased() ?? ""
        if channel.isMediaServerSeries
            || channel.isMediaServerEpisode
            || ["series", "season", "episode", "tv", "tvshow", "show"].contains(type) {
            self = .series
        } else if channel.isExplicitlyOnDemand
            || ["movie", "video", "musicvideo", "program"].contains(type) {
            self = .movies
        } else {
            self = .other
        }
    }
}

private struct RoveSavedSection: Identifiable {
    let kind: RoveSavedMediaKind
    let channels: [Channel]

    var id: String { kind.id }
}

private struct RoveSavedBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.black, tint.opacity(0.34), Color.black]
                : [Color(uiColor: .systemBackground), tint.opacity(0.18), Color.cyan.opacity(0.16)],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .overlay(
            LinearGradient(
                colors: [Color.clear, Color.pink.opacity(colorScheme == .dark ? 0.08 : 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .ignoresSafeArea()
    }
}

private struct RoveSavedPosterCard: View {
    let channel: Channel
    let kind: RoveSavedMediaKind
    let group: String
    let transitionID: AnyHashable?
    let transitionNamespace: Namespace.ID?

    private var subtitle: String {
        if let year = channel.productionYear {
            return kind == .series ? "\(year) - 现在" : String(year)
        }
        return kind == .other ? group : (kind == .series ? "剧集" : "电影")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                RoveArtworkView(channel: channel, landscape: false)
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let rating = channel.communityRating, rating > 0 {
                    Text(String(format: "%.1f", rating))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.74))
                }
            }
            .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
            .roveHeroTransitionSource(
                id: transitionID,
                namespace: transitionNamespace
            )

            Text(channel.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct RoveSavedCollectionView: View {
    @EnvironmentObject private var library: ChannelLibrary
    let title: String
    let channels: [Channel]
    let tint: Color
    @State private var selectedChannel: Channel?
    @State private var mediaStateRevision = 0
    @Namespace private var mediaHeroNamespace

    var body: some View {
        ZStack {
            RoveSavedBackdrop(tint: tint)
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: 3),
                    alignment: .leading,
                    spacing: 20
                ) {
                    ForEach(channels) { channel in
                        let kind = RoveSavedMediaKind(channel: channel)
                        Button { selectedChannel = channel } label: {
                            RoveSavedPosterCard(
                                channel: channel,
                                kind: kind,
                                group: library.displayGroup(for: channel),
                                transitionID: "saved-all-channel-\(channel.id.uuidString)",
                                transitionNamespace: mediaHeroNamespace
                            )
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                        .roveMediaActions(
                            for: channel,
                            onOpen: { selectedChannel = channel },
                            onStateChange: { mediaStateRevision += 1 }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
        }
        .id(mediaStateRevision)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedChannel) { channel in
            RoveMediaDetailView(channel: channel)
                .roveHeroNavigationTransition(
                    id: "saved-all-channel-\(channel.id.uuidString)",
                    namespace: mediaHeroNamespace
                )
        }
    }
}

private struct RoveWatchlistCollectionView: View {
    @EnvironmentObject private var library: ChannelLibrary
    @ObservedObject private var watchlistStore = RoveWatchlistStore.shared
    let title: String
    let tint: Color
    private let entryIDs: Set<String>

    @State private var selectedChannel: Channel?
    @State private var selectedTMDBMovie: TMDBFeaturedMovie?
    @Namespace private var mediaHeroNamespace

    init(title: String, entries: [RoveWatchlistEntry], tint: Color) {
        self.title = title
        self.tint = tint
        entryIDs = Set(entries.map(\.id))
    }

    private var entries: [RoveWatchlistEntry] {
        watchlistStore.entries.filter { entryIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            RoveSavedBackdrop(tint: tint)
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: 3),
                    alignment: .leading,
                    spacing: 20
                ) {
                    ForEach(entries) { entry in
                        let channel = entry.displayChannel
                        let kind = RoveSavedMediaKind(channel: channel)
                        Button { open(entry) } label: {
                            RoveSavedPosterCard(
                                channel: channel,
                                kind: kind,
                                group: library.displayGroup(for: channel),
                                transitionID: "watchlist-all-\(entry.id)",
                                transitionNamespace: mediaHeroNamespace
                            )
                        }
                        .buttonStyle(RoveMotionButtonStyle())
                        .contextMenu {
                            Button("从待看移除", systemImage: "ticket", role: .destructive) {
                                watchlistStore.remove(entry)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedChannel) { channel in
            RoveMediaDetailView(channel: channel)
                .roveHeroNavigationTransition(
                    id: "watchlist-all-\(RoveWatchlistEntry(channel: channel).id)",
                    namespace: mediaHeroNamespace
                )
        }
        .navigationDestination(item: $selectedTMDBMovie) { movie in
            RoveMediaDetailView(recommendation: movie)
                .roveHeroNavigationTransition(
                    id: "watchlist-all-tmdb-\(movie.identity)",
                    namespace: mediaHeroNamespace
                )
        }
    }

    private func open(_ entry: RoveWatchlistEntry) {
        if let recommendation = entry.recommendation {
            selectedTMDBMovie = recommendation
        } else {
            selectedChannel = entry.channel
        }
    }
}

#if !DJHUB_METADATA_ONLY
private struct RoveDownloadManagementView: View {
    @StateObject private var manager = RoveDownloadManager.shared
    @State private var isSelecting = false
    @State private var selection = Set<UUID>()
    @State private var playbackChannel: Channel?

    var body: some View {
        Group {
            if manager.items.isEmpty {
                ContentUnavailableView(
                    "暂无下载",
                    systemImage: "arrow.down.circle",
                    description: Text("在影片或剧集详情页选择要下载的内容。")
                )
            } else {
                List(selection: $selection) {
                    ForEach(manager.items) { item in
                        HStack(spacing: 12) {
                            RoveArtworkView(channel: item.channel, landscape: true)
                                .frame(width: 92, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.channel.name)
                                    .font(.headline)
                                    .lineLimit(2)
                                HStack(spacing: 6) {
                                    if item.state == .downloading { ProgressView().controlSize(.small) }
                                    Text(item.state.title)
                                    if item.fileSize > 0 {
                                        Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(item.state == .failed ? .red : .secondary)
                                if item.state == .failed {
                                    Button("重试") { manager.retry(item.id) }
                                        .font(.caption.weight(.semibold))
                                }
                            }
                            Spacer(minLength: 0)
                            if item.state == .completed {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.roveAccent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isSelecting else { return }
                            playbackChannel = manager.playbackChannel(for: item)
                        }
                        .tag(item.id)
                    }
                    .onDelete { offsets in
                        manager.remove(Set(offsets.map { manager.items[$0].id }))
                    }
                }
                .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
            }
        }
        .navigationTitle("下载管理")
        .fullScreenCover(item: $playbackChannel) { channel in
            PlayerDetailView(channel: channel)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink {
                    RoveDownloadSettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                if !manager.items.isEmpty {
                    Button(isSelecting ? "完成" : "选择") {
                        if isSelecting { selection.removeAll() }
                        isSelecting.toggle()
                    }
                }
            }
            if isSelecting, !selection.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    Button("删除所选", role: .destructive) {
                        manager.remove(selection)
                        selection.removeAll()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                ProgressView(value: storageRatio)
                HStack {
                    Text("下载占用 \(ByteCountFormatter.string(fromByteCount: manager.totalBytes, countStyle: .file))")
                    Spacer()
                    Text("可用 \(ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var availableBytes: Int64 {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    private var storageRatio: Double {
        let total = manager.totalBytes + availableBytes
        return total > 0 ? Double(manager.totalBytes) / Double(total) : 0
    }
}

private struct RoveDownloadSettingsView: View {
    @AppStorage(RoveDownloadManager.maximumConcurrentKey) private var maximumConcurrent = 2
    @AppStorage(RoveDownloadManager.allowsCellularKey) private var allowsCellular = false
    @StateObject private var manager = RoveDownloadManager.shared

    var body: some View {
        Form {
            Section {
                Stepper(value: $maximumConcurrent, in: 1...5) {
                    LabeledContent("最大同时下载数", value: "\(maximumConcurrent)")
                }
                Toggle("允许蜂窝网络下载", isOn: $allowsCellular)
            } footer: {
                Text("降低并发不会中断当前任务；蜂窝网络设置仅应用于新建和重试的下载。")
            }
        }
        .navigationTitle("下载设置")
        .onChange(of: maximumConcurrent) { _, _ in manager.settingsDidChange() }
        .onChange(of: allowsCellular) { _, _ in manager.settingsDidChange() }
    }
}

private struct RovePlaybackSettingsView: View {
    @EnvironmentObject private var playback: PlaybackCoordinator
    @StateObject private var cacheManager = PlaybackCacheManager.shared
    @AppStorage(PlaybackPreferences.forwardIntervalDefaultsKey) private var forwardInterval = 10.0
    @AppStorage(PlaybackPreferences.backwardIntervalDefaultsKey) private var backwardInterval = 10.0
    @AppStorage(PlaybackPreferences.longPressRateDefaultsKey) private var longPressRate = 2.0
    @AppStorage(PlaybackPreferences.continuePolicyDefaultsKey) private var continuePolicyRaw = PlaybackContinuePolicy.resume.rawValue
    @AppStorage(PlaybackPreferences.continuousPlaybackDefaultsKey) private var continuousPlayback = true
    @AppStorage(PlaybackPreferences.autoSkipIntroOutroDefaultsKey) private var autoSkipIntroOutro = false
    @AppStorage(PlaybackPreferences.autoMarkWatchedDefaultsKey) private var autoMarkWatched = true
    @AppStorage(PlaybackPreferences.rememberPlaybackRateDefaultsKey) private var rememberPlaybackRate = true
    @AppStorage(PlaybackPreferences.automaticPictureInPictureDefaultsKey) private var automaticPictureInPicture = true
    @AppStorage(PlaybackPreferences.hardwareAccelerationDefaultsKey) private var hardwareAcceleration = true
    @AppStorage(PlaybackPreferences.baiduLoadingOptimizationDefaultsKey) private var baiduLoadingOptimization = true
    @AppStorage(PlaybackPreferences.hapticFeedbackDefaultsKey) private var hapticFeedback = true
    @AppStorage(PlaybackPreferences.cellularPlaybackWarningDefaultsKey) private var cellularPlaybackWarning = true
    @AppStorage(PlaybackPreferences.preloadModeDefaultsKey) private var preloadModeRaw = PlaybackPreloadMode.disk.rawValue

    private let engineOptions: [PlaybackEnginePreference] = [
        .automaticCompatibleFirst,
        .system,
        .compatible,
        .mpv,
        .vlc
    ]

    private var engineSelection: Binding<PlaybackEnginePreference> {
        Binding(
            get: { playback.preferredEngine },
            set: { playback.setPreferredEngine($0) }
        )
    }

    private var continuePolicy: PlaybackContinuePolicy {
        PlaybackContinuePolicy(rawValue: continuePolicyRaw) ?? .resume
    }

    private var preloadMode: PlaybackPreloadMode {
        PlaybackPreloadMode(rawValue: preloadModeRaw) ?? .disk
    }

    var body: some View {
        Form {
            Section("播放引擎") {
                Picker("播放引擎", selection: engineSelection) {
                    ForEach(engineOptions) { engine in
                        Text(engineShortTitle(engine)).tag(engine)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    Text(engineShortTitle(engineSelection.wrappedValue))
                        .font(.title3.bold())
                    Text(engineSelection.wrappedValue.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(engineCapability(engineSelection.wrappedValue))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                intervalPicker("快进间隔", selection: $forwardInterval)
                intervalPicker("快退间隔", selection: $backwardInterval)

                Picker("长按倍速播放", selection: $longPressRate) {
                    ForEach(PlaybackPreferences.longPressRates, id: \.self) { rate in
                        Text("\(rate.formatted())×").tag(rate)
                    }
                }

                Picker("继续播放", selection: $continuePolicyRaw) {
                    ForEach(PlaybackContinuePolicy.allCases) { policy in
                        Text(policy.title).tag(policy.rawValue)
                    }
                }

                Toggle("自动播放下一集", isOn: $continuousPlayback)
                Toggle("自动跳过片头片尾", isOn: $autoSkipIntroOutro)
                Toggle("播放超过 95% 后自动标记为已观看", isOn: $autoMarkWatched)
                Toggle("始终记住播放速度", isOn: $rememberPlaybackRate)
            } header: {
                Text("播放行为")
            } footer: {
                Text("片头片尾跳过仅在媒体服务器提供有效片段标记时生效。")
            }

            Section("后台与画中画") {
                Toggle("自动小窗播放", isOn: $automaticPictureInPicture)
            }

            Section {
                Toggle("硬件加速", isOn: $hardwareAcceleration)
                Toggle("百度加载优化（Beta）", isOn: $baiduLoadingOptimization)
            } header: {
                Text("性能与网络")
            } footer: {
                Text("硬件加速与百度加载优化将在下次开始播放时生效。")
            }

            Section("反馈与提醒") {
                Toggle("触感反馈", isOn: $hapticFeedback)
                Toggle("蜂窝网络播放提醒", isOn: $cellularPlaybackWarning)
            }

            Section {
                Picker("缓冲模式", selection: $preloadModeRaw) {
                    ForEach(PlaybackPreloadMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                if preloadMode == .disk {
                    Picker("磁盘缓存限制", selection: $cacheManager.sizeLimit) {
                        ForEach(PlaybackCacheSizeLimit.allCases) { limit in
                            Text(limit.title).tag(limit)
                        }
                    }
                }
            } header: {
                Text("缓冲 / 预加载")
            } footer: {
                switch preloadMode {
                case .off:
                    Text("关闭额外预加载，保留播放器维持连续解码所需的最小缓冲。")
                case .memory:
                    Text("仅使用内存缓冲，退出播放后不会保留媒体数据。")
                case .disk:
                    Text("直播播放时同步写入磁盘缓存，可在缓存页继续查看，达到限制后自动清理旧内容。")
                }
            }
        }
        .navigationTitle("播放设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            forwardInterval = PlaybackPreferences.forwardInterval
            backwardInterval = PlaybackPreferences.backwardInterval
            cacheManager.isEnabled = preloadMode == .disk
        }
        .onChange(of: forwardInterval) { _, value in
            playback.setForwardInterval(value)
        }
        .onChange(of: backwardInterval) { _, value in
            playback.setBackwardInterval(value)
        }
        .onChange(of: preloadModeRaw) { _, _ in
            cacheManager.isEnabled = preloadMode == .disk
        }
        .onChange(of: rememberPlaybackRate) { _, enabled in
            if !enabled {
                UserDefaults.standard.removeObject(forKey: PlaybackPreferences.playbackRateDefaultsKey)
            }
        }
        .onChange(of: hapticFeedback) { _, enabled in
            if enabled { PlaybackPreferences.triggerSelectionFeedback() }
        }
    }

    @ViewBuilder
    private func intervalPicker(_ title: String, selection: Binding<Double>) -> some View {
        Picker(title, selection: selection) {
            ForEach(PlaybackPreferences.skipIntervals, id: \.self) { seconds in
                Text("\(Int(seconds)) 秒").tag(seconds)
            }
        }
    }

    private func engineShortTitle(_ engine: PlaybackEnginePreference) -> String {
        switch engine {
        case .automaticSystemFirst, .automaticCompatibleFirst: "自动"
        case .system: "系统"
        case .compatible: "KS"
        case .mpv: "MPV"
        case .vlc: "VLC"
        }
    }

    private func engineCapability(_ engine: PlaybackEnginePreference) -> String {
        switch engine {
        case .automaticSystemFirst, .automaticCompatibleFirst:
            "根据媒体格式在 AVPlayer、KSPlayer/FFmpeg 与兼容回退之间自动选择。"
        case .system:
            "原生 AVPlayer，优先用于本地 MP4、AirPlay 与系统画中画。"
        case .compatible:
            "KSPlayer/FFmpeg，适合更多协议、字幕与特殊封装格式。"
        case .mpv:
            "libmpv，适合高码率、复杂封装与网络媒体。"
        case .vlc:
            "MobileVLCKit，适合 IPTV、非常规协议与复杂媒体封装。"
        }
    }
}

private struct RoveSettingsView: View {
    @EnvironmentObject private var library: ChannelLibrary
    @EnvironmentObject private var playback: PlaybackCoordinator
    @AppStorage(AppAppearance.defaultsKey) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(AppLanguage.defaultsKey) private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    @AppStorage(RoveDeepSeekService.providerDefaultsKey) private var aiProviderRaw = RoveAIProvider.deepSeek.rawValue
    @StateObject private var purchases = ProPurchaseManager.shared
    @StateObject private var minorMode = MinorModeService.shared
    @ObservedObject private var remotePush = RoveRemotePushService.shared
    @State private var showingPro = false

    private var appearance: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    private var language: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: languageRaw) ?? .simplifiedChinese },
            set: { languageRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingPro = true
                    } label: {
                        Label {
                            LabeledContent(
                                "RovePlayer Pro",
                                value: purchases.isPro ? "已解锁" : "查看权益"
                            )
                        } icon: {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Color.roveIndigo)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section("外观") {
                    Picker("显示模式", selection: appearance) {
                        ForEach(AppAppearance.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("语言", selection: language) {
                        ForEach(AppLanguage.allCases) { item in
                            Text("\(item.symbol) \(item.displayName)").tag(item)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    NavigationLink {
                        RovePersonalizationView()
                    } label: {
                        Label("个性化", systemImage: "paintpalette")
                    }
                }

                Section("播放") {
                    NavigationLink {
                        RovePlaybackSettingsView()
                    } label: {
                        Label {
                            LabeledContent("播放设置", value: playback.preferredEngine.title)
                        } icon: {
                            Image(systemName: "play.rectangle.on.rectangle")
                        }
                    }
                    NavigationLink {
                        RoveSubtitleSettingsView()
                    } label: {
                        Label("字幕和音轨", systemImage: "captions.bubble")
                    }
                    NavigationLink {
                        RoveDanmakuSettingsView()
                    } label: {
                        Label("弹幕设置", systemImage: "text.bubble")
                    }
                    NavigationLink {
                        RovePlaybackEnhancementView()
                    } label: {
                        Label("画质与帧率增强", systemImage: "wand.and.stars")
                    }
                }

                Section("下载") {
                    NavigationLink {
                        RoveDownloadManagementView()
                    } label: {
                        Label {
                            LabeledContent(
                                "下载管理",
                                value: ByteCountFormatter.string(
                                    fromByteCount: RoveDownloadManager.shared.totalBytes,
                                    countStyle: .file
                                )
                            )
                        } icon: {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(Color.roveAccent)
                        }
                    }

                    NavigationLink {
                        RoveCacheManagementView()
                    } label: {
                        Label("缓存管理", systemImage: "internaldrive")
                    }
                }

                Section("家长控制") {
                    NavigationLink {
                        RoveMinorModeView()
                    } label: {
                        Label {
                            LabeledContent(
                                "未成年人模式",
                                value: minorMode.isEnabled ? "已开启" : "未开启"
                            )
                        } icon: {
                            Image(systemName: "figure.child")
                                .foregroundStyle(minorMode.isEnabled ? Color.roveGreen : Color.roveAccent)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        RoveAISettingsView()
                    } label: {
                        Label {
                            LabeledContent(
                                "AI 服务",
                                value: RoveDeepSeekService.shared.configuredProviderTitle
                            )
                        } icon: {
                            Image(systemName: "brain.head.profile")
                                .foregroundStyle(Color.roveAccent)
                        }
                    }

                    NavigationLink {
                        RoveMediaSyncSettingsView()
                    } label: {
                        Label {
                            LabeledContent("媒体同步", value: "iCloud · Trakt · Simkl")
                        } icon: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color.roveAccent)
                        }
                    }

                    NavigationLink {
                        RoveEpisodeReminderSettingsView()
                    } label: {
                        Label {
                            LabeledContent(
                                "剧集提醒",
                                value: remotePush.bindings.isEmpty
                                    ? "入库推送"
                                    : "已绑定 \(remotePush.bindings.count) 个"
                            )
                        } icon: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(Color.roveAccent)
                        }
                    }

                    NavigationLink {
                        APISettingsView()
                    } label: {
                        Label {
                            LabeledContent("API 设置", value: "TMDB · 图片 · 反代")
                        } icon: {
                            Image(systemName: "network")
                                .foregroundStyle(Color.roveAccent)
                        }
                    }

                    NavigationLink {
                        RoveBadgeSettingsView()
                    } label: {
                        Label {
                            LabeledContent(
                                "资源徽章",
                                value: "\(RoveBadgeLibrary.shared.packages.count) 个规则库"
                            )
                        } icon: {
                            Image(systemName: "link.badge.plus")
                                .foregroundStyle(Color.roveAccent)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        RoveAboutUsView()
                    } label: {
                        Label("关于我们", systemImage: "info.circle")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RoveBackdrop())
            .navigationTitle("设置")
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingPro) {
                ProView()
            }
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
            content()
                .padding(.horizontal, 14)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.roveAccent)
                .frame(width: 34, height: 34)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct RoveMinorModeView: View {
    @StateObject private var minorMode = MinorModeService.shared
    @State private var pinAction: RoveMinorPINAction?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image("MediaDeckBrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 116, height: 116)
                    .padding(.top, 42)

                Text(minorMode.isEnabled ? "未成年人模式已开启" : "未成年人模式未开启")
                    .font(.title2.bold())
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 26) {
                    RoveMinorFeatureRow(
                        icon: "lock",
                        text: "开启未成年人模式时，需设置独立密码。关闭时，必须输入同样的独立密码进行验证"
                    )
                    RoveMinorFeatureRow(
                        icon: "clock",
                        text: "自动开启时间锁，每日使用时长不超过 1 小时，每日 22:00 至次日 06:00 期间无法使用 RovePlayer"
                    )
                    RoveMinorFeatureRow(
                        icon: "wallet.pass",
                        text: "无法进行付费购买 RovePlayer Pro 会员服务的操作"
                    )
                }
                .padding(.top, 48)

                if minorMode.isEnabled {
                    VStack(spacing: 8) {
                        ProgressView(
                            value: min(minorMode.usageSecondsToday, MinorModeService.dailyLimit),
                            total: MinorModeService.dailyLimit
                        )
                        .tint(Color.roveGreen)
                        Text(usageSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 34)
                }

                Button {
                    pinAction = minorMode.isEnabled ? .disable : .enable
                } label: {
                    Text(minorMode.isEnabled ? "关闭未成年人模式" : "开启未成年人模式")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.roveGreen, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.top, 42)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("未成年人模式")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            minorMode.refreshUsage()
        }
        .fullScreenCover(item: $pinAction) { action in
            RoveMinorPINView(action: action)
        }
    }

    private var usageSummary: String {
        let usedMinutes = Int(minorMode.usageSecondsToday / 60)
        let remainingMinutes = max(0, Int(ceil(minorMode.remainingSecondsToday / 60)))
        return String(format: "今日已使用 %d 分钟，剩余 %d 分钟", usedMinutes, remainingMinutes)
    }
}

private struct RoveMinorFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum RoveMinorPINAction: String, Identifiable {
    case enable
    case disable

    var id: String { rawValue }
}

private struct RoveMinorPINView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var minorMode = MinorModeService.shared
    let action: RoveMinorPINAction

    @State private var digits = ""
    @State private var firstPIN: String?
    @State private var errorMessage: String?

    private let keypadRows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Image("MediaDeckBrandMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                        .padding(.top, 30)

                    Text(prompt)
                        .font(.title2.bold())
                        .padding(.top, 34)

                    HStack(spacing: 24) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index < digits.count ? Color.roveGreen : Color.clear)
                                .overlay(Circle().stroke(Color.roveGreen, lineWidth: 2.5))
                                .frame(width: 22, height: 22)
                        }
                    }
                    .padding(.top, 20)

                    Text(errorMessage ?? " ")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(minHeight: 22)
                        .padding(.top, 12)

                    VStack(spacing: 18) {
                        ForEach(keypadRows, id: \.self) { row in
                            HStack(spacing: 28) {
                                ForEach(row, id: \.self) { number in
                                    keypadButton(number)
                                }
                            }
                        }
                        HStack(spacing: 28) {
                            Color.clear.frame(width: 76, height: 76)
                            keypadButton("0")
                            Button {
                                if !digits.isEmpty { digits.removeLast() }
                                errorMessage = nil
                            } label: {
                                Image(systemName: "delete.left")
                                    .font(.title2.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .frame(width: 76, height: 76)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("删除")
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            }
            .background(Color(uiColor: .systemBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Color.roveGreen)
                }
            }
        }
    }

    private var prompt: String {
        switch action {
        case .disable:
            return "请输入密码"
        case .enable:
            return firstPIN == nil ? "请设置 4 位密码" : "请再次输入密码"
        }
    }

    private func keypadButton(_ number: String) -> some View {
        Button {
            guard digits.count < 4 else { return }
            let submittedPIN = digits + number
            digits = submittedPIN
            errorMessage = nil
            if submittedPIN.count == 4 {
                submit(submittedPIN)
            }
        } label: {
            Text(number)
                .font(.title.bold())
                .foregroundStyle(.primary)
                .frame(width: 76, height: 76)
                .overlay(Circle().stroke(Color.roveGreen, lineWidth: 2.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(number)
    }

    private func submit(_ pin: String) {
        guard pin.count == 4 else {
            errorMessage = "请输入 4 位密码"
            digits = ""
            return
        }
        switch action {
        case .disable:
            if minorMode.disable(pin: pin) {
                dismiss()
            } else {
                errorMessage = "密码错误，请重新输入"
                digits = ""
            }
        case .enable:
            if let firstPIN {
                if firstPIN == pin, minorMode.enable(pin: pin) {
                    if PlaybackCoordinator.shared.isPlaying {
                        PlaybackCoordinator.shared.pause()
                    }
                    dismiss()
                } else {
                    errorMessage = firstPIN == pin ? "密码保存失败，请重试" : "两次输入的密码不一致"
                    self.firstPIN = nil
                    digits = ""
                }
            } else {
                firstPIN = pin
                digits = ""
            }
        }
    }
}

private struct RoveAISettingsView: View {
    @AppStorage(RoveDeepSeekService.providerDefaultsKey) private var providerRaw = RoveAIProvider.deepSeek.rawValue
    @AppStorage(RoveDeepSeekService.baseURLDefaultsKey) private var baseURL = "https://api.deepseek.com"
    @AppStorage(RoveDeepSeekService.modelDefaultsKey) private var model = "deepseek-chat"
    @AppStorage(RoveDeepSeekService.miniMaxBaseURLDefaultsKey) private var miniMaxBaseURL = "https://api.minimaxi.com/v1/chat/completions"
    @AppStorage(RoveDeepSeekService.miniMaxModelDefaultsKey) private var miniMaxModel = "MiniMax-M3"
    @AppStorage(RoveDeepSeekService.recommendationsEnabledKey) private var recommendationsEnabled = false
    @State private var apiKey = ""
    @State private var statusMessage: String?
    @State private var isTesting = false

    private var provider: RoveAIProvider {
        RoveAIProvider(rawValue: providerRaw) ?? .deepSeek
    }

    var body: some View {
        Form {
            Section("服务商") {
                Picker("AI 服务商", selection: $providerRaw) {
                    ForEach(RoveAIProvider.allCases) { provider in
                        Text(provider.title).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                SecureField(
                    RoveDeepSeekService.shared.hasAPIKey ? "已保存，输入新 Key 可替换" : "sk-...",
                    text: $apiKey
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button("保存 API Key", systemImage: "key") { saveKey() }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if RoveDeepSeekService.shared.hasAPIKey {
                    Button("删除 API Key", systemImage: "trash", role: .destructive) {
                        RoveDeepSeekService.shared.deleteAPIKey()
                        apiKey = ""
                        statusMessage = "API Key 已从本机钥匙串删除"
                    }
                }
            } header: {
                Text("\(provider.title) API Key")
            } footer: {
                Text("API Key 仅保存在本机系统钥匙串，不写入项目文件，也不通过 iCloud 同步。")
            }

            Section("接口") {
                if provider == .miniMax {
                    TextField("API 地址", text: $miniMaxBaseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("模型", text: $miniMaxModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    TextField("API 地址", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("模型", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Button(isTesting ? "测试中…" : "测试连接", systemImage: "network") {
                    testConnection()
                }
                .disabled(isTesting || !RoveDeepSeekService.shared.hasAPIKey)
            }

            Section {
                Toggle("首页 AI 推荐", isOn: $recommendationsEnabled)
            } header: {
                Text("AI 推荐")
            } footer: {
                Text("仅发送观看记录中的片名，以及候选媒体的片名、年份和分类。不会发送服务器地址、账号、Token 或播放链接。")
            }

            Section("AI 字幕") {
                LabeledContent("翻译入口", value: "播放器字幕菜单")
                Text("播放时选择本地 SRT 或 VTT，\(provider.title) 会保留时间轴并翻译台词。生成结果保存在本机字幕缓存。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let statusMessage {
                Section { Text(statusMessage).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("AI 服务")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: providerRaw) { _, _ in
            apiKey = ""
            statusMessage = nil
        }
    }

    private func saveKey() {
        do {
            try RoveDeepSeekService.shared.saveAPIKey(apiKey)
            apiKey = ""
            statusMessage = "\(provider.title) API Key 已安全保存"
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func testConnection() {
        isTesting = true
        statusMessage = nil
        Task {
            do {
                try await RoveDeepSeekService.shared.testConnection()
                statusMessage = "\(provider.title) 连接成功"
            } catch {
                statusMessage = "连接失败：\(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}

private struct RoveMediaSyncSettingsView: View {
    @EnvironmentObject private var library: ChannelLibrary
    @AppStorage(CloudSyncService.enabledDefaultsKey) private var cloudSyncEnabled = false
    @AppStorage(MetadataSyncA.syncEnabledDefaultsKey) private var traktSyncEnabled = true
    @AppStorage(MetadataSyncB.syncEnabledDefaultsKey) private var simklSyncEnabled = true
    @StateObject private var cloudSync = CloudSyncService.shared
    @StateObject private var trakt = MetadataSyncA.shared
    @StateObject private var simkl = MetadataSyncB.shared

    var body: some View {
        Form {
            Section("iCloud") {
                Toggle("自动同步", isOn: $cloudSyncEnabled)
                LabeledContent("状态", value: cloudSync.state.title)
                Button("立即同步") {
                    Task { await cloudSync.synchronize(library: library, force: true) }
                }
                .disabled(cloudSync.state == .syncing)
            }

            Section {
                switch trakt.state {
                case .disconnected:
                    Button {
                        trakt.connect()
                    } label: {
                        Label("连接 Trakt", systemImage: "link")
                    }
                    .disabled(trakt.isBusy)
                case .authorizing:
                    HStack {
                        Label("正在打开 Trakt 授权页面", systemImage: "safari")
                        Spacer()
                        ProgressView()
                    }
                case .connected(let username):
                    RoveMediaSyncAccountCard(
                        serviceName: "Trakt",
                        snapshot: trakt.accountSnapshot ?? MediaSyncAccountSnapshot(
                            username: username,
                            avatarURL: nil,
                            isVIP: false,
                            movieCount: nil,
                            showCount: nil,
                            episodeCount: nil
                        ),
                        accent: Color(red: 0.88, green: 0.19, blue: 0.55),
                        isSyncEnabled: $traktSyncEnabled,
                        note: "对 Emby/Jellyfin/Plex/fnOS 服务生效",
                        onLogout: trakt.disconnect
                    )
                }
            } header: {
                Text("Trakt")
            } footer: {
                Text("通过 Trakt 网页授权；影片的已看状态会自动同步。")
            }

            Section {
                switch simkl.state {
                case .disconnected:
                    Button {
                        simkl.connect()
                    } label: {
                        Label("连接 Simkl", systemImage: "link")
                    }
                    .disabled(simkl.isBusy)
                case .authorizing:
                    HStack {
                        Label("正在打开 Simkl 授权页面", systemImage: "safari")
                        Spacer()
                        ProgressView()
                    }
                case .connected(let username):
                    RoveMediaSyncAccountCard(
                        serviceName: "Simkl",
                        snapshot: simkl.accountSnapshot ?? MediaSyncAccountSnapshot(
                            username: username,
                            avatarURL: nil,
                            isVIP: false,
                            movieCount: nil,
                            showCount: nil,
                            episodeCount: nil
                        ),
                        accent: Color(red: 0.20, green: 0.72, blue: 0.53),
                        isSyncEnabled: $simklSyncEnabled,
                        note: "对 Emby/Jellyfin/Plex/fnOS 服务生效",
                        onLogout: simkl.disconnect
                    )
                }
            } header: {
                Text("Simkl")
            } footer: {
                Text("通过 Simkl AUTH V2 安全授权；影片的已看状态会同步到 Simkl。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(RoveBackdrop())
        .navigationTitle("媒体同步")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert(
            "Trakt",
            isPresented: Binding(
                get: { trakt.errorMessage != nil },
                set: { if !$0 { trakt.clearError() } }
            )
        ) {
            Button("好", role: .cancel) {
                trakt.clearError()
            }
        } message: {
            Text(trakt.errorMessage ?? "")
        }
        .alert(
            "Simkl",
            isPresented: Binding(
                get: { simkl.errorMessage != nil },
                set: { if !$0 { simkl.clearError() } }
            )
        ) {
            Button("好", role: .cancel) {
                simkl.clearError()
            }
        } message: {
            Text(simkl.errorMessage ?? "")
        }
    }
}

private struct RoveMediaSyncAccountCard: View {
    let serviceName: String
    let snapshot: MediaSyncAccountSnapshot
    let accent: Color
    @Binding var isSyncEnabled: Bool
    let note: String
    let onLogout: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.94))
                    Text(String(serviceName.prefix(1)))
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                }
                .frame(width: 68, height: 68)
                .shadow(color: accent.opacity(0.28), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(serviceName)
                        .font(.title3.weight(.semibold))
                    if snapshot.isVIP {
                        Text("VIP")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.82), in: Capsule())
                    }
                }
                Spacer(minLength: 0)
            }

            accountAvatar

            Text(snapshot.username)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 10) {
                accountStat(value: snapshot.movieCount, title: "电影")
                accountStat(value: snapshot.showCount, title: "节目")
                accountStat(value: snapshot.episodeCount, title: "集数")
            }

            HStack {
                Text("同步记录")
                    .font(.title3.weight(.semibold))
                Spacer()
                Toggle("同步记录", isOn: $isSyncEnabled)
                    .labelsHidden()
                    .tint(accent)
            }

            Label(note, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Button("退出登录", action: onLogout)
                .font(.body.weight(.medium))
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.16),
                                    Color.black.opacity(0.30),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var accountAvatar: some View {
        Group {
            if let avatarURL = snapshot.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 112, height: 112)
        .background(Color.white.opacity(0.86), in: Circle())
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.58), lineWidth: 2))
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 48, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.62))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func accountStat(value: Int?, title: String) -> some View {
        VStack(spacing: 4) {
            Text(value.map(String.init) ?? "—")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.17), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        }
    }
}

private struct RoveBadgeSettingsView: View {
    @StateObject private var library = RoveBadgeLibrary.shared
    @State private var remoteAddress = ""
    @State private var isImporting = false
    @State private var refreshingPackageID: UUID?
    @State private var showingFileImporter = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("https://example.com/badges.json", text: $remoteAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Button {
                    importRemote()
                } label: {
                    if isImporting {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("正在验证")
                        }
                    } else {
                        Label("验证并保存", systemImage: "checkmark.shield")
                    }
                }
                .disabled(isImporting || remoteAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    showingFileImporter = true
                } label: {
                    Label("从本地 JSON 导入", systemImage: "doc.badge.plus")
                }
                .disabled(isImporting)
            } header: {
                Text("添加规则库")
            } footer: {
                Text("已内置良友媒体徽章规则库，图片按需加载并缓存。你也可以添加远程地址或从本地导入其他规则库。")
            }

            Section {
                Toggle("黑白图标自动适配", isOn: $library.monochromeAdaptive)
            } footer: {
                Text("为浅色或深色单色徽章增加边缘对比，彩色徽章会保留原色。")
            }

            if let package = library.selectedPackage {
                Section("实时预览 · \(package.name)") {
                    RoveBadgePackagePreview(package: package)
                        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                }
            }

            Section("已添加的规则库") {
                if library.packages.isEmpty {
                    Text("尚未添加规则库")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(library.packages) { package in
                        HStack(spacing: 12) {
                            Button {
                                library.select(package)
                            } label: {
                                Image(systemName: library.selectedPackageID == package.id
                                    ? "checkmark.circle.fill"
                                    : "circle")
                                    .font(.title3)
                                    .foregroundStyle(library.selectedPackageID == package.id ? Color.accentColor : Color.secondary)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(library.selectedPackageID == package.id
                                ? "当前使用 \(package.name)"
                                : "使用 \(package.name)")

                            VStack(alignment: .leading, spacing: 4) {
                                Text(package.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text("\(sourceLabel(for: package)) · \(package.rules.count) 条规则")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                library.select(package)
                            }
                            Spacer()
                            if refreshingPackageID == package.id {
                                ProgressView()
                            } else if package.isRemote {
                                Button {
                                    refresh(package)
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("刷新 \(package.name)")
                            }
                            Button(role: .destructive) {
                                library.remove(package)
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("删除 \(package.name)")
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(RoveBackdrop())
        .navigationTitle("资源徽章")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                if case .failure(let error) = result { errorMessage = error.localizedDescription }
                return
            }
            importLocal(url)
        }
        .alert("导入完成", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("好", role: .cancel) { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
        .alert("无法导入", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func sourceLabel(for package: RoveBadgePackage) -> String {
        guard package.isRemote else { return package.source }
        return URL(string: package.source)?.host ?? "远程规则库"
    }

    private func importRemote() {
        guard !isImporting else { return }
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                let package = try await library.importRemote(address: remoteAddress)
                remoteAddress = ""
                resultMessage = "已保存“\(package.name)”，共 \(package.rules.count) 条规则。"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func importLocal(_ url: URL) {
        guard !isImporting else { return }
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                let package = try await library.importLocal(fileURL: url)
                resultMessage = "已导入“\(package.name)”，共 \(package.rules.count) 条规则。"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refresh(_ package: RoveBadgePackage) {
        guard refreshingPackageID == nil else { return }
        refreshingPackageID = package.id
        Task {
            defer { refreshingPackageID = nil }
            do {
                let refreshed = try await library.refresh(package)
                resultMessage = "已刷新“\(refreshed.name)”，共 \(refreshed.rules.count) 条规则。"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum RoveCacheCategory: String, CaseIterable, Identifiable, Sendable {
    case video
    case images
    case subtitles
    case mediaLibrary
    case downloads
    case temporary

    var id: String { rawValue }
    var title: String {
        switch self {
        case .video: "视频缓存"
        case .images: "图片缓存"
        case .subtitles: "字幕缓存"
        case .mediaLibrary: "媒体库缓存"
        case .downloads: "下载缓存"
        case .temporary: "临时缓存"
        }
    }
}

private enum RoveCacheStorage {
    static func sizes() async -> [RoveCacheCategory: Int64] {
        await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: RoveCacheCategory.allCases.map { category in
                (category, paths(for: category).reduce(0) { $0 + directorySize($1) })
            })
        }.value
    }

    static func clear(_ category: RoveCacheCategory) async {
        if category == .video {
            await MainActor.run { PlaybackCacheManager.shared.clear() }
        }
        await Task.detached(priority: .utility) {
            for url in paths(for: category) {
                removeContents(at: url)
            }
            if category == .temporary {
                URLCache.shared.removeAllCachedResponses()
            }
        }.value
    }

    private static func paths(for category: RoveCacheCategory) -> [URL] {
        let manager = FileManager.default
        let caches = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let documents = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        switch category {
        case .video:
            return [caches.appendingPathComponent("TuboLiveCache", isDirectory: true)]
        case .images:
            return [
                caches.appendingPathComponent("TuboEmbyArtwork", isDirectory: true),
                caches.appendingPathComponent("TuboTMDBArtwork", isDirectory: true),
                caches.appendingPathComponent("ChannelPreviewFrames", isDirectory: true),
                caches.appendingPathComponent("BaiduMusicArtwork", isDirectory: true),
                support.appendingPathComponent("TuboLocalVideos/Thumbnails", isDirectory: true),
            ]
        case .subtitles:
            return [
                caches.appendingPathComponent("RoveSubtitles", isDirectory: true),
                caches.appendingPathComponent("TuboSubtitles", isDirectory: true),
            ]
        case .mediaLibrary:
            return [
                caches.appendingPathComponent("TuboEmby", isDirectory: true),
                support.appendingPathComponent("TuboEmby", isDirectory: true),
                caches.appendingPathComponent("TuboEPG", isDirectory: true),
            ]
        case .downloads:
            return [documents.appendingPathComponent("RoveDownloads", isDirectory: true)]
        case .temporary:
            return [manager.temporaryDirectory]
        }
    }

    private static func directorySize(_ url: URL) -> Int64 {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
            ), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    private static func removeContents(at directory: URL) {
        let manager = FileManager.default
        guard let children = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        children.forEach { try? manager.removeItem(at: $0) }
    }
}

private struct RoveCacheManagementView: View {
    @State private var sizes: [RoveCacheCategory: Int64] = [:]
    @State private var clearing: RoveCacheCategory?
    @State private var showingClearAllConfirmation = false

    private var totalSize: Int64 { sizes.values.reduce(0, +) }

    var body: some View {
        Form {
            Section {
                ForEach(RoveCacheCategory.allCases) { category in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.title)
                                .font(.headline)
                            Text(formattedSize(sizes[category, default: 0]))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if clearing == category {
                            ProgressView()
                        } else {
                            Button("清理", role: .destructive) {
                                clear(category)
                            }
                            .font(.headline)
                        }
                    }
                    .frame(minHeight: 58)
                }
            }

            Section {
                LabeledContent("缓存大小", value: formattedSize(totalSize))
                    .font(.headline)
                Button("一键清理", role: .destructive) {
                    showingClearAllConfirmation = true
                }
                .font(.headline)
                .disabled(clearing != nil || totalSize == 0)
            } footer: {
                Text("不会删除服务器账号、播放列表、本地导入视频或观看记录。图片和媒体库信息会在下次使用时重新缓存。")
            }
        }
        .navigationTitle("缓存管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reloadSizes() }
        .refreshable { await reloadSizes() }
        .confirmationDialog("清理全部缓存？", isPresented: $showingClearAllConfirmation) {
            Button("一键清理", role: .destructive) { clearAll() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("缓存会在后续浏览或播放时重新生成。")
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func clear(_ category: RoveCacheCategory) {
        guard clearing == nil else { return }
        clearing = category
        Task {
            await RoveCacheStorage.clear(category)
            await reloadSizes()
            clearing = nil
        }
    }

    private func clearAll() {
        guard clearing == nil else { return }
        Task {
            for category in RoveCacheCategory.allCases {
                clearing = category
                await RoveCacheStorage.clear(category)
            }
            await reloadSizes()
            clearing = nil
        }
    }

    private func reloadSizes() async {
        sizes = await RoveCacheStorage.sizes()
    }
}

private struct RoveAppIconOption: Identifiable {
    let iconName: String?
    let previewName: String
    let title: String

    var id: String { iconName ?? "default" }

    static let all = [
        RoveAppIconOption(iconName: nil, previewName: "MediaDeckBrandMark", title: "默认"),
        RoveAppIconOption(iconName: "AppIconCinemaRed", previewName: "RoveIconCinemaRedPreview", title: "影院红"),
        RoveAppIconOption(iconName: "AppIconDrive", previewName: "RoveIconDrivePreview", title: "驾驶"),
        RoveAppIconOption(iconName: "AppIconEmbyGreen", previewName: "RoveIconEmbyGreenPreview", title: "翡翠"),
        RoveAppIconOption(iconName: "AppIconPeach", previewName: "RoveIconPeachPreview", title: "桃粉"),
        RoveAppIconOption(iconName: "AppIconTiger", previewName: "RoveIconTigerPreview", title: "虎纹")
    ]
}

private struct RovePersonalizationView: View {
    @AppStorage(RoveAccentTheme.defaultsKey) private var accentThemeRaw = RoveAccentTheme.cyan.rawValue
    @State private var selectedIconName = UIApplication.shared.alternateIconName
    @State private var iconError: String?

    private let iconColumns = [
        GridItem(.adaptive(minimum: 84, maximum: 108), spacing: 18)
    ]

    var body: some View {
        Form {
            Section("App 图标") {
                LazyVGrid(columns: iconColumns, spacing: 18) {
                    ForEach(RoveAppIconOption.all) { option in
                        Button {
                            selectIcon(option)
                        } label: {
                            VStack(spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    Image(option.previewName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                    if selectedIconName == option.iconName {
                                        Image(systemName: "checkmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, Color.roveAccent)
                                            .background(.black.opacity(0.25), in: Circle())
                                            .offset(x: 7, y: -7)
                                    }
                                }
                                Text(option.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)

                if !UIApplication.shared.supportsAlternateIcons {
                    Text("当前系统不支持更换 App 图标。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("主题色") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 18) {
                    ForEach(RoveAccentTheme.allCases) { theme in
                        Button {
                            accentThemeRaw = theme.rawValue
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 46, height: 46)
                                    if accentThemeRaw == theme.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.headline.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                Text(theme.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(theme.title)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("个性化")
        .navigationBarTitleDisplayMode(.inline)
        .alert("无法更换图标", isPresented: Binding(
            get: { iconError != nil },
            set: { if !$0 { iconError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(iconError ?? "")
        }
    }

    private func selectIcon(_ option: RoveAppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            iconError = "当前系统不支持更换 App 图标。"
            return
        }
        guard selectedIconName != option.iconName else { return }
        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            Task { @MainActor in
                if let error {
                    iconError = error.localizedDescription
                } else {
                    selectedIconName = option.iconName
                }
            }
        }
    }
}

private struct RoveEpisodeReminderSettingsView: View {
    @EnvironmentObject private var library: ChannelLibrary
    @Environment(\.openURL) private var openURL
    @ObservedObject private var pushService = RoveRemotePushService.shared

    private var mediaServers: [PlaylistConfiguration] {
        library.configurations
            .filter { $0.kind.usesMediaLibraryBrowser }
            .sorted {
                serverDisplayName($0).localizedStandardCompare(serverDisplayName($1)) == .orderedAscending
            }
    }

    var body: some View {
        Form {
            Section {
                Button {
                    openURL(RoveRemotePushService.telegramBotURL)
                } label: {
                    Label("打开 @rovepush_bot", systemImage: "paperplane.circle.fill")
                }
            } footer: {
                Text("在 Telegram 机器人发送 /new，注册媒体服务器后会获得专属 Webhook 和 App 推送口令。")
            }

            if mediaServers.isEmpty {
                Section {
                    ContentUnavailableView(
                        "还没有媒体服务器",
                        systemImage: "server.rack",
                        description: Text("请先在资源库添加 Emby、Jellyfin 或其他媒体服务器。")
                    )
                }
            } else {
                Section {
                    ForEach(mediaServers) { configuration in
                        NavigationLink {
                            RoveLibraryPushSettingsView(configuration: configuration)
                        } label: {
                            HStack(spacing: 12) {
                                RoveServerBrandIcon(configuration: configuration, size: 36)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(serverDisplayName(configuration))
                                        .foregroundStyle(.primary)
                                    Text(bindingStatus(for: configuration))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("入库通知")
                } footer: {
                    Text("选择服务器后粘贴对应的推送口令。同一台设备可以绑定多个服务器。")
                }
            }

            Section {
                LabeledContent("通知权限", value: authorizationTitle)
                if pushService.authorizationStatus == .denied {
                    Button("打开系统通知设置") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                }
            } header: {
                Text("状态")
            }

            Section {
                NavigationLink {
                    RovePushTutorialView()
                } label: {
                    Label("新片入库推送配置教程", systemImage: "book.pages.fill")
                }
            } header: {
                Text("使用帮助")
            } footer: {
                Text("包含 Telegram 机器人、Emby Webhook 和 RovePlayer 真机绑定的完整步骤。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(RoveBackdrop())
        .navigationTitle("剧集提醒")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await pushService.refreshAuthorizationStatus()
        }
    }

    private func bindingStatus(for configuration: PlaylistConfiguration) -> String {
        let count = pushService.bindings(for: configuration.id).count
        return count == 0 ? "未绑定推送口令" : "已绑定 \(count) 个推送口令"
    }

    private func serverDisplayName(_ configuration: PlaylistConfiguration) -> String {
        let remark = configuration.serverRemark?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !remark.isEmpty { return remark }
        let reportedName = configuration.serverReportedName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !reportedName.isEmpty { return reportedName }
        let savedName = configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return savedName.isEmpty ? configuration.kind.title : savedName
    }

    private var authorizationTitle: String {
        switch pushService.authorizationStatus {
        case .authorized: "已允许"
        case .provisional: "临时允许"
        case .ephemeral: "本次允许"
        case .denied: "未允许"
        case .notDetermined: "尚未请求"
        @unknown default: "未知"
        }
    }
}

private struct RovePushTutorialView: View {
    var body: some View {
        RoveBundledPDFView(resourceName: "RovePlayer新片入库推送配置教程")
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("配置教程")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RoveBundledPDFView: UIViewRepresentable {
    let resourceName: String

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.pageBreakMargins = .init(top: 10, left: 0, bottom: 10, right: 0)
        view.backgroundColor = .systemBackground
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "pdf") {
            view.document = PDFDocument(url: url)
        }
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

private struct RoveAboutUsView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var supportContacts = SupportContactService.shared
    @State private var showingQQOpenFailed = false
    @State private var qqAlertMessage = ""
    @State private var isCheckingUpdate = false
    @State private var showingUpdateResult = false
    @State private var updateResultTitle = ""
    @State private var updateResultMessage = ""
    @State private var availableUpdateURL: URL?

    private let appStoreID = "6812869916"

    var body: some View {
        Form {
            Section {
                LabeledContent("RovePlayer", value: appVersion)
                LabeledContent("内容服务", value: "不提供媒体内容")

                Button {
                    NotificationCenter.default.post(name: .roveReplayPosterOnboarding, object: nil)
                } label: {
                    Label("重新认识 RovePlayer", systemImage: "sparkles.rectangle.stack")
                }
                .foregroundStyle(.primary)
            }

            Section("App Store") {
                Link(destination: reviewURL) {
                    Label("评价 RovePlayer", systemImage: "star.bubble")
                }
                .foregroundStyle(.primary)

                Button {
                    Task { await checkForUpdate() }
                } label: {
                    HStack {
                        Label("检测更新", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if isCheckingUpdate {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("当前版本 \(appVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(.primary)
                .disabled(isCheckingUpdate)
            }

            Section("联系与支持") {
                Link(destination: URL(string: "https://roveplayer.pw")!) {
                    LabeledContent("官方网站", value: "roveplayer.pw")
                }
                .foregroundStyle(.primary)

                Button {
                    openQQGroup()
                } label: {
                    LabeledContent(
                        "QQ群",
                        value: supportContacts.qqGroup
                            ?? (supportContacts.isLoading ? "正在获取…" : "点击刷新")
                    )
                }
                .foregroundStyle(.primary)
                .disabled(supportContacts.qqGroup == nil && supportContacts.isLoading)

                Link(destination: URL(string: "mailto:support@tubo.pw")!) {
                    LabeledContent("支持邮箱", value: "support@tubo.pw")
                }
                .foregroundStyle(.primary)

                Link(destination: URL(string: "https://t.me/+adgedU7dWY00YjBl")!) {
                    LabeledContent("Telegram", value: "点击加入")
                }
                .foregroundStyle(.primary)

                Link(destination: URL(string: "https://docs.qq.com/markdown/DY2F1Q0tZT2tSbUxa")!) {
                    LabeledContent("URL Schemes", value: "查看文档")
                }
                .foregroundStyle(.primary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(RoveBackdrop())
        .navigationTitle("关于我们")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await supportContacts.refresh()
        }
        .alert("无法打开 QQ", isPresented: $showingQQOpenFailed) {
            Button("好", role: .cancel) {}
        } message: {
            Text(qqAlertMessage)
        }
        .alert(updateResultTitle, isPresented: $showingUpdateResult) {
            if let availableUpdateURL {
                Button("前往 App Store") { openURL(availableUpdateURL) }
            }
            Button("好", role: .cancel) {}
        } message: {
            Text(updateResultMessage)
        }
    }

    private var reviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func openQQGroup() {
        guard let groupNumber = supportContacts.qqGroup else {
            Task {
                await supportContacts.refresh()
                guard supportContacts.qqGroup == nil else {
                    openQQGroup()
                    return
                }
                qqAlertMessage = "暂时无法获取最新QQ群，请检查网络后重试。"
                showingQQOpenFailed = true
            }
            return
        }

        guard let groupCardURL = URL(
            string: "mqqapi://card/show_pslcard?src_type=internal&version=1&uin=\(groupNumber)&card_type=group&source=external"
        ) else { return }

        UIApplication.shared.open(groupCardURL, options: [:]) { opened in
            guard !opened else { return }
            Task { @MainActor in
                UIPasteboard.general.string = groupNumber
                qqAlertMessage = "请先安装 QQ。群号 \(groupNumber) 已复制。"
                showingQQOpenFailed = true
            }
        }
    }

    @MainActor
    private func checkForUpdate() async {
        guard !isCheckingUpdate else { return }
        isCheckingUpdate = true
        availableUpdateURL = nil
        defer {
            isCheckingUpdate = false
            showingUpdateResult = true
        }

        let currentVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"

        for country in ["cn", "us"] {
            var components = URLComponents(string: "https://itunes.apple.com/lookup")
            components?.queryItems = [
                URLQueryItem(name: "id", value: appStoreID),
                URLQueryItem(name: "country", value: country)
            ]
            guard let url = components?.url else { continue }
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 10
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let result = try JSONDecoder().decode(
                        RoveAppStoreLookupResponse.self,
                        from: data
                      ).results.first else { continue }

                if result.version.compare(currentVersion, options: .numeric) == .orderedDescending {
                    updateResultTitle = "发现新版本"
                    updateResultMessage = "RovePlayer \(result.version) 已发布，当前版本为 \(currentVersion)。"
                    availableUpdateURL = URL(string: result.trackViewURL)
                } else {
                    updateResultTitle = "已是最新版本"
                    updateResultMessage = "当前安装的 RovePlayer \(currentVersion) 已是最新版。"
                }
                return
            } catch {
                continue
            }
        }

        updateResultTitle = "暂时无法检测更新"
        updateResultMessage = "App Store 暂未返回 RovePlayer 的版本信息，请稍后再试。"
    }
}

private struct RoveAppStoreLookupResponse: Decodable {
    struct Result: Decodable {
        let version: String
        let trackViewURL: String

        enum CodingKeys: String, CodingKey {
            case version
            case trackViewURL = "trackViewUrl"
        }
    }

    let results: [Result]
}

private struct RoveDanmakuSettingsView: View {
    @StateObject private var settings = RoveDanmakuSettingsStore.shared
    @State private var editingSource: RoveDanmakuSource?

    var body: some View {
        Form {
            Section {
                Toggle("全局弹幕开关", isOn: $settings.isEnabled)
                Toggle("记住弹幕源", isOn: $settings.remembersSource)
            } footer: {
                Text("记住后，播放新影片或剧集时会继续使用上次在播放器中选择的弹幕源。")
            }

            Section {
                ForEach(settings.sources) { source in
                    Button {
                        editingSource = source
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "cloud")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(source.isBuiltIn ? .orange : Color.roveAccent)
                                .frame(width: 34, height: 34)
                                .background(
                                    (source.isBuiltIn ? Color.orange : Color.roveAccent).opacity(0.12),
                                    in: Circle()
                                )
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 7) {
                                    Text(source.name)
                                        .foregroundStyle(.primary)
                                    if settings.defaultSourceID == source.id {
                                        Text("默认")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(.secondary.opacity(0.12), in: Capsule())
                                    }
                                }
                                Text(source.baseURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        if !source.isBuiltIn {
                            Button("删除", role: .destructive) {
                                settings.remove(source)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("弹幕源")
                    Spacer()
                    Button {
                        editingSource = RoveDanmakuSource(
                            id: UUID(),
                            name: "",
                            baseURL: "",
                            appID: ""
                        )
                    } label: {
                        Label("添加弹幕源", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .textCase(nil)
                }
            } footer: {
                Text("DanDanPlay 为默认兼容接口。官方地址需要开发者 AppId 和 AppSecret；自建兼容节点可按服务要求留空。")
            }

            Section("屏蔽关键词") {
                TextEditor(text: $settings.blockedKeywordsText)
                    .frame(minHeight: 96)
                    .overlay(alignment: .topLeading) {
                        if settings.blockedKeywordsText.isEmpty {
                            Text("输入要屏蔽的关键词，每行一个或使用逗号分隔")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("中文简繁转换") {
                Picker("中文简繁转换", selection: $settings.conversion) {
                    ForEach(RoveDanmakuChineseConversion.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }

            Section("字体大小") {
                HStack(spacing: 14) {
                    Image(systemName: "textformat.size")
                        .foregroundStyle(Color.roveAccent)
                    Slider(value: $settings.fontSize, in: 12...32, step: 1)
                    Text("\(Int(settings.fontSize))")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .navigationTitle("弹幕设置")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { settings.settingsDidChange() }
        .sheet(item: $editingSource) { source in
            RoveDanmakuSourceEditor(source: source)
        }
    }
}

private struct RoveDanmakuSourceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = RoveDanmakuSettingsStore.shared
    let source: RoveDanmakuSource

    @State private var name: String
    @State private var baseURL: String
    @State private var appID: String
    @State private var appSecret: String
    @State private var isDefault: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(source: RoveDanmakuSource) {
        self.source = source
        _name = State(initialValue: source.name)
        _baseURL = State(initialValue: source.baseURL)
        _appID = State(initialValue: source.appID)
        _appSecret = State(initialValue: RoveDanmakuCredentialStore.secret(for: source.id) ?? "")
        _isDefault = State(initialValue: RoveDanmakuSettingsStore.shared.defaultSourceID == source.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("弹幕源") {
                    TextField("名称", text: $name)
                    TextField("https://api.dandanplay.net", text: $baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("设为默认弹幕源", isOn: $isDefault)
                }

                Section {
                    TextField("AppId（可选）", text: $appID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("AppSecret（可选）", text: $appSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("接口凭据")
                } footer: {
                    Text("DanDanPlay 官方接口必须填写开发者中心签发的 AppId 和 AppSecret。AppSecret 仅保存在本机钥匙串。")
                }
            }
            .navigationTitle(source.name.isEmpty ? "添加弹幕源" : "编辑弹幕源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中…" : "保存") { save() }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("无法保存", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        do {
            let updated = RoveDanmakuSource(
                id: source.id,
                name: name,
                baseURL: baseURL,
                appID: appID
            )
            try settings.upsert(updated, secret: appSecret)
            if isDefault { settings.setDefault(updated.id) }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

private struct RoveSubtitleSettingsView: View {
    @AppStorage(CompatiblePlaybackPreferences.sidecarSubtitleRuleDefaultsKey)
    private var sidecarRuleRaw = RoveSidecarSubtitleRule.sameName.rawValue
    @AppStorage(CompatiblePlaybackPreferences.autoLoadEmbeddedSubtitleDefaultsKey)
    private var autoLoadEmbeddedSubtitle = true
    @AppStorage(CompatiblePlaybackPreferences.embeddedSubtitleLanguageDefaultsKey)
    private var embeddedSubtitleLanguageRaw = RoveMediaLanguage.simplifiedChinese.rawValue
    @AppStorage(CompatiblePlaybackPreferences.onlineSubtitleLanguageDefaultsKey)
    private var onlineSubtitleLanguageRaw = RoveMediaLanguage.simplifiedChinese.rawValue
    @AppStorage(CompatiblePlaybackPreferences.defaultAudioLanguageDefaultsKey)
    private var defaultAudioLanguageRaw = RoveMediaLanguage.simplifiedChinese.rawValue
    @AppStorage(CompatiblePlaybackPreferences.subtitleTextColorDefaultsKey)
    private var subtitleTextColorHex = "#FFFFFFFF"
    @AppStorage(CompatiblePlaybackPreferences.subtitleBackgroundColorDefaultsKey)
    private var subtitleBackgroundColorHex = "#00000000"
    @AppStorage(CompatiblePlaybackPreferences.subtitleBoldDefaultsKey)
    private var subtitleBold = false
    @AppStorage(CompatiblePlaybackPreferences.subtitleItalicDefaultsKey)
    private var subtitleItalic = false
    @AppStorage(CompatiblePlaybackPreferences.hdrSubtitleAutomaticDefaultsKey)
    private var hdrSubtitleAutomatic = true
    @AppStorage(RoveSystemSubtitleTranslationPreferences.enabledDefaultsKey)
    private var realtimeTranslationEnabled = false

    var body: some View {
        Form {
            Section {
                if #available(iOS 18.0, *) {
                    NavigationLink {
                        RoveSystemTranslationSettingsView()
                    } label: {
                        LabeledContent(
                            "实时字幕翻译",
                            value: realtimeTranslationEnabled ? "Apple 系统翻译 · 已开启" : "未开启"
                        )
                    }
                } else {
                    NavigationLink {
                        RoveSystemTranslationUnavailableView()
                    } label: {
                        LabeledContent("实时字幕翻译", value: "需要 iOS 18+")
                    }
                }
            }

            Section {
                Picker("自动加载外挂字幕规则", selection: $sidecarRuleRaw) {
                    ForEach(RoveSidecarSubtitleRule.allCases) { rule in
                        Text(rule.title).tag(rule.rawValue)
                    }
                }
                .pickerStyle(.navigationLink)

                Toggle("自动加载内置字幕", isOn: $autoLoadEmbeddedSubtitle)

                Picker("自动加载内置字幕语言", selection: $embeddedSubtitleLanguageRaw) {
                    languageOptions
                }
                .pickerStyle(.navigationLink)

                Picker("在线字幕搜索语言", selection: $onlineSubtitleLanguageRaw) {
                    languageOptions
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                Picker("默认音轨语言", selection: $defaultAudioLanguageRaw) {
                    languageOptions
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                ColorPicker(
                    "字体颜色",
                    selection: storedColor($subtitleTextColorHex),
                    supportsOpacity: false
                )
                ColorPicker(
                    "边框颜色",
                    selection: storedColor($subtitleBackgroundColorHex),
                    supportsOpacity: true
                )
                Toggle("粗体文本", isOn: $subtitleBold)
                Toggle("斜体文本", isOn: $subtitleItalic)
            } header: {
                Text("字幕设置")
            } footer: {
                Text("字幕样式会应用到 KS 内核的内置字幕和外挂字幕。")
            }

            Section {
                Toggle("HDR 字幕自动", isOn: $hdrSubtitleAutomatic)
            } footer: {
                Text("根据视频动态范围自动保持图形字幕的正确亮度。")
            }
        }
        .navigationTitle("字幕和音轨")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: subtitleTextColorHex) { _, _ in applySubtitleAppearance() }
        .onChange(of: subtitleBackgroundColorHex) { _, _ in applySubtitleAppearance() }
        .onChange(of: subtitleBold) { _, _ in applySubtitleAppearance() }
        .onChange(of: subtitleItalic) { _, _ in applySubtitleAppearance() }
        .onAppear { applySubtitleAppearance() }
    }

    @ViewBuilder
    private var languageOptions: some View {
        ForEach(RoveMediaLanguage.allCases) { language in
            Text(language.title).tag(language.rawValue)
        }
    }

    private func storedColor(_ value: Binding<String>) -> Binding<Color> {
        Binding(
            get: { Color(uiColor: UIColor(roveSettingsHex: value.wrappedValue)) },
            set: { value.wrappedValue = UIColor($0).roveSettingsRGBAHex }
        )
    }

    private func applySubtitleAppearance() {
        CompatiblePlaybackPreferences.applySubtitleAppearance()
    }
}

private struct RoveSystemTranslationUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "系统翻译不可用",
            systemImage: "captions.bubble",
            description: Text("Apple 本地字幕翻译需要 iOS 18 或更高版本。")
        )
        .navigationTitle("实时字幕翻译")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 18.0, *)
private struct RoveSystemTranslationSettingsView: View {
    @AppStorage(RoveSystemSubtitleTranslationPreferences.enabledDefaultsKey)
    private var isEnabled = false
    @AppStorage(RoveSystemSubtitleTranslationPreferences.validityDetectionDefaultsKey)
    private var automaticallyDetectsValidity = true
    @AppStorage(RoveSystemSubtitleTranslationPreferences.sourceLanguageDefaultsKey)
    private var sourceLanguageRaw = RoveSubtitleTranslationLanguage.english.rawValue
    @AppStorage(RoveSystemSubtitleTranslationPreferences.targetLanguageDefaultsKey)
    private var targetLanguageRaw = RoveSubtitleTranslationLanguage.simplifiedChinese.rawValue
    @AppStorage(RoveSystemSubtitleTranslationPreferences.modeDefaultsKey)
    private var modeRaw = RoveSubtitleTranslationMode.bilingual.rawValue

    @State private var modelStatuses: [String: LanguageAvailability.Status] = [:]
    @State private var pendingDownload: RoveSubtitleTranslationLanguage?
    @State private var configuration: TranslationSession.Configuration?
    @State private var statusMessage: String?
    @State private var refreshGeneration = 0

    private var sourceLanguage: RoveSubtitleTranslationLanguage {
        RoveSubtitleTranslationLanguage(rawValue: sourceLanguageRaw) ?? .english
    }

    private var targetLanguage: RoveSubtitleTranslationLanguage {
        RoveSubtitleTranslationLanguage(rawValue: targetLanguageRaw) ?? .simplifiedChinese
    }

    var body: some View {
        Form {
            Section {
                Toggle("启用字幕翻译", isOn: $isEnabled)
                Toggle("自动检测语言有效性", isOn: $automaticallyDetectsValidity)
                LabeledContent("翻译服务", value: "Apple 系统翻译")
            } footer: {
                Text("翻译在设备本地运行，不需要网络或 API Key。播放时使用 KS 内核获取字幕文本。")
            }

            Section("实时字幕翻译") {
                Picker("源语言", selection: $sourceLanguageRaw) {
                    ForEach(RoveSubtitleTranslationLanguage.allCases) { language in
                        Text(language.title).tag(language.rawValue)
                    }
                }
                Picker("目标语言", selection: $targetLanguageRaw) {
                    ForEach(RoveSubtitleTranslationLanguage.allCases) { language in
                        Text(language.title).tag(language.rawValue)
                    }
                }
                Picker("翻译模式", selection: $modeRaw) {
                    ForEach(RoveSubtitleTranslationMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                LabeledContent("翻译额度", value: "本地运行 · 不限次数")
            }

            Section("字幕预览") {
                VStack(spacing: 8) {
                    if modeRaw == RoveSubtitleTranslationMode.bilingual.rawValue {
                        Text(previewTargetText)
                        Text("Subtitle Preview")
                    } else {
                        Text(previewTargetText)
                    }
                }
                .font(.headline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 104)
                .padding(.horizontal, 16)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
            }

            Section {
                ForEach(RoveSubtitleTranslationLanguage.allCases.filter { $0 != sourceLanguage }) { language in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(language.title)
                                .foregroundStyle(.primary)
                            Text("\(sourceLanguage.rawValue) → \(language.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        modelAction(for: language)
                    }
                }
            } header: {
                Text("系统翻译语言模型")
            } footer: {
                Text("点按下载后，iOS 会显示系统语言模型下载确认；完成或取消后状态会自动刷新。")
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("翻译服务配置")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(sourceLanguageRaw)-\(refreshGeneration)") {
            await refreshModelStatuses()
        }
        .onChange(of: sourceLanguageRaw) { _, _ in
            normalizeLanguagePair()
            modelStatuses = [:]
            refreshGeneration += 1
        }
        .onChange(of: targetLanguageRaw) { _, _ in
            normalizeLanguagePair()
        }
        .translationTask(configuration) { session in
            guard let pendingDownload else { return }
            do {
                try await session.prepareTranslation()
                statusMessage = "\(pendingDownload.title)语言模型已可用"
            } catch is CancellationError {
                statusMessage = "已取消语言模型下载"
            } catch {
                statusMessage = "语言模型准备失败：\(error.localizedDescription)"
            }
            self.pendingDownload = nil
            configuration = nil
            refreshGeneration += 1
        }
    }

    @ViewBuilder
    private func modelAction(for language: RoveSubtitleTranslationLanguage) -> some View {
        if pendingDownload == language {
            ProgressView()
                .controlSize(.small)
        } else {
            switch modelStatuses[language.rawValue] {
            case .installed:
                Label("已下载", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            case .supported:
                Button("下载", systemImage: "arrow.down.circle.fill") {
                    requestModelDownload(language)
                }
                .buttonStyle(.borderless)
            case .unsupported:
                Text("不支持")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case nil:
                ProgressView()
                    .controlSize(.small)
            @unknown default:
                Text("未知")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var previewTargetText: String {
        switch targetLanguage {
        case .simplifiedChinese: "实时字幕预览"
        case .traditionalChineseTaiwan, .traditionalChineseHongKong: "即時字幕預覽"
        case .english: "Subtitle Preview"
        case .japanese: "リアルタイム字幕プレビュー"
        case .korean: "실시간 자막 미리보기"
        case .french: "Aperçu des sous-titres"
        case .german: "Untertitelvorschau"
        case .spanish: "Vista previa de subtítulos"
        case .russian: "Предпросмотр субтитров"
        case .arabic: "معاينة الترجمة"
        }
    }

    private func normalizeLanguagePair() {
        guard sourceLanguageRaw == targetLanguageRaw else { return }
        targetLanguageRaw = RoveSubtitleTranslationLanguage.allCases
            .first(where: { $0.rawValue != sourceLanguageRaw })?.rawValue
            ?? RoveSubtitleTranslationLanguage.simplifiedChinese.rawValue
    }

    private func requestModelDownload(_ language: RoveSubtitleTranslationLanguage) {
        pendingDownload = language
        statusMessage = "正在等待 iOS 确认下载…"
        configuration = TranslationSession.Configuration(
            source: sourceLanguage.language,
            target: language.language
        )
    }

    private func refreshModelStatuses() async {
        let availability = LanguageAvailability()
        var updated: [String: LanguageAvailability.Status] = [:]
        for language in RoveSubtitleTranslationLanguage.allCases where language != sourceLanguage {
            guard !Task.isCancelled else { return }
            updated[language.rawValue] = await availability.status(
                from: sourceLanguage.language,
                to: language.language
            )
        }
        guard !Task.isCancelled else { return }
        modelStatuses = updated
    }
}

private struct RovePlaybackEnhancementView: View {
    @AppStorage(CompatiblePlaybackPreferences.qualityEnhancementDefaultsKey)
    private var qualityEnhancement = false
    @AppStorage(CompatiblePlaybackPreferences.frameRateEnhancementDefaultsKey)
    private var frameRateEnhancement = false

    var body: some View {
        Form {
            Section {
                Toggle("画质增强", isOn: $qualityEnhancement)
                Toggle("帧率增强", isOn: $frameRateEnhancement)
            } header: {
                Text("KSPlayer 增强")
            } footer: {
                Text("画质增强使用 KS 内核的细节锐化；帧率增强优化高刷新率屏幕的视频帧呈现。设置将在下次播放时生效。")
            }

            Section {
                LabeledContent("适用内核", value: "KSPlayer")
            LabeledContent("硬件解码", value: "VideoToolbox 优先；保留 FFmpeg 时间戳同步")
            }
        }
        .navigationTitle("画质与帧率增强")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#endif

private extension UIColor {
    func roveInterpolated(to other: UIColor, progress: CGFloat) -> UIColor {
        let amount = min(max(progress, 0), 1)
        var fromRed: CGFloat = 0
        var fromGreen: CGFloat = 0
        var fromBlue: CGFloat = 0
        var fromAlpha: CGFloat = 0
        var toRed: CGFloat = 0
        var toGreen: CGFloat = 0
        var toBlue: CGFloat = 0
        var toAlpha: CGFloat = 0
        guard getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha),
              other.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha) else {
            return amount < 0.5 ? self : other
        }
        return UIColor(
            red: fromRed + (toRed - fromRed) * amount,
            green: fromGreen + (toGreen - fromGreen) * amount,
            blue: fromBlue + (toBlue - fromBlue) * amount,
            alpha: fromAlpha + (toAlpha - fromAlpha) * amount
        )
    }

    var roveImmersiveBackground: UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
        }
        return UIColor(
            hue: hue,
            saturation: min(max(saturation * 0.82, 0.28), 0.72),
            brightness: min(max(brightness * 0.52, 0.22), 0.42),
            alpha: 1
        )
    }

    var roveHomeExtendedBackground: UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        return UIColor(
            hue: hue,
            saturation: min(max(saturation * 1.08, 0.34), 0.82),
            brightness: min(max(brightness * 1.30, 0.32), 0.56),
            alpha: alpha
        )
    }

    convenience init(roveSettingsHex: String) {
        let text = roveSettingsHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: text).scanHexInt64(&value)
        if text.count == 8 {
            self.init(
                red: CGFloat((value >> 24) & 0xFF) / 255,
                green: CGFloat((value >> 16) & 0xFF) / 255,
                blue: CGFloat((value >> 8) & 0xFF) / 255,
                alpha: CGFloat(value & 0xFF) / 255
            )
        } else {
            self.init(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        }
    }

    var roveSettingsRGBAHex: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#FFFFFFFF"
        }
        return String(
            format: "#%02X%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255)),
            Int(round(alpha * 255))
        )
    }
}

private enum RoveImageColorSampler {
    static let context = CIContext(options: [.workingColorSpace: NSNull()])
}

private extension UIImage {
    var roveImmersiveColor: UIColor {
        guard let input = CIImage(image: self),
              let filter = CIFilter(name: "CIAreaAverage") else {
            return UIColor.black
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: input.extent), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return UIColor.black }
        var bitmap = [UInt8](repeating: 0, count: 4)
        RoveImageColorSampler.context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        ).roveImmersiveBackground
    }
}

#if !DJHUB_METADATA_ONLY
private struct RoveSearchView: View {
    private enum SourceMode: String, CaseIterable, Identifiable {
        case files = "文件源"
        case mediaServers = "影视服务器"

        var id: String { rawValue }
    }

    @EnvironmentObject private var library: ChannelLibrary
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rove.search.showRecommendations.v1") private var showsRecommendations = true
    @AppStorage("rove.search.aggregate.v1") private var aggregateSearch = true
    @State private var query = ""
    @State private var sourceMode = SourceMode.mediaServers
    @State private var selectedChannel: Channel?
    @State private var selectedChannelHeroID: AnyHashable?
    @State private var recommendationOffset = 0
    @State private var excludedConfigurationIDs = Set<UUID>()
    @State private var remoteResults: [Channel] = []
    @State private var isSearching = false
    @State private var mediaStateRevision = 0
    @State private var searchBackOffset: CGFloat = 0
    @State private var isCompletingSearchBack = false
    @Namespace private var mediaHeroNamespace
    var showsDoneButton = true
    var onSwipeBack: (() -> Void)? = nil

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12),
        count: 3
    )

    private var fileConfigurations: [PlaylistConfiguration] {
        library.configurations.filter { !$0.kind.usesMediaLibraryBrowser && !$0.isExpired }
    }

    private var mediaServerConfigurations: [PlaylistConfiguration] {
        library.configurations.filter { $0.kind.usesMediaLibraryBrowser && !$0.isExpired }
    }

    private var availableSourceModes: [SourceMode] {
        var modes: [SourceMode] = []
        if !fileConfigurations.isEmpty { modes.append(.files) }
        if !mediaServerConfigurations.isEmpty { modes.append(.mediaServers) }
        return modes
    }

    private var sourceModeSignature: String {
        availableSourceModes.map(\.rawValue).joined(separator: "|")
    }

    private var availableConfigurations: [PlaylistConfiguration] {
        sourceMode == .mediaServers ? mediaServerConfigurations : fileConfigurations
    }

    private var selectedConfigurations: [PlaylistConfiguration] {
        availableConfigurations.filter { !excludedConfigurationIDs.contains($0.id) }
    }

    private var sourceChannels: [Channel] {
        uniqueChannels(selectedConfigurations.flatMap(\.channels))
    }

    private var recommendationChannels: [Channel] {
        guard sourceMode == .mediaServers else { return sourceChannels }
        return sourceChannels.filter { channel in
            guard !channel.isMediaServerEpisode else { return false }
            return channel.mediaServerItemType?.caseInsensitiveCompare("Season") != .orderedSame
        }
    }

    private var displayedChannels: [Channel] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            guard showsRecommendations else { return [] }
            let candidates = recommendationChannels
            guard !candidates.isEmpty else { return [] }
            let offset = recommendationOffset % candidates.count
            return Array((Array(candidates.dropFirst(offset)) + Array(candidates.prefix(offset))).prefix(90))
        }

        let cachedMatches = sourceChannels.filter {
            $0.name.localizedCaseInsensitiveContains(text)
                || library.displayGroup(for: $0).localizedCaseInsensitiveContains(text)
        }
        return Array(uniqueChannels(cachedMatches + remoteResults).prefix(120))
    }

    private var searchTaskID: String {
        "\(sourceMode.rawValue)|\(aggregateSearch)|\(selectedConfigurations.map(\.id.uuidString).joined(separator: ","))|\(query)"
    }

    var body: some View {
        GeometryReader { rootGeometry in
            ZStack(alignment: .leading) {
                Color(uiColor: .secondarySystemBackground)
                    .ignoresSafeArea()

                NavigationStack {
                    GeometryReader { geometry in
                        let contentWidth = max(geometry.size.width - 40, 0)
                        let cardWidth = max((contentWidth - 24) / 3, 0)

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 18) {
                                sectionHeader

                                if isSearching && displayedChannels.isEmpty {
                                    ProgressView("正在搜索…")
                                        .frame(maxWidth: .infinity, minHeight: 320)
                                } else if displayedChannels.isEmpty {
                                    ContentUnavailableView(
                                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                            ? "没有可推荐的媒体"
                                            : "没有搜索结果",
                                        systemImage: query.isEmpty ? "film.stack" : "magnifyingglass",
                                        description: Text(query.isEmpty ? "请连接或选择一个媒体来源。" : "试试其他关键词。")
                                    )
                                    .frame(maxWidth: .infinity, minHeight: 320)
                                } else {
                                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                                        ForEach(displayedChannels) { channel in
                                            posterCard(channel, width: cardWidth)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 18)
                            .padding(.bottom, 100)
                        }
                        .scrollIndicators(.hidden)
                        .background(Color(uiColor: .systemBackground))
                    }
                    .background(Color(uiColor: .systemBackground).ignoresSafeArea())
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.ultraThinMaterial.opacity(0.46), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .searchable(
                        text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "搜索"
                    )
                    .toolbar {
                        if showsDoneButton {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("完成") { dismiss() }
                            }
                        }

                        ToolbarItem(placement: .principal) {
                            if availableSourceModes.count > 1 {
                                Picker("搜索来源", selection: $sourceMode) {
                                    ForEach(availableSourceModes) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: showsDoneButton ? 238 : 250)
                            } else if let onlyMode = availableSourceModes.first {
                                Text(onlyMode.rawValue)
                                    .font(.headline.weight(.bold))
                            } else {
                                Text("搜索")
                                    .font(.headline.weight(.bold))
                            }
                        }

                        if !availableConfigurations.isEmpty {
                            ToolbarItem(placement: .primaryAction) {
                                sourceMenu
                            }
                        }
                    }
                    .navigationDestination(item: $selectedChannel) { channel in
                        RoveMediaDetailView(channel: channel)
                            .roveHeroNavigationTransition(
                                id: selectedChannelHeroID,
                                namespace: mediaHeroNamespace
                            )
                    }
                    .task(id: searchTaskID) {
                        await loadRemoteResults()
                    }
                    .onChange(of: sourceModeSignature, initial: true) { _, _ in
                        synchronizeSourceMode()
                    }
                    .id(mediaStateRevision)
                }
                .offset(x: searchBackOffset)
                .shadow(
                    color: .black.opacity(searchBackProgress(in: rootGeometry.size.width) * 0.24),
                    radius: 18,
                    x: -7
                )

                if searchBackOffset > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial, in: Circle())
                        .offset(x: min(max(searchBackOffset * 0.35 - 17, 8), 34))
                        .opacity(searchBackProgress(in: rootGeometry.size.width))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(searchRootBackGesture(containerWidth: rootGeometry.size.width))
        }
        .toolbarBackground(.ultraThinMaterial.opacity(0.42), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .presentationDetents(showsDoneButton ? [.large] : [])
        .presentationDragIndicator(showsDoneButton ? .visible : .hidden)
    }

    private func searchBackProgress(in width: CGFloat) -> CGFloat {
        min(max(searchBackOffset / max(width * 0.42, 1), 0), 1)
    }

    private func searchRootBackGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .global)
            .onChanged { value in
                guard selectedChannel == nil,
                      onSwipeBack != nil,
                      !isCompletingSearchBack,
                      value.startLocation.x <= 28,
                      value.translation.width > 0,
                      abs(value.translation.height) <= abs(value.translation.width) * 0.8
                else { return }
                searchBackOffset = min(value.translation.width, containerWidth)
            }
            .onEnded { value in
                guard selectedChannel == nil,
                      let onSwipeBack,
                      value.startLocation.x <= 28,
                      abs(value.translation.height) <= abs(value.translation.width) * 0.65
                else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        searchBackOffset = 0
                    }
                    return
                }

                let shouldComplete = value.translation.width >= containerWidth * 0.28
                    || value.predictedEndTranslation.width >= containerWidth * 0.52
                guard shouldComplete else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        searchBackOffset = 0
                    }
                    return
                }

                isCompletingSearchBack = true
                withAnimation(.easeOut(duration: 0.22)) {
                    searchBackOffset = containerWidth
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(210))
                    onSwipeBack()
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        searchBackOffset = 0
                        isCompletingSearchBack = false
                    }
                }
            }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "推荐观看" : "搜索结果")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.primary)
            Spacer()
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               showsRecommendations,
               !displayedChannels.isEmpty {
                Button {
                    recommendationOffset += 9
                } label: {
                    Label("换一批", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else if isSearching {
                ProgressView()
            }
        }
    }

    private var sourceMenu: some View {
        Menu {
            Toggle("显示推荐观看", isOn: $showsRecommendations)
            Toggle("启用聚合搜索", isOn: $aggregateSearch)

            if !availableConfigurations.isEmpty {
                Divider()
                Section("聚合搜索") {
                    ForEach(availableConfigurations) { configuration in
                        Button {
                            if excludedConfigurationIDs.contains(configuration.id) {
                                excludedConfigurationIDs.remove(configuration.id)
                            } else {
                                excludedConfigurationIDs.insert(configuration.id)
                            }
                        } label: {
                            Label(
                                searchSourceDisplayName(configuration),
                                systemImage: excludedConfigurationIDs.contains(configuration.id)
                                    ? "circle"
                                    : "checkmark"
                            )
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline.weight(.bold))
                .frame(width: 34, height: 34)
        }
        .accessibilityLabel("搜索设置")
    }

    private func searchSourceDisplayName(_ configuration: PlaylistConfiguration) -> String {
        let remark = configuration.serverRemark?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !remark.isEmpty { return remark }

        let reportedName = configuration.serverReportedName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !reportedName.isEmpty { return reportedName }

        let savedName = configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return savedName.isEmpty ? configuration.kind.title : savedName
    }

    private func posterCard(_ channel: Channel, width: CGFloat) -> some View {
        let transitionID = "search-channel-\(channel.id.uuidString)"
        return Button {
            openSearchResult(channel, heroID: transitionID)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    RoveArtworkView(channel: channel, landscape: false)
                        .frame(width: width, height: width * 1.5)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
                        .roveHeroTransitionSource(
                            id: transitionID,
                            namespace: mediaHeroNamespace
                        )

                    if let rating = channel.communityRating, rating > 0 {
                        Text(String(format: "%.1f", rating))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.68), in: UnevenRoundedRectangle(topLeadingRadius: 8))
                    }

                    if RoveWatchedStore.contains(channel) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.black, .white.opacity(0.92))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(8)
                    }
                }
                Text(channel.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: width, alignment: .leading)
                Text(channel.productionYear.map(String.init) ?? library.displayGroup(for: channel))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: width, alignment: .leading)
            }
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .roveMediaActions(
            for: channel,
            onOpen: { openSearchResult(channel, heroID: transitionID) },
            onStateChange: { mediaStateRevision += 1 }
        )
    }

    private func openSearchResult(_ channel: Channel, heroID: AnyHashable) {
        selectedChannelHeroID = heroID
        Task { @MainActor in
            await Task.yield()
            guard selectedChannelHeroID == heroID else { return }
            selectedChannel = channel
        }
    }

    private func uniqueChannels(_ channels: [Channel]) -> [Channel] {
        var seen = Set<String>()
        return channels.filter { channel in
            let key = channel.tvgID.map { "\(channel.streamURL.host ?? "")|\($0)" }
                ?? channel.streamURL.absoluteString
            return seen.insert(key).inserted
        }
    }

    private func synchronizeSourceMode() {
        guard !availableSourceModes.contains(sourceMode),
              let firstMode = availableSourceModes.first else { return }
        sourceMode = firstMode
        excludedConfigurationIDs.formIntersection(Set(library.configurations.map(\.id)))
        recommendationOffset = 0
        remoteResults = []
    }

    @MainActor
    private func loadRemoteResults() async {
        remoteResults = []
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sourceMode == .mediaServers, aggregateSearch, !text.isEmpty else {
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }
        do {
            try await Task.sleep(for: .milliseconds(300))
            try Task.checkCancellation()
        } catch {
            return
        }

        var loaded: [Channel] = []
        for configuration in selectedConfigurations {
            guard !Task.isCancelled else { return }
            if let result = try? await library.searchAllEmbyItems(
                configurationID: configuration.id,
                searchTerm: text
            ) {
                loaded.append(contentsOf: result)
            }
        }
        guard !Task.isCancelled,
              text == query.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return }
        remoteResults = uniqueChannels(loaded)
    }
}

private struct RoveSourceSheetView: View {
    @Binding var pendingLocalVideoImport: URL?
    let onSelect: (RoveSourceSheet) -> Void
    @State private var activeSheet: RoveSourceSheet

    init(
        sheet: RoveSourceSheet,
        pendingLocalVideoImport: Binding<URL?>,
        onSelect: @escaping (RoveSourceSheet) -> Void
    ) {
        _pendingLocalVideoImport = pendingLocalVideoImport
        self.onSelect = onSelect
        _activeSheet = State(initialValue: sheet)
    }

    var body: some View {
        switch activeSheet {
        case .picker:
            RoveSourcePicker { destination in
                if case .localFiles = destination {
                    onSelect(destination)
                } else {
                    activeSheet = destination
                }
            }
        case .mediaServer(let kind, let request):
            TuboMediaServerConfigurationForm(
                serverKind: kind,
                embyImportRequest: request
            )
        case .moviePilot(let connection):
            MoviePilotConnectionForm(connection: connection)
        case .legacyLibraryD:
            RovePlexForm()
        case .networkShare(let scheme):
            RoveNetworkShareForm(scheme: scheme)
        case .webDAV:
            RoveWebDAVForm()
        case .playlist(let request):
            RovePlaylistForm(importRequest: request)
        case .rss:
            RoveRSSFeedForm()
        case .directStream:
            RoveDirectStreamForm()
        case .localFiles:
            NavigationStack {
                LocalVideoLibraryView(pendingImportURL: $pendingLocalVideoImport)
            }
        case .privateLocalFiles:
            NavigationStack {
                PrivateLocalVideoLibraryView()
            }
        case .cloudDrives:
            NavigationStack {
                CloudDriveConnectionsView()
            }
        case .cloudDrive(let provider):
            NavigationStack {
                switch provider {
                case .google: GoogleDriveView()
                case .baidu: BaiduNetdiskView()
                case .pan115: Pan115DriveView()
                case .pan123: Pan123DriveView()
                case .aliyun: AliyunDriveView()
                case .cloud139: Cloud139DriveView()
                case .cloud189: Cloud189DriveView()
                case .lanzou: LanzouDriveView()
                case .quark: QuarkDriveView()
                case .thunder: ThunderDriveView()
                case .guangya: GuangYaDriveView()
                }
            }
        }
    }
}

private struct RoveSourcePicker: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (RoveSourceSheet) -> Void

    private let sections: [(String, [(String, String, String, RoveSourceSheet)])] = [
        ("文件服务器", [
            ("SMB", "连接 Windows 或 NAS 共享", "externaldrive.connected.to.line.below", .networkShare("smb")),
            ("WebDAV", "浏览远程文件", "externaldrive", .webDAV),
            ("SFTP", "连接安全文件服务器", "network", .networkShare("sftp"))
        ]),
        ("媒体服务器", [
            ("Emby", "连接个人媒体库", "server.rack", .mediaServer(.legacyLibraryB, nil)),
            ("极影视", "连接极空间影视库", "externaldrive.fill", .mediaServer(.zspaceVideo, nil)),
            ("Jellyfin", "连接开源媒体库", "play.rectangle.on.rectangle", .mediaServer(.legacyLibraryA, nil)),
            ("MovieClaw", "连接 MovieClaw 媒体库", "movieclapper.fill", .mediaServer(.movieClaw, nil)),
            ("旧版资料库", "连接飞牛 NAS 影视库", "film.stack.fill", .mediaServer(.legacyLibraryC, nil)),
            ("Plex", "连接 Plex Media Server", "chevron.right.square.fill", .legacyLibraryD)
        ]),
        ("订阅自动化", [
            ("MoviePilot", "连接并管理电影与剧集订阅", "sparkles.tv", .moviePilot(nil))
        ]),
        ("播放列表与云服务", [
            ("M3U 订阅", "导入直播或媒体列表", "list.and.film", .playlist(nil)),
            ("RSS 视频订阅", "导入视频播客或 Atom 源", "dot.radiowaves.left.and.right", .rss),
            ("网络直链", "打开一个媒体地址", "link", .directStream),
            ("本地视频", "导入设备文件", "folder", .localFiles),
            ("本地私密", "密码或面容 ID 保护的本地文件", "folder.fill.badge.person.crop", .privateLocalFiles),
            ("网盘", "连接云端文件", "cloud", .cloudDrives)
        ])
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    Section(section.0) {
                        ForEach(Array(section.1.enumerated()), id: \.offset) { _, item in
                            Button {
                                onSelect(item.3)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.2)
                                        .foregroundStyle(Color.roveAccent)
                                        .frame(width: 34, height: 34)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.0).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        Text(item.1).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("添加来源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct MoviePilotConnectionForm: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: ChannelLibrary
    @StateObject private var store = MoviePilotConnectionStore.shared

    let connection: MoviePilotConnection?
    @State private var name: String
    @State private var server: String
    @State private var authenticationMode: MoviePilotAuthenticationMode
    @State private var username: String
    @State private var password = ""
    @State private var apiToken = ""
    @State private var localError: String?

    init(connection: MoviePilotConnection? = nil) {
        self.connection = connection
        _name = State(initialValue: connection?.name ?? "MoviePilot")
        _server = State(initialValue: connection?.server ?? "")
        _authenticationMode = State(initialValue: connection?.authenticationMode ?? .account)
        _username = State(initialValue: connection?.username ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    TextField("名称", text: $name)
                    TextField("例如 http://192.168.1.10:3000", text: $server)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }

                Section("认证方式") {
                    Picker("认证方式", selection: $authenticationMode) {
                        ForEach(MoviePilotAuthenticationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if authenticationMode == .account {
                        TextField("用户名", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField(connection == nil ? "密码" : "密码（留空则保持不变）", text: $password)
                    } else {
                        SecureField(connection == nil ? "API Token" : "API Token（留空则保持不变）", text: $apiToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section {
                    Button {
                        validateAndSave()
                    } label: {
                        HStack {
                            Spacer()
                            if store.isSaving {
                                ProgressView().padding(.trailing, 6)
                            }
                            Text(store.isSaving ? "正在验证" : "验证并保存")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit || store.isSaving)
                }
            }
            .navigationTitle("MoviePilot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert(
                "无法连接 MoviePilot",
                isPresented: Binding(
                    get: { localError != nil || store.lastError != nil },
                    set: { if !$0 { localError = nil; store.clearError() } }
                )
            ) {
                Button("好", role: .cancel) {
                    localError = nil
                    store.clearError()
                }
            } message: {
                Text(localError ?? store.lastError ?? "未知错误")
            }
        }
        .presentationDetents([.large])
    }

    private var canSubmit: Bool {
        guard !server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if connection != nil { return true }
        switch authenticationMode {
        case .account:
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
        case .apiToken:
            return !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func validateAndSave() {
        if connection == nil {
            let existingCount = library.configurations.count + store.connections.count
            guard ProPurchaseManager.shared.canAddConfiguration(existingCount: existingCount) else {
                localError = "免费版最多可添加 \(ProPurchaseManager.freeConfigurationLimit) 个资源，升级 RovePlayer Pro 后不限制数量。"
                return
            }
        }
        Task {
            let saved = await store.validateAndSave(
                existingID: connection?.id,
                name: name,
                server: server,
                mode: authenticationMode,
                username: username,
                password: password,
                apiToken: apiToken
            )
            if saved != nil { dismiss() }
        }
    }
}

private struct MoviePilotSubscriptionsView: View {
    @StateObject private var store = MoviePilotConnectionStore.shared
    let connection: MoviePilotConnection

    @State private var subscriptions: [MoviePilotSubscription] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && subscriptions.isEmpty {
                ProgressView("正在读取订阅")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, subscriptions.isEmpty {
                ContentUnavailableView {
                    Label("无法读取订阅", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("重试") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if subscriptions.isEmpty {
                ContentUnavailableView(
                    "暂无订阅",
                    systemImage: "sparkles.tv",
                    description: Text("MoviePilot 当前没有电影或剧集订阅。")
                )
            } else {
                List(subscriptions) { subscription in
                    HStack(spacing: 12) {
                        AsyncImage(url: subscription.posterURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "film.stack")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color(uiColor: .tertiarySystemFill))
                            }
                        }
                        .frame(width: 50, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(subscription.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            if !subscription.detailText.isEmpty {
                                Text(subscription.detailText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if let status = subscription.status, !status.isEmpty {
                                Text(status)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color.roveAccent)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .background(RoveBackdrop())
        .navigationTitle(connection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel("刷新订阅")
            }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        guard !isLoading || subscriptions.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            subscriptions = try await store.subscriptions(for: connection)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SMBNearbyShare: Identifiable, Equatable {
    let serviceName: String
    let host: String
    let port: Int

    var id: String { serviceName + "|" + host + "|" + String(port) }
    var address: String { port == 445 ? host : "\(host):\(port)" }
}

private final class SMBNearbyDiscovery: NSObject, ObservableObject,
    NetServiceBrowserDelegate, NetServiceDelegate {
    @Published private(set) var shares: [SMBNearbyShare] = []
    @Published private(set) var isSearching = false

    private let browser = NetServiceBrowser()
    private var services: [NetService] = []

    override init() {
        super.init()
        browser.delegate = self
    }

    func start() {
        guard !isSearching else { return }
        shares = []
        isSearching = true
        browser.searchForServices(ofType: "_smb._tcp.", inDomain: "local.")
    }

    func restart() {
        stop()
        start()
    }

    func stop() {
        browser.stop()
        services.forEach { $0.stop() }
        services.removeAll()
        isSearching = false
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        guard !services.contains(where: { $0 === service }) else { return }
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        services.removeAll { $0 === service }
        shares.removeAll { $0.serviceName == service.name }
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        isSearching = false
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard var host = sender.hostName, !host.isEmpty else { return }
        while host.hasSuffix(".") { host.removeLast() }
        let resolved = SMBNearbyShare(
            serviceName: sender.name,
            host: host,
            port: sender.port > 0 ? sender.port : 445
        )
        shares.removeAll { $0.serviceName == sender.name }
        shares.append(resolved)
        shares.sort { $0.serviceName.localizedStandardCompare($1.serviceName) == .orderedAscending }
        isSearching = false
    }
}

private struct RoveNetworkShareForm: View {
    @EnvironmentObject private var library: ChannelLibrary
    @Environment(\.dismiss) private var dismiss
    let scheme: String

    @StateObject private var smbDiscovery = SMBNearbyDiscovery()
    @State private var name = ""
    @State private var address = ""
    @State private var username = ""
    @State private var password = ""

    private var displayName: String { scheme.uppercased() }

    var body: some View {
        NavigationStack {
            Form {
                if scheme == "smb" {
                    Section {
                        if smbDiscovery.shares.isEmpty {
                            HStack(spacing: 12) {
                                if smbDiscovery.isSearching { ProgressView() }
                                Image(systemName: "externaldrive.connected.to.line.below")
                                    .foregroundStyle(Color.roveAccent)
                                Text(smbDiscovery.isSearching ? "正在查找附近的共享…" : "未发现附近的 SMB 共享")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(smbDiscovery.shares) { share in
                                Button {
                                    selectNearbyShare(share)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "externaldrive.connected.to.line.below.fill")
                                            .foregroundStyle(Color.roveAccent)
                                            .frame(width: 34, height: 34)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(share.serviceName)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            Text(share.address)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        HStack {
                            Text("可用的共享")
                            Spacer()
                            Button {
                                smbDiscovery.restart()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .accessibilityLabel("重新查找")
                        }
                    }
                }
                Section {
                    TextField("名称（可选）", text: $name)
                    TextField("服务器与文件路径", text: $address, prompt: Text("192.168.1.10/共享/影片.mp4"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("用户名（可选）", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码（可选）", text: $password)
                } footer: {
                    Text("请输入可直接访问的媒体文件路径，RovePlayer 会使用 \(displayName) 连接并播放。")
                }
                Section {
                    Button("添加 \(displayName)") { addShare() }
                        .frame(maxWidth: .infinity)
                        .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("添加 \(displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            if scheme == "smb" { smbDiscovery.start() }
        }
        .onDisappear { smbDiscovery.stop() }
    }

    private func selectNearbyShare(_ share: SMBNearbyShare) {
        address = share.address
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = share.serviceName
        }
    }

    private func addShare() {
        var raw = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.lowercased().hasPrefix("\(scheme)://") { raw = "\(scheme)://" + raw }
        guard var components = URLComponents(string: raw) else { return }
        let cleanUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanUser.isEmpty { components.user = cleanUser }
        if !password.isEmpty { components.password = password }
        guard let url = components.url else { return }
        library.addSingleChannelConfiguration(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? displayName : name,
            address: url.absoluteString
        )
        dismiss()
    }
}

struct RovePlexForm: View {
    @EnvironmentObject private var library: ChannelLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var server = ""
    @State private var token = ""
    @State private var isConnecting = false
    @State private var pinCode = ""
    @State private var statusText = ""
    @State private var servers: [PlexConfigurationService.ServerCandidate] = []
    @State private var authorizationTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        startAuthorization()
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                            Text(isConnecting ? "等待 Plex 授权…" : "使用 Plex 账号登录")
                            Spacer()
                            if isConnecting { ProgressView() }
                        }
                    }
                    .disabled(isConnecting)
                    if !pinCode.isEmpty {
                        LabeledContent("授权码", value: pinCode)
                            .font(.body.monospaced())
                    }
                    if !statusText.isEmpty {
                        Text(statusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("登录会打开 Plex 官方授权页。授权完成后，RovePlayer 会探测账号下可用的 Plex Media Server 线路。")
                }

                if !servers.isEmpty {
                    Section("选择 Plex 服务器") {
                        ForEach(servers) { candidate in
                            Button {
                                connect(candidate)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: candidate.owned ? "server.rack" : "person.2.fill")
                                        .foregroundStyle(Color.roveAccent)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(candidate.name)
                                            .foregroundStyle(.primary)
                                        Text(candidate.server)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if !candidate.alternateRoutes.isEmpty {
                                        Text("+\(candidate.alternateRoutes.count) 线路")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }

                DisclosureGroup("手动连接") {
                    TextField("名称（可选）", text: $name)
                    TextField("服务器地址", text: $server, prompt: Text("http://192.168.1.10:32400"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Plex Access Token", text: $token)
                        .textInputAutocapitalization(.never)
                    Button("连接服务器") {
                        Task {
                            await add(name: name, server: server, token: token)
                        }
                    }
                    .disabled(server.isEmpty || token.isEmpty || isConnecting)
                }
                if let error = library.lastError {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("添加 Plex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onDisappear { authorizationTask?.cancel() }
        }
    }

    private func startAuthorization() {
        authorizationTask?.cancel()
        library.clearError()
        servers = []
        pinCode = ""
        statusText = "正在创建 Plex 授权请求…"
        isConnecting = true
        authorizationTask = Task {
            do {
                let pin = try await PlexConfigurationService.createAuthorizationPin()
                try Task.checkCancellation()
                pinCode = pin.code
                statusText = "请在 Plex 页面完成授权。"
                if let url = PlexConfigurationService.authorizationURL(code: pin.code) {
                    await UIApplication.shared.open(url)
                }
                var accountToken: String?
                for _ in 0..<100 where !Task.isCancelled {
                    try await Task.sleep(for: .milliseconds(1_200))
                    let current = try await PlexConfigurationService.authorizationPin(id: pin.id)
                    if let value = current.authToken, !value.isEmpty {
                        accountToken = value
                        break
                    }
                }
                try Task.checkCancellation()
                guard let accountToken else {
                    statusText = "Plex 授权已超时，请重试。"
                    isConnecting = false
                    return
                }
                statusText = "正在探测 Plex 服务器线路…"
                servers = try await PlexConfigurationService.discoverServers(accountToken: accountToken)
                statusText = servers.isEmpty
                    ? "账号下没有可访问的 Plex Media Server。"
                    : "请选择要添加的服务器。"
            } catch is CancellationError {
                return
            } catch {
                statusText = "Plex 授权失败：\(error.localizedDescription)"
            }
            isConnecting = false
        }
    }

    private func connect(_ candidate: PlexConfigurationService.ServerCandidate) {
        authorizationTask?.cancel()
        Task {
            await add(name: candidate.name, server: candidate.server, token: candidate.token)
        }
    }

    private func add(name: String, server: String, token: String) async {
        isConnecting = true
        library.clearError()
        await library.addPlexConfiguration(name: name, server: server, token: token)
        isConnecting = false
        if library.lastError == nil { dismiss() }
    }
}

private struct RoveWebDAVForm: View {
    @EnvironmentObject private var library: ChannelLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("WebDAV") {
                    TextField("名称（可选）", text: $name)
                    TextField("服务器地址", text: $server)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $password)
                }
                Section {
                    Button("验证并连接") { connect() }
                        .frame(maxWidth: .infinity)
                        .disabled(server.isEmpty || library.isImportingConfiguration)
                }
            }
            .navigationTitle("连接 WebDAV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .libraryErrorAlert(library)
        }
    }

    private func connect() {
        let count = library.configurations.count
        Task {
            await library.addWebDAVConfiguration(name: name, server: server, username: username, password: password)
            if library.configurations.count > count { dismiss() }
        }
    }
}

private struct RovePlaylistForm: View {
    @EnvironmentObject private var library: ChannelLibrary
    @Environment(\.dismiss) private var dismiss
    let importRequest: WebPlaylistImportRequest?

    @State private var name: String
    @State private var address: String
    @State private var epgAddress: String

    init(importRequest: WebPlaylistImportRequest?) {
        self.importRequest = importRequest
        _name = State(initialValue: importRequest?.name ?? "")
        _address = State(initialValue: importRequest?.address ?? "")
        _epgAddress = State(initialValue: importRequest?.epgAddress ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("M3U 订阅") {
                    TextField("名称（可选）", text: $name)
                    TextField("播放列表地址", text: $address, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("EPG 地址（可选）", text: $epgAddress, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("导入播放列表") { importPlaylist() }
                        .frame(maxWidth: .infinity)
                        .disabled(address.isEmpty || library.isImportingConfiguration)
                }
            }
            .navigationTitle("添加 M3U")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .libraryErrorAlert(library)
        }
    }

    private func importPlaylist() {
        let epgURLs = epgAddress
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .compactMap { URL(string: String($0)) }
        let count = library.configurations.count
        Task {
            await library.addSubscriptionConfiguration(
                name: name,
                address: address,
                customEPGURLs: epgURLs,
                isWebImportProtected: importRequest != nil,
                expirationDate: importRequest?.expirationDate
            )
            if library.configurations.count > count { dismiss() }
        }
    }
}

private struct RoveRSSFeedForm: View {
    @EnvironmentObject private var library: ChannelLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（可选）", text: $name)
                    TextField("RSS 或 Atom 地址", text: $address, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                } header: {
                    Text("RSS 视频订阅")
                } footer: {
                    Text("支持 RSS 2.0、Atom 和 Media RSS，仅导入包含可直接播放视频附件的条目。")
                }
                Section {
                    Button("导入 RSS 视频") { importFeed() }
                        .frame(maxWidth: .infinity)
                        .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || library.isImportingConfiguration)
                }
            }
            .navigationTitle("添加 RSS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .libraryErrorAlert(library)
        }
    }

    private func importFeed() {
        let configurationCount = library.configurations.count
        Task {
            await library.addRSSConfiguration(name: name, address: address)
            if library.configurations.count > configurationCount { dismiss() }
        }
    }
}

private struct RoveDirectStreamForm: View {
    @EnvironmentObject private var library: ChannelLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("网络直链") {
                    TextField("名称", text: $name)
                    TextField("媒体地址", text: $address, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("添加并播放") {
                        library.addSingleChannelConfiguration(name: name, address: address)
                        if library.lastError == nil { dismiss() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(address.isEmpty)
                }
            }
            .navigationTitle("打开媒体")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .libraryErrorAlert(library)
        }
    }
}

#endif

extension Color {
    static var roveAccent: Color { RoveAccentTheme.selected.color }
    static let roveIndigo = Color(red: 0.36, green: 0.25, blue: 0.90)
    static let roveInk = Color(red: 0.06, green: 0.09, blue: 0.11)
    static let roveMist = Color(red: 0.91, green: 0.96, blue: 0.97)
    static let roveBlue = Color(red: 0.16, green: 0.48, blue: 0.84)
    static let roveGreen = Color(red: 0.18, green: 0.62, blue: 0.39)
    static let roveViolet = Color(red: 0.48, green: 0.35, blue: 0.78)
    static let roveAmber = Color(red: 0.91, green: 0.59, blue: 0.12)

    // Compatibility aliases for shared capability views that still reference
    // the former shell palette internally.
    static let mediaDeckCyan = roveAccent
    static let mediaDeckPink = Color(red: 0.85, green: 0.24, blue: 0.48)
    static let mediaDeckGreen = roveGreen
    static let mediaDeckAmber = roveAmber
    static let mediaDeckInk = roveInk
    static let mediaDeckCanvas = Color(uiColor: .systemGroupedBackground)
    static let mediaDeckSurface = Color(uiColor: .secondarySystemGroupedBackground)
}
