import Foundation
import UIKit

#if DJHUB_METADATA_ONLY
@MainActor
enum ChannelLogoProvider {
    static func image(for channelName: String, prefersLight: Bool = true) -> UIImage? { nil }
    static func image(for channel: Channel, prefersLight: Bool = true) -> UIImage? { nil }
}

@MainActor
final class ChannelArtworkLoader {
    static let shared = ChannelArtworkLoader()
    private let cache = NSCache<NSString, UIImage>()
    private init() {}
    func image(for channel: Channel, maxWidth: Int = 720) async -> UIImage? { await load(channel, maxWidth) }
    func landscapeImage(for channel: Channel, maxWidth: Int = 720) async -> UIImage? { await load(channel, maxWidth) }
    func primaryImage(for channel: Channel, maxWidth: Int = 1200) async -> UIImage? { await load(channel, maxWidth) }
    func cachedLandscapeImage(for channel: Channel, maxWidth: Int = 720) -> UIImage? { cache.object(forKey: key(channel, maxWidth) as NSString) }
    func cachedPrimaryImage(for channel: Channel, maxWidth: Int = 720) -> UIImage? { cachedLandscapeImage(for: channel, maxWidth: maxWidth) }
    func cachedDetailPreview(for channel: Channel) async -> UIImage? { cachedPrimaryImage(for: channel, maxWidth: 1200) }
    func embyImage(configurationID: UUID, itemID: String, maxWidth: Int = 640, cacheTag: String? = nil) async -> UIImage? { nil }
    func cachedEmbyImage(configurationID: UUID, itemID: String, maxWidth: Int = 640, cacheTag: String? = nil) -> UIImage? { nil }
    private func load(_ channel: Channel, _ maxWidth: Int) async -> UIImage? {
        let cacheKey = key(channel, maxWidth)
        if let value = cache.object(forKey: cacheKey as NSString) { return value }
        guard let url = channel.logoURL,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let value = UIImage(data: data) else { return nil }
        cache.setObject(value, forKey: cacheKey as NSString)
        return value
    }
    private func key(_ channel: Channel, _ maxWidth: Int) -> String { "\(channel.id)|\(maxWidth)|\(channel.logoURL?.absoluteString ?? "")" }
}
#else
/// 将播放列表中的频道名称映射到应用内置台标。
/// 资源文件保留 APTV 中的原始名称，运行时忽略高清、HD、空格等差异。
@MainActor
enum ChannelLogoProvider {
    private struct Variants {
        var regular: URL?
        var light: URL?
    }

    private static let index: [String: Variants] = buildIndex()
    private static let imageCache = NSCache<NSString, UIImage>()
    private static var resolvedImageCache: [String: UIImage] = [:]
    private static var unresolvedKeys = Set<String>()

    static func image(for channelName: String, prefersLight: Bool = true) -> UIImage? {
        image(forIdentifiers: [channelName], prefersLight: prefersLight)
    }

    /// 播放列表的显示名称可能被用户修改，因此同时使用 tvg-name 和 tvg-id 匹配。
    static func image(for channel: Channel, prefersLight: Bool = true) -> UIImage? {
        image(
            forIdentifiers: [channel.name, channel.tvgName, channel.tvgID].compactMap { $0 },
            prefersLight: prefersLight
        )
    }

    private static func image(forIdentifiers identifiers: [String], prefersLight: Bool) -> UIImage? {
        let lookupKey = "\(prefersLight ? "light" : "regular")|\(identifiers.joined(separator: "|"))"
        if let cached = resolvedImageCache[lookupKey] { return cached }
        if unresolvedKeys.contains(lookupKey) { return nil }

        // 先尝试所有标识的精确匹配，避免显示名称的模糊结果盖过 tvg-name/tvg-id。
        for identifier in identifiers {
            for key in candidateKeys(for: identifier) {
                if let image = image(forKey: key, prefersLight: prefersLight) {
                    resolvedImageCache[lookupKey] = image
                    return image
                }
            }
        }

        // 少量地方频道的源名称会比台标名称多“新闻综合”等字样。
        for identifier in identifiers {
            let key = normalized(identifier, dropping4K: true)
            let closest = index.keys
                .filter { min($0.count, key.count) >= 4 && ($0.contains(key) || key.contains($0)) }
                .min { abs($0.count - key.count) < abs($1.count - key.count) }
            if let closest, let image = image(forKey: closest, prefersLight: prefersLight) {
                resolvedImageCache[lookupKey] = image
                return image
            }
        }
        unresolvedKeys.insert(lookupKey)
        return nil
    }

