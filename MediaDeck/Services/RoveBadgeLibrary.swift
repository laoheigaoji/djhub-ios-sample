import Foundation
import CryptoKit
import SwiftUI
import UIKit
import WebKit

struct RoveBadgeRule: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let groupID: String
    let name: String
    let pattern: String
    let imageURL: String
    let isEnabled: Bool
}

struct RoveBadgePackage: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let source: String
    let importedAt: Date
    let rules: [RoveBadgeRule]

    var isRemote: Bool {
        source.hasPrefix("https://") || source.hasPrefix("http://")
    }
}

enum RoveBadgeLibraryError: LocalizedError {
    case invalidAddress
    case invalidResponse
    case unsupportedFormat
    case noValidRules

    var errorDescription: String? {
        switch self {
        case .invalidAddress: "请输入完整的 HTTP 或 HTTPS JSON 地址。"
        case .invalidResponse: "服务器没有返回可用的 JSON 数据。"
        case .unsupportedFormat: "无法识别此 Badge JSON 的规则结构。"
        case .noValidRules: "没有找到同时包含有效正则表达式和图片地址的规则。"
        }
    }
}

enum RoveBadgePatternMatcher {
    // Badge libraries commonly use ICU features such as inline flags and
    // look-behind. NSRegularExpression accepts those libraries while Swift's
    // native Regex parser rejects otherwise valid rules.
    private static let maximumPatternLength = 8_192

    static func expression(
        for pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression? {
        guard !pattern.isEmpty, pattern.utf8.count <= maximumPatternLength else { return nil }
        return try? NSRegularExpression(pattern: pattern, options: options)
    }

    static func matches(
        _ pattern: String,
        in text: String,
        caseInsensitive: Bool = false
    ) -> Bool {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let expression = expression(for: pattern, options: options) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }
}

@MainActor
final class RoveBadgeLibrary: ObservableObject {
    static let shared = RoveBadgeLibrary()

    private static let packagesDefaultsKey = "rove.badges.packages.v1"
    private static let selectedPackageDefaultsKey = "rove.badges.selected-package.v1"
    private static let defaultPackageMigrationKey = "rove.badges.default-liangyou.v1"
    private static let defaultPackageAssetName = "LiangYouBadges"
    private static let defaultPackageName = "良友媒体徽章"
    private static let defaultPackageSource = "https://raw.githubusercontent.com/MaddestAlistar/liangyou-appletv-badges/main/Badge%20LiangYou%20Ver.OopsPlayer.BF3.json"
    private static let defaultPackageID = UUID(uuidString: "4EBD6EA1-5FD0-4B83-9B33-01A2D738D12A")!
    static let adaptiveDefaultsKey = "rove.badges.monochrome-adaptive.v1"
    private var compiledPatterns: [String: NSRegularExpression] = [:]
    private var invalidPatterns = Set<String>()

    @Published private(set) var packages: [RoveBadgePackage]
    @Published private(set) var selectedPackageID: UUID?
    @Published var monochromeAdaptive: Bool {
        didSet {
            UserDefaults.standard.set(monochromeAdaptive, forKey: Self.adaptiveDefaultsKey)
        }
    }

    var selectedPackage: RoveBadgePackage? {
        guard let selectedPackageID else { return nil }
        return packages.first { $0.id == selectedPackageID }
    }

    private init() {
        let defaults = UserDefaults.standard
        var shouldPersistSeed = false
        if let data = UserDefaults.standard.data(forKey: Self.packagesDefaultsKey),
           let decoded = try? JSONDecoder().decode([RoveBadgePackage].self, from: data) {
            packages = decoded
        } else {
            packages = []
        }
        if UserDefaults.standard.object(forKey: Self.adaptiveDefaultsKey) == nil {
            monochromeAdaptive = true
        } else {
            monochromeAdaptive = UserDefaults.standard.bool(forKey: Self.adaptiveDefaultsKey)
        }
        selectedPackageID = nil
        if !defaults.bool(forKey: Self.defaultPackageMigrationKey) {
            if packages.isEmpty, let bundledPackage = Self.bundledDefaultPackage() {
                packages = [bundledPackage]
                shouldPersistSeed = true
            }
            defaults.set(true, forKey: Self.defaultPackageMigrationKey)
        }
        if let rawValue = UserDefaults.standard.string(forKey: Self.selectedPackageDefaultsKey),
           let storedID = UUID(uuidString: rawValue),
           packages.contains(where: { $0.id == storedID }) {
            selectedPackageID = storedID
        } else {
            selectedPackageID = packages.first?.id
        }
        if shouldPersistSeed {
            persist()
        }
    }