    private static func image(forKey key: String, prefersLight: Bool) -> UIImage? {
        guard let variants = index[key] else { return nil }
        let url = prefersLight
            ? (variants.light ?? variants.regular)
            : (variants.regular ?? variants.light)
        guard let url else { return nil }

        let cacheKey = url.path as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache.setObject(image, forKey: cacheKey)
        return image
    }

    private static func buildIndex() -> [String: Variants] {
        let rootURLs = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        let folderURLs = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "ChannelLogos") ?? []
        let aptvURLs = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "APTVChannelLogos") ?? []
        let urls = Array(Set(rootURLs + folderURLs + aptvURLs)).filter { url in
            let name = url.deletingPathExtension().lastPathComponent
            return name.hasPrefix("n_")
                || name.localizedCaseInsensitiveContains("CCTV")
                || name.localizedCaseInsensitiveContains("NEWTV")
                || url.path.contains("ChannelLogos")
        }

        var result: [String: Variants] = [:]
        for url in urls {
            var resourceName = url.deletingPathExtension().lastPathComponent
            if resourceName.hasPrefix("n_") {
                resourceName.removeFirst(2)
            }
            let isLight = resourceName.lowercased().hasSuffix("-light")
            resourceName = resourceName.replacingOccurrences(
                of: #"-(light|dark)$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )

            let key = normalized(resourceName, dropping4K: false)
            var variants = result[key] ?? Variants()
            if isLight {
                variants.light = url
            } else if variants.regular == nil {
                variants.regular = url
            }
            result[key] = variants
        }
        return result
    }

    private static func candidateKeys(for channelName: String) -> [String] {
        let exact = normalized(channelName, dropping4K: false)
        let without4K = normalized(channelName, dropping4K: true)
        return exact == without4K ? [exact] : [exact, without4K]
    }

    private static func normalized(_ rawValue: String, dropping4K: Bool) -> String {
        var value = rawValue.precomposedStringWithCompatibilityMapping.uppercased()
        value = value.replacingOccurrences(of: #"^N_"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(
            of: #"-(LIGHT|DARK)$"#,
            with: "",
            options: .regularExpression
        )

        let themedChannels: [(source: String, logo: String)] = [
            ("世界地理", "世界地理"), ("兵器科技", "兵器科技"),
            ("央视台球", "央视台球"), ("文化精品", "文化精品"),
            ("怀旧剧场", "怀旧剧场"), ("电视指南", "电视指南"),
            ("第一剧场", "第一剧场"), ("风云剧场", "风云剧场"),
            ("风云足球", "风云足球"), ("风云音乐", "风云音乐"),
            ("高尔夫网球", "央视高网")
        ]
        if let themed = themedChannels.first(where: { value.contains($0.source) }) {
            return themed.logo
        }

        if value.contains("CCTV"),
           let regex = try? NSRegularExpression(pattern: #"CCTV[\s_-]*0*(\d{1,2})(\+)?"#),
           let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let numberRange = Range(match.range(at: 1), in: value) {
            let number = String(value[numberRange])
            let plus = Range(match.range(at: 2), in: value).map { String(value[$0]) } ?? ""
            if number == "4", value.contains("4K") { return "CCTV4K" }
            if number == "8", value.contains("8K") { return "CCTV8K" }
            return "CCTV\(number)\(plus)"
        }

        let aliases = [
            "北京卡酷少儿": "KAKU少儿",
            "卡酷少儿": "KAKU少儿",
            "凤凰卫视中文台": "凤凰中文",
            "凤凰卫视资讯台": "凤凰资讯",
            "重庆卫视": "重庆",
            "熊猫频道": "熊猫",
            "南通新闻综合": "江苏南通"
        ]
        if let alias = aliases.first(where: { value.contains($0.key.uppercased()) }) {
            value = alias.value.uppercased()
        }

        var removable = [
            "超高清", "高清", "超清", "标清", "蓝光", "广播电视总台",
            "电视台", "频道", "IPV4", "IPV6", "FHD", "UHD", "HD"
        ]
        if dropping4K { removable.append("4K") }
        for token in removable {
            value = value.replacingOccurrences(of: token, with: "")
        }
        return value.replacingOccurrences(
            of: #"[\s\-_·•:：()（）\[\]【】“”\"'、/]+"#,
            with: "",
            options: .regularExpression
        )
    }
}