    func importRemote(address: String) async throws -> RoveBadgePackage {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            throw RoveBadgeLibraryError.invalidAddress
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("RovePlayer/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !data.isEmpty else {
            throw RoveBadgeLibraryError.invalidResponse
        }
        let decoded = try Self.decodePackage(
            data: data,
            source: trimmed,
            fallbackName: trimmed == Self.defaultPackageSource
                ? Self.defaultPackageName
                : url.deletingPathExtension().lastPathComponent,
            baseURL: url.deletingLastPathComponent()
        )
        return saveReplacingSource(decoded)
    }

    func importLocal(fileURL: URL) async throws -> RoveBadgePackage {
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: fileURL)
        let source = "本地文件 · \(fileURL.lastPathComponent)"
        let decoded = try Self.decodePackage(
            data: data,
            source: source,
            fallbackName: fileURL.deletingPathExtension().lastPathComponent,
            baseURL: fileURL.deletingLastPathComponent()
        )
        return saveReplacingSource(decoded)
    }

    func refresh(_ package: RoveBadgePackage) async throws -> RoveBadgePackage {
        guard package.isRemote else { return package }
        let refreshed = try await importRemote(address: package.source)
        if refreshed.id != package.id,
           let index = packages.firstIndex(where: { $0.id == refreshed.id }) {
            packages[index] = RoveBadgePackage(
                id: package.id,
                name: refreshed.name,
                source: refreshed.source,
                importedAt: refreshed.importedAt,
                rules: refreshed.rules
            )
            persist()
            return packages[index]
        }
        return refreshed
    }

    func remove(_ package: RoveBadgePackage) {
        packages.removeAll { $0.id == package.id }
        if selectedPackageID == package.id {
            selectedPackageID = packages.first?.id
        }
        persist()
    }

    func select(_ package: RoveBadgePackage) {
        guard packages.contains(where: { $0.id == package.id }) else { return }
        selectedPackageID = package.id
        persistSelection()
    }

    func matchingRules(in text: String, limit: Int = 10) -> [RoveBadgeRule] {
        guard !text.isEmpty else { return [] }
        guard let selectedPackage else { return [] }
        var result: [RoveBadgeRule] = []
        var matchedGroups = Set<String>()
        for rule in selectedPackage.rules where rule.isEnabled {
            let group = rule.groupID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !group.isEmpty, matchedGroups.contains(group) { continue }
            guard let expression = compiledExpression(for: rule.pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard expression.firstMatch(in: text, range: range) != nil else { continue }
            result.append(rule)
            if !group.isEmpty { matchedGroups.insert(group) }
            if result.count == limit { break }
        }
        return result
    }

    private func compiledExpression(for pattern: String) -> NSRegularExpression? {
        if let expression = compiledPatterns[pattern] { return expression }
        guard !invalidPatterns.contains(pattern),
              let expression = RoveBadgePatternMatcher.expression(for: pattern) else {
            invalidPatterns.insert(pattern)
            return nil
        }
        compiledPatterns[pattern] = expression
        return expression
    }

    private static func bundledDefaultPackage() -> RoveBadgePackage? {
        guard let data = NSDataAsset(name: defaultPackageAssetName)?.data,
              let sourceURL = URL(string: defaultPackageSource),
              let decoded = try? decodePackage(
                data: data,
                source: defaultPackageSource,
                fallbackName: defaultPackageName,
                baseURL: sourceURL.deletingLastPathComponent()
              ) else { return nil }
        return RoveBadgePackage(
            id: defaultPackageID,
            name: defaultPackageName,
            source: defaultPackageSource,
            importedAt: Date(),
            rules: decoded.rules
        )
    }

    private func saveReplacingSource(_ package: RoveBadgePackage) -> RoveBadgePackage {
        if let index = packages.firstIndex(where: { $0.source == package.source }) {
            let replacement = RoveBadgePackage(
                id: packages[index].id,
                name: package.name,
                source: package.source,
                importedAt: package.importedAt,
                rules: package.rules
            )
            packages[index] = replacement
            persist()
            return replacement
        }
        packages.append(package)
        if selectedPackageID == nil {
            selectedPackageID = package.id
        }
        persist()
        return package
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(packages) else { return }
        UserDefaults.standard.set(data, forKey: Self.packagesDefaultsKey)
        persistSelection()
    }

    private func persistSelection() {
        if let selectedPackageID {
            UserDefaults.standard.set(selectedPackageID.uuidString, forKey: Self.selectedPackageDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedPackageDefaultsKey)
        }
    }

    private static func decodePackage(
        data: Data,
        source: String,
        fallbackName: String,
        baseURL: URL?
    ) throws -> RoveBadgePackage {
        let root = try JSONSerialization.jsonObject(with: data)
        let packageName = ((root as? [String: Any])?["name"] as? String)
            ?? ((root as? [String: Any])?["title"] as? String)
            ?? fallbackName
        let candidateArrays = collectRuleArrays(from: root)
        guard !candidateArrays.isEmpty else { throw RoveBadgeLibraryError.unsupportedFormat }

        let parsedCandidates = candidateArrays.map { entries in
            entries.enumerated().compactMap { index, item in
                parseRule(item, index: index, baseURL: baseURL)
            }
        }
        guard let rules = parsedCandidates.max(by: { $0.count < $1.count }), !rules.isEmpty else {
            throw RoveBadgeLibraryError.noValidRules
        }
        return RoveBadgePackage(
            id: UUID(),
            name: packageName.isEmpty ? "Badge 规则库" : packageName,
            source: source,
            importedAt: Date(),
            rules: rules
        )
    }

    private static func collectRuleArrays(from value: Any, depth: Int = 0) -> [[[String: Any]]] {
        guard depth <= 4 else { return [] }
        if let array = value as? [[String: Any]] {
            var result = [array]
            for item in array {
                result.append(contentsOf: collectRuleArrays(from: item, depth: depth + 1))
            }
            return result
        }
        if let dictionary = value as? [String: Any] {
            let preferredKeys = ["filters", "rules", "badges", "items", "data", "presets"]
            var result: [[[String: Any]]] = []
            for key in preferredKeys where dictionary[key] != nil {
                result.append(contentsOf: collectRuleArrays(from: dictionary[key]!, depth: depth + 1))
            }
            for (key, nested) in dictionary where !preferredKeys.contains(key) {
                result.append(contentsOf: collectRuleArrays(from: nested, depth: depth + 1))
            }
            return result
        }
        return []
    }

    private static func parseRule(
        _ item: [String: Any],
        index: Int,
        baseURL: URL?
    ) -> RoveBadgeRule? {
        let pattern = stringValue(in: item, keys: ["pattern", "regex", "regularExpression", "match"])
            ?? stringArrayValue(in: item, keys: ["patterns", "matches"])?.map { "(?:\($0))" }.joined(separator: "|")
        guard let pattern, !pattern.isEmpty,
              RoveBadgePatternMatcher.expression(for: pattern) != nil,
              let rawImage = stringValue(
                in: item,
                keys: ["imageURL", "imageUrl", "image_url", "iconURL", "iconUrl", "icon", "image", "logo", "url"]
              ),
              let imageURL = resolvedImageURL(rawImage, baseURL: baseURL) else { return nil }

        let name = stringValue(in: item, keys: ["name", "title", "label", "id"]) ?? "Badge \(index + 1)"
        let id = stringValue(in: item, keys: ["id", "identifier"]) ?? "\(name)-\(index)"
        let group = stringValue(in: item, keys: ["groupId", "groupID", "group", "category"]) ?? id
        let enabled = boolValue(in: item, keys: ["isEnabled", "enabled", "active"]) ?? true
        return RoveBadgeRule(
            id: "\(id)-\(index)",
            groupID: group,
            name: name,
            pattern: pattern,
            imageURL: imageURL,
            isEnabled: enabled
        )
    }

    private static func stringValue(in item: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = item[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func stringArrayValue(in item: [String: Any], keys: [String]) -> [String]? {
        for key in keys {
            if let values = item[key] as? [String], !values.isEmpty { return values }
        }
        return nil
    }

    private static func boolValue(in item: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = item[key] as? Bool { return value }
            if let value = item[key] as? NSNumber { return value.boolValue }
            if let value = item[key] as? String {
                if ["true", "yes", "1"].contains(value.lowercased()) { return true }
                if ["false", "no", "0"].contains(value.lowercased()) { return false }
            }
        }
        return nil
    }

    private static func resolvedImageURL(_ rawValue: String, baseURL: URL?) -> String? {
        if let url = URL(string: rawValue),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "data"].contains(scheme) {
            return url.absoluteString
        }
        guard let baseURL, let url = URL(string: rawValue, relativeTo: baseURL)?.absoluteURL else { return nil }
        if url.isFileURL, let data = try? Data(contentsOf: url), !data.isEmpty {
            let mimeType = switch url.pathExtension.lowercased() {
            case "svg": "image/svg+xml"
            case "jpg", "jpeg": "image/jpeg"
            case "gif": "image/gif"
            case "webp": "image/webp"
            default: "image/png"
            }
            return "data:\(mimeType);base64,\(data.base64EncodedString())"
        }
        return url.absoluteString
    }
}

/// Persists remote badge artwork outside UserDefaults so every detail page and
/// every resource row can reuse the same downloaded image after relaunch.
actor RoveBadgeAssetCache {
    static let shared = RoveBadgeAssetCache()

    private let directory: URL
    private var memory: [String: String] = [:]

    private init() {
        directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("RoveBadgeAssets", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func cachedImageSource(for source: String) async -> String {
        guard let url = URL(string: source),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return source
        }
        if let cached = memory[source] { return cached }

        let fileURL = directory.appendingPathComponent(cacheKey(for: source))
        if let data = try? Data(contentsOf: fileURL), !data.isEmpty {
            let result = dataURI(data: data, source: source)
            memory[source] = result
            return result
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("RovePlayer/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !data.isEmpty,
              data.count <= 12 * 1024 * 1024 else {
            return source
        }
        try? data.write(to: fileURL, options: .atomic)
        let result = dataURI(data: data, source: source)
        memory[source] = result
        return result
    }

    private func cacheKey(for source: String) -> String {
        SHA256.hash(data: Data(source.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
            + ".asset"
    }

    private func dataURI(data: Data, source: String) -> String {
        let path = URL(string: source)?.path.lowercased() ?? source.lowercased()
        let mimeType: String
        switch URL(fileURLWithPath: path).pathExtension {
        case "svg": mimeType = "image/svg+xml"
        case "jpg", "jpeg": mimeType = "image/jpeg"
        case "gif": mimeType = "image/gif"
        case "webp": mimeType = "image/webp"
        default: mimeType = "image/png"
        }
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}

struct RoveBadgeStrip: View {
    @ObservedObject private var library = RoveBadgeLibrary.shared
    let matchText: String
    var height: CGFloat = 42

    private var rules: [RoveBadgeRule] {
        library.matchingRules(in: matchText)
    }

    var body: some View {
        if !rules.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(rules) { rule in
                        RoveBadgeImage(
                            source: rule.imageURL,
                            monochromeAdaptive: library.monochromeAdaptive
                        )
                        .frame(width: 92, height: max(28, height - 10))
                    }
                }
                .padding(.horizontal, 10)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rules.map(\.name).joined(separator: "、"))
        }
    }
}

struct DJHUBAssignedBadgeStrip: View {
    let badges: [DJHUBBadge]

    private var rules: [RoveBadgeRule] {
        badges.compactMap { badge in
            guard !badge.imageURL.isEmpty else { return nil }
            return RoveBadgeRule(
                id: badge.id,
                groupID: badge.groupID,
                name: badge.name,
                pattern: ".*",
                imageURL: badge.imageURL,
                isEnabled: true
            )
        }
    }

    var body: some View {
        if !rules.isEmpty {
            RoveBadgeWebStrip(rules: rules, monochromeAdaptive: true)
                .frame(height: 42)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rules.map(\.name).joined(separator: "、"))
        }
    }
}

private struct RoveBadgeImage: View {
    let source: String
    let monochromeAdaptive: Bool
    @State private var image: UIImage?
    @State private var isFailed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .modifier(RoveBadgeAdaptiveModifier(enabled: monochromeAdaptive))
            } else if isFailed {
                Image(systemName: "rectangle.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Match the established artwork/card loading treatment. The
                // placeholder occupies the final badge frame, so controls do
                // not jump as several badge assets complete independently.
                RoveShimmerBlock(cornerRadius: 6)
            }
        }
        .task(id: source) {
            let cachedSource = await RoveBadgeAssetCache.shared.cachedImageSource(for: source)
            guard !Task.isCancelled else { return }
            guard let data = RoveBadgeImage.data(from: cachedSource),
                  let decoded = UIImage(data: data) else {
                isFailed = true
                return
            }
            image = decoded
        }
    }

    private static func data(from source: String) -> Data? {
        guard let separator = source.firstIndex(of: ",") else { return nil }
        let payload = String(source[source.index(after: separator)...])
        return Data(base64Encoded: payload)
    }
}

private struct RoveBadgeAdaptiveModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.shadow(color: .black.opacity(0.75), radius: 1)
        } else {
            content
        }
    }
}