/// Loads subscription logos plus Jellyfin/Emby posters without persisting
/// private media-server tokens in Channel.logoURL. Authentication is resolved
/// from the keychain only for the duration of the image request.
@MainActor
final class ChannelArtworkLoader {
    static let shared = ChannelArtworkLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private var cacheKeysByConfigurationID: [UUID: Set<String>] = [:]
    private let networkSession = URLSession(configuration: ProxyNetworkConfiguration.ephemeral())

    private init() {
        cache.countLimit = 160
        cache.totalCostLimit = 64 * 1_024 * 1_024
    }

    func image(for channel: Channel, maxWidth: Int = 720) async -> UIImage? {
        let key = cacheKey(for: channel, maxWidth: maxWidth)
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let task = inFlight[key] { return await task.value }
        if let diskImage = await diskImage(forKey: key) {
            store(diskImage, forKey: key)
            return diskImage
        }

        let task = Task<UIImage?, Never> {
            let data: Data?
            if channel.isMediaServerItem {
                do {
                    data = try await ChannelLibrary.shared.mediaServerArtworkData(
                        for: channel,
                        maxWidth: maxWidth
                    )
                } catch {
#if DEBUG
                    print("RoveArtwork primary failed for \(channel.name): \(error.localizedDescription)")
#endif
                    data = nil
                }
            } else if let logoURL = channel.logoURL {
                data = try? await networkSession.data(from: logoURL).0
            } else {
                data = nil
            }
            guard let data else { return nil }
            let diskURL = artworkDiskURL(forKey: key)
            let decoded = await Task.detached(priority: .utility) {
                if let diskURL {
                    try? FileManager.default.createDirectory(
                        at: diskURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try? data.write(to: diskURL, options: .atomic)
                }
                let image = UIImage(data: data)
                return UncheckedImage(value: image?.preparingForDisplay() ?? image)
            }.value
            return decoded.value
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            store(image, forKey: key)
        }
        return image
    }

    /// Emby/Jellyfin landscape cards prefer a true backdrop, then a thumb.
    /// Servers that expose neither keep the existing Primary artwork as a
    /// cropped fallback so the card geometry remains stable.
    func landscapeImage(for channel: Channel, maxWidth: Int = 720) async -> UIImage? {
        guard let key = landscapeCacheKey(for: channel, maxWidth: maxWidth) else {
            if let image = await image(for: channel, maxWidth: maxWidth) { return image }
            return await seriesArtworkFallback(for: channel, maxWidth: maxWidth)
        }
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let task = inFlight[key] {
            if let landscapeImage = await task.value { return landscapeImage }
            if let image = await image(for: channel, maxWidth: maxWidth) { return image }
            return await seriesArtworkFallback(for: channel, maxWidth: maxWidth)
        }
        if let diskImage = await diskImage(forKey: key) {
            store(diskImage, forKey: key)
            return diskImage
        }

        let task = Task<UIImage?, Never> {
            var data: Data?
            for imageType in [MediaServerArtworkType.backdrop, .thumb] {
                do {
                    data = try await ChannelLibrary.shared.mediaServerArtworkData(
                        for: channel,
                        maxWidth: maxWidth,
                        imageType: imageType
                    )
                    if data != nil { break }
                } catch {
#if DEBUG
                    print("RoveArtwork \(imageType.rawValue) failed for \(channel.name): \(error.localizedDescription)")
#endif
                }
            }
            guard let data else { return nil }
            let diskURL = artworkDiskURL(forKey: key)
            let decoded = await Task.detached(priority: .utility) {
                if let diskURL {
                    try? FileManager.default.createDirectory(
                        at: diskURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try? data.write(to: diskURL, options: .atomic)
                }
                let image = UIImage(data: data)
                return UncheckedImage(value: image?.preparingForDisplay() ?? image)
            }.value
            return decoded.value
        }
        inFlight[key] = task
        let landscapeImage = await task.value
        inFlight[key] = nil
        if let landscapeImage {
            store(landscapeImage, forKey: key)
            return landscapeImage
        }
        if let image = await image(for: channel, maxWidth: maxWidth) { return image }
        return await seriesArtworkFallback(for: channel, maxWidth: maxWidth)
    }

    private func seriesArtworkFallback(for channel: Channel, maxWidth: Int) async -> UIImage? {
        guard channel.isMediaServerEpisode,
              let seriesID = channel.mediaServerSeriesID,
              !seriesID.isEmpty else { return nil }

        var series = channel
        series.id = UUID()
        series.name = channel.group
        series.tvgID = seriesID
        series.mediaServerItemType = "Series"
        series.mediaServerSeriesID = nil
        switch channel.resolver {
        case .legacyLibraryA(let configurationID, _):
            series.resolver = .legacyLibraryA(configurationID: configurationID, itemID: seriesID)
        case .movieClaw(let configurationID, _):
            series.resolver = .movieClaw(configurationID: configurationID, itemID: seriesID)
        case .legacyLibraryB(let configurationID, _):
            series.resolver = .legacyLibraryB(configurationID: configurationID, itemID: seriesID)
        case .legacyLibraryC(let configurationID, _):
            series.resolver = .legacyLibraryC(configurationID: configurationID, itemID: seriesID)
        case .legacyLibraryD(let configurationID, _):
            series.resolver = .legacyLibraryD(configurationID: configurationID, itemID: seriesID)
        default:
            return nil
        }
        return await landscapeImage(for: series, maxWidth: maxWidth)
    }

    /// Detail pages use the server's Primary image before landscape fallbacks.
    func primaryImage(for channel: Channel, maxWidth: Int = 1200) async -> UIImage? {
        let key = "primary-detail|\(cacheKey(for: channel, maxWidth: maxWidth))"
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let disk = await diskImage(forKey: key) {
            store(disk, forKey: key)
            return disk
        }
        guard let data = try? await ChannelLibrary.shared.mediaServerArtworkData(
            for: channel,
            maxWidth: maxWidth,
            imageType: .primary
        ) else { return await image(for: channel, maxWidth: maxWidth) }
        let decoded = await Task.detached(priority: .utility) {
            UncheckedImage(value: UIImage(data: data)?.preparingForDisplay())
        }.value
        if let image = decoded.value {
            store(image, forKey: key)
            return image
        }
        return await image(for: channel, maxWidth: maxWidth)
    }

    func cachedLandscapeImage(for channel: Channel, maxWidth: Int = 720) -> UIImage? {
        if let key = landscapeCacheKey(for: channel, maxWidth: maxWidth),
           let image = cache.object(forKey: key as NSString) {
            return image
        }
        let primaryKey = cacheKey(for: channel, maxWidth: maxWidth)
        return cache.object(forKey: primaryKey as NSString)
    }

    func cachedPrimaryImage(for channel: Channel, maxWidth: Int = 720) -> UIImage? {
        let primaryKey = cacheKey(for: channel, maxWidth: maxWidth)
        return cache.object(forKey: "primary-detail|\(primaryKey)" as NSString)
            ?? cache.object(forKey: primaryKey as NSString)
    }

    /// Reuse a decoded Primary poster as the detail hero's first frame. A
    /// cached landscape card must not briefly replace the portrait poster.
    /// This method never starts a network request.
    func cachedDetailPreview(for channel: Channel) async -> UIImage? {
        var keys: [String] = []
        for width in [1200, 900, 720, 600] {
            let primaryKey = cacheKey(for: channel, maxWidth: width)
            keys.append("primary-detail|\(primaryKey)")
            keys.append(primaryKey)
        }

        var visited = Set<String>()
        let uniqueKeys = keys.filter { visited.insert($0).inserted }
        for key in uniqueKeys {
            if let image = cache.object(forKey: key as NSString) {
                return image
            }
        }
        for key in uniqueKeys {
            if let image = await diskImage(forKey: key) {
                store(image, forKey: key)
                return image
            }
        }
        return nil
    }

    func embyImage(
        configurationID: UUID,
        itemID: String,
        maxWidth: Int = 640,
        cacheTag: String? = nil
    ) async -> UIImage? {
        let key = embyCacheKey(
            configurationID: configurationID,
            itemID: itemID,
            maxWidth: maxWidth,
            cacheTag: cacheTag
        )
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if let task = inFlight[key] { return await task.value }
        if let diskImage = await diskImage(forKey: key) {
            store(diskImage, forKey: key)
            return diskImage
        }

        let legacyKey = embyCacheKey(
            configurationID: configurationID,
            itemID: itemID,
            maxWidth: maxWidth,
            cacheTag: nil
        )
        if key != legacyKey, let legacyImage = await diskImage(forKey: legacyKey) {
            migrateDiskImage(fromKey: legacyKey, toKey: key)
            store(legacyImage, forKey: key)
            return legacyImage
        }

        let task = Task<UIImage?, Never> {
            guard let data = try? await ChannelLibrary.shared.loadEmbyArtwork(
                configurationID: configurationID,
                itemID: itemID,
                maxWidth: maxWidth
            ) else { return nil }
            let diskURL = artworkDiskURL(forKey: key)
            let decoded = await Task.detached(priority: .utility) {
                if let diskURL {
                    try? FileManager.default.createDirectory(
                        at: diskURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try? data.write(to: diskURL, options: .atomic)
                }
                let image = UIImage(data: data)
                return UncheckedImage(value: image?.preparingForDisplay() ?? image)
            }.value
            return decoded.value
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            store(image, forKey: key)
        }
        return image
    }

    func cachedEmbyImage(
        configurationID: UUID,
        itemID: String,
        maxWidth: Int = 640,
        cacheTag: String? = nil
    ) -> UIImage? {
        let key = embyCacheKey(
            configurationID: configurationID,
            itemID: itemID,
            maxWidth: maxWidth,
            cacheTag: cacheTag
        )
        if let cached = cache.object(forKey: key as NSString) { return cached }
        // Disk reads and image decompression belong to the async loader. This
        // method is called from SwiftUI initializers, where synchronous file
        // I/O would block home-page layout and scrolling.
        return nil
    }

    private func store(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
        if let configurationID = configurationID(fromCacheKey: key) {
            cacheKeysByConfigurationID[configurationID, default: []].insert(key)
        }
    }

    func invalidate(configurationID: UUID) async {
        let identifier = configurationID.uuidString.lowercased()
        for key in cacheKeysByConfigurationID.removeValue(forKey: configurationID) ?? [] {
            cache.removeObject(forKey: key as NSString)
        }
        let matchingInFlightKeys = inFlight.keys.filter {
            $0.lowercased().contains(identifier)
        }
        for key in matchingInFlightKeys {
            inFlight[key]?.cancel()
            inFlight[key] = nil
        }

        let artworkDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("TuboEmbyArtwork", isDirectory: true)
        await Task.detached(priority: .utility) {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: artworkDirectory,
                includingPropertiesForKeys: nil
            ) else { return }
            for file in files where file.lastPathComponent.lowercased().contains(identifier) {
                try? FileManager.default.removeItem(at: file)
            }
        }.value
    }

    private func configurationID(fromCacheKey key: String) -> UUID? {
        key.split(separator: "|").compactMap { UUID(uuidString: String($0)) }.first
    }

    private func diskImage(forKey key: String) async -> UIImage? {
        guard let url = artworkDiskURL(forKey: key) else { return nil }
        let decoded = await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url) else {
                return UncheckedImage(value: nil)
            }
            let image = UIImage(data: data)
            return UncheckedImage(value: image?.preparingForDisplay() ?? image)
        }.value
        return decoded.value
    }

    private func artworkDiskURL(forKey key: String) -> URL? {
        guard key.hasPrefix("legacyLibraryB|")
                || key.hasPrefix("legacyLibraryA|")
                || key.hasPrefix("feiniu-video|") else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let fileName = key.unicodeScalars.map {
            allowed.contains($0) ? Character(String($0)) : "_"
        }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches
            .appendingPathComponent("TuboEmbyArtwork", isDirectory: true)
            .appendingPathComponent(String(fileName) + ".image", isDirectory: false)
    }

    private func migrateDiskImage(fromKey sourceKey: String, toKey destinationKey: String) {
        guard let sourceURL = artworkDiskURL(forKey: sourceKey),
              let destinationURL = artworkDiskURL(forKey: destinationKey),
              FileManager.default.fileExists(atPath: sourceURL.path),
              !FileManager.default.fileExists(atPath: destinationURL.path) else { return }
        try? FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: sourceURL)
        }
    }

    private func embyCacheKey(
        configurationID: UUID,
        itemID: String,
        maxWidth: Int,
        cacheTag: String?
    ) -> String {
        let base = "legacyLibraryB|\(configurationID.uuidString)|\(itemID)|\(maxWidth)"
        guard let cacheTag, !cacheTag.isEmpty else { return base }
        var fingerprint: UInt64 = 14_695_981_039_346_656_037
        for byte in cacheTag.utf8 {
            fingerprint ^= UInt64(byte)
            fingerprint &*= 1_099_511_628_211
        }
        return "\(base)|\(String(fingerprint, radix: 16))"
    }

    private func cacheKey(for channel: Channel, maxWidth: Int) -> String {
        if case .legacyLibraryA(let configurationID, let itemID) = channel.resolver {
            return "legacyLibraryA|\(configurationID.uuidString)|\(itemID)|\(maxWidth)"
        }
        if case .movieClaw(let configurationID, let itemID) = channel.resolver {
            return "movieclaw|\(configurationID.uuidString)|\(itemID)|\(maxWidth)"
        }
        if case .legacyLibraryB(let configurationID, let itemID) = channel.resolver {
            return "legacyLibraryB|\(configurationID.uuidString)|\(itemID)|\(maxWidth)"
        }
        if case .legacyLibraryC(let configurationID, let itemID) = channel.resolver {
            return "feiniu-video|\(configurationID.uuidString)|\(itemID)|\(maxWidth)"
        }
        if case .legacyLibraryD(let configurationID, let itemID) = channel.resolver {
            return "legacyLibraryD|\(configurationID.uuidString)|\(itemID)|\(maxWidth)"
        }
        return "remote|\(channel.logoURL?.absoluteString ?? channel.streamURL.absoluteString)|\(maxWidth)"
    }

    private func landscapeCacheKey(for channel: Channel, maxWidth: Int) -> String? {
        if case .legacyLibraryA(let configurationID, let itemID) = channel.resolver {
            return "legacyLibraryA|landscape-v2|\(configurationID.uuidString)|\(itemID)|\(maxWidth)"
        }
        if case .movieClaw(let configurationID, let itemID) = channel.resolver {
            return "movieclaw|landscape-v2|\(configurationID.uuidString)|\(itemID)|\(maxWidth)"
        }
        if case .legacyLibraryB(let configurationID, let itemID) = channel.resolver {
            return "legacyLibraryB|landscape-v2|\(configurationID.uuidString)|\(itemID)|\(maxWidth)"
        }
        if case .legacyLibraryD(let configurationID, let itemID) = channel.resolver {
            return "legacyLibraryD|landscape-v2|\(configurationID.uuidString)|\(itemID)|\(maxWidth)"
        }
        return nil
    }
}

private struct UncheckedImage: @unchecked Sendable {
    let value: UIImage?
}
#endif