struct RoveBadgePackagePreview: View {
    @ObservedObject private var library = RoveBadgeLibrary.shared
    let package: RoveBadgePackage

    private var previewRules: [RoveBadgeRule] {
        let enabledRules = package.rules.filter(\.isEnabled)
        let matchedRules = enabledRules.filter(matchesPreviewMedia)
        let candidates = matchedRules.isEmpty ? enabledRules : matchedRules
        return Array(candidates.sorted {
            previewPriority(for: $0) > previewPriority(for: $1)
        }.prefix(10))
    }

    /// The preview should demonstrate the most recognisable cinema features
    /// first, even when a rule library stores resolution badges at the top.
    private let previewMediaText = """
    4K 2160p UHD HDR HDR10 HDR10+ Dolby Vision DV 杜比视界
    Dolby Atmos Atmos 杜比全景声 Dolby TrueHD TrueHD DTS:X DTS
    HEVC H.265 AVC H.264 AAC 5.1 7.1 1080p 720p
    """

    private func matchesPreviewMedia(_ rule: RoveBadgeRule) -> Bool {
        RoveBadgePatternMatcher.matches(
            rule.pattern,
            in: previewMediaText,
            caseInsensitive: true
        )
    }

    private func previewPriority(for rule: RoveBadgeRule) -> Int {
        let text = "\(rule.name) \(rule.pattern)".folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        ).lowercased()
        if text.contains("dolby vision") || text.contains("杜比视界") { return 1_000 }
        if text.contains("dolby atmos") || text.contains("杜比全景声") { return 990 }
        if text.contains("dolby") || text.contains("atmos") { return 980 }
        if text.contains("vision") || text.contains("全景声") { return 970 }
        if text.contains("hdr") || text.contains("dts") { return 900 }
        if text.contains("4k") || text.contains("2160") { return 800 }
        if text.contains("1080") || text.contains("720") { return 700 }
        return 0
    }

    var body: some View {
        if previewRules.isEmpty {
            ContentUnavailableView("暂无可预览徽章", systemImage: "rectangle.slash")
                .frame(maxWidth: .infinity, minHeight: 96)
        } else {
            VStack(spacing: 10) {
                previewRow(background: Color.black, icon: "moon.fill", iconColor: .white.opacity(0.72))
                previewRow(background: Color.white, icon: "sun.max.fill", iconColor: .black.opacity(0.62))
            }
        }
    }

    private func previewRow(background: Color, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: 30)
                .accessibilityHidden(true)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(previewRules) { rule in
                        RoveBadgeImage(
                            source: rule.imageURL,
                            monochromeAdaptive: library.monochromeAdaptive
                        )
                        .frame(width: 92, height: 28)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 44)
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(package.name)徽章预览")
    }
}

private struct RoveBadgeWebStrip: UIViewRepresentable {
    let rules: [RoveBadgeRule]
    let monochromeAdaptive: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = true
        webView.scrollView.isDirectionalLockEnabled = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let signature = rules.map { "\($0.id)|\($0.imageURL)" }.joined(separator: ";")
            + "|adaptive=\(monochromeAdaptive)"
        guard context.coordinator.signature != signature else { return }
        context.coordinator.signature = signature
        let coordinator = context.coordinator
        let currentRules = rules
        let currentAdaptive = monochromeAdaptive
        Task { @MainActor in
            let html = await RoveBadgeHTMLRenderer.html(
                rules: currentRules,
                monochromeAdaptive: currentAdaptive
            )
            guard coordinator.signature == signature else { return }
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var signature = ""
    }

}

private enum RoveBadgeHTMLRenderer {
    static func html(
        rules: [RoveBadgeRule],
        monochromeAdaptive: Bool
    ) async -> String {
        let adaptiveClass = monochromeAdaptive ? " adaptive" : ""
        var images: [String] = []
        images.reserveCapacity(rules.count)
        for rule in rules {
            let imageSource = await RoveBadgeAssetCache.shared.cachedImageSource(for: rule.imageURL)
            images.append(
                "<img class=\"badge\(adaptiveClass)\" src=\"\(htmlEscaped(imageSource))\" alt=\"\(htmlEscaped(rule.name))\">"
            )
        }
        let joinedImages = images.joined()
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        *{box-sizing:border-box}html,body{margin:0;padding:0;background:transparent;height:100%;overflow:hidden}
        body{display:flex;align-items:center;gap:12px;padding:6px 10px;white-space:nowrap;width:max-content;min-width:100%;overflow-x:auto;overflow-y:hidden;-webkit-overflow-scrolling:touch;scrollbar-width:none}
        body::-webkit-scrollbar{display:none}
        img{display:block;flex:0 0 auto;max-height:28px;max-width:92px;object-fit:contain}
        img.adaptive{filter:drop-shadow(0 0 1px rgba(0,0,0,.75)) drop-shadow(0 0 1px rgba(255,255,255,.45))}
        </style></head><body>\(joinedImages)</body></html>
        """
    }

    private static func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
