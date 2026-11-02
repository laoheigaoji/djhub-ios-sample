import Foundation
import Security

#if DJHUB_METADATA_ONLY
struct CloudConfigurationSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let channels: [Channel]
    let configurations: [PlaylistConfiguration]?
    let activeConfigurationID: UUID?
    let favoriteURLs: Set<String>
    let recentURLs: [String]
    let playlistEPGURLs: [URL]?
    let customEPGURLs: [URL]?
    let defaultEPGAddress: String?
    let modifiedAt: Date
}

private enum WebDAVService {
    static func normalizedBaseURL(_ address: String) throws -> URL {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: value),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host?.isEmpty == false else {
            throw URLError(.badURL)
        }
        if components.path.isEmpty { components.path = "/" }
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    static func list(
        url: URL,
        username: String,
        password: String
    ) async throws -> [URL] {
        []
    }
}

private enum PlaybackRequestPreferences {
    static var isCustomUserAgentEnabled: Bool { false }
    static var customUserAgent: String { "DJHUB/1.0" }

    static func headers(for channel: Channel) -> [String: String] {
        channel.httpHeaders
    }
}

private enum LocalVideoFormatSupport {
    static let fileExtensions: Set<String> = [
        "mp4", "mov", "m4v", "mkv", "webm", "avi", "wmv", "mpg", "mpeg",
        "vob", "ts", "m2ts", "mts", "flv", "ogv", "rm", "rmvb"
    ]
}
#endif

struct MetadataLibraryCollection: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let collectionType: String?
    let primaryImageTag: String?

    init(
        id: String,
        name: String,
        collectionType: String?,
        primaryImageTag: String? = nil
    ) {
        self.id = id
        self.name = name
        self.collectionType = collectionType
        self.primaryImageTag = primaryImageTag
    }
}

struct MetadataContinueItem: Identifiable, Codable, Sendable {
    let channel: Channel
    let positionSeconds: TimeInterval
    let durationSeconds: TimeInterval

    var id: UUID { channel.id }

    var progress: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(max(positionSeconds / durationSeconds, 0), 1)
    }
}

struct MetadataLibraryPage: Codable, Sendable {
    let channels: [Channel]
    let totalCount: Int
    let nextStartIndex: Int

    var hasMore: Bool { nextStartIndex < totalCount }
}

struct MetadataCreditPerson: Identifiable, Codable, Sendable {
    let id: String
    let imageItemID: String?
    let name: String
    let role: String?
    let type: String?
}

struct MetadataStreamDetail: Identifiable, Codable, Sendable {
    let id: String
    let type: String
    let title: String
    let codec: String?
    let language: String?
    let width: Int?
    let height: Int?
    let channels: Int?
    let sampleRate: Int?
    let bitRate: Int?
    let frameRate: Double?
}

struct MetadataVersion: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let container: String?
    let sizeBytes: Int64?
    let bitRate: Int?
    let width: Int?
    let height: Int?
    /// The source server is kept with the version so a merged resource list
    /// can route playback to the server that owns the selected file.
    let serverName: String?
    let serverConfigurationID: UUID?
    let serverItemID: String?
    let serverKind: String?
    let dynamicRange: String?
    let frameRate: Double?
    let subtitleTracks: [String]?
    let audioTracks: [String]?

    var selectionKey: String {
        "\(serverConfigurationID?.uuidString ?? "local")|\(id)"
    }

    var qualityLabel: String? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return height >= 2160 ? "4K" : (height >= 1080 ? "1080p" : "\(height)p")
    }

    var bitRateLabel: String? {
        guard let bitRate, bitRate > 0 else { return nil }
        if bitRate >= 1_000_000 { return String(format: "%.1f Mbps", Double(bitRate) / 1_000_000) }
        return "\(Int((Double(bitRate) / 1_000).rounded())) Kbps"
    }

    var displayName: String {
        var details: [String] = []
        if let width, let height, width > 0, height > 0 {
            details.append("\(height >= 2160 ? "4K" : "\(width)×\(height)")")
        }
        if let container, !container.isEmpty {
            details.append(container.uppercased())
        }
        if let sizeBytes, sizeBytes > 0 {
            let size = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
            details.append(size)
        }
        return details.isEmpty ? name : "\(name) · \(details.joined(separator: " · "))"
    }
}

struct MediaServerSubtitleSource: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let url: URL
}

struct ChannelGroupVisibility: Identifiable, Equatable, Sendable {
    let name: String
    let channelCount: Int
    let isHidden: Bool

    var id: String { name }
}

struct MetadataDetails: Codable, Sendable {
    let itemID: String
    let title: String
    let overview: String?
    let premiereDate: String?
    let productionYear: Int?
    let communityRating: Double?
    let officialRating: String?
    let genres: [String]
    let runtimeSeconds: TimeInterval?
    let container: String?
    let sizeBytes: Int64?
    let people: [MetadataCreditPerson]
    let studios: [String]?
    let streams: [MetadataStreamDetail]
    let mediaVersions: [MetadataVersion]?
}

struct MediaLibraryStatistics: Equatable, Sendable {
    struct ItemCount: Equatable, Sendable {
        let unique: Int
        let allVersions: Int
    }

    let movies: ItemCount
    let series: ItemCount
    let episodes: ItemCount

    init(channels: [Channel]) {
        movies = Self.count(channels, matching: ["movie", "video", "musicvideo", "program"])
        series = Self.count(channels, matching: ["series"])
        episodes = Self.count(channels, matching: ["episode"])
    }

    init(movies: ItemCount, series: ItemCount, episodes: ItemCount) {
        self.movies = movies
        self.series = series
        self.episodes = episodes
    }

    private static func count(_ channels: [Channel], matching types: Set<String>) -> ItemCount {
        let matches = channels.filter {
            guard let type = $0.mediaServerItemType?.lowercased() else { return false }
            return types.contains(type)
        }
        let unique = Set(matches.map { channel in
            let name = (channel.tvgName ?? channel.name)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "|")
            return "\(channel.mediaServerSeriesID ?? channel.group)|\(name)|\(channel.productionYear ?? 0)"
        }).count
        return ItemCount(unique: unique, allVersions: matches.count)
    }
}

#if DJHUB_METADATA_ONLY
private enum DJHUBMetadataCompatibilityError: Error { case unavailable }

@MainActor
final class ChannelLibrary: ObservableObject {
    static let shared = ChannelLibrary()
    @Published private(set) var channels: [Channel] = []
    @Published private(set) var configurations: [PlaylistConfiguration] = []
    @Published private(set) var activeConfigurationID: UUID?
    private let favoritesKey = "djhub.metadata.favorites.v1"
    private var favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: "djhub.metadata.favorites.v1") ?? [])
    private init() {}

    var activeConfiguration: PlaylistConfiguration? { nil }
    var groupedChannels: [(name: String, channels: [Channel])] { [] }
    var favoriteChannels: [Channel] { channels.filter(isFavorite) }
    var recentChannels: [Channel] { [] }
    func localizedDisplayGroup(_ group: String) -> String { group }
    func displayGroup(for channel: Channel) -> String { channel.group }
    func selectConfiguration(_ id: UUID) {}
    func refreshConfiguration(_ id: UUID) async {}
    func isFavorite(_ channel: Channel) -> Bool { favoriteIDs.contains(identifier(channel)) }
    func toggleFavorite(_ channel: Channel) {
        let id = identifier(channel)
        if favoriteIDs.remove(id) == nil { favoriteIDs.insert(id) }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: favoritesKey)
        objectWillChange.send()
    }
    func cachedEmbyContinueWatching(configurationID: UUID) async -> [MetadataContinueItem] { [] }
    func cachedEmbyCollections(configurationID: UUID) async -> [MetadataLibraryCollection] { [] }
    func isMediaServerHomeCacheFresh(configurationID: UUID, maxAge: TimeInterval = 900) async -> Bool { true }
    func loadEmbyCollections(configurationID: UUID) async throws -> [MetadataLibraryCollection] { [] }
    func loadEmbyContinueWatching(configurationID: UUID, limit: Int = 12) async throws -> [MetadataContinueItem] { [] }
    func setMediaServerPlayed(_ played: Bool, for channel: Channel) async -> Bool { false }
    func cachedEmbyPage(configurationID: UUID, parentID: String? = nil, startIndex: Int = 0, limit: Int = 60, genre: String? = nil, prefersSeries: Bool = false) async -> MetadataLibraryPage? { nil }
    func cachedMetadataDetails(configurationID: UUID, itemID: String) async -> MetadataDetails? { nil }
    func loadMetadataDetails(configurationID: UUID, itemID: String) async throws -> MetadataDetails { throw DJHUBMetadataCompatibilityError.unavailable }
    func loadEmbyPage(configurationID: UUID, parentID: String? = nil, startIndex: Int = 0, limit: Int = 60, searchTerm: String? = nil, genre: String? = nil, prefersSeries: Bool = false, sortBy: String? = nil, sortDescending: Bool? = nil, includesMediaSources: Bool = false) async throws -> MetadataLibraryPage {
        MetadataLibraryPage(channels: [], totalCount: 0, nextStartIndex: 0)
    }
    func loadSimilarItems(for channel: Channel, limit: Int = 20) async throws -> [Channel] { [] }
    func loadAggregatedMediaDetails(for channel: Channel, base: MetadataDetails) async -> MetadataDetails { base }
    func searchMediaServersByProviderIDs(_ providerIDs: [String], includeItemTypes: String, limit: Int = 10) async -> [Channel] { [] }
    func searchAllEmbyItems(configurationID: UUID, searchTerm: String) async throws -> [Channel] { [] }
    func registerTransientPlaybackLines(_ channels: [Channel]) {}
    func loadItemsForPerson(configurationID: UUID, personID: String, limit: Int = 60) async throws -> [Channel] { [] }

    private func identifier(_ channel: Channel) -> String {
        if let value = channel.tvgID, !value.isEmpty { return value }
        return channel.streamURL.absoluteString
    }
}
#else
@MainActor
final class ChannelLibrary: ObservableObject {
    static let shared = ChannelLibrary()

    @Published private(set) var channels: [Channel] = [] {
        didSet {
            guard !isApplyingPreparedPresentation else { return }
            rebuildChannelPresentationCache()
            rebuildSavedChannelCaches()
        }
    }
    @Published private(set) var lastError: String?
    @Published private(set) var favoriteURLs: Set<String> = [] {
        didSet { rebuildSavedChannelCaches() }
    }
    @Published private(set) var recentURLs: [String] = [] {
        didSet { rebuildSavedChannelCaches() }
    }
    @Published private(set) var playlistEPGURLs: [URL] = []
    @Published private(set) var customEPGURLs: [URL] = []
    @Published private(set) var defaultEPGAddress = ""
    @Published private(set) var configurations: [PlaylistConfiguration] = []
    @Published private(set) var activeConfigurationID: UUID?
    @Published private(set) var expiredConfigurationNotice: PlaylistConfiguration?
    @Published private(set) var isImportingConfiguration = false
    @Published private(set) var hasRestoredPersistedState = false

    private let parser = M3UParser()
    private let storageKey = "roadstream.channels.v1"
    private let favoritesStorageKey = "roadstream.favorites.v1"
    private let suppressedServerFavoritesStorageKey = "rove.server-favorites.suppressed.v1"
    private let recentStorageKey = "roadstream.recents.v1"
    private let playlistEPGStorageKey = "roadstream.epg.playlist.v1"
    private let customEPGStorageKey = "roadstream.epg.custom.v1"
    private let defaultEPGStorageKey = "roadstream.epg.default.v1"
    private let modifiedAtStorageKey = "roadstream.configuration.modifiedAt.v1"
    private let configurationsStorageKey = "tubo.playlist.configurations.v1"
    private let activeConfigurationStorageKey = "tubo.playlist.activeConfiguration.v1"
    private(set) var configurationModifiedAt = Date.distantPast
    private var expirationTask: Task<Void, Never>?
    private var reportedExpiredConfigurationIDs: Set<UUID> = []
    private var isRestoringPersistedState = false
    private var configurationImportActivityCount = 0
    private var configurationPersistenceTask: Task<Void, Never>?
    private var channelPersistenceTask: Task<Void, Never>?
    private var activePresentationTask: Task<Void, Never>?
    private var legacyMediaServerDetectionTasks: [UUID: Task<Void, Never>] = [:]
    private var confirmedJellyfinConfigurationIDs = Set<UUID>()
    private struct MediaServerPageCacheKey: Hashable {
        let configurationID: UUID
        let parentID: String?
        let startIndex: Int
        let limit: Int
        let genre: String?
        let prefersSeries: Bool
        let sortBy: String?
        let sortDescending: Bool?
        let includesMediaSources: Bool
    }
    private struct MediaServerBrowseCacheKey: Hashable {
        let configurationID: UUID
        let parentID: String
        let kind: String
    }
    private struct ProviderIDSearchRequest: Sendable {
        let index: Int
        let server: String
        let token: String
        let username: String
        let userID: String?
        let configurationID: UUID
        let serverKind: PlaylistConfigurationKind
    }
    private var mediaServerCollectionsMemoryCache: [UUID: [MetadataLibraryCollection]] = [:]
    private var mediaServerContinueWatchingMemoryCache: [UUID: [MetadataContinueItem]] = [:]
    private var mediaServerDetailsMemoryCache: [String: MetadataDetails] = [:]
    private var mediaServerPageMemoryCache: [MediaServerPageCacheKey: MetadataLibraryPage] = [:]
    private var mediaServerBrowseMemoryCache: [MediaServerBrowseCacheKey: [MetadataLibraryCollection]] = [:]
    private var groupedChannelsCache: [(name: String, channels: [Channel])] = []
    private var displayGroupByChannelID: [UUID: String] = [:]
    /// All physical stream addresses behind the active channel list. Aggregate
    /// configurations expose one logical channel in `channels`, while this
    /// cache keeps the remaining addresses available as fallback lines.
    private var activeLineChannels: [Channel] = []
    /// `favoriteChannels`, CarPlay rows and SwiftUI card bodies ask for the
    /// same logical channel lines very frequently. Re-running the transitive
    /// name/tvg-id scan for every card turns opening Favorites into an
    /// O(channel^3) main-thread operation on large playlists. Build the
    /// connected components once when the active configuration changes.
    private var playbackLinesByChannelID: [UUID: [Channel]] = [:]
    private var playbackLinesByAddress: [String: [Channel]] = [:]
    private var playbackLinesByLogicalKey: [String: [Channel]] = [:]
    private var favoriteChannelsCache: [Channel] = []
    private var recentChannelsCache: [Channel] = []
    private lazy var suppressedServerFavoriteURLs = Set(
        UserDefaults.standard.stringArray(forKey: suppressedServerFavoritesStorageKey) ?? []
    )
    private var isApplyingPreparedPresentation = false

    private struct PreparedChannelGroup: Sendable {
        let name: String
        let channels: [Channel]
    }

    /// Immutable result of the expensive active-source calculation. Preparing
    /// this value outside the main actor keeps deleting a large active source
    /// from freezing taps and navigation while line, group and saved-item
    /// indexes are rebuilt.
    private struct PreparedActivePresentation: Sendable {
        let activeLineChannels: [Channel]
        let channels: [Channel]
        let playlistEPGURLs: [URL]
        let playbackLinesByChannelID: [UUID: [Channel]]
        let playbackLinesByAddress: [String: [Channel]]
        let playbackLinesByLogicalKey: [String: [Channel]]
        let groups: [PreparedChannelGroup]
        let displayGroupByChannelID: [UUID: String]
        let favoriteChannels: [Channel]
        let recentChannels: [Channel]
    }

    private init() {}

    /// Restore after SwiftUI has presented its first frame. Decoding a large
    /// saved configuration synchronously from `RoadStreamApp.init()` keeps the
    /// launch screen up and looks like a multi-second white freeze.
    func restorePersistedStateIfNeeded() async {
        guard !hasRestoredPersistedState, !isRestoringPersistedState else { return }
        isRestoringPersistedState = true
        await Task.yield()
        restore()
        isRestoringPersistedState = false
        hasRestoredPersistedState = true
    }

    var activeConfiguration: PlaylistConfiguration? {
        guard let activeConfigurationID else { return nil }
        return configurations.first { $0.id == activeConfigurationID }
    }

    func preloadPreference(for channel: Channel) -> RoveServerPreloadPreference {
        let configurationID: UUID? = switch channel.resolver {
        case .legacyLibraryA(let id, _), .movieClaw(let id, _), .legacyLibraryB(let id, _), .legacyLibraryC(let id, _),
             .legacyLibraryD(let id, _): id
        case .legacySourceA, .none: nil
        }
        guard let configurationID,
              let configuration = configurations.first(where: { $0.id == configurationID }) else {
            return .inherit
        }
        return configuration.preloadPreference
    }

    var groupedChannels: [(name: String, channels: [Channel])] {
        groupedChannelsCache
    }

    /// Returns every unique address that represents the same logical channel,
    /// in configuration and playlist order. This deliberately remains
    /// separate from `channels`, so aggregate lists can merge duplicate rows
    /// without losing manual line switching or automatic failover.
    func playbackLines(for channel: Channel) -> [Channel] {
        if let lines = playbackLinesByChannelID[channel.id] {
            return lines
        }
        if let lines = playbackLinesByAddress[channel.streamURL.absoluteString] {
            return lines
        }
        for key in Self.logicalChannelKeys(channel) {
            if let lines = playbackLinesByLogicalKey[key] {
                return lines
            }
        }
        return [channel]
    }

    /// APTV 同款优先级：导入时指定 > M3U 自带 > 全局默认。
    var epgURLs: [URL] {
        let configured: [URL]
        if !customEPGURLs.isEmpty {
            configured = customEPGURLs
        } else if !playlistEPGURLs.isEmpty {
            configured = playlistEPGURLs
        } else {
            configured = Self.parseURLList(defaultEPGAddress)
        }
        if channels.isEmpty, configured.isEmpty { return [] }

        // 部分播放列表携带的 EPG 会停止更新。内置公开 EPG 只在前面的来源
        // 已过期或缺少频道时兜底，用户配置仍然具有最高优先级。
        let fallback = URL(string: "https://epg.pw/xmltv/epg_CN.xml")!
        return configured.contains(fallback) ? configured : configured + [fallback]
    }

    /// 当播放源没有提供 group-title 时，根据频道名生成适合车机浏览的分类。
    /// 已经带有有效分类的播放源会完整保留原分类。
    func displayGroup(for channel: Channel) -> String {
        displayGroupByChannelID[channel.id] ?? Self.inferredDisplayGroup(for: channel)
    }

    func localizedDisplayGroup(_ group: String) -> String {
        switch group {
        case "未分组", "单频道", "央视频道", "卫视频道", "4K/8K", "影视", "体育", "少儿",
             "地方频道", "直播", "剧集", "电影", "音乐视频", "节目", "视频", "直播缓存",
             "DLNA 投屏", "其他":
            return AppLanguage.localized(group)
        default:
            return group
        }
    }

    func channelGroups(for configurationID: UUID) -> [ChannelGroupVisibility] {
        guard let configuration = configurations.first(where: { $0.id == configurationID }) else {
            return []
        }
        return Self.channelGroups(for: configuration, configurations: configurations)
    }

    func setChannelGroup(
        _ groupName: String,
        hidden: Bool,
        for configurationID: UUID
    ) {
        guard let index = configurations.firstIndex(where: { $0.id == configurationID }) else {
            return
        }
        let normalizedName = Self.normalizedChannelGroupName(groupName)
        guard !normalizedName.isEmpty else { return }

        let changed: Bool
        if hidden {
            changed = configurations[index].hiddenChannelGroups.insert(normalizedName).inserted
        } else {
            changed = configurations[index].hiddenChannelGroups.remove(normalizedName) != nil
        }
        guard changed else { return }

        persistConfigurations()
        refreshActivePresentationAfterGroupVisibilityChange(configurationID: configurationID)
        markConfigurationChanged()
    }

    func setAllChannelGroups(hidden: Bool, for configurationID: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == configurationID }) else {
            return
        }
        let updatedGroups = hidden
            ? Set(channelGroups(for: configurationID).map(\.name))
            : Set<String>()
        guard configurations[index].hiddenChannelGroups != updatedGroups else { return }

        configurations[index].hiddenChannelGroups = updatedGroups
        persistConfigurations()
        refreshActivePresentationAfterGroupVisibilityChange(configurationID: configurationID)
        markConfigurationChanged()
    }

    private nonisolated static func inferredDisplayGroup(for channel: Channel) -> String {
        let sourceGroup = channel.group.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceGroup.isEmpty, sourceGroup != "未分组" {
            return sourceGroup
        }

        let name = channel.name.uppercased()
        if containsAny(name, ["4K", "8K", "超高清", "UHD"]) {
            return "4K/8K"
        }
        if containsAny(name, ["体育", "足球", "篮球", "网球", "台球", "围棋", "高尔夫", "SPORT"]) {
            return "体育"
        }
        if containsAny(name, ["电影", "影院", "剧场", "影视", "CHC", "MOVIE"]) {
            return "影视"
        }
        if containsAny(name, ["少儿", "卡酷", "KAKU", "动漫", "动画", "金鹰卡通", "嘉佳卡通", "优漫卡通"]) {
            return "少儿"
        }
        if containsAny(name, ["卫视"]) {
            return "卫视频道"
        }
        if containsAny(name, ["CCTV", "央视", "CGTN"]) {
            return "央视频道"
        }
        return "地方频道"
    }

    nonisolated static func filteredChannels(
        _ channels: [Channel],
        hiddenChannelGroups: Set<String>
    ) -> [Channel] {
        guard !hiddenChannelGroups.isEmpty else { return channels }
        let normalizedHiddenGroups = Set(hiddenChannelGroups.map(normalizedChannelGroupName))
        return channels.filter {
            !normalizedHiddenGroups.contains(
                normalizedChannelGroupName(inferredDisplayGroup(for: $0))
            )
        }
    }

    private nonisolated static func normalizedChannelGroupName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func channelGroups(
        for configuration: PlaylistConfiguration,
        configurations: [PlaylistConfiguration]
    ) -> [ChannelGroupVisibility] {
        let sourceChannels: [Channel]
        if configuration.kind == .aggregate {
            let memberIDs = Set(configuration.memberIDs)
            sourceChannels = configurations
                .filter {
                    memberIDs.contains($0.id)
                        && $0.kind != .aggregate
                        && !$0.isExpired
                }
                .flatMap {
                    filteredChannels(
                        $0.channels,
                        hiddenChannelGroups: $0.hiddenChannelGroups
                    )
                }
        } else {
            sourceChannels = configuration.channels
        }

        let hiddenGroups = Set(configuration.hiddenChannelGroups.map(normalizedChannelGroupName))
        let preferredOrder = [
            "央视频道", "卫视频道", "4K/8K", "影视", "体育", "少儿", "地方频道",
        ]
        return Dictionary(grouping: sourceChannels) {
            normalizedChannelGroupName(inferredDisplayGroup(for: $0))
        }
        .map { name, channels in
            ChannelGroupVisibility(
                name: name,
                channelCount: channels.count,
                isHidden: hiddenGroups.contains(name)
            )
        }
        .sorted { lhs, rhs in
            let lhsIndex = preferredOrder.firstIndex(of: lhs.name) ?? preferredOrder.count
            let rhsIndex = preferredOrder.firstIndex(of: rhs.name) ?? preferredOrder.count
            return lhsIndex == rhsIndex
                ? lhs.name.localizedCompare(rhs.name) == .orderedAscending
                : lhsIndex < rhsIndex
        }
    }

    private func rebuildChannelPresentationCache() {
        var groupsByID: [UUID: String] = [:]
        groupsByID.reserveCapacity(channels.count)
        for channel in channels {
            groupsByID[channel.id] = Self.inferredDisplayGroup(for: channel)
        }
        displayGroupByChannelID = groupsByID

        let order = ["央视频道", "卫视频道", "4K/8K", "影视", "体育", "少儿", "地方频道"]
        groupedChannelsCache = Dictionary(grouping: channels) {
            groupsByID[$0.id] ?? Self.inferredDisplayGroup(for: $0)
        }
        .map { name, grouped in
            // Dictionary(grouping:) keeps the input order inside every value.
            // Do not alphabetize here: CarPlay must follow the order supplied
            // by the subscription rather than silently rearranging channels.
            (name, grouped)
        }
        .sorted { lhs, rhs in
            let lhsIndex = order.firstIndex(of: lhs.name) ?? order.count
            let rhsIndex = order.firstIndex(of: rhs.name) ?? order.count
            return lhsIndex == rhsIndex
                ? lhs.name.localizedCompare(rhs.name) == .orderedAscending
                : lhsIndex < rhsIndex
        }
    }

    var favoriteChannels: [Channel] {
        favoriteChannelsCache
    }

    var recentChannels: [Channel] {
        recentChannelsCache
    }

    /// Favorites and recent rows are read repeatedly while a paged SwiftUI
    /// TabView is moving. Re-scanning a 10k-50k channel configuration on every
    /// animation frame makes the gesture hitch. Rebuild once when the source
    /// data changes, then make every view read O(1).
    private func rebuildSavedChannelCaches() {
        guard !channels.isEmpty else {
            favoriteChannelsCache = []
            recentChannelsCache = []
            return
        }

        var displayedByID: [UUID: Channel] = [:]
        var displayedByAddress: [String: Channel] = [:]
        var displayedByLogicalKey: [String: Channel] = [:]
        displayedByID.reserveCapacity(channels.count)
        displayedByAddress.reserveCapacity(channels.count)
        displayedByLogicalKey.reserveCapacity(channels.count * 2)
        for channel in channels {
            displayedByID[channel.id] = channel
            displayedByAddress[channel.streamURL.absoluteString] = channel
            for key in Self.logicalChannelKeys(channel) where displayedByLogicalKey[key] == nil {
                displayedByLogicalKey[key] = channel
            }
        }

        func displayedChannel(for address: String) -> Channel? {
            if let direct = displayedByAddress[address] { return direct }
            guard let lines = playbackLinesByAddress[address] else { return nil }
            for line in lines {
                if let direct = displayedByID[line.id]
                    ?? displayedByAddress[line.streamURL.absoluteString] {
                    return direct
                }
                for key in Self.logicalChannelKeys(line) {
                    if let logical = displayedByLogicalKey[key] { return logical }
                }
            }
            return nil
        }

        var favoriteChannelIDs = Set(favoriteURLs.compactMap {
            displayedChannel(for: $0)?.id
        })
        for channel in channels where channel.mediaServerFavorite == true {
            let address = channel.streamURL.absoluteString
            if !suppressedServerFavoriteURLs.contains(address) {
                favoriteChannelIDs.insert(channel.id)
            }
        }
        let favorites = channels.filter { favoriteChannelIDs.contains($0.id) }

        var seenRecentChannelIDs = Set<UUID>()
        let recents = recentURLs.compactMap { address -> Channel? in
            guard let channel = displayedChannel(for: address),
                  seenRecentChannelIDs.insert(channel.id).inserted
            else { return nil }
            return channel
        }

        favoriteChannelsCache = favorites
        recentChannelsCache = recents
    }

    /// Returns true only when every saved configuration containing this channel
    /// has expired. This lets an expiry stop an existing phone/CarPlay stream
    /// without interrupting local video or the same channel from another valid source.
    func isChannelExpired(_ channel: Channel) -> Bool {
        let address = channel.streamURL.absoluteString
        let owners = configurations.filter { configuration in
            configuration.kind != .aggregate && configuration.channels.contains { candidate in
                candidate.id == channel.id || candidate.streamURL.absoluteString == address
            }
        }
        return !owners.isEmpty && owners.allSatisfy(\.isExpired)
    }

    /// Media servers are libraries rather than live-channel
    /// configurations. Keep them available to CarPlay even when another IPTV
    /// configuration is currently selected on iPhone.
    var mediaServerConfigurations: [PlaylistConfiguration] {
        configurations.filter {
            $0.kind.usesMediaLibraryBrowser && !$0.channels.isEmpty
        }
    }

    var mediaServerChannels: [Channel] {
        mediaServerConfigurations.flatMap(\.channels)
    }

    /// Compatibility alias for older call sites and persisted behavior.
    var jellyfinChannels: [Channel] { mediaServerChannels }

    func isFavorite(_ channel: Channel) -> Bool {
        playbackLines(for: channel).contains { candidate in
            let address = candidate.streamURL.absoluteString
            if favoriteURLs.contains(address) { return true }
            return candidate.mediaServerFavorite == true
                && !suppressedServerFavoriteURLs.contains(address)
        }
    }

    func toggleFavorite(_ channel: Channel) {
        let wasFavorite = isFavorite(channel)
        let shouldFavorite = !wasFavorite
        let channelAddress = channel.streamURL.absoluteString
        let lines = playbackLines(for: channel)
        let savedLineAddress = lines
            .lazy
            .map({ $0.streamURL.absoluteString })
            .first(where: favoriteURLs.contains)

        if wasFavorite {
            favoriteURLs.remove(channelAddress)
            if let savedLineAddress { favoriteURLs.remove(savedLineAddress) }
            for line in lines where line.mediaServerFavorite == true {
                suppressedServerFavoriteURLs.insert(line.streamURL.absoluteString)
            }
        } else if let savedLineAddress {
            // Remove only the one persisted favorite represented by this
            // card. Some playlists have malformed aliases that accidentally
            // connect unrelated channels; bulk subtraction must never erase
            // the user's other favorites.
            favoriteURLs.remove(savedLineAddress)
        } else {
            favoriteURLs.insert(channelAddress)
            for line in lines {
                suppressedServerFavoriteURLs.remove(line.streamURL.absoluteString)
            }
        }
        persistPreferences()
        UserDefaults.standard.set(
            Array(suppressedServerFavoriteURLs),
            forKey: suppressedServerFavoritesStorageKey
        )
        rebuildSavedChannelCaches()
        markConfigurationChanged()
        Task { @MainActor in
            _ = await setMediaServerFavorite(shouldFavorite, for: channel)
        }
    }

    /// A channel can be edited only when it is backed by a regular saved
    /// configuration. Web-imported configurations are deliberately read-only,
    /// while resolver-backed channels (Stalker/Jellyfin/Emby) must continue to
    /// receive their temporary playback addresses from their own service.
    func canEditChannel(_ channel: Channel) -> Bool {
        guard channel.resolver == nil else { return false }
        let address = channel.streamURL.absoluteString
        let owners = configurations.filter { configuration in
            configuration.kind != .aggregate && configuration.channels.contains { candidate in
                candidate.id == channel.id || candidate.streamURL.absoluteString == address
            }
        }
        return !owners.isEmpty && owners.allSatisfy { $0.isWebImportProtected != true }
    }

    /// Resolver-backed and protected web-import channels remain read-only.
    /// In an aggregate configuration, every playback line represented by the
    /// visible card must be removable before the card can be deleted.
    func canDeleteChannel(_ channel: Channel) -> Bool {
        let lines = playbackLines(for: channel)
        return !lines.isEmpty && lines.allSatisfy { canEditChannel($0) }
    }

    /// Validates a whole selection with one configuration scan. Calling
    /// `canDeleteChannel` for every selected item becomes quadratic on very
    /// large playlists and can freeze the selection toolbar.
    func canDeleteChannels(_ selectedChannels: [Channel]) -> Bool {
        guard !selectedChannels.isEmpty else { return false }

        let lines = selectedChannels.flatMap { playbackLines(for: $0) }
        guard !lines.isEmpty, lines.allSatisfy({ $0.resolver == nil }) else { return false }

        let requestedIDs = Set(lines.map(\.id))
        let requestedAddresses = Set(lines.map { $0.streamURL.absoluteString })
        var foundIDs = Set<UUID>()
        var foundAddresses = Set<String>()

        for configuration in configurations where configuration.kind != .aggregate {
            for candidate in configuration.channels {
                let address = candidate.streamURL.absoluteString
                guard requestedIDs.contains(candidate.id)
                        || requestedAddresses.contains(address)
                else { continue }
                guard configuration.isWebImportProtected != true else { return false }
                foundIDs.insert(candidate.id)
                foundAddresses.insert(address)
            }
        }

        return lines.allSatisfy {
            foundIDs.contains($0.id)
                || foundAddresses.contains($0.streamURL.absoluteString)
        }
    }

    /// Updates the matching persisted channel in place without rebuilding the
    /// configuration or dropping advanced playback metadata. Remote playlist
    /// refreshes remain authoritative and may replace manual edits later.
    @discardableResult
    func updateChannel(
        _ original: Channel,
        name: String,
        streamAddress: String,
        group: String,
        tvgID: String,
        tvgName: String,
        logoAddress: String
    ) -> String? {
        guard canEditChannel(original) else {
            return AppLanguage.localized("该频道不可编辑")
        }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            return AppLanguage.localized("频道名称不能为空")
        }

        guard let parsedAddress = MediaAddress.parse(streamAddress),
              let scheme = parsedAddress.url.scheme?.lowercased(),
              parsedAddress.url.isFileURL || MediaAddress.supportedSchemes.contains(scheme)
        else {
            return AppLanguage.localized("地址格式不正确")
        }

        let trimmedLogo = logoAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let logoURL: URL?
        if trimmedLogo.isEmpty {
            logoURL = nil
        } else if let parsedLogo = MediaAddress.parse(trimmedLogo),
                  let scheme = parsedLogo.url.scheme?.lowercased(),
                  parsedLogo.url.isFileURL || ["http", "https"].contains(scheme) {
            logoURL = parsedLogo.url
        } else {
            return AppLanguage.localized("台标地址格式不正确")
        }

        let oldAddress = original.streamURL.absoluteString
        let normalizedGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTVGID = tvgID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTVGName = tvgName.trimmingCharacters(in: .whitespacesAndNewlines)
        var didUpdate = false

        for configurationIndex in configurations.indices
        where configurations[configurationIndex].kind != .aggregate {
            var configurationChanged = false
            for channelIndex in configurations[configurationIndex].channels.indices {
                let candidate = configurations[configurationIndex].channels[channelIndex]
                guard candidate.id == original.id
                        || candidate.streamURL.absoluteString == oldAddress
                else { continue }

                var updated = candidate
                updated.name = normalizedName
                updated.streamURL = parsedAddress.url
                updated.group = normalizedGroup.isEmpty ? "未分组" : normalizedGroup
                updated.tvgID = normalizedTVGID.isEmpty ? nil : normalizedTVGID
                updated.tvgName = normalizedTVGName.isEmpty ? nil : normalizedTVGName
                updated.logoURL = logoURL
                updated.httpHeaders = candidate.httpHeaders.merging(parsedAddress.headers) {
                    _, inlineValue in inlineValue
                }
                configurations[configurationIndex].channels[channelIndex] = updated
                configurationChanged = true
                didUpdate = true
            }

            guard configurationChanged else { continue }
            configurations[configurationIndex].updatedAt = Date()
            if configurations[configurationIndex].kind == .single {
                configurations[configurationIndex].name = normalizedName
                configurations[configurationIndex].sourceAddress = streamAddress
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard didUpdate else {
            return AppLanguage.localized("该频道不可编辑")
        }

        let newAddress = parsedAddress.url.absoluteString
        if oldAddress != newAddress {
            if favoriteURLs.remove(oldAddress) != nil {
                favoriteURLs.insert(newAddress)
            }
            recentURLs = recentURLs.map { $0 == oldAddress ? newAddress : $0 }
            persistPreferences()
        }

        persistConfigurations()
        applyActiveConfiguration()
        lastError = nil
        markConfigurationChanged()
        return nil
    }

    /// Deletes the logical channel represented by a card. Aggregate cards can
    /// contain several fallback lines, so all of those persisted lines are
    /// removed together; unrelated channels and configurations are untouched.
    @discardableResult
    func deleteChannel(_ channel: Channel) -> String? {
        guard canDeleteChannel(channel) else {
            return AppLanguage.localized("该频道不可删除")
        }

        let lines = playbackLines(for: channel)
        let channelIDs = Set(lines.map(\.id))
        let channelAddresses = Set(lines.map { $0.streamURL.absoluteString })
        var didDelete = false
        var emptySingleConfigurationIDs = Set<UUID>()

        for configurationIndex in configurations.indices
        where configurations[configurationIndex].kind != .aggregate
            && configurations[configurationIndex].isWebImportProtected != true {
            let previousCount = configurations[configurationIndex].channels.count
            configurations[configurationIndex].channels.removeAll { candidate in
                channelIDs.contains(candidate.id)
                    || channelAddresses.contains(candidate.streamURL.absoluteString)
            }
            guard configurations[configurationIndex].channels.count != previousCount else {
                continue
            }

            didDelete = true
            configurations[configurationIndex].updatedAt = Date()
            if configurations[configurationIndex].kind == .single,
               configurations[configurationIndex].channels.isEmpty {
                emptySingleConfigurationIDs.insert(configurations[configurationIndex].id)
            }
        }

        guard didDelete else {
            return AppLanguage.localized("该频道不可删除")
        }

        if !emptySingleConfigurationIDs.isEmpty {
            configurations.removeAll { emptySingleConfigurationIDs.contains($0.id) }
            for index in configurations.indices where configurations[index].kind == .aggregate {
                configurations[index].memberIDs.removeAll {
                    emptySingleConfigurationIDs.contains($0)
                }
            }
            if let activeConfigurationID,
               emptySingleConfigurationIDs.contains(activeConfigurationID) {
                self.activeConfigurationID = configurations.first?.id
            }
        }

        favoriteURLs.subtract(channelAddresses)
        recentURLs.removeAll { channelAddresses.contains($0) }
        persistPreferences()

#if !DJHUB_METADATA_ONLY
        if let current = PlaybackCoordinator.shared.currentChannel,
           channelIDs.contains(current.id)
            || channelAddresses.contains(current.streamURL.absoluteString) {
            PlaybackCoordinator.shared.stop()
        }
#endif

        persistConfigurations()
        applyActiveConfiguration()
        lastError = nil
        markConfigurationChanged()
        return nil
    }

    /// Deletes many logical channels as one transaction. Configuration JSON
    /// encoding and active-list index rebuilding stay off the main actor; the
    /// published channel list changes only once when both results are ready.
    @discardableResult
    func deleteChannels(_ selectedChannels: [Channel]) async -> String? {
        guard canDeleteChannels(selectedChannels) else {
            return AppLanguage.localized("所选频道包含不可删除的频道")
        }

        let lines = selectedChannels.flatMap { playbackLines(for: $0) }
        let channelIDs = Set(lines.map(\.id))
        let channelAddresses = Set(lines.map { $0.streamURL.absoluteString })
        let baseConfigurations = configurations
        var updatedConfigurations = baseConfigurations
        var didDelete = false
        var emptySingleConfigurationIDs = Set<UUID>()

        for configurationIndex in updatedConfigurations.indices
        where updatedConfigurations[configurationIndex].kind != .aggregate
            && updatedConfigurations[configurationIndex].isWebImportProtected != true {
            let previousCount = updatedConfigurations[configurationIndex].channels.count
            updatedConfigurations[configurationIndex].channels.removeAll { candidate in
                channelIDs.contains(candidate.id)
                    || channelAddresses.contains(candidate.streamURL.absoluteString)
            }
            guard updatedConfigurations[configurationIndex].channels.count != previousCount else {
                continue
            }

            didDelete = true
            updatedConfigurations[configurationIndex].updatedAt = Date()
            if updatedConfigurations[configurationIndex].kind == .single,
               updatedConfigurations[configurationIndex].channels.isEmpty {
                emptySingleConfigurationIDs.insert(updatedConfigurations[configurationIndex].id)
            }
        }

        guard didDelete else {
            return AppLanguage.localized("该频道不可删除")
        }

        if !emptySingleConfigurationIDs.isEmpty {
            updatedConfigurations.removeAll { emptySingleConfigurationIDs.contains($0.id) }
            for index in updatedConfigurations.indices
            where updatedConfigurations[index].kind == .aggregate {
                updatedConfigurations[index].memberIDs.removeAll {
                    emptySingleConfigurationIDs.contains($0)
                }
            }
        }

        let updatedActiveID: UUID? = if let activeConfigurationID,
                                        emptySingleConfigurationIDs.contains(activeConfigurationID) {
            updatedConfigurations.first?.id
        } else {
            activeConfigurationID
        }
        let updatedFavoriteURLs = favoriteURLs.subtracting(channelAddresses)
        let updatedRecentURLs = recentURLs.filter { !channelAddresses.contains($0) }
#if !DJHUB_METADATA_ONLY
        let shouldStopCurrentPlayback: Bool = if let current = PlaybackCoordinator.shared.currentChannel {
            channelIDs.contains(current.id)
                || channelAddresses.contains(current.streamURL.absoluteString)
        } else {
            false
        }
#endif

        configurationPersistenceTask?.cancel()
        configurationPersistenceTask = nil
        // Freeze the complete deletion result before crossing concurrency
        // boundaries. Swift 6 otherwise treats the captured local `var` as a
        // value that could still be mutated while the background work runs.
        let deletionConfigurations = updatedConfigurations
        let deletionActiveID = updatedActiveID
        let deletionFavoriteURLs = updatedFavoriteURLs
        let deletionRecentURLs = updatedRecentURLs
        let persistenceTask = Task {
            try await ChannelLibraryPersistenceWriter.shared.writeConfigurations(
                deletionConfigurations,
                activeConfigurationID: deletionActiveID,
                configurationsKey: configurationsStorageKey,
                activeConfigurationKey: activeConfigurationStorageKey
            )
        }
        let preparationTask = Task.detached(priority: .userInitiated) {
            Self.prepareActivePresentation(
                configurations: deletionConfigurations,
                activeConfigurationID: deletionActiveID,
                favoriteURLs: deletionFavoriteURLs,
                recentURLs: deletionRecentURLs
            )
        }

        do {
            try await persistenceTask.value
        } catch {
            preparationTask.cancel()
            return AppLanguage.localizedFormat(
                "批量删除失败：%@",
                error.localizedDescription
            )
        }

        let preparedPresentation = await preparationTask.value
        guard configurations == baseConfigurations else {
            // The deletion snapshot has already been persisted, but another
            // scene changed the in-memory library while it was being prepared.
            // Restore that newer state to disk and never publish stale rows.
            persistConfigurations()
            return AppLanguage.localized("频道列表已变化，请重试")
        }

        configurations = deletionConfigurations
        activeConfigurationID = deletionActiveID
        favoriteURLs = deletionFavoriteURLs
        recentURLs = deletionRecentURLs
        persistPreferences()

        for id in emptySingleConfigurationIDs {
            ConfigurationCredentialVault.remove(for: id)
            reportedExpiredConfigurationIDs.remove(id)
        }
        if let notice = expiredConfigurationNotice,
           emptySingleConfigurationIDs.contains(notice.id) {
            expiredConfigurationNotice = nil
        }
#if !DJHUB_METADATA_ONLY
        if shouldStopCurrentPlayback {
            PlaybackCoordinator.shared.stop()
        }
#endif

        applyPreparedActivePresentation(preparedPresentation)
        lastError = nil
        markConfigurationChanged()
        return nil
    }

    func recordPlayback(_ channel: Channel) {
        let address = channel.streamURL.absoluteString
        // Treat every alternate address as the same recent item. This keeps a
        // line change from inserting duplicate cards with the same Channel ID.
        let logicalAddresses = Set(
            playbackLines(for: channel).map { $0.streamURL.absoluteString }
        )
        var updated = recentURLs.filter { !logicalAddresses.contains($0) }
        updated.insert(address, at: 0)
        recentURLs = Array(updated.prefix(30))
        persistPreferences()
        // 最近播放只是本机的轻量偏好，不是播放列表配置变更。此前这里
        // 会触发 iCloud 调度并把完整频道库重新序列化发送给 Apple Watch，
        // 用户点卡片时这些工作与页面转场抢主线程，造成明显卡顿。
    }

    func clearRecentChannels() {
        recentURLs = []
        persistPreferences()
        markConfigurationChanged()
    }

    func importPlaylist(data: Data, baseURL: URL? = nil, customEPGURLs: [URL] = []) async {
        await importLocalConfiguration(
            data: data,
            name: AppLanguage.localizedFormat(
                "本地配置 %@",
                Date().formatted(date: .numeric, time: .shortened)
            ),
            baseURL: baseURL,
            customEPGURLs: customEPGURLs
        )
    }

    func reportPlaylistImportError(_ error: Error) {
        lastError = AppLanguage.localizedFormat(
            "导入失败：%@",
            Self.userFacingPlaylistError(error)
        )
    }

    func importLocalConfiguration(
        data: Data,
        name: String,
        baseURL: URL? = nil,
        customEPGURLs: [URL] = []
    ) async {
        beginConfigurationImport()
        defer { endConfigurationImport() }
        do {
            let result = try await parser.parsePlaylistInBackground(
                data: data,
                baseURL: baseURL
            )
            let configuration = PlaylistConfiguration(
                name: normalizedConfigurationName(name, fallback: AppLanguage.localized("本地配置")),
                kind: .local,
                channels: result.channels,
                epgURLs: customEPGURLs.isEmpty ? result.epgURLs : customEPGURLs
            )
            await addAndActivatePrepared(configuration)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func importPlaylist(from url: URL, customEPGURLs: [URL] = []) async {
        await importPlaylist(from: url.absoluteString, customEPGURLs: customEPGURLs)
    }

    func importPlaylist(from rawAddress: String, customEPGURLs: [URL] = []) async {
        await addSubscriptionConfiguration(
            name: "",
            address: rawAddress,
            customEPGURLs: customEPGURLs
        )
    }

    func addSubscriptionConfiguration(
        name: String,
        address rawAddress: String,
        customEPGURLs: [URL] = [],
        isWebImportProtected: Bool = false,
        expirationDate: Date? = nil,
        requestHeaders: [String: String] = [:],
        proxy: StreamProxyConfiguration? = nil,
        hlsProxyMode: HLSProxyMode = .off,
        rtspTransport: RTSPTransportPreference? = nil,
        rtspRedirectDetectionEnabled: Bool? = nil,
        bufferPolicy: PlaybackBufferPolicy? = nil,
        automaticRefreshEnabled: Bool = false,
        automaticRefreshInterval: TimeInterval = 8 * 60 * 60
    ) async {
        guard expirationDate.map({ Date() < $0 }) ?? true else {
            lastError = AppLanguage.localized("该配置已过期，无法导入。")
            return
        }
        beginConfigurationImport()
        defer { endConfigurationImport() }
        do {
            let download = try await downloadPlaylist(
                rawAddress,
                requestHeaders: requestHeaders,
                proxy: proxy
            )
            let parsed = try await parseDownloadedPlaylist(download, requestedName: name)
            let channels = await Self.applyConfigurationDefaultsInBackground(
                to: parsed.channels,
                requestHeaders: requestHeaders,
                proxy: proxy,
                hlsProxyMode: hlsProxyMode,
                rtspTransport: rtspTransport,
                rtspRedirectDetectionEnabled: rtspRedirectDetectionEnabled,
                bufferPolicy: bufferPolicy
            )
            let configuration = PlaylistConfiguration(
                name: normalizedConfigurationName(
                    name,
                    fallback: download.location.url.host ?? AppLanguage.localized("订阅配置")
                ),
                kind: .subscription,
                channels: channels,
                sourceAddress: rawAddress,
                epgURLs: customEPGURLs.isEmpty ? parsed.epgURLs : customEPGURLs,
                isWebImportProtected: isWebImportProtected,
                expirationDate: expirationDate,
                requestHeaders: requestHeaders,
                proxy: proxy,
                hlsProxyMode: hlsProxyMode,
                rtspTransport: rtspTransport,
                rtspRedirectDetectionEnabled: rtspRedirectDetectionEnabled,
                bufferPolicy: bufferPolicy,
                automaticRefreshEnabled: automaticRefreshEnabled,
                automaticRefreshInterval: automaticRefreshInterval,
                lastAutomaticRefreshAt: automaticRefreshEnabled ? Date() : nil
            )
            await addAndActivatePrepared(configuration)
        } catch {
            lastError = AppLanguage.localizedFormat(
                "导入失败：%@",
                Self.userFacingPlaylistError(error)
            )
        }
    }

    func addRSSConfiguration(
        name: String,
        address rawAddress: String,
        requestHeaders: [String: String] = [:],
        proxy: StreamProxyConfiguration? = nil
    ) async {
        beginConfigurationImport()
        defer { endConfigurationImport() }
        do {
            let trimmedAddress = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            let download = try await downloadPlaylist(
                trimmedAddress,
                requestHeaders: requestHeaders,
                proxy: proxy
            )
            let document = try await parseRSSDocument(download)
            let channels = await Self.applyConfigurationDefaultsInBackground(
                to: document.videoChannels,
                requestHeaders: requestHeaders,
                proxy: proxy,
                hlsProxyMode: .off,
                rtspTransport: nil,
                rtspRedirectDetectionEnabled: nil,
                bufferPolicy: nil
            )
            guard !channels.isEmpty else { throw M3UParserError.emptyPlaylist }
            let configuration = PlaylistConfiguration(
                name: normalizedConfigurationName(
                    name,
                    fallback: document.title.isEmpty
                        ? (download.responseURL.host ?? AppLanguage.localized("RSS 视频订阅"))
                        : document.title
                ),
                kind: .rss,
                channels: channels,
                totalItemCount: channels.count,
                sourceAddress: trimmedAddress,
                requestHeaders: requestHeaders,
                proxy: proxy
            )
            await addAndActivatePrepared(configuration)
        } catch {
            lastError = AppLanguage.localizedFormat(
                "RSS 导入失败：%@",
                Self.userFacingPlaylistError(error)
            )
        }
    }

    func loadRSSFeed(address: String, configurationID: UUID) async throws -> RSSFeedDocument {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind == .rss,
              !configuration.isExpired else {
            throw IPTVConfigurationError.missingConfiguration
        }
        let download = try await downloadPlaylist(
            address,
            requestHeaders: configuration.requestHeaders,
            proxy: configuration.proxy
        )
        return try await parseRSSDocument(download)
    }

    func addXtreamConfiguration(
        name: String,
        server: String,
        username: String,
        password: String
    ) async {
        beginConfigurationImport()
        defer { endConfigurationImport() }
        do {
            let configurationID = UUID()
            let result = try await IPTVConfigurationService.loadXtream(
                server: server,
                username: username,
                password: password
            )
            ConfigurationCredentialVault.set(password, for: configurationID)
            await addAndActivatePrepared(
                PlaylistConfiguration(
                    id: configurationID,
                    name: normalizedConfigurationName(name, fallback: "Xtream Codes"),
                    kind: .legacySourceB,
                    channels: result.channels,
                    sourceAddress: server,
                    username: username,
                    epgURLs: result.epgURLs
                )
            )
        } catch {
            lastError = AppLanguage.localizedFormat(
                "Xtream Codes 导入失败：%@",
                error.localizedDescription
            )
        }
    }

    func addSingleChannelConfiguration(
        name: String,
        address: String,
        requestHeaders: [String: String] = [:],
        proxy: StreamProxyConfiguration? = nil,
        hlsProxyMode: HLSProxyMode = .off,
        rtspTransport: RTSPTransportPreference? = nil,
        rtspRedirectDetectionEnabled: Bool? = nil,
        bufferPolicy: PlaybackBufferPolicy? = nil
    ) {
        let channelName = normalizedConfigurationName(name, fallback: AppLanguage.localized("单频道"))
        guard let location = MediaAddress.parse(address),
              let scheme = location.url.scheme?.lowercased(),
              MediaAddress.supportedSchemes.contains(scheme) else {
            lastError = AppLanguage.localized("请输入有效的频道播放地址。")
            return
        }
        let headers = requestHeaders.merging(location.headers) { _, inlineValue in inlineValue }
        let channel = Channel(
            name: channelName,
            streamURL: location.url,
            group: AppLanguage.localized("单频道"),
            httpHeaders: headers,
            proxyOverride: proxy,
            hlsProxyMode: hlsProxyMode,
            rtspTransport: rtspTransport,
            rtspRedirectDetectionEnabled: rtspRedirectDetectionEnabled,
            bufferPolicy: bufferPolicy
        )
        addAndActivate(
            PlaylistConfiguration(
                name: channelName,
                kind: .single,
                channels: [channel],
                sourceAddress: address.trimmingCharacters(in: .whitespacesAndNewlines),
                requestHeaders: headers,
                proxy: proxy,
                hlsProxyMode: hlsProxyMode,
                rtspTransport: rtspTransport,
                rtspRedirectDetectionEnabled: rtspRedirectDetectionEnabled,
                bufferPolicy: bufferPolicy
            )
        )
    }

    func addStalkerConfiguration(
        name: String,
        portal: String,
        macAddress: String
    ) async {
        beginConfigurationImport()
        defer { endConfigurationImport() }
        do {
            let configurationID = UUID()
            let channels = try await IPTVConfigurationService.loadStalker(
                portal: portal,
                macAddress: macAddress,
                configurationID: configurationID
            )
            await addAndActivatePrepared(
                PlaylistConfiguration(
                    id: configurationID,
                    name: normalizedConfigurationName(name, fallback: "Stalker Portal"),
                    kind: .legacySourceA,
                    channels: channels,
                    sourceAddress: portal,
                    macAddress: IPTVConfigurationService.normalizedMAC(macAddress)
                )
            )
        } catch {
            lastError = AppLanguage.localizedFormat(
                "Stalker Portal 导入失败：%@",
                error.localizedDescription
            )
        }
    }

    func addJellyfinConfiguration(
        name: String,
        server: String,
        username: String,
        password: String,
        apiKey: String = "",
        legacyListStyle: LegacyListStyle = .classic
    ) async {
        await addMediaServerConfiguration(
            kind: .legacyLibraryA,
            name: name,
            server: server,
            username: username,
            password: password,
            apiKey: apiKey,
            legacyListStyle: legacyListStyle
        )
    }

    func addMovieClawConfiguration(
        name: String,
        server: String,
        username: String,
        password: String,
        apiKey: String = "",
        legacyListStyle: LegacyListStyle = .classic
    ) async {
        await addMediaServerConfiguration(
            kind: .movieClaw,
            name: name,
            server: server,
            username: username,
            password: password,
            apiKey: apiKey,
            legacyListStyle: legacyListStyle
        )
    }

    func addEmbyConfiguration(
        name: String,
        server: String,
        username: String,
        password: String,
        apiKey: String = "",
        isWebImportProtected: Bool = false,
        legacyListStyle: LegacyListStyle = .classic
    ) async {
        await addEmbyCompatibleConfiguration(
            kind: .legacyLibraryB,
            name: name,
            server: server,
            username: username,
            password: password,
            apiKey: apiKey,
            isWebImportProtected: isWebImportProtected,
            legacyListStyle: legacyListStyle
        )
    }

    func addEmbyCompatibleConfiguration(
        kind: PlaylistConfigurationKind,
        name: String,
        server: String,
        username: String,
        password: String,
        apiKey: String = "",
        isWebImportProtected: Bool = false,
        legacyListStyle: LegacyListStyle = .classic
    ) async {
        guard kind.isEmbyCompatible else {
            lastError = AppLanguage.localized("不支持的媒体服务器")
            return
        }
        await addMediaServerConfiguration(
            kind: kind,
            name: name,
            server: server,
            username: username,
            password: password,
            apiKey: apiKey,
            isWebImportProtected: isWebImportProtected,
            legacyListStyle: legacyListStyle
        )
    }

    func addFeiniuVideoConfiguration(
        name: String,
        server: String,
        username: String,
        password: String,
        legacyListStyle: LegacyListStyle = .classic
    ) async {
        beginConfigurationImport()
        defer { endConfigurationImport() }
        do {
            let configurationID = UUID()
            let result = try await FeiniuVideoService.authenticate(
                server: server,
                username: username,
                password: password,
                configurationID: configurationID
            )
            let storedServer = try FeiniuVideoService.canonicalServerAddress(server)
            ConfigurationCredentialVault.set(result.token, for: configurationID)
            await addAndActivatePrepared(
                PlaylistConfiguration(
                    id: configurationID,
                    name: normalizedConfigurationName(name, fallback: PlaylistConfigurationKind.legacyLibraryC.title),
                    kind: .legacyLibraryC,
                    channels: result.channels,
                    totalItemCount: result.totalItemCount,
                    sourceAddress: storedServer,
                    username: result.username,
                    legacyListStyle: legacyListStyle
                )
            )
        } catch {
            lastError = AppLanguage.localizedFormat(
                "%@ 登录失败：%@",
                PlaylistConfigurationKind.legacyLibraryC.title,
                error.localizedDescription
            )
        }
    }

    func addWebDAVConfiguration(
        name: String,
        server: String,
        username: String,
        password: String
    ) async {
        beginConfigurationImport()
        defer { endConfigurationImport() }
        do {
            let configurationID = UUID()
            let baseURL = try WebDAVService.normalizedBaseURL(server)
            let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await WebDAVService.list(
                url: baseURL,
                username: cleanUsername,
                password: password
            )
            if !password.isEmpty {
                ConfigurationCredentialVault.set(password, for: configurationID)
            }
            await addAndActivatePrepared(
                PlaylistConfiguration(
                    id: configurationID,
                    name: normalizedConfigurationName(name, fallback: "WebDAV"),
                    kind: .legacySourceC,
                    sourceAddress: baseURL.absoluteString,
                    username: cleanUsername.isEmpty ? nil : cleanUsername
                )
            )
        } catch {
            lastError = AppLanguage.localizedFormat(
                "WebDAV 连接失败：%@",
                error.localizedDescription
            )
        }
    }

    func addPlexConfiguration(name: String, server: String, token: String) async {
        beginConfigurationImport()
        defer { endConfigurationImport() }
        do {
            let configurationID = UUID()
            let result = try await PlexConfigurationService.loadLibrary(
                server: server,
                token: token,
                configurationID: configurationID
            )
            ConfigurationCredentialVault.set(token, for: configurationID)
            await addAndActivatePrepared(
                PlaylistConfiguration(
                    id: configurationID,
                    name: normalizedConfigurationName(name, fallback: "Plex"),
                    kind: .legacyLibraryD,
                    channels: result.channels,
                    totalItemCount: result.channels.count,
                    sourceAddress: result.server.absoluteString
                )
            )
        } catch {
            lastError = "Plex 连接失败：\(error.localizedDescription)"
        }
    }

    private func addMediaServerConfiguration(
        kind: PlaylistConfigurationKind,
        name: String,
        server: String,
        username: String,
        password: String,
        apiKey: String,
        isWebImportProtected: Bool = false,
        legacyListStyle: LegacyListStyle = .classic
    ) async {
        beginConfigurationImport()
        defer { endConfigurationImport() }
        do {
            let configurationID = UUID()
            let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            // Load a small real media page before activation. This prevents a
            // blank home shell while avoiding the old wait for the full index.
            // The remaining index is filled by the background pass below.
            let result = if trimmedAPIKey.isEmpty {
                try await JellyfinConfigurationService.authenticate(
                    server: server,
                    username: username,
                    password: password,
                    configurationID: configurationID,
                    serverKind: kind,
                    loadInitialItems: true,
                    initialItemLimit: 12,
                    loadServerName: false
                )
            } else {
                try await JellyfinConfigurationService.authenticateWithAPIKey(
                    server: server,
                    apiKey: trimmedAPIKey,
                    preferredUsername: username,
                    configurationID: configurationID,
                    serverKind: kind,
                    loadInitialItems: true,
                    initialItemLimit: 12,
                    loadServerName: false
                )
            }
            // Store the access token rather than the account password. Refresh
            // and playback can then work without persisting the user's secret.
            ConfigurationCredentialVault.set(result.token, for: configurationID)
            await addAndActivatePrepared(
                PlaylistConfiguration(
                    id: configurationID,
                    name: normalizedConfigurationName(
                        name,
                        fallback: result.serverName ?? kind.title
                    ),
                    kind: kind,
                    channels: result.channels,
                    totalItemCount: result.totalItemCount,
                    sourceAddress: server,
                    username: result.username,
                    mediaServerUserID: result.userID,
                    isWebImportProtected: isWebImportProtected,
                    legacyListStyle: legacyListStyle,
                    serverReportedName: result.serverName
                )
            )
            // Fill the channel index and disk caches after the configuration
            // is visible. This keeps the first frame responsive while still
            // preserving the existing complete refresh behavior.
            Task { [weak self] in
                await self?.refreshMediaServerIndex(configurationID)
            }
        } catch {
            lastError = AppLanguage.localizedFormat(
                "%@ 登录失败：%@",
                kind.title,
                error.localizedDescription
            )
        }
    }

    func addAggregateConfiguration(name: String, memberIDs: [UUID]) {
        let validIDs = orderedAggregateMemberIDs(memberIDs)
        guard !validIDs.isEmpty else {
            lastError = AppLanguage.localized("请至少选择一个要聚合的配置。")
            return
        }
        addAndActivate(
            PlaylistConfiguration(
                name: normalizedConfigurationName(name, fallback: AppLanguage.localized("聚合配置")),
                kind: .aggregate,
                memberIDs: validIDs
            )
        )
    }

    func selectConfiguration(_ id: UUID) {
        guard let configuration = configurations.first(where: { $0.id == id }) else { return }
        guard !configuration.isExpired else {
            lastError = AppLanguage.localized("该配置已过期，不能继续使用。")
            return
        }
        guard activeConfigurationID != id else { return }
        activeConfigurationID = id
        UserDefaults.standard.set(id.uuidString, forKey: activeConfigurationStorageKey)
        activePresentationTask?.cancel()

        // Normal IPTV lists are cheap enough to publish immediately. Sending
        // every selection through a detached task kept the old source visible
        // until the complete index build finished, which made the tap feel
        // unresponsive. Only genuinely oversized lists keep the background
        // preparation path.
        let estimatedChannelCount: Int
        if configuration.kind == .aggregate {
            let memberIDs = Set(configuration.memberIDs)
            estimatedChannelCount = configurations.lazy
                .filter { memberIDs.contains($0.id) && !$0.isExpired }
                .reduce(into: 0) { $0 += $1.channels.count }
        } else {
            estimatedChannelCount = configuration.channels.count
        }
        if configuration.kind.usesMediaLibraryBrowser
            || shouldIdentifyLegacyMediaServer(configuration)
            || estimatedChannelCount <= 12_000 {
            applyActiveConfiguration(persistChannelSnapshot: false)
            return
        }

        let configurationSnapshot = configurations
        let favoriteSnapshot = favoriteURLs
        let recentSnapshot = recentURLs
        activePresentationTask = Task { [weak self] in
            let prepared = await Task.detached(priority: .userInitiated) {
                Self.prepareActivePresentation(
                    configurations: configurationSnapshot,
                    activeConfigurationID: id,
                    favoriteURLs: favoriteSnapshot,
                    recentURLs: recentSnapshot
                )
            }.value
            guard !Task.isCancelled,
                  let self,
                  self.activeConfigurationID == id else { return }
            self.activePresentationTask = nil
            self.applyPreparedActivePresentation(
                prepared,
                persistChannelSnapshot: false
            )
        }
    }

    /// Reorders saved configurations without changing the selected source or
    /// rebuilding its current channel presentation.
    func moveConfigurations(from source: IndexSet, to destination: Int) {
        configurations.move(fromOffsets: source, toOffset: destination)
        persistConfigurations()
        markConfigurationChanged()
    }

    func renameConfiguration(_ id: UUID, name: String) {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        configurations[index].name = normalizedConfigurationName(name, fallback: configurations[index].kind.title)
        persistConfigurations()
        markConfigurationChanged()
    }

    func setPrivateServer(_ id: UUID, isPrivate: Bool) {
        guard let index = configurations.firstIndex(where: { $0.id == id }),
              configurations[index].kind.usesMediaLibraryBrowser else { return }
        configurations[index].isPrivateServer = isPrivate
        persistConfigurations()
        markConfigurationChanged()
    }

    func setServerIcon(_ id: UUID, selection: RoveServerIconSelection?) {
        guard let index = configurations.firstIndex(where: { $0.id == id }),
              configurations[index].kind.usesMediaLibraryBrowser else { return }
        configurations[index].serverIcon = selection
        persistConfigurations()
        markConfigurationChanged()
    }

    func setServerRemark(_ id: UUID, remark: String?) {
        guard let index = configurations.firstIndex(where: { $0.id == id }),
              configurations[index].kind.usesMediaLibraryBrowser else { return }
        let normalized = remark?.trimmingCharacters(in: .whitespacesAndNewlines)
        configurations[index].serverRemark = normalized?.isEmpty == false ? normalized : nil
        persistConfigurations()
        markConfigurationChanged()
    }

    func refreshServerReportedName(_ id: UUID) async {
        guard let configuration = configurations.first(where: { $0.id == id }),
              configuration.kind.usesMediaLibraryBrowser,
              configuration.serverReportedName == nil,
              let server = configuration.sourceAddress,
              let reportedName = await JellyfinConfigurationService.serverName(server: server),
              let index = configurations.firstIndex(where: { $0.id == id }),
              configurations[index].serverReportedName == nil
        else { return }
        configurations[index].serverReportedName = reportedName
        persistConfigurations()
        markConfigurationChanged()
    }

    func setServerPreloadPreference(_ id: UUID, preference: RoveServerPreloadPreference) {
        guard let index = configurations.firstIndex(where: { $0.id == id }),
              configurations[index].kind.usesMediaLibraryBrowser else { return }
        configurations[index].preloadPreference = preference
        persistConfigurations()
        markConfigurationChanged()
    }

    func setLibraryNotificationPreferences(
        _ id: UUID,
        preferences: RoveLibraryNotificationPreferences
    ) {
        guard let index = configurations.firstIndex(where: { $0.id == id }),
              configurations[index].kind.usesMediaLibraryBrowser else { return }
        configurations[index].libraryNotifications = preferences
        persistConfigurations()
        markConfigurationChanged()
    }

    @discardableResult
    func updateServerRoutes(
        _ id: UUID,
        routes: [String],
        activeRoute: String,
        routeNames: [String: String] = [:],
        automaticallySelectBestRoute: Bool? = nil,
        automaticallyFetchBackupRoutes: Bool? = nil
    ) async -> Bool {
        guard let index = configurations.firstIndex(where: { $0.id == id }),
              configurations[index].kind.usesMediaLibraryBrowser else { return false }

        var seen = Set<String>()
        let normalizedRoutes = routes.compactMap { raw -> String? in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let components = URLComponents(string: trimmed),
                  ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
                  components.host?.isEmpty == false,
                  seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
        let selectedRoute = activeRoute.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedRoutes.contains(selectedRoute) else {
            lastError = AppLanguage.localized("请选择有效的服务器线路。")
            return false
        }

        let previous = configurations[index]
        configurations[index].serverRoutes = normalizedRoutes
        configurations[index].serverRouteNames = normalizedRoutes.reduce(into: [:]) { result, route in
            let name = routeNames[route]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !name.isEmpty { result[route] = String(name.prefix(100)) }
        }
        configurations[index].sourceAddress = selectedRoute
        if let automaticallySelectBestRoute {
            configurations[index].automaticallySelectBestServerRoute = automaticallySelectBestRoute
        }
        if let automaticallyFetchBackupRoutes {
            configurations[index].automaticallyFetchBackupRoutes = automaticallyFetchBackupRoutes
        }
        persistConfigurations()
        markConfigurationChanged()

        guard previous.sourceAddress != selectedRoute else {
            lastError = nil
            return true
        }

        await refreshConfiguration(id)
        guard lastError == nil else {
            guard let rollbackIndex = configurations.firstIndex(where: { $0.id == id }) else {
                return false
            }
            let routeError = lastError
            configurations[rollbackIndex] = previous
            persistConfigurations()
            markConfigurationChanged()
            lastError = routeError
            return false
        }
        return true
    }

    /// Fetches the server-published alternate domains and merges them into
    /// the existing route list without changing the active route or removing
    /// user-entered lines.
    @discardableResult
    func fetchAndMergeServerRoutes(_ id: UUID) async -> [String]? {
        guard let index = configurations.firstIndex(where: { $0.id == id }),
              configurations[index].kind.usesMediaLibraryBrowser,
              let server = configurations[index].sourceAddress else { return nil }
        do {
            let discovered = try await RoveServerRouteDiscoveryService.fetch(from: server)
            var seen = Set<String>()
            let merged = (configurations[index].serverRoutes + [server] + discovered)
                .compactMap { raw -> String? in
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    let comparisonKey = trimmed.hasSuffix("/")
                        ? String(trimmed.dropLast()).lowercased()
                        : trimmed.lowercased()
                    guard !trimmed.isEmpty, seen.insert(comparisonKey).inserted else { return nil }
                    return trimmed
                }
            configurations[index].serverRoutes = merged
            configurations[index].serverRouteNames = configurations[index].serverRouteNames.filter {
                merged.contains($0.key)
            }
            persistConfigurations()
            markConfigurationChanged()
            lastError = nil
            return merged
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Returns the password kept in the keychain for an Xtream configuration.
    /// The password is intentionally never persisted in PlaylistConfiguration.
    func configurationPassword(_ id: UUID) -> String? {
        ConfigurationCredentialVault.password(for: id)
    }

    /// Updates an existing configuration in place. Remote configurations are
    /// reloaded before replacing their stored channels so an edit cannot leave
    /// the user with a saved URL that no longer matches the channel list.
    func editConfiguration(
        _ id: UUID,
        name: String,
        address: String = "",
        username: String = "",
        password: String = "",
        apiKey: String = "",
        macAddress: String = "",
        memberIDs: [UUID] = [],
        customEPGURLs: [URL] = [],
        requestHeaders: [String: String]? = nil,
        proxy: StreamProxyConfiguration? = nil,
        hlsProxyMode: HLSProxyMode? = nil,
        rtspTransport: RTSPTransportPreference? = nil,
        rtspRedirectDetectionEnabled: Bool? = nil,
        bufferPolicy: PlaybackBufferPolicy? = nil,
        automaticRefreshEnabled: Bool? = nil,
        automaticRefreshInterval: TimeInterval? = nil,
        legacyListStyle: LegacyListStyle? = nil
    ) async {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        let existing = configurations[index]
        guard existing.isWebImportProtected != true else {
            lastError = AppLanguage.localized("该配置不可编辑；如需更换，请删除后重新导入。")
            return
        }
        var updatedConfiguration = existing
        do {
            switch existing.kind {
            case .subscription:
                let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedAddress.isEmpty else { throw URLError(.badURL) }
                let effectiveHeaders = requestHeaders ?? existing.requestHeaders
                let effectiveHLSProxyMode = hlsProxyMode ?? existing.hlsProxyMode
                let download = try await downloadPlaylist(
                    trimmedAddress,
                    requestHeaders: effectiveHeaders,
                    proxy: proxy
                )
                let result = try await parseDownloadedPlaylist(download, requestedName: name)
                updatedConfiguration.channels = await Self.applyConfigurationDefaultsInBackground(
                    to: result.channels,
                    requestHeaders: effectiveHeaders,
                    proxy: proxy,
                    hlsProxyMode: effectiveHLSProxyMode,
                    rtspTransport: rtspTransport,
                    rtspRedirectDetectionEnabled: rtspRedirectDetectionEnabled,
                    bufferPolicy: bufferPolicy
                )
                updatedConfiguration.sourceAddress = trimmedAddress
                updatedConfiguration.epgURLs = customEPGURLs.isEmpty ? result.epgURLs : customEPGURLs
                updatedConfiguration.username = nil
                updatedConfiguration.macAddress = nil
                updatedConfiguration.requestHeaders = effectiveHeaders
                updatedConfiguration.proxy = proxy
                updatedConfiguration.hlsProxyMode = effectiveHLSProxyMode
                updatedConfiguration.rtspTransport = rtspTransport
                updatedConfiguration.rtspRedirectDetectionEnabled = rtspRedirectDetectionEnabled
                updatedConfiguration.bufferPolicy = bufferPolicy
                if let automaticRefreshEnabled {
                    let interval = max(
                        15 * 60,
                        automaticRefreshInterval ?? existing.automaticRefreshInterval
                    )
                    updatedConfiguration.automaticRefreshEnabled = automaticRefreshEnabled
                    updatedConfiguration.automaticRefreshInterval = interval
                    if !automaticRefreshEnabled {
                        updatedConfiguration.lastAutomaticRefreshAt = nil
                    } else if !existing.automaticRefreshEnabled
                                || interval != existing.automaticRefreshInterval {
                        updatedConfiguration.lastAutomaticRefreshAt = Date()
                    }
                }
            case .rss:
                let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedAddress.isEmpty else { throw URLError(.badURL) }
                let effectiveHeaders = requestHeaders ?? existing.requestHeaders
                let download = try await downloadPlaylist(
                    trimmedAddress,
                    requestHeaders: effectiveHeaders,
                    proxy: proxy
                )
                let document = try await parseRSSDocument(download)
                let channels = await Self.applyConfigurationDefaultsInBackground(
                    to: document.videoChannels,
                    requestHeaders: effectiveHeaders,
                    proxy: proxy,
                    hlsProxyMode: .off,
                    rtspTransport: rtspTransport,
                    rtspRedirectDetectionEnabled: rtspRedirectDetectionEnabled,
                    bufferPolicy: bufferPolicy
                )
                guard !channels.isEmpty else { throw M3UParserError.emptyPlaylist }
                updatedConfiguration.channels = channels
                updatedConfiguration.totalItemCount = channels.count
                updatedConfiguration.sourceAddress = trimmedAddress
                updatedConfiguration.requestHeaders = effectiveHeaders
                updatedConfiguration.proxy = proxy
                updatedConfiguration.rtspTransport = rtspTransport
                updatedConfiguration.rtspRedirectDetectionEnabled = rtspRedirectDetectionEnabled
                updatedConfiguration.bufferPolicy = bufferPolicy
            case .single:
                let channelName = normalizedConfigurationName(name, fallback: AppLanguage.localized("单频道"))
                guard let location = MediaAddress.parse(address),
                      let scheme = location.url.scheme?.lowercased(),
                      MediaAddress.supportedSchemes.contains(scheme) else {
                    throw URLError(.badURL)
                }
                let effectiveHeaders = (requestHeaders ?? existing.requestHeaders)
                    .merging(location.headers) { _, inlineValue in inlineValue }
                let effectiveHLSProxyMode = hlsProxyMode ?? existing.hlsProxyMode
                updatedConfiguration.channels = [Channel(
                    name: channelName,
                    streamURL: location.url,
                    group: AppLanguage.localized("单频道"),
                    httpHeaders: effectiveHeaders,
                    proxyOverride: proxy,
                    hlsProxyMode: effectiveHLSProxyMode,
                    rtspTransport: rtspTransport,
                    rtspRedirectDetectionEnabled: rtspRedirectDetectionEnabled,
                    bufferPolicy: bufferPolicy
                )]
                updatedConfiguration.sourceAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
                updatedConfiguration.requestHeaders = effectiveHeaders
                updatedConfiguration.proxy = proxy
                updatedConfiguration.hlsProxyMode = effectiveHLSProxyMode
                updatedConfiguration.rtspTransport = rtspTransport
                updatedConfiguration.rtspRedirectDetectionEnabled = rtspRedirectDetectionEnabled
                updatedConfiguration.bufferPolicy = bufferPolicy
            case .legacySourceB:
                let server = address.trimmingCharacters(in: .whitespacesAndNewlines)
                let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
                let secret = password.isEmpty
                    ? (ConfigurationCredentialVault.password(for: id) ?? "")
                    : password
                guard !server.isEmpty, !user.isEmpty, !secret.isEmpty else {
                    throw IPTVConfigurationError.missingCredentials
                }
                let result = try await IPTVConfigurationService.loadXtream(
                    server: server,
                    username: user,
                    password: secret
                )
                ConfigurationCredentialVault.set(secret, for: id)
                updatedConfiguration.channels = result.channels
                updatedConfiguration.sourceAddress = server
                updatedConfiguration.username = user
                updatedConfiguration.epgURLs = result.epgURLs
            case .legacySourceA:
                let portal = address.trimmingCharacters(in: .whitespacesAndNewlines)
                let mac = IPTVConfigurationService.normalizedMAC(macAddress)
                guard !portal.isEmpty, !mac.isEmpty else {
                    throw IPTVConfigurationError.missingCredentials
                }
                updatedConfiguration.channels = try await IPTVConfigurationService.loadStalker(
                    portal: portal,
                    macAddress: mac,
                    configurationID: id
                )
                updatedConfiguration.sourceAddress = portal
                updatedConfiguration.macAddress = mac
            case .legacyLibraryA, .movieClaw, .legacyLibraryB, .zspaceVideo:
                let server = address.trimmingCharacters(in: .whitespacesAndNewlines)
                let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                let existingServer = existing.sourceAddress?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let existingUser = existing.username?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !server.isEmpty else {
                    throw IPTVConfigurationError.missingCredentials
                }
                if !trimmedAPIKey.isEmpty {
                    let result = try await JellyfinConfigurationService.authenticateWithAPIKey(
                        server: server,
                        apiKey: trimmedAPIKey,
                        preferredUsername: user,
                        configurationID: id,
                        serverKind: existing.kind
                    )
                    ConfigurationCredentialVault.set(result.token, for: id)
                    updatedConfiguration.channels = result.channels
                    updatedConfiguration.totalItemCount = result.totalItemCount
                    updatedConfiguration.username = result.username
                    updatedConfiguration.mediaServerUserID = result.userID
                    updatedConfiguration.serverReportedName = result.serverName
                } else if password.isEmpty,
                          server == existingServer,
                          user == existingUser {
                    // A metadata-only edit must not refresh a large media
                    // server library. Keep the existing token and cached page.
                } else if password.isEmpty {
                    guard let token = ConfigurationCredentialVault.password(for: id) else {
                        throw IPTVConfigurationError.missingCredentials
                    }
                    let result = try await JellyfinConfigurationService.refresh(
                        server: server,
                        token: token,
                        preferredUsername: user,
                        knownUserID: existing.mediaServerUserID,
                        configurationID: id,
                        serverKind: existing.kind
                    )
                    updatedConfiguration.channels = result.channels
                    updatedConfiguration.totalItemCount = result.totalItemCount
                    updatedConfiguration.mediaServerUserID = result.userID
                    updatedConfiguration.serverReportedName = result.serverName
                } else {
                    guard !user.isEmpty else { throw IPTVConfigurationError.missingCredentials }
                    let result = try await JellyfinConfigurationService.authenticate(
                        server: server,
                        username: user,
                        password: password,
                        configurationID: id,
                        serverKind: existing.kind
                    )
                    ConfigurationCredentialVault.set(result.token, for: id)
                    updatedConfiguration.channels = result.channels
                    updatedConfiguration.totalItemCount = result.totalItemCount
                    updatedConfiguration.username = result.username
                    updatedConfiguration.mediaServerUserID = result.userID
                    updatedConfiguration.serverReportedName = result.serverName
                }
                updatedConfiguration.sourceAddress = server
            case .legacyLibraryD:
                let server = existing.sourceAddress ?? address
                guard let token = ConfigurationCredentialVault.password(for: id) else {
                    throw IPTVConfigurationError.missingCredentials
                }
                let result = try await PlexConfigurationService.loadLibrary(
                    server: server,
                    token: token,
                    configurationID: id
                )
                updatedConfiguration.channels = result.channels
                updatedConfiguration.totalItemCount = result.channels.count
                updatedConfiguration.sourceAddress = result.server.absoluteString
            case .legacyLibraryC:
                let server = try FeiniuVideoService.canonicalServerAddress(address)
                let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
                let existingServer = existing.sourceAddress?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let existingUser = existing.username?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !server.isEmpty, !user.isEmpty else {
                    throw IPTVConfigurationError.missingCredentials
                }
                if password.isEmpty, server == existingServer, user == existingUser {
                    // Presentation-only edits keep the existing access token.
                } else if password.isEmpty {
                    guard let token = ConfigurationCredentialVault.password(for: id) else {
                        throw IPTVConfigurationError.missingCredentials
                    }
                    let result = try await FeiniuVideoService.refresh(
                        server: server,
                        token: token,
                        preferredUsername: user,
                        configurationID: id
                    )
                    updatedConfiguration.channels = result.channels
                    updatedConfiguration.totalItemCount = result.totalItemCount
                    updatedConfiguration.username = result.username
                } else {
                    let result = try await FeiniuVideoService.authenticate(
                        server: server,
                        username: user,
                        password: password,
                        configurationID: id
                    )
                    ConfigurationCredentialVault.set(result.token, for: id)
                    updatedConfiguration.channels = result.channels
                    updatedConfiguration.totalItemCount = result.totalItemCount
                    updatedConfiguration.username = result.username
                }
                updatedConfiguration.sourceAddress = server
            case .legacySourceC:
                let baseURL = try WebDAVService.normalizedBaseURL(address)
                let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
                let secret = password.isEmpty
                    ? (ConfigurationCredentialVault.password(for: id) ?? "")
                    : password
                _ = try await WebDAVService.list(
                    url: baseURL,
                    username: user,
                    password: secret
                )
                if !password.isEmpty {
                    ConfigurationCredentialVault.set(password, for: id)
                }
                updatedConfiguration.sourceAddress = baseURL.absoluteString
                updatedConfiguration.username = user.isEmpty ? nil : user
            case .aggregate:
                let validIDs = orderedAggregateMemberIDs(memberIDs)
                guard !validIDs.isEmpty else {
                    lastError = AppLanguage.localized("请至少选择一个要聚合的配置。")
                    return
                }
                updatedConfiguration.memberIDs = validIDs
            case .local:
                break
            }

            updatedConfiguration.name = normalizedConfigurationName(
                name,
                fallback: existing.kind.title
            )
            if existing.kind.usesMediaLibraryBrowser, let legacyListStyle {
                updatedConfiguration.legacyListStyle = legacyListStyle
            }
            updatedConfiguration.updatedAt = Date()
            try await commitPreparedConfiguration(updatedConfiguration)
            if activeConfigurationID == id
                || activeConfiguration?.memberIDs.contains(id) == true {
                applyActiveConfiguration()
            }
            lastError = nil
            markConfigurationChanged()
        } catch {
            lastError = AppLanguage.localizedFormat("保存配置失败：%@", error.localizedDescription)
        }
    }

    @discardableResult
    func deleteConfiguration(_ id: UUID) async -> Bool {
        guard configurations.contains(where: { $0.id == id }) else { return false }

        let previousActiveID = activeConfigurationID
        let activeAggregateContainsDeletedConfiguration = activeConfiguration?
            .memberIDs.contains(id) == true

        var updatedConfigurations = configurations
        updatedConfigurations.removeAll { $0.id == id }
        for index in updatedConfigurations.indices
        where updatedConfigurations[index].kind == .aggregate {
            updatedConfigurations[index].memberIDs.removeAll { $0 == id }
        }
        let deletionConfigurations = updatedConfigurations

        let updatedActiveID = previousActiveID == id
            ? deletionConfigurations.first?.id
            : previousActiveID
        let affectsActivePresentation = previousActiveID == id
            || activeAggregateContainsDeletedConfiguration
        let favoriteSnapshot = favoriteURLs
        let recentSnapshot = recentURLs

        // Encoding and the optional active-source rebuild can run together.
        // Neither operation touches published state until both final results
        // are ready for one main-actor commit.
        configurationPersistenceTask?.cancel()
        configurationPersistenceTask = nil
        let persistenceTask = Task {
            try await ChannelLibraryPersistenceWriter.shared.writeConfigurations(
                deletionConfigurations,
                activeConfigurationID: updatedActiveID,
                configurationsKey: configurationsStorageKey,
                activeConfigurationKey: activeConfigurationStorageKey
            )
        }
        let preparationTask: Task<PreparedActivePresentation, Never>? = if affectsActivePresentation {
            Task.detached(priority: .userInitiated) {
                Self.prepareActivePresentation(
                    configurations: deletionConfigurations,
                    activeConfigurationID: updatedActiveID,
                    favoriteURLs: favoriteSnapshot,
                    recentURLs: recentSnapshot
                )
            }
        } else {
            nil
        }

        do {
            try await persistenceTask.value
        } catch {
            preparationTask?.cancel()
            lastError = AppLanguage.localizedFormat("删除配置失败：%@", error.localizedDescription)
            return false
        }

        let preparedPresentation = await preparationTask?.value
        configurations = deletionConfigurations
        activeConfigurationID = updatedActiveID
        ConfigurationCredentialVault.remove(for: id)
        RoveServerIconStore.remove(configurationID: id)
        if expiredConfigurationNotice?.id == id {
            expiredConfigurationNotice = nil
        }
        reportedExpiredConfigurationIDs.remove(id)

        if let preparedPresentation {
            applyPreparedActivePresentation(preparedPresentation)
        }
        // Deleting a source that is neither active nor part of the active
        // aggregate must not rebuild the unchanged channel library.
        markConfigurationChanged()
        publishExpiredConfigurationNoticeIfNeeded()
        return true
    }

    func dismissExpiredConfigurationNotice() {
        expiredConfigurationNotice = nil
    }

    func refreshConfiguration(_ id: UUID) async {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        let configuration = configurations[index]
        guard !configuration.isExpired else {
            lastError = AppLanguage.localized("该配置已过期，不能刷新。")
            return
        }
        var updatedConfiguration = configuration
        var newlyAddedMedia: [Channel] = []
        do {
            switch configuration.kind {
            case .subscription:
                guard let address = configuration.sourceAddress else { throw URLError(.badURL) }
                let download = try await downloadPlaylist(
                    address,
                    requestHeaders: configuration.requestHeaders,
                    proxy: configuration.proxy
                )
                let result = try await parseDownloadedPlaylist(
                    download,
                    requestedName: configuration.name
                )
                updatedConfiguration.channels = await Self.applyConfigurationDefaultsInBackground(
                    to: result.channels,
                    configuration: configuration
                )
                if !result.epgURLs.isEmpty { updatedConfiguration.epgURLs = result.epgURLs }
            case .rss:
                guard let address = configuration.sourceAddress else { throw URLError(.badURL) }
                let download = try await downloadPlaylist(
                    address,
                    requestHeaders: configuration.requestHeaders,
                    proxy: configuration.proxy
                )
                let document = try await parseRSSDocument(download)
                let channels = await Self.applyConfigurationDefaultsInBackground(
                    to: document.videoChannels,
                    configuration: configuration
                )
                guard !channels.isEmpty else { throw M3UParserError.emptyPlaylist }
                updatedConfiguration.channels = channels
                updatedConfiguration.totalItemCount = channels.count
            case .single:
                break
            case .legacySourceB:
                guard let server = configuration.sourceAddress,
                      let username = configuration.username,
                      let password = ConfigurationCredentialVault.password(for: id) else {
                    throw IPTVConfigurationError.missingCredentials
                }
                let result = try await IPTVConfigurationService.loadXtream(
                    server: server,
                    username: username,
                    password: password
                )
                updatedConfiguration.channels = result.channels
                updatedConfiguration.epgURLs = result.epgURLs
            case .legacySourceA:
                guard let portal = configuration.sourceAddress,
                      let mac = configuration.macAddress else { throw IPTVConfigurationError.missingCredentials }
                updatedConfiguration.channels = try await IPTVConfigurationService.loadStalker(
                    portal: portal,
                    macAddress: mac,
                    configurationID: id
                )
            case .legacyLibraryA, .movieClaw, .legacyLibraryB, .zspaceVideo:
                guard let server = configuration.sourceAddress,
                      let token = ConfigurationCredentialVault.password(for: id) else {
                    throw IPTVConfigurationError.missingCredentials
                }
                let result = try await JellyfinConfigurationService.refresh(
                    server: server,
                    token: token,
                    preferredUsername: configuration.username,
                    knownUserID: configuration.mediaServerUserID,
                    configurationID: id,
                    serverKind: configuration.kind
                )
                updatedConfiguration.channels = result.channels
                updatedConfiguration.totalItemCount = result.totalItemCount
                updatedConfiguration.mediaServerUserID = result.userID
                newlyAddedMedia = Self.newMediaItems(
                    previous: configuration.channels,
                    refreshed: result.channels
                )
                let collections = try await JellyfinConfigurationService.loadEmbyCollections(
                    server: server,
                    token: token,
                    preferredUsername: configuration.username ?? "",
                    knownUserID: result.userID
                )
                await invalidateMediaServerCache(configurationID: id)
                mediaServerCollectionsMemoryCache[id] = collections
                await EmbyLibraryCache.storeCollections(collections, configurationID: id)
            case .legacyLibraryC:
                guard let server = configuration.sourceAddress,
                      let token = ConfigurationCredentialVault.password(for: id) else {
                    throw IPTVConfigurationError.missingCredentials
                }
                let result = try await FeiniuVideoService.refresh(
                    server: server,
                    token: token,
                    preferredUsername: configuration.username ?? "",
                    configurationID: id
                )
                updatedConfiguration.channels = result.channels
                updatedConfiguration.totalItemCount = result.totalItemCount
                updatedConfiguration.username = result.username
                newlyAddedMedia = Self.newMediaItems(
                    previous: configuration.channels,
                    refreshed: result.channels
                )
                let collections = try await FeiniuVideoService.loadCollections(
                    server: server,
                    token: token
                )
                await invalidateMediaServerCache(configurationID: id)
                mediaServerCollectionsMemoryCache[id] = collections
                await EmbyLibraryCache.storeCollections(collections, configurationID: id)
            case .legacyLibraryD:
                guard let server = configuration.sourceAddress,
                      let token = ConfigurationCredentialVault.password(for: id) else {
                    throw IPTVConfigurationError.missingCredentials
                }
                let result = try await PlexConfigurationService.loadLibrary(
                    server: server,
                    token: token,
                    configurationID: id
                )
                updatedConfiguration.channels = result.channels
                updatedConfiguration.totalItemCount = result.channels.count
                newlyAddedMedia = Self.newMediaItems(
                    previous: configuration.channels,
                    refreshed: result.channels
                )
                await invalidateMediaServerCache(configurationID: id)
            case .legacySourceC:
                guard let address = configuration.sourceAddress else {
                    throw URLError(.badURL)
                }
                let baseURL = try WebDAVService.normalizedBaseURL(address)
                _ = try await WebDAVService.list(
                    url: baseURL,
                    username: configuration.username ?? "",
                    password: ConfigurationCredentialVault.password(for: id) ?? ""
                )
            case .local, .aggregate:
                break
            }
            if configuration.kind == .subscription {
                // Manual and automatic refreshes share the same checkpoint so
                // a foreground refresh does not immediately trigger another
                // background download.
                updatedConfiguration.lastAutomaticRefreshAt = Date()
            }
            updatedConfiguration.updatedAt = Date()
            try await commitPreparedConfiguration(updatedConfiguration)
            if activeConfigurationID == id
                || activeConfiguration?.memberIDs.contains(id) == true {
                applyActiveConfiguration()
            }
            lastError = nil
            markConfigurationChanged()
            if !newlyAddedMedia.isEmpty {
                await RoveLibraryNotificationService.shared.notifyNewItems(
                    newlyAddedMedia,
                    configuration: updatedConfiguration
                )
            }
        } catch {
            lastError = AppLanguage.localizedFormat(
                "刷新失败：%@",
                Self.userFacingPlaylistError(error)
            )
        }
    }

    /// Completes the lightweight media-server activation in the background.
    /// The home view owns collection/shelf loading, so this pass only fills
    /// the general channel index and avoids issuing the same collection calls
    /// a second time while the first home frame is being assembled.
    private func refreshMediaServerIndex(_ id: UUID) async {
        guard let index = configurations.firstIndex(where: { $0.id == id }) else { return }
        let configuration = configurations[index]
        guard configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: id) else { return }

        do {
            if configuration.kind == .legacyLibraryD {
                let result = try await PlexConfigurationService.loadLibrary(
                    server: server,
                    token: token,
                    configurationID: id
                )
                guard let currentIndex = configurations.firstIndex(where: { $0.id == id }) else {
                    return
                }
                var updatedConfiguration = configurations[currentIndex]
                updatedConfiguration.channels = result.channels
                updatedConfiguration.totalItemCount = result.channels.count
                updatedConfiguration.updatedAt = Date()
                try await commitPreparedConfiguration(updatedConfiguration)
                if activeConfigurationID == id
                    || activeConfiguration?.memberIDs.contains(id) == true {
                    applyActiveConfiguration(persistChannelSnapshot: false)
                }
                markConfigurationChanged()
                return
            }
            let result = try await JellyfinConfigurationService.refresh(
                server: server,
                token: token,
                preferredUsername: configuration.username,
                knownUserID: configuration.mediaServerUserID,
                configurationID: id,
                serverKind: configuration.kind
            )
            guard let currentIndex = configurations.firstIndex(where: { $0.id == id }) else {
                return
            }
            var updatedConfiguration = configurations[currentIndex]
            updatedConfiguration.channels = result.channels
            updatedConfiguration.totalItemCount = result.totalItemCount
            updatedConfiguration.mediaServerUserID = result.userID
            updatedConfiguration.serverReportedName = result.serverName
            updatedConfiguration.updatedAt = Date()
            try await commitPreparedConfiguration(updatedConfiguration)
            if activeConfigurationID == id
                || activeConfiguration?.memberIDs.contains(id) == true {
                applyActiveConfiguration(persistChannelSnapshot: false)
            }
            markConfigurationChanged()
        } catch {
            // Login already succeeded and the home shelves can still load
            // independently. Keep a transient index failure out of the
            // login form's error banner; the normal refresh action reports it.
        }
    }

    private static func newMediaItems(previous: [Channel], refreshed: [Channel]) -> [Channel] {
        guard !previous.isEmpty else { return [] }
        let existing = Set(previous.map(mediaIdentity))
        return refreshed.filter { !existing.contains(mediaIdentity($0)) }
    }

    private static func mediaIdentity(_ channel: Channel) -> String {
        if let tvgID = channel.tvgID, !tvgID.isEmpty {
            return "\(channel.mediaServerItemType ?? "item"):\(tvgID)"
        }
        return channel.streamURL.absoluteString
    }

    /// Refreshes only subscriptions whose user-selected interval has elapsed.
    /// The active player is intentionally left alone while a video is playing;
    /// the next background/foreground opportunity will retry the subscription.
    func refreshDueSubscriptions(now: Date = Date()) async {
#if !DJHUB_METADATA_ONLY
        guard PlaybackCoordinator.shared.currentChannel == nil else { return }
#endif
        let dueIDs = configurations.compactMap { configuration -> UUID? in
            guard configuration.kind == .subscription,
                  configuration.automaticRefreshEnabled,
                  !configuration.isExpired else { return nil }
            let interval = max(15 * 60, configuration.automaticRefreshInterval)
            let reference = configuration.lastAutomaticRefreshAt ?? configuration.updatedAt
            return now.timeIntervalSince(reference) >= interval ? configuration.id : nil
        }
        for id in dueIDs {
            await refreshConfiguration(id)
        }
    }

    func resolveStream(for channel: Channel) async throws -> URL {
        guard let resolver = channel.resolver else { return channel.streamURL }
        switch resolver {
        case .legacySourceA(let configurationID, let command):
            guard let configuration = configurations.first(where: { $0.id == configurationID }),
                  !configuration.isExpired,
                  let portal = configuration.sourceAddress,
                  let mac = configuration.macAddress else {
                throw IPTVConfigurationError.missingConfiguration
            }
            return try await IPTVConfigurationService.resolveStalkerStream(
                portal: portal,
                macAddress: mac,
                command: command
            )
        case .legacyLibraryA(let configurationID, let itemID):
            guard let configuration = configurations.first(where: { $0.id == configurationID }),
                  !configuration.isExpired,
                  let server = configuration.sourceAddress,
                  let token = ConfigurationCredentialVault.password(for: configurationID) else {
                throw IPTVConfigurationError.missingCredentials
            }
            return try JellyfinConfigurationService.resolveStream(
                server: server,
                token: token,
                itemID: itemID,
                container: channel.httpHeaders["X-Tubo-Jellyfin-Container"]
            )
        case .movieClaw(let configurationID, let itemID):
            guard let configuration = configurations.first(where: { $0.id == configurationID }),
                  !configuration.isExpired,
                  let server = configuration.sourceAddress,
                  let token = ConfigurationCredentialVault.password(for: configurationID) else {
                throw IPTVConfigurationError.missingCredentials
            }
            return try await JellyfinConfigurationService.resolveEmbyStream(
                server: server,
                token: token,
                itemID: itemID,
                container: channel.httpHeaders["X-Tubo-MovieClaw-Container"],
                preferredMediaSourceID: channel.mediaServerSourceID
            )
        case .legacyLibraryB(let configurationID, let itemID):
            guard let configuration = configurations.first(where: { $0.id == configurationID }),
                  !configuration.isExpired,
                  let server = configuration.sourceAddress,
                  let token = ConfigurationCredentialVault.password(for: configurationID) else {
                throw IPTVConfigurationError.missingCredentials
            }
            return try await JellyfinConfigurationService.resolveEmbyStream(
                server: server,
                token: token,
                itemID: itemID,
                container: channel.httpHeaders["X-Tubo-Emby-Container"]
            )
        case .legacyLibraryC(let configurationID, let itemID):
            guard let configuration = configurations.first(where: { $0.id == configurationID }),
                  !configuration.isExpired,
                  let server = configuration.sourceAddress,
                  let token = ConfigurationCredentialVault.password(for: configurationID) else {
                throw IPTVConfigurationError.missingCredentials
            }
            return try await FeiniuVideoService.resolveStream(
                server: server,
                token: token,
                itemID: itemID
            )
        case .legacyLibraryD(let configurationID, let itemID):
            guard let configuration = configurations.first(where: { $0.id == configurationID }),
                  !configuration.isExpired,
                  let server = configuration.sourceAddress,
                  let token = ConfigurationCredentialVault.password(for: configurationID) else {
                throw IPTVConfigurationError.missingCredentials
            }
            return try await PlexConfigurationService.resolveStream(
                server: server,
                token: token,
                itemID: itemID
            )
        }
    }

    /// Hosted Emby servers backed by cloud drives often prepare a temporary
    /// direct URL when PlaybackInfo is requested. Resolve it while the detail
    /// page is visible so tapping Play can reuse the in-memory result.
    func preloadEmbyPlaybackInfo(for channel: Channel) async {
        guard case .legacyLibraryB = channel.resolver else { return }
        // The resolver owns the short-lived cache and the in-flight request.
        // A failed prefetch is intentionally ignored; tapping Play retries
        // through the normal playback error path.
        if let resolvedURL = try? await resolveStream(for: channel) {
            JellyfinConfigurationService.prewarmEmbyStream(
                resolvedURL,
                channel: channel
            )
        }
    }

    /// Send the native media-server playback heartbeat. Local resume state
    /// remains independent, so a temporary server
    /// failure can never interrupt playback or erase the local position.
    func reportMediaServerPlayback(
        for channel: Channel,
        position: Double,
        duration: Double,
        isPaused: Bool,
        stopped: Bool = false
    ) async {
        let identity: (UUID, String)? = switch channel.resolver {
        case .legacyLibraryB(let configurationID, let itemID),
             .legacyLibraryA(let configurationID, let itemID),
             .movieClaw(let configurationID, let itemID),
             .legacyLibraryC(let configurationID, let itemID),
             .legacyLibraryD(let configurationID, let itemID): (configurationID, itemID)
        default: nil
        }
        guard let (configurationID, itemID) = identity,
              let configuration = configurations.first(where: { $0.id == configurationID }),
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID)
        else { return }

        if configuration.kind == .legacyLibraryC {
            await FeiniuVideoService.reportPlayback(
                server: server,
                token: token,
                itemID: itemID,
                position: position,
                duration: duration,
                stopped: stopped
            )
        } else if configuration.kind == .legacyLibraryD {
            await PlexConfigurationService.reportPlayback(
                server: server,
                token: token,
                itemID: itemID,
                position: position,
                duration: duration,
                isPaused: isPaused,
                stopped: stopped
            )
        } else {
            await JellyfinConfigurationService.reportPlayback(
                server: server,
                token: token,
                itemID: itemID,
                mediaSourceID: channel.mediaServerSourceID,
                userID: configuration.mediaServerUserID,
                position: position,
                duration: duration,
                isPaused: isPaused,
                stopped: stopped
            )
        }
    }

    @discardableResult
    func setMediaServerFavorite(_ favorite: Bool, for channel: Channel) async -> Bool {
        let identity: (UUID, String)? = switch channel.resolver {
        case .legacyLibraryB(let configurationID, let itemID),
             .legacyLibraryA(let configurationID, let itemID),
             .movieClaw(let configurationID, let itemID),
             .legacyLibraryD(let configurationID, let itemID): (configurationID, itemID)
        default: nil
        }
        guard let (configurationID, itemID) = identity,
              let configuration = configurations.first(where: { $0.id == configurationID }),
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID)
        else { return false }

        // The Android Plex provider intentionally keeps favorites locally.
        if configuration.kind == .legacyLibraryD { return true }
        return await JellyfinConfigurationService.setUserState(
            server: server,
            token: token,
            userID: configuration.mediaServerUserID,
            itemID: itemID,
            kind: .favorite,
            enabled: favorite
        )
    }

    @discardableResult
    func setMediaServerPlayed(_ played: Bool, for channel: Channel) async -> Bool {
        let identity: (UUID, String)? = switch channel.resolver {
        case .legacyLibraryB(let configurationID, let itemID),
             .legacyLibraryA(let configurationID, let itemID),
             .movieClaw(let configurationID, let itemID),
             .legacyLibraryC(let configurationID, let itemID),
             .legacyLibraryD(let configurationID, let itemID): (configurationID, itemID)
        default: nil
        }
        guard let (configurationID, itemID) = identity,
              let configuration = configurations.first(where: { $0.id == configurationID }),
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID)
        else { return false }

        if configuration.kind == .legacyLibraryC {
            // This matches the Android provider: fnOS exposes deletion of a
            // playback record, but has no explicit mark-played operation.
            guard !played else { return false }
            return await FeiniuVideoService.clearPlaybackRecord(
                server: server,
                token: token,
                itemID: itemID
            )
        }
        if configuration.kind == .legacyLibraryD {
            return await PlexConfigurationService.setPlayed(
                server: server,
                token: token,
                itemID: itemID,
                played: played
            )
        }
        return await JellyfinConfigurationService.setUserState(
            server: server,
            token: token,
            userID: configuration.mediaServerUserID,
            itemID: itemID,
            kind: .played,
            enabled: played
        )
    }

    func mediaServerExternalSubtitles(
        for channel: Channel
    ) async throws -> [MediaServerSubtitleSource] {
        let identity: (configurationID: UUID, itemID: String)? = switch channel.resolver {
        case .legacyLibraryA(let configurationID, let itemID): (configurationID, itemID)
        case .movieClaw(let configurationID, let itemID): (configurationID, itemID)
        case .legacyLibraryB(let configurationID, let itemID): (configurationID, itemID)
        case .legacyLibraryC: nil
        default: nil
        }
        guard let identity,
              let configuration = configurations.first(where: { $0.id == identity.configurationID }),
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: identity.configurationID) else {
            return []
        }
        return try await JellyfinConfigurationService.loadExternalSubtitles(
            server: server,
            token: token,
            itemID: identity.itemID
        )
    }

    func jellyfinArtworkData(for channel: Channel, maxWidth: Int = 720) async throws -> Data? {
        let identity: (configurationID: UUID, itemID: String)? = switch channel.resolver {
        case .legacyLibraryA(let configurationID, let itemID),
             .movieClaw(let configurationID, let itemID): (configurationID, itemID)
        default: nil
        }
        guard let identity,
              let configuration = configurations.first(where: { $0.id == identity.configurationID }),
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: identity.configurationID) else {
            return nil
        }
        return try await JellyfinConfigurationService.loadArtwork(
            server: server,
            token: token,
            itemID: identity.itemID,
            maxWidth: maxWidth
        )
    }

    func mediaServerArtworkData(
        for channel: Channel,
        maxWidth: Int = 720,
        imageType: MediaServerArtworkType = .primary
    ) async throws -> Data? {
        let resolvedIdentity: (configurationID: UUID, itemID: String)? = switch channel.resolver {
        case .legacyLibraryA(let configurationID, let itemID): (configurationID, itemID)
        case .movieClaw(let configurationID, let itemID): (configurationID, itemID)
        case .legacyLibraryB(let configurationID, let itemID): (configurationID, itemID)
        case .legacyLibraryC(let configurationID, let itemID): (configurationID, itemID)
        case .legacyLibraryD(let configurationID, let itemID): (configurationID, itemID)
        default: nil
        }
        let identity = resolvedIdentity ?? channel.tvgID.flatMap { itemID in
            activeConfigurationID.map { (configurationID: $0, itemID: itemID) }
        }
        guard let identity else { return nil }
        guard let configuration = configurations.first(where: { $0.id == identity.configurationID }),
              let server = configuration.sourceAddress else {
#if DEBUG
            print("RoveArtwork missing configuration for \(channel.name)")
#endif
            return nil
        }
        guard let token = ConfigurationCredentialVault.password(for: identity.configurationID) else {
#if DEBUG
            print("RoveArtwork missing credential for \(configuration.name)")
#endif
            return nil
        }
        if configuration.kind == .legacyLibraryC {
            guard imageType == .primary else { return nil }
            return try await FeiniuVideoService.loadArtwork(
                server: server,
                token: token,
                itemID: identity.itemID,
                posterPath: channel.httpHeaders["X-Tubo-Feiniu-Poster"],
                maxWidth: maxWidth
            )
        }
        if configuration.kind == .legacyLibraryD {
            return try await PlexConfigurationService.artworkData(
                server: server,
                token: token,
                itemID: identity.itemID,
                landscape: imageType != .primary
            )
        }
        let data = try await JellyfinConfigurationService.loadArtwork(
            server: server,
            token: token,
            itemID: identity.itemID,
            maxWidth: maxWidth,
            imageType: imageType
        )
#if DEBUG
        print("RoveArtwork response \(configuration.name) item=\(identity.itemID) bytes=\(data?.count ?? 0)")
#endif
        return data
    }

    func loadEmbyCollections(configurationID: UUID) async throws -> [MetadataLibraryCollection] {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID) else {
            throw IPTVConfigurationError.missingCredentials
        }
        let collections: [MetadataLibraryCollection]
        if configuration.kind == .legacyLibraryC {
            collections = try await FeiniuVideoService.loadCollections(server: server, token: token)
        } else if configuration.kind == .legacyLibraryD {
            collections = try await PlexConfigurationService.loadCollections(
                server: server,
                token: token
            )
        } else {
            collections = try await JellyfinConfigurationService.loadEmbyCollections(
                server: server,
                token: token,
                preferredUsername: configuration.username ?? "",
                knownUserID: configuration.mediaServerUserID
            )
        }
        mediaServerCollectionsMemoryCache[configurationID] = collections
        await EmbyLibraryCache.storeCollections(collections, configurationID: configurationID)
        return collections
    }

    func invalidateMediaServerCache(
        configurationID: UUID,
        preservingHomeCache: Bool = false
    ) async {
        if !preservingHomeCache {
            mediaServerCollectionsMemoryCache[configurationID] = nil
            mediaServerContinueWatchingMemoryCache[configurationID] = nil
        }
        let identifier = configurationID.uuidString.lowercased()
        mediaServerDetailsMemoryCache = mediaServerDetailsMemoryCache.filter {
            !$0.key.hasPrefix(identifier + "|")
        }
        mediaServerPageMemoryCache = mediaServerPageMemoryCache.filter {
            $0.key.configurationID != configurationID
        }
        mediaServerBrowseMemoryCache = mediaServerBrowseMemoryCache.filter {
            $0.key.configurationID != configurationID
        }
        await EmbyLibraryCache.invalidate(
            configurationID: configurationID,
            preservingHomeCache: preservingHomeCache
        )
        await ChannelArtworkLoader.shared.invalidate(configurationID: configurationID)
    }

    func loadFeiniuVideoCategorySummaries(
        configurationID: UUID
    ) async throws -> [FeiniuVideoCategorySummary] {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind == .legacyLibraryC,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID) else {
            throw IPTVConfigurationError.missingCredentials
        }
        return try await FeiniuVideoService.loadCategorySummaries(
            server: server,
            token: token
        )
    }

    func cachedEmbyCollections(configurationID: UUID) async -> [MetadataLibraryCollection] {
        if let cached = mediaServerCollectionsMemoryCache[configurationID] {
            return cached
        }
        let cached = await EmbyLibraryCache.collections(configurationID: configurationID) ?? []
        if !cached.isEmpty {
            mediaServerCollectionsMemoryCache[configurationID] = cached
        }
        return cached
    }

    /// Home media is rendered from the persisted snapshot first. A short
    /// freshness window prevents every foreground/view reconstruction from
    /// re-fetching the same server collections while still allowing periodic
    /// updates and explicit manual refreshes.
    func isMediaServerHomeCacheFresh(
        configurationID: UUID,
        maxAge: TimeInterval = 15 * 60
    ) async -> Bool {
        await EmbyLibraryCache.homeCacheIsFresh(
            configurationID: configurationID,
            maxAge: maxAge
        )
    }

    func loadEmbyGenres(
        configurationID: UUID,
        parentID: String
    ) async throws -> [MetadataLibraryCollection] {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID) else {
            throw IPTVConfigurationError.missingCredentials
        }
        if configuration.kind == .legacyLibraryC { return [] }
        let genres = try await JellyfinConfigurationService.loadEmbyGenres(
            server: server,
            token: token,
            preferredUsername: configuration.username ?? "",
            knownUserID: configuration.mediaServerUserID,
            parentID: parentID
        )
        let key = MediaServerBrowseCacheKey(
            configurationID: configurationID,
            parentID: parentID,
            kind: "genres"
        )
        mediaServerBrowseMemoryCache[key] = genres
        await EmbyLibraryCache.storeBrowseNodes(
            genres,
            configurationID: configurationID,
            parentID: parentID,
            kind: key.kind
        )
        return genres
    }

    func cachedEmbyGenres(
        configurationID: UUID,
        parentID: String
    ) async -> [MetadataLibraryCollection]? {
        await cachedEmbyBrowseNodes(
            configurationID: configurationID,
            parentID: parentID,
            kind: "genres"
        )
    }

    func loadEmbyFolders(
        configurationID: UUID,
        parentID: String
    ) async throws -> [MetadataLibraryCollection] {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID) else {
            throw IPTVConfigurationError.missingCredentials
        }
        if configuration.kind == .legacyLibraryC { return [] }
        let folders = try await JellyfinConfigurationService.loadEmbyFolders(
            server: server,
            token: token,
            preferredUsername: configuration.username ?? "",
            knownUserID: configuration.mediaServerUserID,
            parentID: parentID
        )
        let key = MediaServerBrowseCacheKey(
            configurationID: configurationID,
            parentID: parentID,
            kind: "folders"
        )
        mediaServerBrowseMemoryCache[key] = folders
        await EmbyLibraryCache.storeBrowseNodes(
            folders,
            configurationID: configurationID,
            parentID: parentID,
            kind: key.kind
        )
        return folders
    }

    func cachedEmbyFolders(
        configurationID: UUID,
        parentID: String
    ) async -> [MetadataLibraryCollection]? {
        await cachedEmbyBrowseNodes(
            configurationID: configurationID,
            parentID: parentID,
            kind: "folders"
        )
    }

    private func cachedEmbyBrowseNodes(
        configurationID: UUID,
        parentID: String,
        kind: String
    ) async -> [MetadataLibraryCollection]? {
        let key = MediaServerBrowseCacheKey(
            configurationID: configurationID,
            parentID: parentID,
            kind: kind
        )
        if let cached = mediaServerBrowseMemoryCache[key] {
            return cached
        }
        let cached = await EmbyLibraryCache.browseNodes(
            configurationID: configurationID,
            parentID: parentID,
            kind: kind
        )
        if let cached {
            mediaServerBrowseMemoryCache[key] = cached
        }
        return cached
    }

    func loadEmbyContinueWatching(
        configurationID: UUID,
        limit: Int = 12
    ) async throws -> [MetadataContinueItem] {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID) else {
            throw IPTVConfigurationError.missingCredentials
        }
        let items: [MetadataContinueItem]
        if configuration.kind == .legacyLibraryC {
            items = try await FeiniuVideoService.loadContinueWatching(
                server: server,
                token: token,
                configurationID: configurationID,
                limit: limit
            )
        } else if configuration.kind == .legacyLibraryD {
            items = try await PlexConfigurationService.loadContinueWatching(
                server: server,
                token: token,
                configurationID: configurationID,
                limit: limit
            )
        } else {
            items = try await JellyfinConfigurationService.loadEmbyContinueWatching(
                server: server,
                token: token,
                preferredUsername: configuration.username ?? "",
                knownUserID: configuration.mediaServerUserID,
                configurationID: configurationID,
                serverKind: configuration.kind,
                limit: limit
            )
        }
        mediaServerContinueWatchingMemoryCache[configurationID] = items
        await EmbyLibraryCache.storeContinueWatching(items, configurationID: configurationID)
        return items
    }

    func loadSimilarItems(for channel: Channel, limit: Int = 20) async throws -> [Channel] {
        let identity: (configurationID: UUID, itemID: String)? = switch channel.resolver {
        case .legacyLibraryA(let configurationID, let itemID),
             .movieClaw(let configurationID, let itemID),
             .legacyLibraryB(let configurationID, let itemID),
             .legacyLibraryC(let configurationID, let itemID),
             .legacyLibraryD(let configurationID, let itemID): (configurationID, itemID)
        default: nil
        }
        guard let identity,
              let configuration = configurations.first(where: { $0.id == identity.configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: identity.configurationID) else {
            throw IPTVConfigurationError.missingCredentials
        }
        if configuration.kind == .legacyLibraryC { return [] }
        if configuration.kind == .legacyLibraryD {
            return try await PlexConfigurationService.loadSimilarItems(
                server: server,
                token: token,
                configurationID: identity.configurationID,
                itemID: identity.itemID,
                limit: limit
            )
        }
        return try await JellyfinConfigurationService.loadSimilarItems(
            server: server,
            token: token,
            preferredUsername: configuration.username ?? "",
            knownUserID: configuration.mediaServerUserID,
            configurationID: identity.configurationID,
            serverKind: configuration.kind,
            itemID: identity.itemID,
            limit: limit
        )
    }

    func loadItemsForPerson(
        configurationID: UUID,
        personID: String,
        limit: Int = 60
    ) async throws -> [Channel] {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID) else {
            throw IPTVConfigurationError.missingCredentials
        }
        if configuration.kind == .legacyLibraryC { return [] }
        if configuration.kind == .legacyLibraryD {
            return try await PlexConfigurationService.loadItemsForPerson(
                server: server,
                token: token,
                configurationID: configurationID,
                personID: personID,
                limit: limit
            )
        }
        return try await JellyfinConfigurationService.loadItemsForPerson(
            server: server,
            token: token,
            preferredUsername: configuration.username ?? "",
            knownUserID: configuration.mediaServerUserID,
            configurationID: configurationID,
            serverKind: configuration.kind,
            personID: personID,
            limit: limit
        )
    }

    func cachedEmbyContinueWatching(configurationID: UUID) async -> [MetadataContinueItem] {
        if let cached = mediaServerContinueWatchingMemoryCache[configurationID] {
            return cached
        }
        let cached = await EmbyLibraryCache.continueWatching(configurationID: configurationID) ?? []
        mediaServerContinueWatchingMemoryCache[configurationID] = cached
        return cached
    }

    func loadEmbyArtwork(
        configurationID: UUID,
        itemID: String,
        maxWidth: Int = 640
    ) async throws -> Data? {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID) else {
            return nil
        }
        if configuration.kind == .legacyLibraryC {
            return try await FeiniuVideoService.loadArtwork(
                server: server,
                token: token,
                itemID: itemID,
                posterPath: nil,
                maxWidth: maxWidth
            )
        }
        return try await JellyfinConfigurationService.loadArtwork(
            server: server,
            token: token,
            itemID: itemID,
            maxWidth: maxWidth
        )
    }

    func cachedMetadataDetails(
        configurationID: UUID,
        itemID: String
    ) async -> MetadataDetails? {
        let key = "\(configurationID.uuidString.lowercased())|\(itemID)"
        if let cached = mediaServerDetailsMemoryCache[key] {
            return mediaDetails(cached, annotatedFor: configurationID, itemID: itemID)
        }
        let cached = await EmbyLibraryCache.mediaDetails(
            configurationID: configurationID,
            itemID: itemID
        )
        if let cached {
            mediaServerDetailsMemoryCache[key] = cached
            return mediaDetails(cached, annotatedFor: configurationID, itemID: itemID)
        }
        return nil
    }

    private func mediaDetails(
        _ details: MetadataDetails,
        annotatedFor configurationID: UUID,
        itemID: String
    ) -> MetadataDetails {
        guard let configuration = configurations.first(where: { $0.id == configurationID }) else {
            return details
        }
        let reportedServerName = configuration.serverReportedName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let serverName = reportedServerName?.isEmpty == false
            ? reportedServerName!
            : configuration.name
        let versions = details.mediaVersions?.map { version in
            MetadataVersion(
                id: version.id,
                name: version.name,
                container: version.container,
                sizeBytes: version.sizeBytes,
                bitRate: version.bitRate,
                width: version.width,
                height: version.height,
                serverName: version.serverName ?? serverName,
                serverConfigurationID: version.serverConfigurationID ?? configurationID,
                serverItemID: version.serverItemID ?? itemID,
                serverKind: version.serverKind ?? configuration.kind.rawValue,
                dynamicRange: version.dynamicRange,
                frameRate: version.frameRate,
                subtitleTracks: version.subtitleTracks,
                audioTracks: version.audioTracks
            )
        }
        return MetadataDetails(
            itemID: details.itemID,
            title: details.title,
            overview: details.overview,
            premiereDate: details.premiereDate,
            productionYear: details.productionYear,
            communityRating: details.communityRating,
            officialRating: details.officialRating,
            genres: details.genres,
            runtimeSeconds: details.runtimeSeconds,
            container: details.container,
            sizeBytes: details.sizeBytes,
            people: details.people,
            studios: details.studios,
            streams: details.streams,
            mediaVersions: versions
        )
    }

    func loadMetadataDetails(
        configurationID: UUID,
        itemID: String
    ) async throws -> MetadataDetails {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID) else {
            throw IPTVConfigurationError.missingCredentials
        }
        let details: MetadataDetails
        if configuration.kind == .legacyLibraryC {
            details = try await FeiniuVideoService.loadDetails(
                server: server,
                token: token,
                itemID: itemID
            )
        } else if configuration.kind == .legacyLibraryD {
            details = try await PlexConfigurationService.loadDetails(
                server: server,
                token: token,
                itemID: itemID
            )
        } else {
            details = try await JellyfinConfigurationService.loadMetadataDetails(
                server: server,
                token: token,
                preferredUsername: configuration.username ?? "",
                knownUserID: configuration.mediaServerUserID,
                itemID: itemID
            )
        }
        let annotatedDetails = mediaDetails(details, annotatedFor: configurationID, itemID: itemID)
        let key = "\(configurationID.uuidString.lowercased())|\(itemID)"
        mediaServerDetailsMemoryCache[key] = annotatedDetails
        await EmbyLibraryCache.storeMediaDetails(
            annotatedDetails,
            configurationID: configurationID
        )
        return annotatedDetails
    }

    /// Merge versions from matching items across all configured media servers.
    /// The item itself remains the current detail item; each version carries
    /// enough routing metadata for playback to switch to its owning server.
    func loadAggregatedMediaDetails(
        for channel: Channel,
        base: MetadataDetails
    ) async -> MetadataDetails {
        guard channel.isMediaServerItem else { return base }
        let identity = mediaAggregationIdentity(for: channel)
        let registeredLines = playbackLines(for: channel)
        let registeredLineIDs = Set(registeredLines.map(\.id))
        var seenRoutes = Set<String>()
        let candidates = (registeredLines + mediaServerChannels).filter { candidate in
            guard candidate.id != channel.id else { return false }
            guard registeredLineIDs.contains(candidate.id)
                    || mediaAggregationIdentity(for: candidate) == identity else {
                return false
            }
            let routeKey: String = switch candidate.resolver {
            case .legacyLibraryB(let configurationID, let itemID),
                 .legacyLibraryA(let configurationID, let itemID),
                 .movieClaw(let configurationID, let itemID),
                 .legacyLibraryC(let configurationID, let itemID),
                 .legacyLibraryD(let configurationID, let itemID):
                "\(configurationID.uuidString.lowercased())|\(itemID)"
            default:
                candidate.streamURL.absoluteString
            }
            return seenRoutes.insert(routeKey).inserted
        }
        guard !candidates.isEmpty else { return base }

        let requests: [(index: Int, configurationID: UUID, itemID: String)] = candidates
            .prefix(12)
            .enumerated()
            .compactMap { index, candidate -> (Int, UUID, String)? in
            let resolved: (UUID, String)? = switch candidate.resolver {
            case .legacyLibraryB(let configurationID, let itemID),
                 .legacyLibraryA(let configurationID, let itemID),
                 .movieClaw(let configurationID, let itemID),
                 .legacyLibraryC(let configurationID, let itemID),
                 .legacyLibraryD(let configurationID, let itemID): (configurationID, itemID)
            default: nil
            }
            guard let (configurationID, itemID) = resolved else { return nil }
            return (index, configurationID, itemID)
        }

        var versionsByIndex: [Int: [MetadataVersion]] = [:]
        await withTaskGroup(of: (Int, [MetadataVersion]).self) { group in
            var nextRequest = 0
            let concurrentRequestLimit = min(4, requests.count)

            func addNextRequest() {
                guard nextRequest < requests.count else { return }
                let request = requests[nextRequest]
                nextRequest += 1
                group.addTask { [weak self] in
                    guard let self else { return (request.0, []) }
                    let cached = await self.cachedMetadataDetails(
                        configurationID: request.configurationID,
                        itemID: request.itemID
                    )
                    let candidateDetails: MetadataDetails?
                    if let cached {
                        candidateDetails = cached
                    } else {
                        candidateDetails = try? await self.loadMetadataDetails(
                            configurationID: request.configurationID,
                            itemID: request.itemID
                        )
                    }
                    return (request.index, candidateDetails?.mediaVersions ?? [])
                }
            }

            for _ in 0..<concurrentRequestLimit {
                addNextRequest()
            }
            while let (index, loadedVersions) = await group.next() {
                versionsByIndex[index] = loadedVersions
                addNextRequest()
            }
        }

        var versions = base.mediaVersions ?? []
        for index in versionsByIndex.keys.sorted() {
            versions.append(contentsOf: versionsByIndex[index] ?? [])
        }

        var seen = Set<String>()
        let uniqueVersions = versions.filter { seen.insert($0.selectionKey).inserted }
        guard !uniqueVersions.isEmpty else { return base }
        return MetadataDetails(
            itemID: base.itemID,
            title: base.title,
            overview: base.overview,
            premiereDate: base.premiereDate,
            productionYear: base.productionYear,
            communityRating: base.communityRating,
            officialRating: base.officialRating,
            genres: base.genres,
            runtimeSeconds: base.runtimeSeconds,
            container: base.container,
            sizeBytes: base.sizeBytes,
            people: base.people,
            studios: base.studios,
            streams: base.streams,
            mediaVersions: uniqueVersions
        )
    }

    private func mediaAggregationIdentity(for channel: Channel) -> String {
        let type = channel.mediaServerItemType?.lowercased() ?? "item"
        let title = (channel.tvgName ?? channel.name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        return "\(type)|\(title)|\(channel.productionYear ?? 0)"
    }

    func loadMediaLibraryStatistics(configurationID: UUID) async throws -> MediaLibraryStatistics {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired else {
            throw IPTVConfigurationError.missingConfiguration
        }
        guard let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID) else {
            return MediaLibraryStatistics(channels: configuration.channels)
        }
        if configuration.kind == .legacyLibraryC {
            return try await FeiniuVideoService.loadLibraryStatistics(
                server: server,
                token: token
            )
        }
        if configuration.kind == .legacyLibraryD {
            return MediaLibraryStatistics(channels: configuration.channels)
        }
        return try await JellyfinConfigurationService.loadLibraryStatistics(
            server: server,
            token: token,
            preferredUsername: configuration.username ?? "",
            knownUserID: configuration.mediaServerUserID
        )
    }

    func nextMediaServerEpisode(after channel: Channel) async throws -> Channel? {
        try await adjacentMediaServerEpisode(to: channel, offset: 1)
    }

    func adjacentMediaServerEpisode(
        to channel: Channel,
        offset: Int
    ) async throws -> Channel? {
        guard channel.isMediaServerEpisode else { return nil }
        let identity: (configurationID: UUID, itemID: String)? = switch channel.resolver {
        case .legacyLibraryA(let configurationID, let itemID): (configurationID, itemID)
        case .movieClaw(let configurationID, let itemID): (configurationID, itemID)
        case .legacyLibraryB(let configurationID, let itemID): (configurationID, itemID)
        case .legacyLibraryC(let configurationID, let itemID): (configurationID, itemID)
        case .legacyLibraryD(let configurationID, let itemID): (configurationID, itemID)
        default: nil
        }
        guard let identity,
              let configuration = configurations.first(where: { $0.id == identity.configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: identity.configurationID) else {
            return nil
        }
        if configuration.kind == .legacyLibraryC {
            return try await FeiniuVideoService.adjacentEpisode(
                server: server,
                token: token,
                configurationID: identity.configurationID,
                currentItemID: identity.itemID,
                parentID: channel.mediaServerSeriesID,
                offset: offset
            )
        }
        if configuration.kind == .legacyLibraryD,
           let seriesID = channel.mediaServerSeriesID {
            let page = try await PlexConfigurationService.loadPage(
                server: server,
                token: token,
                configurationID: identity.configurationID,
                parentID: seriesID,
                startIndex: 0,
                limit: 1_000,
                searchTerm: nil
            )
            guard let index = page.channels.firstIndex(where: { $0.tvgID == identity.itemID }) else {
                return nil
            }
            let target = index + offset
            return page.channels.indices.contains(target) ? page.channels[target] : nil
        }
        return try await JellyfinConfigurationService.loadAdjacentEpisode(
            server: server,
            token: token,
            preferredUsername: configuration.username ?? "",
            knownUserID: configuration.mediaServerUserID,
            configurationID: identity.configurationID,
            serverKind: configuration.kind,
            currentItemID: identity.itemID,
            knownSeriesID: channel.mediaServerSeriesID,
            offset: offset
        )
    }

    func loadEmbyPage(
        configurationID: UUID,
        parentID: String? = nil,
        startIndex: Int = 0,
        limit: Int = 60,
        searchTerm: String? = nil,
        genre: String? = nil,
        prefersSeries: Bool = false,
        sortBy: String? = nil,
        sortDescending: Bool? = nil,
        includesMediaSources: Bool = false
    ) async throws -> MetadataLibraryPage {
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired,
              let server = configuration.sourceAddress,
              let token = ConfigurationCredentialVault.password(for: configurationID) else {
            throw IPTVConfigurationError.missingCredentials
        }
        let page: MetadataLibraryPage
        if configuration.kind == .legacyLibraryC {
            page = try await FeiniuVideoService.loadPage(
                server: server,
                token: token,
                configurationID: configurationID,
                parentID: parentID,
                startIndex: startIndex,
                limit: limit,
                searchTerm: searchTerm,
                prefersSeries: prefersSeries
            )
        } else if configuration.kind == .legacyLibraryD {
            page = try await PlexConfigurationService.loadPage(
                server: server,
                token: token,
                configurationID: configurationID,
                parentID: parentID,
                startIndex: startIndex,
                limit: limit,
                searchTerm: searchTerm
            )
        } else {
            page = try await JellyfinConfigurationService.loadEmbyPage(
                server: server,
                token: token,
                preferredUsername: configuration.username ?? "",
                knownUserID: configuration.mediaServerUserID,
                configurationID: configurationID,
                serverKind: configuration.kind,
                parentID: parentID,
                startIndex: startIndex,
                limit: limit,
                searchTerm: searchTerm,
                genre: genre,
                prefersSeries: prefersSeries,
                sortBy: sortBy,
                sortDescending: sortDescending,
                includesMediaSources: includesMediaSources
            )
        }
        if (searchTerm?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
           sortBy == nil, sortDescending == nil, !includesMediaSources {
            let key = MediaServerPageCacheKey(
                configurationID: configurationID,
                parentID: parentID,
                startIndex: startIndex,
                limit: limit,
                genre: genre,
                prefersSeries: prefersSeries,
                sortBy: nil,
                sortDescending: nil,
                includesMediaSources: false
            )
            mediaServerPageMemoryCache[key] = page
            await EmbyLibraryCache.storePage(
                page,
                configurationID: configurationID,
                parentID: parentID,
                startIndex: startIndex,
                limit: limit,
                genre: genre,
                prefersSeries: prefersSeries
            )
        }
        return page
    }

    func searchAllEmbyItems(
        configurationID: UUID,
        searchTerm: String
    ) async throws -> [Channel] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        guard let configuration = configurations.first(where: { $0.id == configurationID }),
              configuration.kind.usesMediaLibraryBrowser,
              !configuration.isExpired else {
            throw IPTVConfigurationError.missingCredentials
        }

        // Series are a separate Emby item type, so searching only playable
        // media misses TV show titles. Fetch both result sets page by page.
        let resultKinds = configuration.kind == .legacyLibraryC
            ? [false]
            : [true, false]
        var results: [Channel] = []
        var seenItemIDs = Set<String>()

        for prefersSeries in resultKinds {
            var startIndex = 0
            while true {
                try Task.checkCancellation()
                let page = try await loadEmbyPage(
                    configurationID: configurationID,
                    startIndex: startIndex,
                    limit: 200,
                    searchTerm: term,
                    prefersSeries: prefersSeries
                )
                results.append(contentsOf: page.channels.filter { channel in
                    let identity = channel.tvgID ?? channel.streamURL.absoluteString
                    return seenItemIDs.insert(identity).inserted
                })

                guard page.hasMore, page.nextStartIndex > startIndex else { break }
                startIndex = page.nextStartIndex
            }
        }
        return results
    }

    func searchMediaServersByProviderIDs(
        _ providerIDs: [String],
        includeItemTypes: String,
        limit: Int = 10
    ) async -> [Channel] {
        let cleanProviderIDs = providerIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanProviderIDs.isEmpty else { return [] }

        let requests: [ProviderIDSearchRequest] = configurations.enumerated().compactMap { index, configuration in
            guard (configuration.kind.isEmbyCompatible || configuration.kind.isJellyfinCompatible),
                  !configuration.isExpired,
                  let server = configuration.sourceAddress,
                  let token = ConfigurationCredentialVault.password(for: configuration.id)
            else { return nil }
            return ProviderIDSearchRequest(
                index: index,
                server: server,
                token: token,
                username: configuration.username ?? "",
                userID: configuration.mediaServerUserID,
                configurationID: configuration.id,
                serverKind: configuration.kind
            )
        }

        let tasks = requests.map { request in
            Task { @MainActor in
                let channels = (try? await JellyfinConfigurationService.loadItems(
                    server: request.server,
                    token: request.token,
                    preferredUsername: request.username,
                    knownUserID: request.userID,
                    configurationID: request.configurationID,
                    serverKind: request.serverKind,
                    providerIDs: cleanProviderIDs,
                    includeItemTypes: includeItemTypes,
                    limit: limit
                )) ?? []
                return (request.index, channels)
            }
        }
        var orderedResults: [(Int, [Channel])] = []
        for task in tasks {
            orderedResults.append(await task.value)
        }
        orderedResults.sort { $0.0 < $1.0 }

        var seen = Set<String>()
        return orderedResults.flatMap { $0.1 }.filter { channel in
            seen.insert(channel.streamURL.absoluteString).inserted
        }
    }

    /// Exact matches may not be present in each server's cached first page.
    /// Keep all queried copies available as playback failover lines in memory.
    func registerTransientPlaybackLines(_ channels: [Channel]) {
        var seen = Set<String>()
        let lines = channels.filter { seen.insert($0.streamURL.absoluteString).inserted }
        guard lines.count > 1 else { return }
        for line in lines {
            playbackLinesByChannelID[line.id] = lines
            playbackLinesByAddress[line.streamURL.absoluteString] = lines
        }
    }

    func cachedEmbyPage(
        configurationID: UUID,
        parentID: String? = nil,
        startIndex: Int = 0,
        limit: Int = 60,
        genre: String? = nil,
        prefersSeries: Bool = false
    ) async -> MetadataLibraryPage? {
        let key = MediaServerPageCacheKey(
            configurationID: configurationID,
            parentID: parentID,
            startIndex: startIndex,
            limit: limit,
            genre: genre,
            prefersSeries: prefersSeries,
            sortBy: nil,
            sortDescending: nil,
            includesMediaSources: false
        )
        if let cached = mediaServerPageMemoryCache[key] {
            return cached
        }
        let cached = await EmbyLibraryCache.page(
            configurationID: configurationID,
            parentID: parentID,
            startIndex: startIndex,
            limit: limit,
            genre: genre,
            prefersSeries: prefersSeries
        )
        if let cached {
            mediaServerPageMemoryCache[key] = cached
        }
        return cached
    }

    func clearError() {
        lastError = nil
    }

    /// CarPlay can restore the shared library before a handset scene exists.
    /// Restore-time notices are phone presentation state, not library state;
    /// carrying them into a handset scene created later can make multiple
    /// SwiftUI alert hosts compete and leave only an untouchable dimming view.
    /// User-initiated errors after the phone is visible are unaffected.
    func clearRestoreNoticesBeforeHandsetSceneConnection() {
        lastError = nil
        expiredConfigurationNotice = nil
    }

    func setDefaultEPGAddress(_ address: String) {
        defaultEPGAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        persistEPGConfiguration()
        markConfigurationChanged()
        guard customEPGURLs.isEmpty, playlistEPGURLs.isEmpty else { return }
        Task { await refreshEPG(force: true) }
    }

    func refreshEPG(force: Bool = false) async {
        await EPGService.shared.refresh(urls: epgURLs, force: force)
    }

    var cloudConfigurationSnapshot: CloudConfigurationSnapshot {
        CloudConfigurationSnapshot(
            schemaVersion: 3,
            channels: channels,
            configurations: configurations,
            activeConfigurationID: activeConfigurationID,
            favoriteURLs: favoriteURLs,
            recentURLs: recentURLs,
            playlistEPGURLs: playlistEPGURLs,
            customEPGURLs: customEPGURLs,
            defaultEPGAddress: defaultEPGAddress,
            modifiedAt: configurationModifiedAt
        )
    }

    func applyCloudConfiguration(_ snapshot: CloudConfigurationSnapshot) {
        var removedOversizedConfigurations = false
        if let remoteConfigurations = snapshot.configurations, !remoteConfigurations.isEmpty {
            let sanitized = Self.sanitizedConfigurations(remoteConfigurations)
            configurations = sanitized.configurations
            removedOversizedConfigurations = sanitized.removedCount > 0
            activeConfigurationID = snapshot.activeConfigurationID.flatMap { remoteID in
                configurations.contains(where: { $0.id == remoteID }) ? remoteID : nil
            } ?? configurations.first?.id
            persistConfigurations()
            applyActiveConfiguration()
        } else {
            if snapshot.channels.count <= M3UParser.maximumChannelCount {
                channels = snapshot.channels
            } else {
                channels = []
                removedOversizedConfigurations = true
            }
        }
        let validAddresses = Set(channels.map { $0.streamURL.absoluteString })
        favoriteURLs = snapshot.favoriteURLs.intersection(validAddresses)
        recentURLs = snapshot.recentURLs.filter { validAddresses.contains($0) }
        playlistEPGURLs = snapshot.playlistEPGURLs ?? []
        customEPGURLs = snapshot.customEPGURLs ?? []
        defaultEPGAddress = snapshot.defaultEPGAddress ?? ""
        configurationModifiedAt = snapshot.modifiedAt

        persist()
        persistPreferences()
        persistEPGConfiguration()
        persistModifiedAt()
        lastError = removedOversizedConfigurations
            ? Self.oversizedConfigurationMessage
            : nil
        NotificationCenter.default.post(name: .channelLibraryDidChange, object: nil)
        Task { await refreshEPG() }
    }

    private struct DownloadedPlaylist: Sendable {
        let data: Data
        let responseURL: URL
        let location: MediaAddress
        let contentType: String?
    }

    private func downloadPlaylist(
        _ rawAddress: String,
        requestHeaders: [String: String] = [:],
        proxy: StreamProxyConfiguration? = nil
    ) async throws -> DownloadedPlaylist {
        let trimmed = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let location = MediaAddress.parse(normalized),
              ["http", "https"].contains(location.url.scheme?.lowercased() ?? "") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: location.url)
        request.timeoutInterval = 35
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if PlaybackRequestPreferences.isCustomUserAgentEnabled {
            request.setValue(
                PlaybackRequestPreferences.customUserAgent,
                forHTTPHeaderField: "User-Agent"
            )
        }
        request.setValue(
            "audio/x-mpegurl, application/vnd.apple.mpegurl, text/plain, */*",
            forHTTPHeaderField: "Accept"
        )
        location.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        requestHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        // URL 内联 Header 对单个订阅地址最具体，优先级最高。
        location.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        // Import is a foreground interaction. Do not let an unreachable
        // server keep its modal progress layer on screen for minutes while
        // URLSession waits for connectivity and performs repeated retries.
        // One retry still covers transient WAF/rate-limit responses.
        let maximumAttempts = 2
        for attempt in 0..<maximumAttempts {
            let configuration: URLSessionConfiguration
            if let proxy {
                configuration = ProxyNetworkConfiguration.configured(.ephemeral, using: proxy.proxyConfiguration)
            } else {
                configuration = ProxyNetworkConfiguration.ephemeral()
            }
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 20
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            configuration.waitsForConnectivity = false
            let session = URLSession(configuration: configuration)
            do {
                let (data, response) = try await session.data(for: request)
                session.finishTasksAndInvalidate()
                if let http = response as? HTTPURLResponse,
                   !(200...299).contains(http.statusCode) {
                    guard Self.shouldRetryPlaylistStatus(http.statusCode),
                          attempt < maximumAttempts - 1 else {
                        throw PlaylistImportError.httpStatus(http.statusCode)
                    }
                    try await Task.sleep(for: .milliseconds(600 * (1 << attempt)))
                    continue
                }
                return DownloadedPlaylist(
                    data: data,
                    responseURL: response.url ?? location.url,
                    location: location,
                    contentType: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")
                )
            } catch let error as PlaylistImportError {
                session.invalidateAndCancel()
                throw error
            } catch {
                session.invalidateAndCancel()
                if Task.isCancelled { throw CancellationError() }
                guard Self.shouldRetryPlaylistError(error),
                      attempt < maximumAttempts - 1 else { throw error }
                try await Task.sleep(for: .milliseconds(600 * (1 << attempt)))
            }
        }

        throw URLError(.cannotLoadFromNetwork)
    }

    private func parseDownloadedPlaylist(
        _ download: DownloadedPlaylist,
        requestedName: String
    ) async throws -> M3UParser.PlaylistParseResult {
        let fallback = normalizedConfigurationName(
            requestedName,
            fallback: download.responseURL.deletingPathExtension().lastPathComponent.isEmpty
                ? (download.responseURL.host ?? "单频道")
                : download.responseURL.deletingPathExtension().lastPathComponent
        )
        let parser = self.parser
        return try await Task.detached(priority: .userInitiated) {
            do {
                return try parser.parsePlaylist(
                    data: download.data,
                    baseURL: download.responseURL
                )
            } catch let error as M3UParserError {
                guard error == .emptyPlaylist || error == .invalidEncoding,
                      Self.isSingleMediaResponse(
                        download.contentType,
                        url: download.responseURL
                      )
                else { throw error }
                return M3UParser.PlaylistParseResult(
                    channels: [Channel(
                        name: fallback,
                        streamURL: download.responseURL,
                        httpHeaders: download.location.headers
                    )],
                    epgURLs: []
                )
            }
        }.value
    }

    private func parseRSSDocument(_ download: DownloadedPlaylist) async throws -> RSSFeedDocument {
        try await Task.detached(priority: .userInitiated) {
            try RSSVideoFeedParser.parseDocument(
                data: download.data,
                baseURL: download.responseURL
            )
        }.value
    }

    private nonisolated static func isSingleMediaResponse(
        _ contentType: String?,
        url: URL
    ) -> Bool {
        let value = contentType?.lowercased() ?? ""
        if value.hasPrefix("video/") || value.hasPrefix("audio/")
            || value.contains("mpegurl") || value.contains("mpegts")
            || value.contains("octet-stream") {
            return true
        }
        let pathExtension = url.pathExtension.lowercased()
        return ["m3u8", "mpd"].contains(pathExtension)
            || LocalVideoFormatSupport.fileExtensions.contains(pathExtension)
    }

    private nonisolated static func applyConfigurationDefaultsInBackground(
        to channels: [Channel],
        configuration: PlaylistConfiguration
    ) async -> [Channel] {
        await applyConfigurationDefaultsInBackground(
            to: channels,
            requestHeaders: configuration.requestHeaders,
            proxy: configuration.proxy,
            hlsProxyMode: configuration.hlsProxyMode,
            rtspTransport: configuration.rtspTransport,
            rtspRedirectDetectionEnabled: configuration.rtspRedirectDetectionEnabled,
            bufferPolicy: configuration.bufferPolicy
        )
    }

    private nonisolated static func applyConfigurationDefaultsInBackground(
        to channels: [Channel],
        requestHeaders: [String: String],
        proxy: StreamProxyConfiguration?,
        hlsProxyMode: HLSProxyMode,
        rtspTransport: RTSPTransportPreference?,
        rtspRedirectDetectionEnabled: Bool?,
        bufferPolicy: PlaybackBufferPolicy?
    ) async -> [Channel] {
        await Task.detached(priority: .userInitiated) {
            channels.map { channel in
                var updated = channel
                updated.httpHeaders = channel.httpHeaders.merging(requestHeaders) {
                    _, configurationValue in configurationValue
                }
                if updated.proxyOverride == nil { updated.proxyOverride = proxy }
                updated.hlsProxyMode = hlsProxyMode
                if updated.rtspTransport == nil { updated.rtspTransport = rtspTransport }
                if updated.rtspRedirectDetectionEnabled == nil {
                    updated.rtspRedirectDetectionEnabled = rtspRedirectDetectionEnabled
                }
                if updated.bufferPolicy == nil { updated.bufferPolicy = bufferPolicy }
                return updated
            }
        }.value
    }

    private static func shouldRetryPlaylistStatus(_ status: Int) -> Bool {
        // 403 is included because several subscription panels intermittently
        // reject a request during token/WAF refresh; it is still bounded to
        // two retries and is reported clearly when it remains unavailable.
        [403, 408, 425, 429, 500, 502, 503, 504].contains(status)
    }

    private static func shouldRetryPlaylistError(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        return [
            .cannotFindHost,
            .cannotConnectToHost,
            .networkConnectionLost,
            .dnsLookupFailed,
            .notConnectedToInternet,
            .resourceUnavailable,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed
        ].contains(error.code)
    }

    private static func userFacingPlaylistError(_ error: Error) -> String {
        guard let error = error as? URLError else { return error.localizedDescription }
        switch error.code {
        case .networkConnectionLost:
            return AppLanguage.localized("网络连接中途断开，已自动重试仍未恢复，请检查网络或代理后再试。")
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
            return AppLanguage.localized("当前没有可用网络，请检查 Wi‑Fi、蜂窝网络或代理设置。")
        case .timedOut:
            return AppLanguage.localized("连接服务器超时，源服务器可能较慢或暂时不可用。")
        case .cannotFindHost, .dnsLookupFailed:
            return AppLanguage.localized("无法解析服务器地址，请检查域名、DNS 或代理设置。")
        case .cannotConnectToHost:
            return AppLanguage.localized("无法连接源服务器，请检查地址、端口、内网或代理设置。")
        case .secureConnectionFailed, .serverCertificateUntrusted,
             .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot:
            return AppLanguage.localized("服务器证书校验失败，请检查 HTTPS 地址和证书。")
        default:
            return error.localizedDescription
        }
    }

    private func normalizedConfigurationName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func beginConfigurationImport() {
        configurationImportActivityCount += 1
        isImportingConfiguration = true
    }

    private func endConfigurationImport() {
        configurationImportActivityCount = max(0, configurationImportActivityCount - 1)
        isImportingConfiguration = configurationImportActivityCount > 0
    }

    private func addAndActivate(_ configuration: PlaylistConfiguration) {
        guard configuration.kind == .aggregate
                || configuration.channels.count <= M3UParser.maximumChannelCount
        else {
            lastError = M3UParserError.tooManyChannels.localizedDescription
            return
        }
#if !DJHUB_METADATA_ONLY
        guard ProPurchaseManager.shared.canAddConfiguration(existingCount: configurations.count) else {
            lastError = AppLanguage.localizedFormat(
                "免费版最多可添加 %d 个资源，升级 RovePlayer Pro 后不限制数量。",
                ProPurchaseManager.freeConfigurationLimit
            )
            return
        }
#endif
        configurations.append(configuration)
        activeConfigurationID = configuration.id
        UserDefaults.standard.set(configuration.id.uuidString, forKey: activeConfigurationStorageKey)
        persistConfigurations()
        applyActiveConfiguration()
        lastError = nil
        markConfigurationChanged()
        NotificationCenter.default.post(name: .configurationDidAdd, object: configuration.id)
        Task { await refreshEPG(force: true) }
    }

    /// Large imports are fully parsed and encoded before touching published
    /// state. The main actor performs one final configuration commit, so the
    /// import form stays responsive and cannot report success before the new
    /// source is durably stored.
    private func addAndActivatePrepared(_ configuration: PlaylistConfiguration) async {
        guard configuration.kind == .aggregate
                || configuration.channels.count <= M3UParser.maximumChannelCount
        else {
            lastError = M3UParserError.tooManyChannels.localizedDescription
            return
        }
#if !DJHUB_METADATA_ONLY
        guard ProPurchaseManager.shared.canAddConfiguration(existingCount: configurations.count) else {
            lastError = AppLanguage.localizedFormat(
                "免费版最多可添加 %d 个资源，升级 RovePlayer Pro 后不限制数量。",
                ProPurchaseManager.freeConfigurationLimit
            )
            return
        }
#endif

        configurationPersistenceTask?.cancel()
        configurationPersistenceTask = nil
        var baseConfigurations = configurations
        var updatedConfigurations: [PlaylistConfiguration]
        while true {
            updatedConfigurations = baseConfigurations + [configuration]
            do {
                try await ChannelLibraryPersistenceWriter.shared.writeConfigurations(
                    updatedConfigurations,
                    activeConfigurationID: configuration.id,
                    configurationsKey: configurationsStorageKey,
                    activeConfigurationKey: activeConfigurationStorageKey
                )
            } catch is CancellationError {
                return
            } catch {
                lastError = AppLanguage.localizedFormat(
                    "保存配置失败：%@",
                    error.localizedDescription
                )
                return
            }

            // A CarPlay action or iCloud merge may update configurations while
            // a very large snapshot is encoding. Rebase and encode once more
            // instead of publishing an old array over the newer user action.
            guard configurations != baseConfigurations else { break }
            baseConfigurations = configurations
        }

        configurations = updatedConfigurations
        activeConfigurationID = configuration.id
        applyActiveConfiguration()
        lastError = nil
        markConfigurationChanged()
        NotificationCenter.default.post(name: .configurationDidAdd, object: configuration.id)
        Task { await refreshEPG(force: true) }
    }

    /// Persists a refreshed/edited configuration before publishing it. If a
    /// different scene changes the configuration array during background JSON
    /// encoding, the replacement is rebased by ID and encoded again.
    private func commitPreparedConfiguration(
        _ updatedConfiguration: PlaylistConfiguration
    ) async throws {
        configurationPersistenceTask?.cancel()
        configurationPersistenceTask = nil
        var baseConfigurations = configurations

        while true {
            guard let index = baseConfigurations.firstIndex(where: {
                $0.id == updatedConfiguration.id
            }) else {
                throw CancellationError()
            }
            var committedConfigurations = baseConfigurations
            committedConfigurations[index] = updatedConfiguration
            try await ChannelLibraryPersistenceWriter.shared.writeConfigurations(
                committedConfigurations,
                activeConfigurationID: activeConfigurationID,
                configurationsKey: configurationsStorageKey,
                activeConfigurationKey: activeConfigurationStorageKey
            )

            guard configurations != baseConfigurations else {
                configurations = committedConfigurations
                return
            }
            baseConfigurations = configurations
        }
    }

    private func applyActiveConfiguration(persistChannelSnapshot: Bool = true) {
        scheduleNextExpiration()
        guard let activeConfiguration else {
            activeLineChannels = []
            rebuildPlaybackLineCache()
            channels = []
            playlistEPGURLs = []
            customEPGURLs = []
            if persistChannelSnapshot { persist() }
            persistEPGConfiguration()
            NotificationCenter.default.post(name: .channelLibraryDidChange, object: nil)
#if !DJHUB_METADATA_ONLY
            WatchSyncService.shared.send(channels: channels, favoriteURLs: favoriteURLs)
#endif
            return
        }

        // Older builds saved Emby servers as Jellyfin and eagerly persisted up
        // to 10,000 items. Publishing that entire array before identifying the
        // server can stall the first frame. Present a small, non-destructive
        // slice while the public server-info endpoint is checked; confirmed
        // Jellyfin keeps its original list, while Emby is migrated to the
        // category/paged path below.
        var presentationConfiguration = activeConfiguration
        if shouldIdentifyLegacyMediaServer(activeConfiguration) {
            presentationConfiguration.channels = Array(
                activeConfiguration.channels.prefix(JellyfinConfigurationService.embyInitialItemLimit)
            )
            scheduleLegacyMediaServerIdentification(for: activeConfiguration)
        }

        activeLineChannels = resolvedLineChannels(for: presentationConfiguration)
        rebuildPlaybackLineCache()
        channels = resolvedChannels(
            for: presentationConfiguration,
            sourceChannels: activeLineChannels
        )
        playlistEPGURLs = resolvedEPGURLs(for: presentationConfiguration)
        customEPGURLs = []
        if persistChannelSnapshot { persist() }
        persistEPGConfiguration()
        NotificationCenter.default.post(name: .channelLibraryDidChange, object: nil)
#if !DJHUB_METADATA_ONLY
        WatchSyncService.shared.send(channels: channels, favoriteURLs: favoriteURLs)
#endif
    }

    private func refreshActivePresentationAfterGroupVisibilityChange(
        configurationID: UUID
    ) {
        guard activeConfigurationID == configurationID
                || activeConfiguration?.memberIDs.contains(configurationID) == true,
              let selectedID = activeConfigurationID
        else { return }

        let configurationSnapshot = configurations
        let favoriteSnapshot = favoriteURLs
        let recentSnapshot = recentURLs
        activePresentationTask?.cancel()
        activePresentationTask = Task { [weak self] in
            let prepared = await Task.detached(priority: .userInitiated) {
                Self.prepareActivePresentation(
                    configurations: configurationSnapshot,
                    activeConfigurationID: selectedID,
                    favoriteURLs: favoriteSnapshot,
                    recentURLs: recentSnapshot
                )
            }.value
            guard !Task.isCancelled,
                  let self,
                  self.activeConfigurationID == selectedID,
                  self.configurations == configurationSnapshot
            else { return }
            self.activePresentationTask = nil
            self.applyPreparedActivePresentation(
                prepared,
                persistChannelSnapshot: false
            )
        }
    }

    private func shouldIdentifyLegacyMediaServer(
        _ configuration: PlaylistConfiguration
    ) -> Bool {
        configuration.kind == .legacyLibraryA
            && configuration.channels.count > JellyfinConfigurationService.embyInitialItemLimit
            && !confirmedJellyfinConfigurationIDs.contains(configuration.id)
            && configuration.sourceAddress?.isEmpty == false
    }

    private func scheduleLegacyMediaServerIdentification(
        for configuration: PlaylistConfiguration
    ) {
        guard legacyMediaServerDetectionTasks[configuration.id] == nil,
              let server = configuration.sourceAddress else { return }
        let configurationID = configuration.id
        let token = ConfigurationCredentialVault.password(for: configurationID)
        let preferredUsername = configuration.username ?? ""
        let knownUserID = configuration.mediaServerUserID
        legacyMediaServerDetectionTasks[configurationID] = Task { [weak self] in
            let detectedKind = await JellyfinConfigurationService.detectServerKind(server: server)
            let totalItemCount: Int? = if detectedKind == .legacyLibraryB, let token {
                try? await JellyfinConfigurationService.loadEmbyPage(
                    server: server,
                    token: token,
                    preferredUsername: preferredUsername,
                    knownUserID: knownUserID,
                    configurationID: configurationID,
                    serverKind: .legacyLibraryB,
                    parentID: nil,
                    startIndex: 0,
                    limit: 1,
                    searchTerm: nil,
                    genre: nil,
                    prefersSeries: false
                ).totalCount
            } else {
                nil
            }
            guard !Task.isCancelled, let self else { return }
            self.finishLegacyMediaServerIdentification(
                configurationID: configurationID,
                detectedKind: detectedKind,
                totalItemCount: totalItemCount
            )
        }
    }

    private func finishLegacyMediaServerIdentification(
        configurationID: UUID,
        detectedKind: PlaylistConfigurationKind?,
        totalItemCount: Int?
    ) {
        legacyMediaServerDetectionTasks[configurationID] = nil
        guard let index = configurations.firstIndex(where: { $0.id == configurationID }),
              configurations[index].kind == .legacyLibraryA else { return }

        guard detectedKind == .legacyLibraryB else {
            if detectedKind == .legacyLibraryA {
                confirmedJellyfinConfigurationIDs.insert(configurationID)
                if activeConfigurationID == configurationID {
                    applyActiveConfiguration(persistChannelSnapshot: false)
                }
            }
            return
        }

        var migrated = configurations[index]
        migrated.kind = .legacyLibraryB
        migrated.totalItemCount = totalItemCount ?? migrated.channels.count
        migrated.channels = migrated.channels
            .prefix(JellyfinConfigurationService.embyInitialItemLimit)
            .map { channel in
                var channel = channel
                if case .legacyLibraryA(_, let itemID) = channel.resolver {
                    channel.resolver = .legacyLibraryB(configurationID: configurationID, itemID: itemID)
                    if let container = channel.httpHeaders.removeValue(
                        forKey: "X-Tubo-Jellyfin-Container"
                    ) {
                        channel.httpHeaders["X-Tubo-Emby-Container"] = container
                    }
                    channel.streamURL = URL(
                        string: "tubo-legacyLibraryB://item/\(configurationID.uuidString.lowercased())/\(itemID)"
                    ) ?? channel.streamURL
                }
                return channel
            }
        migrated.updatedAt = Date()
        configurations[index] = migrated
        persistConfigurations()
        if activeConfigurationID == configurationID {
            applyActiveConfiguration(persistChannelSnapshot: false)
        }
    }

    private func applyPreparedActivePresentation(
        _ prepared: PreparedActivePresentation,
        persistChannelSnapshot: Bool = true
    ) {
        scheduleNextExpiration()
        isApplyingPreparedPresentation = true
        activeLineChannels = prepared.activeLineChannels
        playbackLinesByChannelID = prepared.playbackLinesByChannelID
        playbackLinesByAddress = prepared.playbackLinesByAddress
        playbackLinesByLogicalKey = prepared.playbackLinesByLogicalKey
        displayGroupByChannelID = prepared.displayGroupByChannelID
        groupedChannelsCache = prepared.groups.map { ($0.name, $0.channels) }
        favoriteChannelsCache = prepared.favoriteChannels
        recentChannelsCache = prepared.recentChannels
        channels = prepared.channels
        isApplyingPreparedPresentation = false
        playlistEPGURLs = prepared.playlistEPGURLs
        customEPGURLs = []
        if persistChannelSnapshot { persist() }
        persistEPGConfiguration()
        NotificationCenter.default.post(name: .channelLibraryDidChange, object: nil)
#if !DJHUB_METADATA_ONLY
        WatchSyncService.shared.send(channels: channels, favoriteURLs: favoriteURLs)
#endif
    }

    private nonisolated static func prepareActivePresentation(
        configurations: [PlaylistConfiguration],
        activeConfigurationID: UUID?,
        favoriteURLs: Set<String>,
        recentURLs: [String]
    ) -> PreparedActivePresentation {
        guard let activeConfigurationID,
              let activeConfiguration = configurations.first(where: {
                  $0.id == activeConfigurationID
              }),
              !activeConfiguration.isExpired
        else {
            return PreparedActivePresentation(
                activeLineChannels: [],
                channels: [],
                playlistEPGURLs: [],
                playbackLinesByChannelID: [:],
                playbackLinesByAddress: [:],
                playbackLinesByLogicalKey: [:],
                groups: [],
                displayGroupByChannelID: [:],
                favoriteChannels: [],
                recentChannels: []
            )
        }

        let sourceChannels: [Channel]
        let epgURLs: [URL]
        if activeConfiguration.kind == .aggregate {
            let requestedIDs = Set(activeConfiguration.memberIDs)
            let members = configurations.filter {
                requestedIDs.contains($0.id)
                    && $0.kind != .aggregate
                    && !$0.isExpired
            }
            let memberChannels = members.flatMap {
                filteredChannels(
                    $0.channels,
                    hiddenChannelGroups: $0.hiddenChannelGroups
                )
            }
            sourceChannels = filteredChannels(
                memberChannels,
                hiddenChannelGroups: activeConfiguration.hiddenChannelGroups
            )
            var seenEPGURLs = Set<String>()
            epgURLs = members.flatMap(\.epgURLs).filter {
                seenEPGURLs.insert($0.absoluteString).inserted
            }
        } else {
            sourceChannels = filteredChannels(
                activeConfiguration.channels,
                hiddenChannelGroups: activeConfiguration.hiddenChannelGroups
            )
            epgURLs = activeConfiguration.epgURLs
        }

        var seenAddresses = Set<String>()
        let activeLines = sourceChannels.filter {
            seenAddresses.insert($0.streamURL.absoluteString).inserted
        }

        let visibleChannels: [Channel]
        if activeConfiguration.kind == .aggregate {
            var merged: [Channel] = []
            var indexByLogicalKey: [String: Int] = [:]
            for channel in activeLines {
                let keys = logicalChannelKeys(channel)
                if let existingIndex = keys.compactMap({ indexByLogicalKey[$0] }).first {
                    for key in keys { indexByLogicalKey[key] = existingIndex }
                    continue
                }
                let index = merged.count
                merged.append(channel)
                for key in keys { indexByLogicalKey[key] = index }
            }
            visibleChannels = merged
        } else {
            visibleChannels = activeLines
        }

        var disjointSet = ChannelLineDisjointSet(count: activeLines.count)
        var firstIndexByKey: [String: Int] = [:]
        firstIndexByKey.reserveCapacity(activeLines.count * 2)
        for (index, channel) in activeLines.enumerated() {
            for key in logicalChannelKeys(channel) {
                if let firstIndex = firstIndexByKey[key] {
                    disjointSet.union(index, firstIndex)
                } else {
                    firstIndexByKey[key] = index
                }
            }
        }

        var linesByRoot: [Int: [Channel]] = [:]
        linesByRoot.reserveCapacity(activeLines.count)
        for (index, channel) in activeLines.enumerated() {
            linesByRoot[disjointSet.root(of: index), default: []].append(channel)
        }

        var linesByID: [UUID: [Channel]] = [:]
        var linesByAddress: [String: [Channel]] = [:]
        var linesByKey: [String: [Channel]] = [:]
        for lines in linesByRoot.values where lines.count > 1 {
            for line in lines {
                linesByID[line.id] = lines
                linesByAddress[line.streamURL.absoluteString] = lines
                for key in logicalChannelKeys(line) { linesByKey[key] = lines }
            }
        }

        var displayGroups: [UUID: String] = [:]
        displayGroups.reserveCapacity(visibleChannels.count)
        for channel in visibleChannels {
            displayGroups[channel.id] = inferredDisplayGroup(for: channel)
        }
        let preferredGroupOrder = [
            "央视频道", "卫视频道", "4K/8K", "影视", "体育", "少儿", "地方频道",
        ]
        let groups = Dictionary(grouping: visibleChannels) {
            displayGroups[$0.id] ?? inferredDisplayGroup(for: $0)
        }
        .map { PreparedChannelGroup(name: $0.key, channels: $0.value) }
        .sorted { lhs, rhs in
            let lhsIndex = preferredGroupOrder.firstIndex(of: lhs.name)
                ?? preferredGroupOrder.count
            let rhsIndex = preferredGroupOrder.firstIndex(of: rhs.name)
                ?? preferredGroupOrder.count
            return lhsIndex == rhsIndex
                ? lhs.name.localizedCompare(rhs.name) == .orderedAscending
                : lhsIndex < rhsIndex
        }

        var displayedByID: [UUID: Channel] = [:]
        var displayedByAddress: [String: Channel] = [:]
        var displayedByLogicalKey: [String: Channel] = [:]
        displayedByID.reserveCapacity(visibleChannels.count)
        displayedByAddress.reserveCapacity(visibleChannels.count)
        displayedByLogicalKey.reserveCapacity(visibleChannels.count * 2)
        for channel in visibleChannels {
            displayedByID[channel.id] = channel
            displayedByAddress[channel.streamURL.absoluteString] = channel
            for key in logicalChannelKeys(channel) where displayedByLogicalKey[key] == nil {
                displayedByLogicalKey[key] = channel
            }
        }

        func displayedChannel(for address: String) -> Channel? {
            if let direct = displayedByAddress[address] { return direct }
            guard let lines = linesByAddress[address] else { return nil }
            for line in lines {
                if let direct = displayedByID[line.id]
                    ?? displayedByAddress[line.streamURL.absoluteString] {
                    return direct
                }
                for key in logicalChannelKeys(line) {
                    if let logical = displayedByLogicalKey[key] { return logical }
                }
            }
            return nil
        }

        let favoriteChannelIDs = Set(favoriteURLs.compactMap {
            displayedChannel(for: $0)?.id
        })
        let favorites = visibleChannels.filter { favoriteChannelIDs.contains($0.id) }
        var seenRecentChannelIDs = Set<UUID>()
        let recents = recentURLs.compactMap { address -> Channel? in
            guard let channel = displayedChannel(for: address),
                  seenRecentChannelIDs.insert(channel.id).inserted
            else { return nil }
            return channel
        }

        return PreparedActivePresentation(
            activeLineChannels: activeLines,
            channels: visibleChannels,
            playlistEPGURLs: epgURLs,
            playbackLinesByChannelID: linesByID,
            playbackLinesByAddress: linesByAddress,
            playbackLinesByLogicalKey: linesByKey,
            groups: groups,
            displayGroupByChannelID: displayGroups,
            favoriteChannels: favorites,
            recentChannels: recents
        )
    }

    private func resolvedChannels(
        for configuration: PlaylistConfiguration,
        sourceChannels: [Channel]
    ) -> [Channel] {
        guard !configuration.isExpired else { return [] }
        guard configuration.kind == .aggregate else { return sourceChannels }

        var merged: [Channel] = []
        var indexByLogicalKey: [String: Int] = [:]
        for channel in sourceChannels {
            let keys = Self.logicalChannelKeys(channel)
            if let existingIndex = keys.compactMap({ indexByLogicalKey[$0] }).first {
                for key in keys { indexByLogicalKey[key] = existingIndex }
                continue
            }
            let index = merged.count
            merged.append(channel)
            for key in keys { indexByLogicalKey[key] = index }
        }
        return merged
    }

    private func resolvedLineChannels(for configuration: PlaylistConfiguration) -> [Channel] {
        guard !configuration.isExpired else { return [] }
        let sourceChannels: [Channel]
        if configuration.kind == .aggregate {
            let memberChannels = orderedAggregateConfigurations(configuration.memberIDs)
                .filter { !$0.isExpired }
                .flatMap {
                    Self.filteredChannels(
                        $0.channels,
                        hiddenChannelGroups: $0.hiddenChannelGroups
                    )
                }
            sourceChannels = Self.filteredChannels(
                memberChannels,
                hiddenChannelGroups: configuration.hiddenChannelGroups
            )
        } else {
            sourceChannels = Self.filteredChannels(
                configuration.channels,
                hiddenChannelGroups: configuration.hiddenChannelGroups
            )
        }

        var seenAddresses = Set<String>()
        return sourceChannels.filter {
            seenAddresses.insert($0.streamURL.absoluteString).inserted
        }
    }

    private func resolvedEPGURLs(for configuration: PlaylistConfiguration) -> [URL] {
        guard !configuration.isExpired else { return [] }
        if configuration.kind != .aggregate { return configuration.epgURLs }
        var seen = Set<String>()
        return orderedAggregateConfigurations(configuration.memberIDs)
            .filter { !$0.isExpired }
            .flatMap(\.epgURLs)
            .filter { seen.insert($0.absoluteString).inserted }
    }

    private func orderedAggregateMemberIDs(_ memberIDs: [UUID]) -> [UUID] {
        let requested = Set(memberIDs)
        return configurations.compactMap { configuration in
            guard requested.contains(configuration.id), configuration.kind != .aggregate else {
                return nil
            }
            return configuration.id
        }
    }

    private func orderedAggregateConfigurations(_ memberIDs: [UUID]) -> [PlaylistConfiguration] {
        let requested = Set(memberIDs)
        return configurations.filter {
            requested.contains($0.id) && $0.kind != .aggregate
        }
    }

    private nonisolated static func logicalChannelKeys(_ channel: Channel) -> Set<String> {
        var keys = Set<String>()
        if let tvgID = channel.tvgID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !tvgID.isEmpty {
            keys.insert("id:\(tvgID)")
        }
        for value in [channel.name, channel.tvgName].compactMap({ $0 }) {
            let normalized = EPGNameNormalizer.normalize(value)
            if !normalized.isEmpty { keys.insert("name:\(normalized)") }
        }
        if keys.isEmpty { keys.insert("url:\(channel.streamURL.absoluteString)") }
        return keys
    }

    /// Groups channels by the transitive closure of tvg-id/name aliases while
    /// preserving playlist order. This work happens only when a configuration
    /// is selected or refreshed; reads during scrolling are dictionary hits.
    private func rebuildPlaybackLineCache() {
        guard !activeLineChannels.isEmpty else {
            playbackLinesByChannelID = [:]
            playbackLinesByAddress = [:]
            playbackLinesByLogicalKey = [:]
            return
        }

        var disjointSet = ChannelLineDisjointSet(count: activeLineChannels.count)
        var firstIndexByKey: [String: Int] = [:]
        firstIndexByKey.reserveCapacity(activeLineChannels.count * 2)

        for (index, channel) in activeLineChannels.enumerated() {
            for key in Self.logicalChannelKeys(channel) {
                if let firstIndex = firstIndexByKey[key] {
                    disjointSet.union(index, firstIndex)
                } else {
                    firstIndexByKey[key] = index
                }
            }
        }

        var linesByRoot: [Int: [Channel]] = [:]
        linesByRoot.reserveCapacity(activeLineChannels.count)
        for (index, channel) in activeLineChannels.enumerated() {
            linesByRoot[disjointSet.root(of: index), default: []].append(channel)
        }

        var byID: [UUID: [Channel]] = [:]
        var byAddress: [String: [Channel]] = [:]
        var byKey: [String: [Channel]] = [:]
        byID.reserveCapacity(activeLineChannels.count)
        byAddress.reserveCapacity(activeLineChannels.count)
        byKey.reserveCapacity(firstIndexByKey.count)

        for lines in linesByRoot.values {
            // Unique channels need no lookup table: playbackLines(for:) can
            // return the supplied channel directly. On a 50,000-item VOD list,
            // indexing every singleton here previously created three huge
            // dictionaries of one-element arrays and exhausted memory.
            guard lines.count > 1 else { continue }
            for line in lines {
                byID[line.id] = lines
                byAddress[line.streamURL.absoluteString] = lines
                for key in Self.logicalChannelKeys(line) {
                    byKey[key] = lines
                }
            }
        }

        playbackLinesByChannelID = byID
        playbackLinesByAddress = byAddress
        playbackLinesByLogicalKey = byKey
    }

    private func scheduleNextExpiration() {
        expirationTask?.cancel()
        let now = Date()
        guard let nextExpiration = configurations.compactMap(\.expirationDate)
            .filter({ $0 > now })
            .min()
        else {
            expirationTask = nil
            return
        }

        expirationTask = Task { [weak self] in
            let delay = max(0, nextExpiration.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.applyActiveConfiguration()
            // Refresh rows and CarPlay configuration controls at the boundary,
            // even when the expiring configuration is not currently active.
            self.configurations = self.configurations
            self.publishExpiredConfigurationNoticeIfNeeded()
        }
    }

    private func publishExpiredConfigurationNoticeIfNeeded() {
        guard expiredConfigurationNotice == nil,
              let configuration = configurations.first(where: {
                  $0.isWebImportProtected == true
                      && $0.isExpired
                      && !reportedExpiredConfigurationIDs.contains($0.id)
              })
        else { return }

        reportedExpiredConfigurationIDs.insert(configuration.id)
        expiredConfigurationNotice = configuration
    }

    private func persistConfigurations() {
        let snapshot = configurations
        let selectedID = activeConfigurationID
        configurationPersistenceTask?.cancel()
        configurationPersistenceTask = Task {
            try? await ChannelLibraryPersistenceWriter.shared.writeConfigurations(
                snapshot,
                activeConfigurationID: selectedID,
                configurationsKey: configurationsStorageKey,
                activeConfigurationKey: activeConfigurationStorageKey
            )
        }
    }

    private func persist() {
        let snapshot = channels
        channelPersistenceTask?.cancel()
        channelPersistenceTask = Task {
            try? await ChannelLibraryPersistenceWriter.shared.writeChannels(
                snapshot,
                storageKey: storageKey
            )
        }
    }

    private func restore() {
        restoreModifiedAt()
        restoreEPGConfiguration()
        restorePreferences()

        if let configurationData = UserDefaults.standard.data(forKey: configurationsStorageKey),
           let decodedConfigurations = try? JSONDecoder().decode(
               [PlaylistConfiguration].self,
               from: configurationData
           ),
           !decodedConfigurations.isEmpty {
            let sanitized = Self.sanitizedConfigurations(decodedConfigurations)
            configurations = sanitized.configurations
            activeConfigurationID = UserDefaults.standard.string(forKey: activeConfigurationStorageKey)
                .flatMap(UUID.init(uuidString:))
            if !configurations.contains(where: { $0.id == activeConfigurationID }) {
                activeConfigurationID = configurations.first?.id
            }
            if sanitized.removedCount > 0 || sanitized.trimmedEmbyCount > 0 {
                // Persist the recovery immediately. Otherwise the same
                // unsupported 160k-channel payload would be decoded again on
                // every launch and could crash before the user can remove it.
                persistConfigurations()
            }
            if sanitized.removedCount > 0 {
                lastError = Self.oversizedConfigurationMessage
            }
            applyActiveConfiguration()
        } else if let data = UserDefaults.standard.data(forKey: storageKey),
                  let decoded = try? JSONDecoder().decode([Channel].self, from: data),
                  !decoded.isEmpty {
            guard decoded.count <= M3UParser.maximumChannelCount else {
                UserDefaults.standard.removeObject(forKey: storageKey)
                lastError = Self.oversizedConfigurationMessage
                return
            }
            activeLineChannels = decoded
            rebuildPlaybackLineCache()
            channels = decoded
            let migrated = PlaylistConfiguration(
                name: AppLanguage.localized("已导入配置"),
                kind: .local,
                channels: decoded,
                epgURLs: customEPGURLs.isEmpty ? playlistEPGURLs : customEPGURLs
            )
            configurations = [migrated]
            activeConfigurationID = migrated.id
            persistConfigurations()
        }

        // Migrate oversized legacy Emby snapshots even when another source is
        // active. Otherwise an unused 10,000-item media-server cache remains
        // in the configuration payload and slows every cold launch.
        for configuration in configurations where shouldIdentifyLegacyMediaServer(configuration) {
            scheduleLegacyMediaServerIdentification(for: configuration)
        }

        if configurationModifiedAt == .distantPast, !channels.isEmpty {
            configurationModifiedAt = Date()
            persistModifiedAt()
        }
        publishExpiredConfigurationNoticeIfNeeded()
    }

    private static var oversizedConfigurationMessage: String {
        AppLanguage.localized("已移除超过 50,000 个频道的配置，请精简或拆分播放列表后重新导入。")
    }

    private static func sanitizedConfigurations(
        _ input: [PlaylistConfiguration]
    ) -> (configurations: [PlaylistConfiguration], removedCount: Int, trimmedEmbyCount: Int) {
        var normalizedInput = input
        var trimmedEmbyCount = 0
        for index in normalizedInput.indices
            where normalizedInput[index].kind.isEmbyCompatible
                && normalizedInput[index].channels.count > JellyfinConfigurationService.embyInitialItemLimit {
            if normalizedInput[index].totalItemCount == nil {
                normalizedInput[index].totalItemCount = normalizedInput[index].channels.count
            }
            normalizedInput[index].channels = Array(
                normalizedInput[index].channels.prefix(JellyfinConfigurationService.embyInitialItemLimit)
            )
            trimmedEmbyCount += 1
        }

        let oversizedIDs: Set<UUID> = Set(normalizedInput.compactMap { configuration -> UUID? in
            guard configuration.kind != .aggregate,
                  configuration.channels.count > M3UParser.maximumChannelCount
            else { return nil }
            return configuration.id
        })
        guard !oversizedIDs.isEmpty else { return (normalizedInput, 0, trimmedEmbyCount) }

        var result: [PlaylistConfiguration] = []
        result.reserveCapacity(normalizedInput.count - oversizedIDs.count)
        for var configuration in normalizedInput where !oversizedIDs.contains(configuration.id) {
            if configuration.kind == .aggregate {
                configuration.memberIDs.removeAll { oversizedIDs.contains($0) }
                guard !configuration.memberIDs.isEmpty else { continue }
            }
            result.append(configuration)
        }
        return (result, oversizedIDs.count, trimmedEmbyCount)
    }

    private func persistPreferences() {
        UserDefaults.standard.set(Array(favoriteURLs), forKey: favoritesStorageKey)
        UserDefaults.standard.set(recentURLs, forKey: recentStorageKey)
    }

    private func markConfigurationChanged() {
        configurationModifiedAt = Date()
        persistModifiedAt()
#if !DJHUB_METADATA_ONLY
        CloudSyncService.shared.scheduleSync(library: self)
#endif
#if !DJHUB_METADATA_ONLY
        WatchSyncService.shared.send(channels: channels, favoriteURLs: favoriteURLs)
#endif
    }

    private func persistModifiedAt() {
        UserDefaults.standard.set(configurationModifiedAt, forKey: modifiedAtStorageKey)
    }

    private func restoreModifiedAt() {
        configurationModifiedAt = UserDefaults.standard.object(forKey: modifiedAtStorageKey) as? Date
            ?? .distantPast
    }

    private func restorePreferences() {
        favoriteURLs = Set(UserDefaults.standard.stringArray(forKey: favoritesStorageKey) ?? [])
        recentURLs = UserDefaults.standard.stringArray(forKey: recentStorageKey) ?? []
    }

    private func persistEPGConfiguration() {
        UserDefaults.standard.set(
            playlistEPGURLs.map(\.absoluteString),
            forKey: playlistEPGStorageKey
        )
        UserDefaults.standard.set(
            customEPGURLs.map(\.absoluteString),
            forKey: customEPGStorageKey
        )
        UserDefaults.standard.set(defaultEPGAddress, forKey: defaultEPGStorageKey)
    }

    private func restoreEPGConfiguration() {
        playlistEPGURLs = (UserDefaults.standard.stringArray(forKey: playlistEPGStorageKey) ?? [])
            .compactMap(URL.init(string:))
        customEPGURLs = (UserDefaults.standard.stringArray(forKey: customEPGStorageKey) ?? [])
            .compactMap(URL.init(string:))
        defaultEPGAddress = UserDefaults.standard.string(forKey: defaultEPGStorageKey) ?? ""
    }

    static func parseURLList(_ address: String) -> [URL] {
        address
            .components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap(URL.init(string:))
            .filter { $0.scheme != nil }
    }

    private nonisolated static func containsAny(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains { text.localizedCaseInsensitiveContains($0) }
    }
}
#endif

#if !DJHUB_METADATA_ONLY
struct IPTVConfigurationLoadResult {
    let channels: [Channel]
    let epgURLs: [URL]
}

enum IPTVConfigurationError: LocalizedError {
    case invalidServer
    case invalidCredentials
    case invalidResponse
    case missingCredentials
    case missingConfiguration
    case portalHandshakeFailed
    case streamResolutionFailed
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidServer: AppLanguage.localized("服务器或 Portal 地址格式不正确。")
        case .invalidCredentials: AppLanguage.localized("用户名或密码错误，或登录信息已失效，请重新输入。")
        case .invalidResponse: AppLanguage.localized("服务器返回了无法识别的数据。")
        case .missingCredentials: AppLanguage.localized("此配置缺少登录凭据，请重新添加。")
        case .missingConfiguration: AppLanguage.localized("找不到频道对应的 Stalker 配置。")
        case .portalHandshakeFailed: AppLanguage.localized("Stalker Portal 握手失败，请检查 Portal 地址和 MAC。")
        case .streamResolutionFailed: AppLanguage.localized("Stalker Portal 未返回可播放地址。")
        case .httpStatus(let code):
            switch code {
            case 401:
                AppLanguage.localized("用户名或密码错误，或登录信息已失效，请重新输入。")
            case 403:
                AppLanguage.localized("当前账号没有访问权限，请联系服务器管理员。")
            case 404:
                AppLanguage.localized("服务器地址或接口路径不正确，请检查地址和端口。")
            case 429:
                AppLanguage.localized("请求过于频繁，服务器暂时拒绝访问，请稍后重试。")
            case 500...599:
                AppLanguage.localizedFormat("服务器暂时不可用，请稍后重试（错误码 %d）。", code)
            default:
                AppLanguage.localizedFormat("服务器请求失败（错误码 %d）。", code)
            }
        }
    }
}

@MainActor
enum IPTVConfigurationService {
    private struct StalkerContext {
        let endpoint: URL
        let token: String
        let macAddress: String
    }

    static func loadXtream(
        server: String,
        username: String,
        password: String
    ) async throws -> IPTVConfigurationLoadResult {
        let baseURL = try normalizedServerURL(server)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty, !password.isEmpty else {
            throw IPTVConfigurationError.invalidCredentials
        }

        let profileObject = try await requestJSON(
            url: try xtreamAPIURL(
                baseURL: baseURL,
                username: cleanUsername,
                password: password,
                action: nil
            )
        )
        guard let profile = profileObject as? [String: Any],
              let userInfo = profile["user_info"] as? [String: Any],
              valueString(userInfo["auth"]) == "1" else {
            throw IPTVConfigurationError.invalidCredentials
        }

        let categoriesObject = try await requestJSON(
            url: try xtreamAPIURL(
                baseURL: baseURL,
                username: cleanUsername,
                password: password,
                action: "get_live_categories"
            )
        )
        let streamsObject = try await requestJSON(
            url: try xtreamAPIURL(
                baseURL: baseURL,
                username: cleanUsername,
                password: password,
                action: "get_live_streams"
            )
        )

        let categoryRows = categoriesObject as? [[String: Any]] ?? []
        let categories: [String: String] = categoryRows.reduce(into: [:]) { result, row in
            guard let id = valueString(row["category_id"]),
                  let name = valueString(row["category_name"]) else { return }
            result[id] = name
        }
        guard let streamRows = streamsObject as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }

        let usernamePath = encodedPathComponent(cleanUsername)
        let passwordPath = encodedPathComponent(password)
        let channels = streamRows.compactMap { row -> Channel? in
            guard let streamID = valueString(row["stream_id"]),
                  let name = valueString(row["name"]),
                  let streamURL = URL(
                    string: "live/\(usernamePath)/\(passwordPath)/\(encodedPathComponent(streamID)).ts",
                    relativeTo: baseURL.appendingPathComponent("/")
                  )?.absoluteURL else { return nil }
            let categoryID = valueString(row["category_id"])
            return Channel(
                name: name,
                streamURL: streamURL,
                group: categoryID.flatMap { categories[$0] } ?? "直播",
                logoURL: valueString(row["stream_icon"]).flatMap(URL.init(string:)),
                tvgID: valueString(row["epg_channel_id"]),
                tvgName: name
            )
        }
        guard !channels.isEmpty else { throw IPTVConfigurationError.invalidResponse }

        let epgURL = try xtreamURL(
            baseURL: baseURL,
            path: "xmltv.php",
            queryItems: [
                URLQueryItem(name: "username", value: cleanUsername),
                URLQueryItem(name: "password", value: password),
            ]
        )
        return IPTVConfigurationLoadResult(channels: channels, epgURLs: [epgURL])
    }

    static func loadStalker(
        portal: String,
        macAddress: String,
        configurationID: UUID
    ) async throws -> [Channel] {
        let context = try await stalkerHandshake(portal: portal, macAddress: macAddress)
        _ = try? await stalkerRequest(
            context: context,
            items: [
                URLQueryItem(name: "type", value: "stb"),
                URLQueryItem(name: "action", value: "get_profile"),
                URLQueryItem(name: "hd", value: "1"),
            ]
        )

        let genresObject = try await stalkerRequest(
            context: context,
            items: [
                URLQueryItem(name: "type", value: "itv"),
                URLQueryItem(name: "action", value: "get_genres"),
            ]
        )
        let genreRows = stalkerArray(from: genresObject)
        let genres: [String: String] = genreRows.reduce(into: [:]) { result, row in
            guard let id = valueString(row["id"]),
                  let title = valueString(row["title"]) else { return }
            result[id] = title
        }

        let channelsObject = try await stalkerRequest(
            context: context,
            items: [
                URLQueryItem(name: "type", value: "itv"),
                URLQueryItem(name: "action", value: "get_all_channels"),
            ]
        )
        let rows = stalkerArray(from: channelsObject)
        let channels = rows.compactMap { row -> Channel? in
            guard let command = valueString(row["cmd"]),
                  let name = valueString(row["name"]),
                  let identifier = valueString(row["id"]),
                  let placeholder = URL(
                    string: "tubo-legacySourceA://channel/\(configurationID.uuidString.lowercased())/\(encodedPathComponent(identifier))"
                  ) else { return nil }
            let genreID = valueString(row["tv_genre_id"])
            let logo = valueString(row["logo"]).flatMap {
                URL(string: $0, relativeTo: context.endpoint)?.absoluteURL
            }
            return Channel(
                name: name,
                streamURL: placeholder,
                group: genreID.flatMap { genres[$0] } ?? "直播",
                logoURL: logo,
                tvgID: valueString(row["xmltv_id"]),
                tvgName: name,
                resolver: .legacySourceA(configurationID: configurationID, command: command)
            )
        }
        guard !channels.isEmpty else { throw IPTVConfigurationError.invalidResponse }
        return channels
    }

    static func resolveStalkerStream(
        portal: String,
        macAddress: String,
        command: String
    ) async throws -> URL {
        let context = try await stalkerHandshake(portal: portal, macAddress: macAddress)
        let object = try await stalkerRequest(
            context: context,
            items: [
                URLQueryItem(name: "type", value: "itv"),
                URLQueryItem(name: "action", value: "create_link"),
                URLQueryItem(name: "cmd", value: command),
                URLQueryItem(name: "series", value: ""),
                URLQueryItem(name: "forced_storage", value: "undefined"),
                URLQueryItem(name: "disable_ad", value: "0"),
                URLQueryItem(name: "download", value: "0"),
            ]
        )
        guard let root = object as? [String: Any],
              let js = root["js"] as? [String: Any],
              let rawCommand = valueString(js["cmd"]),
              let url = playbackURL(fromStalkerCommand: rawCommand) else {
            throw IPTVConfigurationError.streamResolutionFailed
        }
        return url
    }

    static func normalizedMAC(_ rawValue: String) -> String {
        let hex = rawValue.uppercased().filter { $0.isHexDigit }
        guard hex.count == 12 else { return rawValue.uppercased() }
        return stride(from: 0, to: 12, by: 2).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: 2)
            return String(hex[start..<end])
        }.joined(separator: ":")
    }

    private static func stalkerHandshake(portal: String, macAddress: String) async throws -> StalkerContext {
        let mac = normalizedMAC(macAddress)
        guard mac.split(separator: ":").count == 6 else {
            throw IPTVConfigurationError.invalidCredentials
        }
        for endpoint in stalkerEndpoints(portal) {
            do {
                let temporary = StalkerContext(endpoint: endpoint, token: "", macAddress: mac)
                let object = try await stalkerRequest(
                    context: temporary,
                    items: [
                        URLQueryItem(name: "type", value: "stb"),
                        URLQueryItem(name: "action", value: "handshake"),
                        URLQueryItem(name: "token", value: ""),
                    ]
                )
                if let root = object as? [String: Any],
                   let js = root["js"] as? [String: Any],
                   let token = valueString(js["token"]),
                   !token.isEmpty {
                    return StalkerContext(endpoint: endpoint, token: token, macAddress: mac)
                }
            } catch {
                continue
            }
        }
        throw IPTVConfigurationError.portalHandshakeFailed
    }

    private static func stalkerRequest(
        context: StalkerContext,
        items: [URLQueryItem]
    ) async throws -> Any {
        guard var components = URLComponents(url: context.endpoint, resolvingAgainstBaseURL: false) else {
            throw IPTVConfigurationError.invalidServer
        }
        components.queryItems = items + [URLQueryItem(name: "JsHttpRequest", value: "1-xml")]
        guard let url = components.url else { throw IPTVConfigurationError.invalidServer }
        let encodedMAC = context.macAddress.replacingOccurrences(of: ":", with: "%3A")
        var headers = [
            "User-Agent": "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG250 stbapp",
            "X-User-Agent": "Model: MAG254; Link: Ethernet",
            "Cookie": "mac=\(encodedMAC); stb_lang=zh; timezone=Asia%2FShanghai",
        ]
        if !context.token.isEmpty { headers["Authorization"] = "Bearer \(context.token)" }
        return try await requestJSON(url: url, headers: headers)
    }

    private static func stalkerEndpoints(_ rawPortal: String) -> [URL] {
        let trimmed = rawPortal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let original = URL(string: trimmed.contains("://") ? trimmed : "http://\(trimmed)") else {
            return []
        }
        let raw = original.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var candidates = [String]()
        if raw.hasSuffix("portal.php") || raw.hasSuffix("server/load.php") {
            candidates.append(raw)
        }
        var base = raw
        if base.hasSuffix("/c") { base.removeLast(2) }
        candidates.append(base + "/portal.php")
        candidates.append(base + "/server/load.php")
        if original.path.isEmpty || original.path == "/" {
            candidates.append(base + "/stalker_portal/server/load.php")
        }
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }.compactMap(URL.init(string:))
    }

    private static func stalkerArray(from object: Any) -> [[String: Any]] {
        guard let root = object as? [String: Any] else { return [] }
        if let js = root["js"] as? [[String: Any]] { return js }
        if let js = root["js"] as? [String: Any] {
            if let data = js["data"] as? [[String: Any]] { return data }
            if let channels = js["channels"] as? [[String: Any]] { return channels }
        }
        return []
    }

    private static func playbackURL(fromStalkerCommand command: String) -> URL? {
        var value = command.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["ffmpeg ", "ffrt ", "auto "] where value.lowercased().hasPrefix(prefix) {
            value = String(value.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        if value.hasPrefix("\"") && value.hasSuffix("\"") {
            value.removeFirst()
            value.removeLast()
        }
        return MediaAddress.parse(value)?.url
    }

    private static func normalizedServerURL(_ rawServer: String) throws -> URL {
        var value = rawServer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") { value = "http://\(value)" }
        guard var components = URLComponents(string: value), components.host != nil else {
            throw IPTVConfigurationError.invalidServer
        }
        if components.path.hasSuffix("player_api.php") {
            components.path = String(components.path.dropLast("player_api.php".count))
        }
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw IPTVConfigurationError.invalidServer }
        return url
    }

    private static func xtreamAPIURL(
        baseURL: URL,
        username: String,
        password: String,
        action: String?
    ) throws -> URL {
        var items = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
        ]
        if let action { items.append(URLQueryItem(name: "action", value: action)) }
        return try xtreamURL(baseURL: baseURL, path: "player_api.php", queryItems: items)
    }

    private static func xtreamURL(
        baseURL: URL,
        path: String,
        queryItems: [URLQueryItem]
    ) throws -> URL {
        let endpoint = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw IPTVConfigurationError.invalidServer
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw IPTVConfigurationError.invalidServer }
        return url
    }

    private static func requestJSON(
        url: URL,
        headers: [String: String] = [:]
    ) async throws -> Any {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json, text/javascript, */*", forHTTPHeaderField: "Accept")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let configuration = ProxyNetworkConfiguration.ephemeral()
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        let (data, response) = try await URLSession(configuration: configuration).data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw IPTVConfigurationError.httpStatus(http.statusCode)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func valueString(_ value: Any?) -> String? {
        switch value {
        case let value as String: value
        case let value as NSNumber: value.stringValue
        default: nil
        }
    }

    private static func encodedPathComponent(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

enum MediaServerArtworkType: String, Sendable {
    case primary = "Primary"
    case backdrop = "Backdrop"
    case thumb = "Thumb"
    case logo = "Logo"
}

@MainActor
enum JellyfinConfigurationService {
    enum UserStateKind {
        case favorite
        case played
    }
    struct LoadResult {
        let channels: [Channel]
        let totalItemCount: Int
        let token: String
        let username: String
        let userID: String
        let serverName: String?
    }

    struct RefreshResult {
        let channels: [Channel]
        let totalItemCount: Int
        let userID: String
        let serverName: String?
    }

    private struct LoadedItems {
        let channels: [Channel]
        let totalItemCount: Int
    }

    /// Emby can expose a .strm item as a local-looking MediaSource while the
    /// actual playable address is resolved only by PlaybackInfo. Keep a short
    /// in-memory cache so player retries do not repeatedly ask the server for
    /// a new path (some hosted Emby services reject repeated failed resolves).
    private static var embyStreamCache: [String: (expiresAt: Date, url: URL)] = [:]
    private static var embyStreamFailureCache: [String: Date] = [:]
    // Detail pages can prefetch while the user is reading. Reuse that exact
    // request when Play is tapped instead of opening a second PlaybackInfo
    // session against hosted Emby servers.
    private static var embyStreamInFlight: [String: Task<URL, Error>] = [:]
    // A cold direct-play stream can spend several seconds opening the first
    // media range on the origin/CDN. Keep a short-lived idle warm-up separate
    // from the signed URL cache so this never keeps a stale playback address
    // alive or blocks the detail page.
    private static var embyStreamWarmupsInFlight = Set<String>()
    private static var embyStreamWarmupCache: [String: Date] = [:]
    private static var resolvedUserCache: [String: (expiresAt: Date, id: String, name: String)] = [:]
    // PlaybackInfo may return a short-lived signed address (notably for
    // 115-backed Emby libraries). Keep Tubo's short cache window so retries
    // obtain a fresh address before the CDN signature expires.
    private static let embyStreamCacheLifetime: TimeInterval = 30
    private static let embyStreamFailureCooldown: TimeInterval = 20
    fileprivate static let embyInitialItemLimit = 60
    private static let mediaServerDeviceID: String = {
        let key = "tubo.media-server.device-id.v1"
        if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
            return value
        }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: key)
        return value
    }()

    static func detectServerKind(server: String) async -> PlaylistConfigurationKind? {
        guard let baseURL = try? normalizedServerURL(server) else { return nil }
        var request = URLRequest(url: baseURL.appendingPathComponent("System/Info/Public"))
        request.timeoutInterval = 6
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let configuration = ProxyNetworkConfiguration.ephemeral()
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 6
        guard let (data, response) = try? await URLSession(configuration: configuration).data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let serverName = (object["ServerName"] as? String)?.lowercased() ?? ""
        if serverName.contains("legacyLibraryB") { return .legacyLibraryB }

        let version = object["Version"] as? String ?? ""
        if let major = version.split(separator: ".").first.flatMap({ Int($0) }) {
            // Emby currently reports 4.x while Jellyfin reports 10.x or newer.
            if major > 0, major < 10 { return .legacyLibraryB }
            if major >= 10 { return .legacyLibraryA }
        }
        return nil
    }

    static func serverName(server: String) async -> String? {
        guard let baseURL = try? normalizedServerURL(server) else { return nil }
        return await serverName(baseURL: baseURL)
    }

    private static func serverName(baseURL: URL) async -> String? {
        guard let rawObject = try? await requestJSON(
            url: baseURL.appendingPathComponent("System/Info/Public")
        ),
              let object = rawObject as? [String: Any],
              let value = object["ServerName"] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func authenticate(
        server: String,
        username: String,
        password: String,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind = .legacyLibraryA,
        loadInitialItems: Bool = true,
        initialItemLimit: Int? = nil,
        loadServerName: Bool = true
    ) async throws -> LoadResult {
        let baseURL = try normalizedServerURL(server)
        let loginSession = requestSession(timeout: 30)
        defer { loginSession.finishTasksAndInvalidate() }
        let requestedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateUsernames: [String]
        if requestedUsername.isEmpty {
            guard serverKind.isEmbyCompatible, cleanPassword.isEmpty else {
                throw IPTVConfigurationError.invalidCredentials
            }
            candidateUsernames = try await publicUsernames(
                baseURL: baseURL,
                session: loginSession
            )
        } else {
            candidateUsernames = [requestedUsername]
        }

        var authenticatedUsername: String?
        var authenticatedObject: Any?
        for candidate in candidateUsernames {
            do {
                authenticatedObject = try await authenticateByName(
                    baseURL: baseURL,
                    username: candidate,
                    password: password,
                    session: loginSession
                )
                authenticatedUsername = candidate
                break
            } catch IPTVConfigurationError.invalidCredentials
                where !cleanPassword.isEmpty && cleanPassword != password {
                do {
                    authenticatedObject = try await authenticateByName(
                        baseURL: baseURL,
                        username: candidate,
                        password: cleanPassword,
                        session: loginSession
                    )
                    authenticatedUsername = candidate
                    break
                } catch IPTVConfigurationError.invalidCredentials {
                    continue
                }
            } catch IPTVConfigurationError.invalidCredentials {
                continue
            }
        }

        guard let cleanUsername = authenticatedUsername,
              let root = authenticatedObject as? [String: Any],
              let token = root["AccessToken"] as? String,
              let user = root["User"] as? [String: Any],
              let userID = user["Id"] as? String,
              !token.isEmpty, !userID.isEmpty else {
            throw IPTVConfigurationError.invalidCredentials
        }
        rememberResolvedUser(
            baseURL: baseURL,
            token: token,
            id: userID,
            name: cleanUsername
        )
        let items: LoadedItems?
        if loadInitialItems {
            items = try await loadItems(
                baseURL: baseURL,
                userPath: userID,
                token: token,
                configurationID: configurationID,
                serverKind: serverKind,
                limit: initialItemLimit
                    ?? (serverKind.usesMediaLibraryBrowser ? embyInitialItemLimit : 10_000),
                detailedFields: initialItemLimit == nil,
                fastInitialPage: initialItemLimit != nil,
                session: loginSession
            )
        } else {
            items = nil
        }
        let resolvedServerName = loadServerName && loadInitialItems
            ? await serverName(baseURL: baseURL)
            : nil
        return LoadResult(
            channels: items?.channels ?? [],
            totalItemCount: items?.totalItemCount ?? 0,
            token: token,
            username: cleanUsername,
            userID: userID,
            // The home shell refreshes the reported name after activation.
            // Avoid a second blocking request during the fast login path.
            serverName: resolvedServerName
        )
    }

    private static func publicUsernames(
        baseURL: URL,
        session: URLSession? = nil
    ) async throws -> [String] {
        let object = try await requestJSON(
            url: baseURL.appendingPathComponent("Users/Public"),
            session: session
        )
        guard let users = object as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }
        let names = users.compactMap { user -> String? in
            guard let name = user["Name"] as? String else { return nil }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard !names.isEmpty else {
            throw IPTVConfigurationError.invalidCredentials
        }
        return names
    }

    private static func authenticateByName(
        baseURL: URL,
        username: String,
        password: String,
        session: URLSession? = nil
    ) async throws -> Any {
        do {
            return try await requestJSON(
                url: baseURL.appendingPathComponent("Users/AuthenticateByName"),
                method: "POST",
                body: ["Username": username, "Pw": password],
                session: session
            )
        } catch let error as IPTVConfigurationError {
            if case .httpStatus(401) = error {
                throw IPTVConfigurationError.invalidCredentials
            }
            throw error
        }
    }

    static func authenticateWithAPIKey(
        server: String,
        apiKey: String,
        preferredUsername: String,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind = .legacyLibraryA,
        loadInitialItems: Bool = true,
        initialItemLimit: Int? = nil,
        loadServerName: Bool = true
    ) async throws -> LoadResult {
        let baseURL = try normalizedServerURL(server)
        let loginSession = requestSession(timeout: 30)
        defer { loginSession.finishTasksAndInvalidate() }
        let token = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw IPTVConfigurationError.invalidCredentials }
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            session: loginSession
        )
        let items: LoadedItems?
        if loadInitialItems {
            items = try await loadItems(
                baseURL: baseURL,
                userPath: user.id,
                token: token,
                configurationID: configurationID,
                serverKind: serverKind,
                limit: initialItemLimit
                    ?? (serverKind.usesMediaLibraryBrowser ? embyInitialItemLimit : 10_000),
                detailedFields: initialItemLimit == nil,
                fastInitialPage: initialItemLimit != nil,
                session: loginSession
            )
        } else {
            items = nil
        }
        let resolvedServerName = loadServerName && loadInitialItems
            ? await serverName(baseURL: baseURL)
            : nil
        return LoadResult(
            channels: items?.channels ?? [],
            totalItemCount: items?.totalItemCount ?? 0,
            token: token,
            username: user.name,
            userID: user.id,
            serverName: resolvedServerName
        )
    }

    static func refresh(
        server: String,
        token: String,
        preferredUsername: String? = nil,
        knownUserID: String? = nil,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind = .legacyLibraryA
    ) async throws -> RefreshResult {
        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername ?? "",
            knownUserID: knownUserID
        )
        let items = try await loadItems(
            baseURL: baseURL,
            userPath: user.id,
            token: token,
            configurationID: configurationID,
            serverKind: serverKind,
            limit: serverKind.usesMediaLibraryBrowser ? embyInitialItemLimit : 10_000
        )
        return RefreshResult(
            channels: items.channels,
            totalItemCount: items.totalItemCount,
            userID: user.id,
            serverName: await serverName(baseURL: baseURL)
        )
    }

    static func loadEmbyCollections(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String? = nil
    ) async throws -> [MetadataLibraryCollection] {
        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID
        )
        let url = baseURL.appendingPathComponent("Users/\(encodedPathComponent(user.id))/Views")

        // Resolve the standard library first; the optional root fallback is
        // best-effort and must never prevent the normal list from appearing.
        var rootComponents = URLComponents(
            url: baseURL.appendingPathComponent(
                "Users/\(encodedPathComponent(user.id))/Items"
            ),
            resolvingAgainstBaseURL: false
        )
        rootComponents?.queryItems = [
            URLQueryItem(name: "Recursive", value: "false"),
            URLQueryItem(name: "Limit", value: "500"),
            URLQueryItem(name: "StartIndex", value: "0"),
            URLQueryItem(name: "EnableTotalRecordCount", value: "true"),
            URLQueryItem(
                name: "Fields",
                value: "BasicSyncInfo,PrimaryImageAspectRatio,CollectionType,ParentId"
            ),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
        ]
        let object = try await requestJSON(url: url, token: token)
        guard let root = object as? [String: Any],
              let rows = root["Items"] as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }

        // Some hosted Emby services (notably 115-backed short-drama servers)
        // expose user-created root folders outside of /Views. The standard
        // library list therefore misses valid top-level categories. Merge the
        // non-recursive root containers when the endpoint supports them.
        var allRows = rows
        if let rootURL = rootComponents?.url,
           let rootObject = try? await requestJSON(url: rootURL, token: token),
           let rootItems = (rootObject as? [String: Any])?["Items"] as? [[String: Any]] {
            var existingIDs = Set(allRows.compactMap { $0["Id"] as? String })
            let additionalRows = rootItems.filter { row in
                guard let id = row["Id"] as? String, !existingIDs.contains(id) else { return false }
                let type = (row["Type"] as? String)?.lowercased() ?? ""
                let isFolder = (row["IsFolder"] as? Bool) ?? false
                guard isFolder || [
                    "folder", "collectionfolder", "userview", "boxset", "playlist"
                ].contains(type) else { return false }
                existingIDs.insert(id)
                return true
            }
            allRows.append(contentsOf: additionalRows)
        }

        let collections: [MetadataLibraryCollection] = allRows.compactMap { row in
            guard let id = row["Id"] as? String,
                  let name = row["Name"] as? String,
                  !id.isEmpty, !name.isEmpty else { return nil }
            let itemType = (row["Type"] as? String)?.lowercased()
            let collectionType = (row["CollectionType"] as? String)
                ?? (["boxset", "playlist"].contains(itemType ?? "") ? itemType : nil)
            let imageTags = row["ImageTags"] as? [String: Any]
            let primaryImageTag = imageTags?["Primary"] as? String
            return MetadataLibraryCollection(
                id: id,
                name: name,
                collectionType: collectionType,
                primaryImageTag: primaryImageTag
            )
        }
        return collections
    }

    static func loadEmbyContinueWatching(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String? = nil,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind,
        limit: Int
    ) async throws -> [MetadataContinueItem] {
        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID
        )
        var components = URLComponents(
            url: baseURL.appendingPathComponent(
                "Users/\(encodedPathComponent(user.id))/Items/Resume"
            ),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "Limit", value: String(min(max(1, limit), 30))),
            URLQueryItem(name: "MediaTypes", value: "Video"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(
                name: "Fields",
                value: "RunTimeTicks,SeriesId,SeriesName,ParentIndexNumber,IndexNumber,ProductionYear,CommunityRating"
            ),
        ]
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }
        let object = try await requestJSON(url: url, token: token)
        guard let root = object as? [String: Any],
              let rows = root["Items"] as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }

        let mappedChannels = channels(
            from: rows,
            configurationID: configurationID,
            serverKind: serverKind
        )
        let channelsByItemID = Dictionary(
            uniqueKeysWithValues: mappedChannels.compactMap { channel in
                channel.tvgID.map { ($0, channel) }
            }
        )
        return rows.compactMap { row in
            guard let itemID = row["Id"] as? String,
                  let channel = channelsByItemID[itemID],
                  let userData = row["UserData"] as? [String: Any],
                  let positionTicks = (userData["PlaybackPositionTicks"] as? NSNumber)?.doubleValue,
                  let durationTicks = (row["RunTimeTicks"] as? NSNumber)?.doubleValue,
                  positionTicks > 0,
                  durationTicks > 0 else { return nil }
            return MetadataContinueItem(
                channel: channel,
                positionSeconds: positionTicks / 10_000_000,
                durationSeconds: durationTicks / 10_000_000
            )
        }
    }

    static func loadSimilarItems(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String?,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind,
        itemID: String,
        limit: Int
    ) async throws -> [Channel] {
        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID
        )
        var components = URLComponents(
            url: baseURL.appendingPathComponent(
                "Items/\(encodedPathComponent(itemID))/Similar"
            ),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "UserId", value: user.id),
            URLQueryItem(name: "Limit", value: String(min(max(1, limit), 100))),
            URLQueryItem(
                name: "Fields",
                value: "RunTimeTicks,SeriesId,SeriesName,ParentIndexNumber,IndexNumber,ProductionYear,CommunityRating,UserData"
            ),
        ]
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }
        let object = try await requestJSON(url: url, token: token)
        guard let root = object as? [String: Any],
              let rows = root["Items"] as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }
        return channels(
            from: rows,
            configurationID: configurationID,
            serverKind: serverKind
        ).filter { $0.tvgID != itemID }
    }

    static func loadItemsForPerson(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String?,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind,
        personID: String,
        limit: Int
    ) async throws -> [Channel] {
        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID
        )
        var components = URLComponents(
            url: baseURL.appendingPathComponent(
                "Users/\(encodedPathComponent(user.id))/Items"
            ),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "PersonIds", value: personID),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series,Episode"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Limit", value: String(min(max(1, limit), 200))),
            URLQueryItem(
                name: "Fields",
                value: "RunTimeTicks,SeriesId,SeriesName,ParentIndexNumber,IndexNumber,ProductionYear,CommunityRating,UserData"
            ),
        ]
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }
        let object = try await requestJSON(url: url, token: token)
        guard let root = object as? [String: Any],
              let rows = root["Items"] as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }
        var seen = Set<String>()
        return channels(
            from: rows,
            configurationID: configurationID,
            serverKind: serverKind
        ).filter { channel in
            guard let itemID = channel.tvgID else { return false }
            return seen.insert(itemID).inserted
        }
    }

    static func loadMetadataDetails(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String? = nil,
        itemID: String
    ) async throws -> MetadataDetails {
        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID
        )
        var components = URLComponents(
            url: baseURL.appendingPathComponent(
                "Users/\(encodedPathComponent(user.id))/Items/\(encodedPathComponent(itemID))"
            ),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(
                name: "Fields",
                value: "Overview,People,Studios,MediaSources,Genres,PremiereDate,ProductionYear,CommunityRating,OfficialRating,RunTimeTicks,ImageTags,BackdropImageTags,ProviderIds,SeriesId,ParentId"
            ),
        ]
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }
        let object = try await requestJSON(url: url, token: token)
        guard let row = object as? [String: Any] else {
            throw IPTVConfigurationError.invalidResponse
        }
        let mediaSources = row["MediaSources"] as? [[String: Any]] ?? []
        let mediaSource = mediaSources.first
        let mediaVersions = mediaSources.enumerated().compactMap { index, source -> MetadataVersion? in
            guard let sourceID = source["Id"] as? String, !sourceID.isEmpty else { return nil }
            let sourceName = (source["Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let container = source["Container"] as? String
            let sourceTitle = sourceName?.isEmpty == false
                ? sourceName!
                : container?.uppercased() ?? "资源版本 \(index + 1)"
            let video = (source["MediaStreams"] as? [[String: Any]] ?? [])
                .first(where: { ($0["Type"] as? String)?.caseInsensitiveCompare("Video") == .orderedSame })
            return MetadataVersion(
                id: sourceID,
                name: sourceTitle,
                container: container,
                sizeBytes: (source["Size"] as? NSNumber)?.int64Value,
                bitRate: (source["Bitrate"] as? NSNumber)?.intValue,
                width: (video?["Width"] as? NSNumber)?.intValue,
                height: (video?["Height"] as? NSNumber)?.intValue,
                serverName: nil,
                serverConfigurationID: nil,
                serverItemID: nil,
                serverKind: nil,
                dynamicRange: (video?["VideoRangeType"] as? String)
                    ?? (video?["VideoRange"] as? String),
                frameRate: (video?["RealFrameRate"] as? NSNumber)?.doubleValue
                    ?? (video?["AverageFrameRate"] as? NSNumber)?.doubleValue,
                subtitleTracks: (source["MediaStreams"] as? [[String: Any]])?
                    .filter { ($0["Type"] as? String)?.caseInsensitiveCompare("Subtitle") == .orderedSame }
                    .compactMap { ($0["DisplayTitle"] as? String) ?? ($0["Language"] as? String) },
                audioTracks: (source["MediaStreams"] as? [[String: Any]])?
                    .filter { ($0["Type"] as? String)?.caseInsensitiveCompare("Audio") == .orderedSame }
                    .compactMap { ($0["DisplayTitle"] as? String) ?? ($0["Language"] as? String) }
            )
        }
        let people = (row["People"] as? [[String: Any]] ?? []).compactMap {
            person -> MetadataCreditPerson? in
            guard let name = person["Name"] as? String, !name.isEmpty else { return nil }
            let id = (person["Id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? "\(name)|\(person["Type"] as? String ?? "person")"
            return MetadataCreditPerson(
                id: id,
                imageItemID: person["Id"] as? String,
                name: name,
                role: person["Role"] as? String,
                type: person["Type"] as? String
            )
        }
        let streams = (mediaSource?["MediaStreams"] as? [[String: Any]] ?? []).enumerated().compactMap {
            index, stream -> MetadataStreamDetail? in
            guard let type = stream["Type"] as? String else { return nil }
            let displayTitle = (stream["DisplayTitle"] as? String)?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let title = displayTitle?.isEmpty == false
                ? displayTitle!
                : (stream["Title"] as? String ?? type)
            return MetadataStreamDetail(
                id: "\(type)-\((stream["Index"] as? NSNumber)?.intValue ?? index)",
                type: type,
                title: title,
                codec: stream["Codec"] as? String,
                language: stream["Language"] as? String,
                width: (stream["Width"] as? NSNumber)?.intValue,
                height: (stream["Height"] as? NSNumber)?.intValue,
                channels: (stream["Channels"] as? NSNumber)?.intValue,
                sampleRate: (stream["SampleRate"] as? NSNumber)?.intValue,
                bitRate: (stream["BitRate"] as? NSNumber)?.intValue,
                frameRate: (stream["RealFrameRate"] as? NSNumber)?.doubleValue
                    ?? (stream["AverageFrameRate"] as? NSNumber)?.doubleValue
            )
        }
        let runtimeTicks = (row["RunTimeTicks"] as? NSNumber)?.doubleValue
        let studios = (row["Studios"] as? [[String: Any]] ?? []).compactMap {
            ($0["Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        return MetadataDetails(
            itemID: itemID,
            title: row["Name"] as? String ?? "",
            overview: row["Overview"] as? String,
            premiereDate: row["PremiereDate"] as? String,
            productionYear: (row["ProductionYear"] as? NSNumber)?.intValue,
            communityRating: (row["CommunityRating"] as? NSNumber)?.doubleValue,
            officialRating: row["OfficialRating"] as? String,
            genres: row["Genres"] as? [String] ?? [],
            runtimeSeconds: runtimeTicks.map { $0 / 10_000_000 },
            container: mediaSource?["Container"] as? String,
            sizeBytes: (mediaSource?["Size"] as? NSNumber)?.int64Value,
            people: Array(people.prefix(20)),
            studios: studios,
            streams: streams,
            mediaVersions: mediaVersions
        )
    }

    static func loadLibraryStatistics(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String? = nil
    ) async throws -> MediaLibraryStatistics {
        let baseURL = try normalizedServerURL(server)
        do {
            let user = try await resolveUser(
                baseURL: baseURL,
                token: token,
                preferredUsername: preferredUsername,
                knownUserID: knownUserID
            )
            return try await loadLibraryStatistics(
                baseURL: baseURL,
                token: token,
                userID: user.id
            )
        } catch {
            // A server can retain an old user ID after an account is recreated.
            // Resolve the current session once before reporting statistics as
            // unavailable instead of falling back to the first 60 loaded items.
            guard knownUserID != nil else { throw error }
            resolvedUserCache.removeValue(forKey: "\(baseURL.absoluteString)|\(token)")
            let user = try await resolveUser(
                baseURL: baseURL,
                token: token,
                preferredUsername: preferredUsername
            )
            return try await loadLibraryStatistics(
                baseURL: baseURL,
                token: token,
                userID: user.id
            )
        }
    }

    private static func loadLibraryStatistics(
        baseURL: URL,
        token: String,
        userID: String
    ) async throws -> MediaLibraryStatistics {
        async let uniqueMovies = libraryItemCount(
            baseURL: baseURL, token: token, userID: userID, type: "Movie", groupItems: true
        )
        async let allMovies = libraryItemCount(
            baseURL: baseURL, token: token, userID: userID, type: "Movie", groupItems: false
        )
        async let uniqueSeries = libraryItemCount(
            baseURL: baseURL, token: token, userID: userID, type: "Series", groupItems: true
        )
        async let allSeries = libraryItemCount(
            baseURL: baseURL, token: token, userID: userID, type: "Series", groupItems: false
        )
        async let uniqueEpisodes = libraryItemCount(
            baseURL: baseURL, token: token, userID: userID, type: "Episode", groupItems: true
        )
        async let allEpisodes = libraryItemCount(
            baseURL: baseURL, token: token, userID: userID, type: "Episode", groupItems: false
        )

        return try await MediaLibraryStatistics(
            movies: .init(unique: uniqueMovies, allVersions: allMovies),
            series: .init(unique: uniqueSeries, allVersions: allSeries),
            episodes: .init(unique: uniqueEpisodes, allVersions: allEpisodes)
        )
    }

    private static func libraryItemCount(
        baseURL: URL,
        token: String,
        userID: String,
        type: String,
        groupItems: Bool
    ) async throws -> Int {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("Users/\(encodedPathComponent(userID))/Items"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "IncludeItemTypes", value: type),
            URLQueryItem(name: "GroupItems", value: groupItems ? "true" : "false"),
            URLQueryItem(name: "EnableTotalRecordCount", value: "true"),
            URLQueryItem(name: "Fields", value: "BasicSyncInfo"),
            URLQueryItem(name: "StartIndex", value: "0"),
            URLQueryItem(name: "Limit", value: "1"),
        ]
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }
        let object = try await requestJSON(url: url, token: token)
        guard let root = object as? [String: Any],
              let count = (root["TotalRecordCount"] as? NSNumber)?.intValue else {
            throw IPTVConfigurationError.invalidResponse
        }
        return count
    }

    static func loadEmbyGenres(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String? = nil,
        parentID: String
    ) async throws -> [MetadataLibraryCollection] {
        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID
        )
        var components = URLComponents(
            url: baseURL.appendingPathComponent("Genres"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "UserId", value: user.id),
            URLQueryItem(name: "ParentId", value: parentID),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(
                name: "IncludeItemTypes",
                value: "Movie,Episode,Video,MusicVideo,Program"
            ),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
        ]
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }
        let object = try await requestJSON(url: url, token: token)
        guard let root = object as? [String: Any],
              let rows = root["Items"] as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }
        return browseNodes(from: rows, collectionType: "genres")
    }

    static func loadEmbyFolders(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String? = nil,
        parentID: String
    ) async throws -> [MetadataLibraryCollection] {
        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID
        )
        var components = URLComponents(
            url: baseURL.appendingPathComponent("Users/\(encodedPathComponent(user.id))/Items"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "ParentId", value: parentID),
            URLQueryItem(name: "Recursive", value: "false"),
            URLQueryItem(name: "IncludeItemTypes", value: "Folder"),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
        ]
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }
        let object = try await requestJSON(url: url, token: token)
        guard let root = object as? [String: Any],
              let rows = root["Items"] as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }
        return browseNodes(from: rows, collectionType: "folders")
    }

    private static func browseNodes(
        from rows: [[String: Any]],
        collectionType: String
    ) -> [MetadataLibraryCollection] {
        rows.compactMap { row -> MetadataLibraryCollection? in
            guard let id = row["Id"] as? String,
                  let name = row["Name"] as? String,
                  !id.isEmpty,
                  !name.isEmpty else { return nil }
            let imageTags = row["ImageTags"] as? [String: Any]
            return MetadataLibraryCollection(
                id: id,
                name: name,
                collectionType: collectionType,
                primaryImageTag: imageTags?["Primary"] as? String
            )
        }
    }

    static func loadEmbyPage(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String? = nil,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind,
        parentID: String?,
        startIndex: Int,
        limit: Int,
        searchTerm: String?,
        genre: String?,
        prefersSeries: Bool,
        sortBy requestedSortBy: String? = nil,
        sortDescending: Bool? = nil,
        includesMediaSources: Bool = false
    ) async throws -> MetadataLibraryPage {
        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID
        )
        var components = URLComponents(
            url: baseURL.appendingPathComponent("Users/\(encodedPathComponent(user.id))/Items"),
            resolvingAgainstBaseURL: false
        )
        let cleanSearch = searchTerm?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sortBy: String
        if let requestedSortBy, !requestedSortBy.isEmpty {
            sortBy = requestedSortBy
        } else if parentID == nil && cleanSearch.isEmpty {
            sortBy = "DateCreated"
        } else if parentID != nil && cleanSearch.isEmpty {
            sortBy = "SeriesSortName,ParentIndexNumber,IndexNumber,SortName"
        } else {
            sortBy = "SortName"
        }
        var fields = "RunTimeTicks,SeriesId,SeriesName,ParentIndexNumber,IndexNumber,ProductionYear,CommunityRating,CriticRating,OfficialRating,DateCreated,PremiereDate"
        if includesMediaSources { fields += ",MediaSources" }
        let defaultDescending = parentID == nil && cleanSearch.isEmpty
        var queryItems = [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(
                name: "IncludeItemTypes",
                value: prefersSeries
                    ? "Series"
                    // Jellyfin libraries can contain standalone music videos
                    // and recorded/live programs in addition to movies,
                    // episodes, generic videos, and short-drama series.
                    : "Movie,Series,Episode,Video,MusicVideo,Program"
            ),
            // PlaybackInfo resolves the full source only after selection.
            // Pulling Overview and every MediaSource for 60 cards made a page
            // nearly ten times larger and blocked scrolling during JSON work.
            URLQueryItem(
                name: "Fields",
                value: fields
            ),
            URLQueryItem(name: "StartIndex", value: String(max(0, startIndex))),
            URLQueryItem(name: "Limit", value: String(min(max(1, limit), 200))),
            URLQueryItem(name: "SortBy", value: sortBy),
            URLQueryItem(name: "SortOrder", value: (sortDescending ?? defaultDescending) ? "Descending" : "Ascending"),
        ]
        if let parentID, !parentID.isEmpty {
            queryItems.append(URLQueryItem(name: "ParentId", value: parentID))
        }
        if !cleanSearch.isEmpty {
            queryItems.append(URLQueryItem(name: "SearchTerm", value: cleanSearch))
        }
        let cleanGenre = genre?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanGenre.isEmpty {
            queryItems.append(URLQueryItem(name: "Genres", value: cleanGenre))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }
        let object = try await requestJSON(url: url, token: token)
        guard let root = object as? [String: Any],
              let rows = root["Items"] as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }
        let channels = channels(
            from: rows,
            configurationID: configurationID,
            serverKind: serverKind
        )
        let nextStartIndex = startIndex + rows.count
        let totalCount = max(
            (root["TotalRecordCount"] as? NSNumber)?.intValue ?? nextStartIndex,
            nextStartIndex
        )
        return MetadataLibraryPage(
            channels: channels,
            totalCount: totalCount,
            nextStartIndex: nextStartIndex
        )
    }

    static func loadItems(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String? = nil,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind,
        providerIDs: [String],
        includeItemTypes: String,
        limit: Int = 10
    ) async throws -> [Channel] {
        let cleanProviderIDs = providerIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleanItemTypes = includeItemTypes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanProviderIDs.isEmpty, !cleanItemTypes.isEmpty else { return [] }

        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID
        )
        var components = URLComponents(
            url: baseURL.appendingPathComponent("Users/\(encodedPathComponent(user.id))/Items"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(
                name: "Fields",
                value: "BasicSyncInfo,ProviderIds,ProductionYear,Container,ParentId"
            ),
            URLQueryItem(name: "GroupProgramsBySeries", value: "true"),
            URLQueryItem(name: "Limit", value: String(min(max(1, limit), 200))),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb"),
            URLQueryItem(name: "IncludeItemTypes", value: cleanItemTypes),
            URLQueryItem(name: "AnyProviderIdEquals", value: cleanProviderIDs.joined(separator: ",")),
            URLQueryItem(name: "Recursive", value: "true"),
        ]
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }
        let object = try await requestJSON(url: url, token: token)
        guard let root = object as? [String: Any],
              let rows = root["Items"] as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }
        return channels(
            from: rows,
            configurationID: configurationID,
            serverKind: serverKind
        )
    }

    /// Compatibility wrapper for callers that only need the next episode.
    static func loadNextEpisode(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String?,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind,
        currentItemID: String,
        knownSeriesID: String?
    ) async throws -> Channel? {
        try await loadAdjacentEpisode(
            server: server,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID,
            configurationID: configurationID,
            serverKind: serverKind,
            currentItemID: currentItemID,
            knownSeriesID: knownSeriesID,
            offset: 1
        )
    }

    static func loadAdjacentEpisode(
        server: String,
        token: String,
        preferredUsername: String,
        knownUserID: String?,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind,
        currentItemID: String,
        knownSeriesID: String?,
        offset: Int
    ) async throws -> Channel? {
        guard offset == -1 || offset == 1 else { return nil }
        let baseURL = try normalizedServerURL(server)
        let user = try await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: preferredUsername,
            knownUserID: knownUserID
        )
        let cleanKnownSeriesID = knownSeriesID?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        let seriesID: String
        if !cleanKnownSeriesID.isEmpty {
            seriesID = cleanKnownSeriesID
        } else {
            let itemURL = baseURL.appendingPathComponent(
                "Users/\(encodedPathComponent(user.id))/Items/\(encodedPathComponent(currentItemID))"
            )
            let object = try await requestJSON(url: itemURL, token: token)
            guard let item = object as? [String: Any],
                  (item["Type"] as? String)?.caseInsensitiveCompare("Episode") == .orderedSame,
                  let resolvedSeriesID = item["SeriesId"] as? String,
                  !resolvedSeriesID.isEmpty else { return nil }
            seriesID = resolvedSeriesID
        }

        let pageSize = 200
        var startIndex = 0
        var returnsFirstEpisodeFromNextPage = false
        var lastEpisodeFromPreviousPage: Channel?
        while true {
            var components = URLComponents(
                url: baseURL.appendingPathComponent(
                    "Users/\(encodedPathComponent(user.id))/Items"
                ),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "ParentId", value: seriesID),
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "IncludeItemTypes", value: "Episode"),
                URLQueryItem(
                    name: "Fields",
                    value: "RunTimeTicks,SeriesId,SeriesName,ParentIndexNumber,IndexNumber"
                ),
                URLQueryItem(
                    name: "SortBy",
                    value: "ParentIndexNumber,IndexNumber,SortName"
                ),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "StartIndex", value: String(startIndex)),
                URLQueryItem(name: "Limit", value: String(pageSize)),
            ]
            guard let url = components?.url else {
                throw IPTVConfigurationError.invalidServer
            }
            let object = try await requestJSON(url: url, token: token)
            guard let root = object as? [String: Any],
                  let rows = root["Items"] as? [[String: Any]] else {
                throw IPTVConfigurationError.invalidResponse
            }
            let pageChannels = channels(
                from: rows,
                configurationID: configurationID,
                serverKind: serverKind
            )
            if returnsFirstEpisodeFromNextPage {
                return pageChannels.first
            }
            if let currentIndex = pageChannels.firstIndex(where: { $0.tvgID == currentItemID }) {
                let adjacentIndex = currentIndex + offset
                if pageChannels.indices.contains(adjacentIndex) {
                    return pageChannels[adjacentIndex]
                }
                if offset > 0 {
                    returnsFirstEpisodeFromNextPage = true
                } else {
                    return lastEpisodeFromPreviousPage
                }
            }

            let totalCount = (root["TotalRecordCount"] as? NSNumber)?.intValue
                ?? (startIndex + rows.count)
            let nextStartIndex = startIndex + rows.count
            guard !rows.isEmpty, nextStartIndex < totalCount else { return nil }
            lastEpisodeFromPreviousPage = pageChannels.last
            startIndex = nextStartIndex
        }
    }

    static func loadExternalSubtitles(
        server: String,
        token: String,
        itemID: String
    ) async throws -> [MediaServerSubtitleSource] {
        let baseURL = try normalizedServerURL(server)
        let playbackInfoURL = baseURL.appendingPathComponent(
            "Items/\(encodedPathComponent(itemID))/PlaybackInfo"
        )
        let object = try await requestJSON(
            url: playbackInfoURL,
            method: "POST",
            token: token
        )
        guard let root = object as? [String: Any],
              let sources = root["MediaSources"] as? [[String: Any]],
              let source = sources.first(where: { source in
                  (source["SupportsDirectPlay"] as? Bool ?? false)
                      || (source["SupportsDirectStream"] as? Bool ?? false)
              }) ?? sources.first,
              let sourceID = source["Id"] as? String,
              !sourceID.isEmpty else { return [] }

        let streams = source["MediaStreams"] as? [[String: Any]] ?? []
        return streams.compactMap { stream -> MediaServerSubtitleSource? in
            guard (stream["Type"] as? String)?.caseInsensitiveCompare("Subtitle") == .orderedSame,
                  (stream["IsExternal"] as? Bool ?? false)
                    || (stream["SupportsExternalStream"] as? Bool ?? false)
                    || stream["DeliveryUrl"] != nil,
                  let index = (stream["Index"] as? NSNumber)?.intValue else { return nil }

            let codec = (stream["Codec"] as? String)?.lowercased() ?? "srt"
            let fileExtension: String = switch codec {
            case "subrip": "srt"
            case "webvtt": "vtt"
            default: codec
            }
            let rawURL: URL?
            if let deliveryURL = stream["DeliveryUrl"] as? String, !deliveryURL.isEmpty {
                rawURL = URL(string: deliveryURL, relativeTo: baseURL)?.absoluteURL
            } else {
                rawURL = baseURL.appendingPathComponent(
                    "Videos/\(encodedPathComponent(itemID))/\(encodedPathComponent(sourceID))/Subtitles/\(index)/Stream.\(fileExtension)"
                )
            }
            guard let rawURL,
                  var components = URLComponents(url: rawURL, resolvingAgainstBaseURL: false)
            else { return nil }
            var queryItems = components.queryItems ?? []
            if !queryItems.contains(where: { $0.name.caseInsensitiveCompare("api_key") == .orderedSame }) {
                queryItems.append(URLQueryItem(name: "api_key", value: token))
            }
            components.queryItems = queryItems
            guard let url = components.url else { return nil }

            let displayTitle = [
                stream["DisplayTitle"] as? String,
                stream["Title"] as? String,
                stream["Language"] as? String,
            ]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty })
                ?? AppLanguage.localizedFormat("字幕 %d", index + 1)
            return MediaServerSubtitleSource(
                id: "media-server-subtitle-\(index)",
                title: AppLanguage.localizedFormat("外挂 · %@", displayTitle),
                url: url
            )
        }
    }

    static func resolveStream(
        server: String,
        token: String,
        itemID: String,
        container: String? = nil
    ) throws -> URL {
        let baseURL = try normalizedServerURL(server)
        let normalizedContainer = container?
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .first(where: { !$0.isEmpty })
        let endpoint = normalizedContainer.map { "Videos/\(itemID)/stream.\($0)" }
            ?? "Videos/\(itemID)/stream"
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "Static", value: "true"),
            URLQueryItem(name: "api_key", value: token),
        ]
        guard let url = components?.url else { throw IPTVConfigurationError.streamResolutionFailed }
        return url
    }

    /// Resolve an Emby item through the same two-step flow used by the native
    /// clients: PlaybackInfo selects the actual MediaSource, then the stream
    /// URL includes MediaSourceId and PlaySessionId. This is required for STRM
    /// libraries, where the item Path is not itself a playable URL.
    static func resolveEmbyStream(
        server: String,
        token: String,
        itemID: String,
        container: String? = nil,
        preferredMediaSourceID: String? = nil
    ) async throws -> URL {
        let baseURL = try normalizedServerURL(server)
        let selectedSource = preferredMediaSourceID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = "\(baseURL.absoluteString)|\(itemID)|\(selectedSource ?? "auto")|\(token)"
        let now = Date()
        if let cached = embyStreamCache[cacheKey], cached.expiresAt > now {
            return cached.url
        }
        embyStreamCache = embyStreamCache.filter { $0.value.expiresAt > now }
        if let failureExpiresAt = embyStreamFailureCache[cacheKey], failureExpiresAt > now {
            throw IPTVConfigurationError.streamResolutionFailed
        }
        embyStreamFailureCache = embyStreamFailureCache.filter { $0.value > now }

        if let inFlight = embyStreamInFlight[cacheKey] {
            return try await inFlight.value
        }

        let request = Task { @MainActor in
            try await requestEmbyStream(
                baseURL: baseURL,
                token: token,
                itemID: itemID,
                container: container,
                preferredMediaSourceID: selectedSource,
                cacheKey: cacheKey,
                startedAt: now
            )
        }
        embyStreamInFlight[cacheKey] = request

        do {
            let resolvedURL = try await request.value
            embyStreamInFlight.removeValue(forKey: cacheKey)
            return resolvedURL
        } catch is CancellationError {
            embyStreamInFlight.removeValue(forKey: cacheKey)
            throw CancellationError()
        } catch {
            embyStreamInFlight.removeValue(forKey: cacheKey)
            embyStreamFailureCache[cacheKey] = now.addingTimeInterval(embyStreamFailureCooldown)
            throw error
        }
    }

    private static func requestEmbyStream(
        baseURL: URL,
        token: String,
        itemID: String,
        container: String?,
        preferredMediaSourceID: String?,
        cacheKey: String,
        startedAt: Date
    ) async throws -> URL {
        let playbackInfoURL = baseURL.appendingPathComponent(
            "Items/\(encodedPathComponent(itemID))/PlaybackInfo"
        )
        let object = try await requestJSON(
            url: playbackInfoURL,
            method: "POST",
            token: token
        )
        guard let root = object as? [String: Any],
              let sources = root["MediaSources"] as? [[String: Any]] else {
            throw IPTVConfigurationError.streamResolutionFailed
        }
        let preferredSource = preferredMediaSourceID.flatMap { preferredID in
            sources.first {
                ($0["Id"] as? String)?.caseInsensitiveCompare(preferredID) == .orderedSame
            }
        }
        guard let source = preferredSource ?? sources.first(where: { source in
                  let directPlay = source["SupportsDirectPlay"] as? Bool ?? false
                  let directStream = source["SupportsDirectStream"] as? Bool ?? false
                  return directPlay || directStream
              }) ?? sources.first,
              let sourceID = source["Id"] as? String,
              !sourceID.isEmpty else {
            throw IPTVConfigurationError.streamResolutionFailed
        }

        let resolvedURL: URL
        let directURLString = (source["DirectPlayUrl"] as? String)
            ?? (source["DirectStreamUrl"] as? String)
        if let directURLString,
           let directURL = URL(string: directURLString, relativeTo: baseURL)?.absoluteURL,
           directURL.scheme != nil {
            resolvedURL = directURL
        } else {
            let sourceContainer = (source["Container"] as? String) ?? container
            let normalizedContainer = sourceContainer?
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .first(where: { !$0.isEmpty })
            let endpoint = normalizedContainer.map {
                "Videos/\(encodedPathComponent(itemID))/stream.\($0)"
            } ?? "Videos/\(encodedPathComponent(itemID))/stream"
            var components = URLComponents(
                url: baseURL.appendingPathComponent(endpoint),
                resolvingAgainstBaseURL: false
            )
            var queryItems = [
                URLQueryItem(name: "Static", value: "true"),
                URLQueryItem(name: "MediaSourceId", value: sourceID),
                URLQueryItem(name: "api_key", value: token),
            ]
            if let playSessionID = root["PlaySessionId"] as? String,
               !playSessionID.isEmpty {
                queryItems.append(URLQueryItem(name: "PlaySessionId", value: playSessionID))
            }
            components?.queryItems = queryItems
            guard let url = components?.url else {
                throw IPTVConfigurationError.streamResolutionFailed
            }
            resolvedURL = url
        }

        embyStreamFailureCache.removeValue(forKey: cacheKey)
        embyStreamCache[cacheKey] = (
            expiresAt: startedAt.addingTimeInterval(embyStreamCacheLifetime),
            url: resolvedURL
        )
        return resolvedURL
    }

    /// Warm only a small direct-play range while the detail page is visible.
    /// This improves cold CDN/origin startup without downloading the movie and
    /// deliberately skips HLS and non-HTTP sources. The player still opens
    /// the same URL and remains the source of truth for decoding and errors.
    static func prewarmEmbyStream(_ url: URL, channel: Channel) {
        guard channel.isMediaServerItem,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.pathExtension.lowercased() != "m3u8",
              channel.container?.lowercased() != "m3u8" else { return }

        let key = url.absoluteString
        let now = Date()
        embyStreamWarmupCache = embyStreamWarmupCache.filter { $0.value > now }
        guard embyStreamWarmupCache[key] == nil,
              !embyStreamWarmupsInFlight.contains(key) else { return }
        embyStreamWarmupsInFlight.insert(key)

        Task { @MainActor in
            defer { embyStreamWarmupsInFlight.remove(key) }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 12
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue("bytes=0-65535", forHTTPHeaderField: "Range")
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            PlaybackRequestPreferences.headers(for: channel).forEach {
                request.setValue($0.value, forHTTPHeaderField: $0.key)
            }

            let configuration = ProxyNetworkConfiguration.ephemeral()
            configuration.timeoutIntervalForRequest = 12
            configuration.timeoutIntervalForResource = 12
            configuration.waitsForConnectivity = false
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            do {
                let (bytes, response) = try await session.bytes(for: request)
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 206 else { return }

                // Consume the requested range so the edge/origin has actually
                // opened and cached it, while still bounding the work to 64KB.
                var iterator = bytes.makeAsyncIterator()
                var consumed = 0
                while consumed < 65_536,
                      let _ = try await iterator.next() {
                    consumed += 1
                }
                guard consumed > 0 else { return }
                embyStreamWarmupCache[key] = Date().addingTimeInterval(20)
            } catch is CancellationError {
                // The warm-up is best effort and must never affect playback.
            } catch {
                // The real player will retry with its normal engine-specific
                // networking and recovery path.
            }
        }
    }

    /// Emby and Jellyfin use the same session-reporting contract. Keep this
    /// best-effort and fire-and-forget: a stalled reporting request must never
    /// be allowed to block or restart the video decoder.
    static func reportPlayback(
        server: String,
        token: String,
        itemID: String,
        mediaSourceID: String?,
        userID: String?,
        position: Double,
        duration: Double,
        isPaused: Bool,
        stopped: Bool
    ) async {
        guard let baseURL = try? normalizedServerURL(server),
              !itemID.isEmpty else { return }
        let endpoint = stopped ? "Sessions/Playing/Stopped" : "Sessions/Playing/Progress"
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader(), forHTTPHeaderField: "X-Emby-Authorization")
        request.setValue(token, forHTTPHeaderField: "X-Emby-Token")

        var body: [String: Any] = [
            "ItemId": itemID,
            "IsPaused": isPaused,
            "IsMuted": false,
            "PlayMethod": "DirectPlay",
            "PositionTicks": Int64(max(0, position) * 10_000_000),
        ]
        if let mediaSourceID, !mediaSourceID.isEmpty {
            body["MediaSourceId"] = mediaSourceID
        }
        if let userID, !userID.isEmpty {
            body["UserId"] = userID
        }
        if !stopped, duration.isFinite, duration > 0 {
            body["RunTimeTicks"] = Int64(duration * 10_000_000)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data

        do {
            let (_, response) = try await URLSession(
                configuration: ProxyNetworkConfiguration.ephemeral()
            ).data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                NSLog("[RovePlayback] media-server report status=%ld", http.statusCode)
            }
        } catch {
            // Reporting is deliberately non-fatal. Local progress has already
            // been saved and the next heartbeat can retry after a reconnect.
        }
    }

    static func setUserState(
        server: String,
        token: String,
        userID: String?,
        itemID: String,
        kind: UserStateKind,
        enabled: Bool
    ) async -> Bool {
        guard let baseURL = try? normalizedServerURL(server), !itemID.isEmpty else {
            return false
        }
        let resolvedUserID: String
        if let userID = userID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !userID.isEmpty {
            resolvedUserID = userID
        } else if let user = try? await resolveUser(
            baseURL: baseURL,
            token: token,
            preferredUsername: ""
        ) {
            resolvedUserID = user.id
        } else {
            return false
        }

        let collection = kind == .favorite ? "FavoriteItems" : "PlayedItems"
        let url = baseURL
            .appendingPathComponent("Users")
            .appendingPathComponent(resolvedUserID)
            .appendingPathComponent(collection)
            .appendingPathComponent(itemID)
        var request = URLRequest(url: url)
        request.httpMethod = enabled ? "POST" : "DELETE"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authorizationHeader(), forHTTPHeaderField: "X-Emby-Authorization")
        request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        do {
            let (_, response) = try await URLSession(
                configuration: ProxyNetworkConfiguration.ephemeral()
            ).data(for: request)
            return (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
        } catch {
            return false
        }
    }

    private static func mediaServerAudioCompatibilityScore(_ source: [String: Any]) -> Int {
        let preferredCodecs: Set<String> = [
            "aac", "ac3", "eac3", "ec-3", "mp3", "opus", "vorbis", "flac", "alac"
        ]
        let codecs = (source["MediaStreams"] as? [[String: Any]] ?? []).compactMap {
            ($0["Type"] as? String)?.caseInsensitiveCompare("Audio") == .orderedSame
                ? ($0["Codec"] as? String)?.lowercased()
                : nil
        }
        return codecs.reduce(into: 0) { score, codec in
            if preferredCodecs.contains(codec) { score += 1 }
        }
    }

    static func loadArtwork(
        server: String,
        token: String,
        itemID: String,
        maxWidth: Int,
        imageType: MediaServerArtworkType = .primary
    ) async throws -> Data? {
        let baseURL = try normalizedServerURL(server)
        var components = URLComponents(
            url: baseURL.appendingPathComponent("Items/\(itemID)/Images/\(imageType.rawValue)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: String(max(120, maxWidth))),
            URLQueryItem(name: "quality", value: "90"),
        ]
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        request.setValue(authorizationHeader(), forHTTPHeaderField: "X-Emby-Authorization")
        request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        let session = URLSession(configuration: ProxyNetworkConfiguration.ephemeral())
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { return nil }
            guard (200...299).contains(http.statusCode) else {
                throw IPTVConfigurationError.httpStatus(http.statusCode)
            }
        }
        return data.isEmpty ? nil : data
    }

    private static func loadItems(
        baseURL: URL,
        userPath: String,
        token: String,
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind,
        limit: Int,
        detailedFields: Bool = true,
        fastInitialPage: Bool = false,
        session: URLSession? = nil
    ) async throws -> LoadedItems {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("Users/\(userPath)/Items"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(
                name: "IncludeItemTypes",
                value: "Movie,Series,Episode,Video,MusicVideo,Program"
            ),
            URLQueryItem(
                name: "Fields",
                value: !detailedFields || serverKind.isEmbyCompatible
                    ? "RunTimeTicks,SeriesId,SeriesName,ParentIndexNumber,IndexNumber"
                    : "Overview,MediaSources,RunTimeTicks,SeriesId,SeriesName,ParentIndexNumber,IndexNumber"
            ),
            URLQueryItem(name: "Limit", value: String(limit)),
        ]
        if fastInitialPage {
            // Login only needs enough real content to render the first frame.
            // Avoid forcing large servers to sort and count their entire library.
            queryItems.append(URLQueryItem(name: "EnableTotalRecordCount", value: "false"))
        } else {
            queryItems.append(URLQueryItem(name: "SortBy", value: "SortName"))
            queryItems.append(URLQueryItem(name: "SortOrder", value: "Ascending"))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw IPTVConfigurationError.invalidServer }
        let object = try await requestJSON(url: url, token: token, session: session)
        guard let root = object as? [String: Any],
              let rows = root["Items"] as? [[String: Any]] else {
            throw IPTVConfigurationError.invalidResponse
        }
        let channels = channels(
            from: rows,
            configurationID: configurationID,
            serverKind: serverKind
        )
        guard !channels.isEmpty else { throw IPTVConfigurationError.invalidResponse }
        let totalItemCount = (root["TotalRecordCount"] as? NSNumber)?.intValue
            ?? channels.count
        return LoadedItems(channels: channels, totalItemCount: totalItemCount)
    }

    private static func channels(
        from rows: [[String: Any]],
        configurationID: UUID,
        serverKind: PlaylistConfigurationKind
    ) -> [Channel] {
        let placeholderScheme: String
        let containerHeader: String
        switch serverKind {
        case .legacyLibraryB, .zspaceVideo:
            placeholderScheme = "tubo-legacyLibraryB"
            containerHeader = "X-Tubo-Emby-Container"
        case .movieClaw:
            placeholderScheme = "tubo-movieclaw"
            containerHeader = "X-Tubo-MovieClaw-Container"
        default:
            placeholderScheme = "tubo-legacyLibraryA"
            containerHeader = "X-Tubo-Jellyfin-Container"
        }
        return rows.compactMap { row -> Channel? in
            guard let itemID = row["Id"] as? String,
                  let name = row["Name"] as? String,
                  let placeholder = URL(
                    string: "\(placeholderScheme)://item/\(configurationID.uuidString.lowercased())/\(itemID)"
                  ) else { return nil }
            let type = row["Type"] as? String ?? "Video"
            guard ["Movie", "Episode", "Video", "Series", "MusicVideo", "Program"].contains(type)
                else { return nil }
            let seriesName = row["SeriesName"] as? String
            let seriesID = row["SeriesId"] as? String
            let episodeNumber = (row["IndexNumber"] as? NSNumber)?.intValue
            let seasonNumber = (row["ParentIndexNumber"] as? NSNumber)?.intValue
            let displayName: String
            let group: String
            if type == "Episode", let episodeNumber {
                let episodeLabel = AppLanguage.localizedFormat("第 %d 集", episodeNumber)
                displayName = name.contains(episodeLabel)
                    ? name
                    : "\(episodeLabel) · \(name)"
                let cleanSeriesName = seriesName?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""
                if let seasonNumber, seasonNumber > 0, !cleanSeriesName.isEmpty {
                    group = AppLanguage.localizedFormat(
                        "%@ · 第 %d 季",
                        cleanSeriesName,
                        seasonNumber
                    )
                } else if !cleanSeriesName.isEmpty {
                    group = cleanSeriesName
                } else {
                    group = AppLanguage.localized("剧集")
                }
            } else {
                displayName = name
                group = seriesName?.isEmpty == false
                    ? seriesName!
                    : type == "Movie" ? AppLanguage.localized("电影")
                    : type == "MusicVideo" ? AppLanguage.localized("音乐视频")
                    : type == "Program" ? AppLanguage.localized("节目")
                    : AppLanguage.localized("视频")
            }
            let container = (row["MediaSources"] as? [[String: Any]])?
                .first?["Container"] as? String
            let mediaSource = (row["MediaSources"] as? [[String: Any]])?.first
            let userData = row["UserData"] as? [String: Any]
            let runtimeTicks = (row["RunTimeTicks"] as? NSNumber)?.doubleValue
            let productionYear = (row["ProductionYear"] as? NSNumber)?.intValue
            let communityRating = (row["CommunityRating"] as? NSNumber)?.doubleValue
            let resolver: StreamResolver = switch serverKind {
            case .legacyLibraryB, .zspaceVideo:
                .legacyLibraryB(configurationID: configurationID, itemID: itemID)
            case .movieClaw:
                .movieClaw(configurationID: configurationID, itemID: itemID)
            default:
                .legacyLibraryA(configurationID: configurationID, itemID: itemID)
            }
            return Channel(
                name: displayName,
                streamURL: placeholder,
                group: group,
                tvgID: itemID,
                tvgName: displayName,
                httpHeaders: container.map {
                    [containerHeader: $0]
                } ?? [:],
                resolver: resolver,
                playbackKind: .onDemand,
                productionYear: productionYear,
                communityRating: communityRating,
                criticRating: (row["CriticRating"] as? NSNumber)?.doubleValue,
                officialRating: row["OfficialRating"] as? String,
                dateAdded: row["DateCreated"] as? String,
                releaseDate: row["PremiereDate"] as? String,
                playCount: (userData?["PlayCount"] as? NSNumber)?.intValue,
                lastPlayedDate: userData?["LastPlayedDate"] as? String,
                runtimeSeconds: runtimeTicks.map { $0 / 10_000_000 },
                fileSize: (mediaSource?["Size"] as? NSNumber)?.int64Value,
                container: container,
                mediaServerItemType: type,
                mediaServerSeriesID: seriesID,
                mediaServerFavorite: userData?["IsFavorite"] as? Bool,
                mediaServerPlayed: (userData?["Played"] as? Bool)
                    ?? ((userData?["PlayCount"] as? NSNumber)?.intValue ?? 0 > 0)
            )
        }
    }

    private static func resolveUser(
        baseURL: URL,
        token: String,
        preferredUsername: String,
        knownUserID: String? = nil,
        session: URLSession? = nil
    ) async throws -> (id: String, name: String) {
        let now = Date()
        let cacheKey = "\(baseURL.absoluteString)|\(token)"
        let preferred = preferredUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if let knownUserID = knownUserID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !knownUserID.isEmpty {
            let resolved = (id: knownUserID, name: preferred)
            resolvedUserCache[cacheKey] = (now.addingTimeInterval(600), resolved.id, resolved.name)
            return resolved
        }
        if let cached = resolvedUserCache[cacheKey], cached.expiresAt > now {
            return (cached.id, cached.name)
        }
        resolvedUserCache = resolvedUserCache.filter { $0.value.expiresAt > now }

        if let currentUser = try? await requestJSON(
            url: baseURL.appendingPathComponent("Users/Me"),
            token: token,
            session: session
        ), let user = currentUser as? [String: Any],
           let id = user["Id"] as? String, !id.isEmpty {
            let name = user["Name"] as? String ?? preferredUsername
            resolvedUserCache[cacheKey] = (now.addingTimeInterval(600), id, name)
            return (id, name)
        }

        // Emby 4.9 can return HTTP 500 for Jellyfin's `/Users/Me` alias, while
        // `/Users` is an administrator-only endpoint and returns HTTP 403 for
        // an otherwise valid regular account. The session list is available
        // to that account and carries the same UserId used by the Items API.
        if let sessionObject = try? await requestJSON(
            url: baseURL.appendingPathComponent("Sessions"),
            token: token,
            session: session
        ), let sessions = sessionObject as? [[String: Any]] {
            let matchingSession = sessions.first(where: { session in
                guard !preferred.isEmpty,
                      let name = session["UserName"] as? String else { return false }
                return name.caseInsensitiveCompare(preferred) == .orderedSame
            }) ?? sessions.first(where: { session in
                (session["Client"] as? String)?.caseInsensitiveCompare("Tubo") == .orderedSame
                    && session["UserId"] as? String != nil
            })
            if let matchingSession,
               let id = matchingSession["UserId"] as? String,
               !id.isEmpty {
                let name = matchingSession["UserName"] as? String ?? preferred
                resolvedUserCache[cacheKey] = (now.addingTimeInterval(600), id, name)
                return (id, name)
            }
        }

        let object = try await requestJSON(
            url: baseURL.appendingPathComponent("Users"),
            token: token,
            session: session
        )
        guard let users = object as? [[String: Any]], !users.isEmpty else {
            throw IPTVConfigurationError.invalidCredentials
        }
        let user = users.first(where: {
            guard !preferred.isEmpty, let name = $0["Name"] as? String else { return false }
            return name.caseInsensitiveCompare(preferred) == .orderedSame
        }) ?? users[0]
        guard let id = user["Id"] as? String, !id.isEmpty else {
            throw IPTVConfigurationError.invalidCredentials
        }
        let name = user["Name"] as? String ?? preferred
        resolvedUserCache[cacheKey] = (now.addingTimeInterval(600), id, name)
        return (id, name)
    }

    private static func rememberResolvedUser(
        baseURL: URL,
        token: String,
        id: String,
        name: String
    ) {
        resolvedUserCache["\(baseURL.absoluteString)|\(token)"] = (
            Date().addingTimeInterval(600),
            id,
            name
        )
    }

    private static func normalizedServerURL(_ rawServer: String) throws -> URL {
        var value = rawServer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") { value = "http://\(value)" }
        guard var components = URLComponents(string: value), components.host != nil else {
            throw IPTVConfigurationError.invalidServer
        }
        components.query = nil
        components.fragment = nil
        while components.path.hasSuffix("/") { components.path.removeLast() }
        guard let url = components.url else { throw IPTVConfigurationError.invalidServer }
        return url
    }

    private static func encodedPathComponent(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func authorizationHeader() -> String {
        "MediaBrowser Client=\"Tubo\", Device=\"iPhone\", DeviceId=\"\(mediaServerDeviceID)\", Version=\"1.8\""
    }

    private static func requestJSON(
        url: URL,
        method: String = "GET",
        body: [String: String]? = nil,
        token: String? = nil,
        timeout: TimeInterval = 30,
        session: URLSession? = nil
    ) async throws -> Any {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authorizationHeader(), forHTTPHeaderField: "X-Emby-Authorization")
        if let token { request.setValue(token, forHTTPHeaderField: "X-Emby-Token") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let requestSession = session ?? requestSession(timeout: timeout)
        let (data, response) = try await requestSession.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw IPTVConfigurationError.httpStatus(http.statusCode)
        }
        let parsed = try await Task.detached(priority: .userInitiated) {
            UncheckedJSONValue(
                value: try JSONSerialization.jsonObject(with: data)
            )
        }.value
        return parsed.value
    }

    private static func requestSession(timeout: TimeInterval) -> URLSession {
        let configuration = ProxyNetworkConfiguration.ephemeral()
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = max(timeout + 4, timeout)
        return URLSession(configuration: configuration)
    }
}

private struct UncheckedJSONValue: @unchecked Sendable {
    let value: Any
}

private enum EmbyLibraryCache {
    static func invalidate(
        configurationID: UUID,
        preservingHomeCache: Bool
    ) async {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let relativePath = "TuboEmby/\(configurationID.uuidString.lowercased())"
        let directories = [
            applicationSupport.appendingPathComponent(relativePath, isDirectory: true),
            caches.appendingPathComponent(relativePath, isDirectory: true),
        ]
        await Task.detached(priority: .utility) {
            for directory in directories {
                if !preservingHomeCache {
                    try? FileManager.default.removeItem(at: directory)
                    continue
                }
                guard let files = try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil
                ) else { continue }
                for file in files where file.lastPathComponent != "collections-v2.json"
                    && file.lastPathComponent != "continue-watching.json" {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }.value
    }

    static func collections(configurationID: UUID) async -> [MetadataLibraryCollection]? {
        await read(
            [MetadataLibraryCollection].self,
            from: fileURL(configurationID: configurationID, name: "collections-v2.json")
        )
    }

    static func homeCacheIsFresh(
        configurationID: UUID,
        maxAge: TimeInterval
    ) async -> Bool {
        await Task.detached(priority: .utility) {
            let url = fileURL(
                configurationID: configurationID,
                name: "collections-v2.json"
            )
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let modifiedAt = attributes[.modificationDate] as? Date else {
                return false
            }
            let age = Date().timeIntervalSince(modifiedAt)
            return age >= 0 && age < max(0, maxAge)
        }.value
    }

    static func storeCollections(
        _ collections: [MetadataLibraryCollection],
        configurationID: UUID
    ) async {
        await write(
            collections,
            to: fileURL(configurationID: configurationID, name: "collections-v2.json")
        )
    }

    static func continueWatching(configurationID: UUID) async -> [MetadataContinueItem]? {
        await read(
            [MetadataContinueItem].self,
            from: fileURL(configurationID: configurationID, name: "continue-watching.json")
        )
    }

    static func storeContinueWatching(
        _ items: [MetadataContinueItem],
        configurationID: UUID
    ) async {
        await write(
            items,
            to: fileURL(configurationID: configurationID, name: "continue-watching.json")
        )
    }

    static func browseNodes(
        configurationID: UUID,
        parentID: String,
        kind: String
    ) async -> [MetadataLibraryCollection]? {
        await read(
            [MetadataLibraryCollection].self,
            from: fileURL(
                configurationID: configurationID,
                name: "browse-v1-\(sanitizedFileComponent(kind))-\(sanitizedFileComponent(parentID)).json"
            )
        )
    }

    static func storeBrowseNodes(
        _ nodes: [MetadataLibraryCollection],
        configurationID: UUID,
        parentID: String,
        kind: String
    ) async {
        await write(
            nodes,
            to: fileURL(
                configurationID: configurationID,
                name: "browse-v1-\(sanitizedFileComponent(kind))-\(sanitizedFileComponent(parentID)).json"
            )
        )
    }

    static func mediaDetails(
        configurationID: UUID,
        itemID: String
    ) async -> MetadataDetails? {
        await read(
            MetadataDetails.self,
            from: fileURL(
                configurationID: configurationID,
                name: "details-v1-\(sanitizedFileComponent(itemID)).json"
            )
        )
    }

    static func storeMediaDetails(
        _ details: MetadataDetails,
        configurationID: UUID
    ) async {
        await write(
            details,
            to: fileURL(
                configurationID: configurationID,
                name: "details-v1-\(sanitizedFileComponent(details.itemID)).json"
            )
        )
    }

    static func page(
        configurationID: UUID,
        parentID: String?,
        startIndex: Int,
        limit: Int,
        genre: String?,
        prefersSeries: Bool
    ) async -> MetadataLibraryPage? {
        await read(
            MetadataLibraryPage.self,
            from: pageURL(
                configurationID: configurationID,
                parentID: parentID,
                startIndex: startIndex,
                limit: limit,
                genre: genre,
                prefersSeries: prefersSeries
            )
        )
    }

    static func storePage(
        _ page: MetadataLibraryPage,
        configurationID: UUID,
        parentID: String?,
        startIndex: Int,
        limit: Int,
        genre: String?,
        prefersSeries: Bool
    ) async {
        await write(
            page,
            to: pageURL(
                configurationID: configurationID,
                parentID: parentID,
                startIndex: startIndex,
                limit: limit,
                genre: genre,
                prefersSeries: prefersSeries
            )
        )
    }

    private static func pageURL(
        configurationID: UUID,
        parentID: String?,
        startIndex: Int,
        limit: Int,
        genre: String?,
        prefersSeries: Bool
    ) -> URL {
        let parent = sanitizedFileComponent(parentID ?? "root")
        let genreKey = sanitizedFileComponent(genre ?? "all")
        return fileURL(
            configurationID: configurationID,
            name: "page-v5-\(prefersSeries ? "series" : "media")-\(parent)-\(genreKey)-\(max(0, startIndex))-\(max(1, limit)).json"
        )
    }

    private static func fileURL(configurationID: UUID, name: String) -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport
            .appendingPathComponent("TuboEmby", isDirectory: true)
            .appendingPathComponent(configurationID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
    }

    private static func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let result = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        return String(result.prefix(96))
    }

    private static func read<Value: Decodable & Sendable>(
        _ type: Value.Type,
        from url: URL
    ) async -> Value? {
        await Task.detached(priority: .utility) {
            let data: Data
            if let current = try? Data(contentsOf: url) {
                data = current
            } else {
                let configurationID = url.deletingLastPathComponent().lastPathComponent
                let legacyURL = FileManager.default.urls(
                    for: .cachesDirectory,
                    in: .userDomainMask
                )[0]
                    .appendingPathComponent("TuboEmby", isDirectory: true)
                    .appendingPathComponent(configurationID, isDirectory: true)
                    .appendingPathComponent(url.lastPathComponent, isDirectory: false)
                guard let legacy = try? Data(contentsOf: legacyURL) else { return nil }
                data = legacy
            }
            return try? JSONDecoder().decode(type, from: data)
        }.value
    }

    private static func write<Value: Encodable & Sendable>(
        _ value: Value,
        to url: URL
    ) async {
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
                let data = try JSONEncoder().encode(value)
                try data.write(to: url, options: .atomic)
            } catch {
                return
            }
        }.value
    }
}

private enum ConfigurationCredentialVault {
    private static let service = "com.tubo.appname.configuration-credentials"
#if targetEnvironment(simulator)
    private static let simulatorDefaultsPrefix = "debug.configuration-credential."
    nonisolated(unsafe) private static var simulatorMemory: [UUID: String] = [:]
#endif

    static func set(_ password: String, for id: UUID) {
#if targetEnvironment(simulator)
        simulatorMemory[id] = password
#endif
        remove(for: id)
#if targetEnvironment(simulator)
        simulatorMemory[id] = password
#endif
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
#if !targetEnvironment(simulator)
        query[kSecAttrSynchronizable as String] = true
#endif
        let status = SecItemAdd(query as CFDictionary, nil)
#if targetEnvironment(simulator)
        if status != errSecSuccess {
            UserDefaults.standard.set(password, forKey: simulatorDefaultsPrefix + id.uuidString)
        }
#endif
    }

    static func password(for id: UUID) -> String? {
#if targetEnvironment(simulator)
        if let password = simulatorMemory[id] { return password }
#endif
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
#if !targetEnvironment(simulator)
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
#endif
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
#if targetEnvironment(simulator)
        return UserDefaults.standard.string(forKey: simulatorDefaultsPrefix + id.uuidString)
#else
        return nil
#endif
    }

    static func remove(for id: UUID) {
#if targetEnvironment(simulator)
        simulatorMemory[id] = nil
#endif
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
        ]
#if !targetEnvironment(simulator)
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
#endif
        SecItemDelete(query as CFDictionary)
#if targetEnvironment(simulator)
        UserDefaults.standard.removeObject(forKey: simulatorDefaultsPrefix + id.uuidString)
#endif
    }
}

private enum PlaylistImportError: LocalizedError {
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return AppLanguage.localizedFormat(
                "服务器返回 HTTP %d，请检查订阅是否过期、是否需要登录或专用请求头。",
                code
            )
        }
    }
}

extension Notification.Name {
    static let channelLibraryDidChange = Notification.Name("ChannelLibraryDidChange")
    static let configurationDidAdd = Notification.Name("ConfigurationDidAdd")
}

/// Serial background writer for the potentially large channel/configuration
/// JSON payloads. Callers pass immutable Sendable snapshots; cancellation is
/// checked after encoding so an obsolete payload can never overwrite a newer
/// configuration that was queued while encoding was in progress.
private actor ChannelLibraryPersistenceWriter {
    static let shared = ChannelLibraryPersistenceWriter()

    func writeConfigurations(
        _ configurations: [PlaylistConfiguration],
        activeConfigurationID: UUID?,
        configurationsKey: String,
        activeConfigurationKey: String
    ) throws {
        try Task.checkCancellation()
        let data = try JSONEncoder().encode(configurations)
        try Task.checkCancellation()

        let defaults = UserDefaults.standard
        defaults.set(data, forKey: configurationsKey)
        if let activeConfigurationID {
            defaults.set(activeConfigurationID.uuidString, forKey: activeConfigurationKey)
        } else {
            defaults.removeObject(forKey: activeConfigurationKey)
        }
    }

    func writeChannels(_ channels: [Channel], storageKey: String) throws {
        try Task.checkCancellation()
        let data = try JSONEncoder().encode(channels)
        try Task.checkCancellation()
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

/// Tiny union-find used only while rebuilding the active channel-line index.
/// Keeping it value-based avoids retaining any Channel or view objects.
private struct ChannelLineDisjointSet {
    private var parents: [Int]
    private var ranks: [UInt8]

    init(count: Int) {
        parents = Array(0..<count)
        ranks = Array(repeating: 0, count: count)
    }

    mutating func root(of index: Int) -> Int {
        var root = index
        while parents[root] != root {
            root = parents[root]
        }
        var cursor = index
        while parents[cursor] != cursor {
            let next = parents[cursor]
            parents[cursor] = root
            cursor = next
        }
        return root
    }

    mutating func union(_ lhs: Int, _ rhs: Int) {
        let lhsRoot = root(of: lhs)
        let rhsRoot = root(of: rhs)
        guard lhsRoot != rhsRoot else { return }
        if ranks[lhsRoot] < ranks[rhsRoot] {
            parents[lhsRoot] = rhsRoot
        } else if ranks[lhsRoot] > ranks[rhsRoot] {
            parents[rhsRoot] = lhsRoot
        } else {
            parents[rhsRoot] = lhsRoot
            ranks[lhsRoot] &+= 1
        }
    }
}

enum PlexConfigurationService {
    struct Result {
        let server: URL
        let channels: [Channel]
    }

    struct AuthorizationPin: Decodable, Sendable {
        let id: Int
        let code: String
        let authToken: String?
        let expiresIn: Int?
    }

    struct ServerCandidate: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let server: String
        let token: String
        let owned: Bool
        let alternateRoutes: [String]
    }

    private struct PlexResource: Decodable {
        struct Connection: Decodable {
            let uri: String
            let local: Bool?
            let relay: Bool?
        }

        let name: String
        let provides: String
        let clientIdentifier: String
        let accessToken: String?
        let owned: Bool?
        let connections: [Connection]
    }

    private static let clientIdentifier: String = {
        let key = "rove.legacyLibraryD.client-identifier.v1"
        if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
            return value
        }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: key)
        return value
    }()

    static func createAuthorizationPin() async throws -> AuthorizationPin {
        let url = URL(string: "https://legacyLibraryD.tv/api/v2/pins?strong=true")!
        let data = try await request(url, method: "POST", token: nil, accept: "application/json")
        return try JSONDecoder().decode(AuthorizationPin.self, from: data)
    }

    static func authorizationURL(code: String) -> URL? {
        var components = URLComponents(string: "https://app.legacyLibraryD.tv/auth")
        components?.fragment = "?clientID=\(clientIdentifier)&code=\(code)&context%5Bdevice%5D%5Bproduct%5D=RovePlayer"
        return components?.url
    }

    static func authorizationPin(id: Int) async throws -> AuthorizationPin {
        let url = URL(string: "https://legacyLibraryD.tv/api/v2/pins/\(id)")!
        let data = try await request(url, token: nil, accept: "application/json")
        return try JSONDecoder().decode(AuthorizationPin.self, from: data)
    }

    static func discoverServers(accountToken: String) async throws -> [ServerCandidate] {
        let endpoint = "https://legacyLibraryD.tv/api/v2/resources?includeHttps=1&includeRelay=1&includeIPv6=1"
        let data = try await request(URL(string: endpoint)!, token: accountToken, accept: "application/json")
        let resources = try JSONDecoder().decode([PlexResource].self, from: data)
            .filter { $0.provides.split(separator: ",").contains("server") }

        var candidates: [ServerCandidate] = []
        for resource in resources {
            let token = resource.accessToken?.isEmpty == false ? resource.accessToken! : accountToken
            let orderedRoutes = resource.connections
                .sorted {
                    let lhs = (($0.local == true) ? 0 : (($0.relay == true) ? 2 : 1), $0.uri.hasPrefix("https") ? 0 : 1)
                    let rhs = (($1.local == true) ? 0 : (($1.relay == true) ? 2 : 1), $1.uri.hasPrefix("https") ? 0 : 1)
                    return lhs < rhs
                }
                .map(\.uri)
            guard let selected = await firstReachableRoute(orderedRoutes, token: token) else { continue }
            candidates.append(ServerCandidate(
                id: resource.clientIdentifier,
                name: resource.name,
                server: selected,
                token: token,
                owned: resource.owned ?? false,
                alternateRoutes: orderedRoutes.filter { $0 != selected }
            ))
        }
        return candidates
    }

    static func loadLibrary(
        server: String,
        token: String,
        configurationID: UUID
    ) async throws -> Result {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { throw IPTVConfigurationError.missingCredentials }
        let baseURL = try normalizedServer(server)
        let sectionsData = try await request(baseURL.appendingPathComponent("library/sections"), token: trimmedToken)
        let sectionParser = PlexSectionsParser()
        let parser = XMLParser(data: sectionsData)
        parser.delegate = sectionParser
        guard parser.parse() else { throw parser.parserError ?? URLError(.cannotParseResponse) }

        var channels: [Channel] = []
        for section in sectionParser.sections where section.type == "movie" || section.type == "show" {
            let url = baseURL.appendingPathComponent("library/sections/\(section.key)/all")
            let data = try await request(url, token: trimmedToken)
            let itemParser = PlexItemsParser(
                baseURL: baseURL,
                token: trimmedToken,
                configurationID: configurationID,
                sectionTitle: section.title
            )
            let xml = XMLParser(data: data)
            xml.delegate = itemParser
            guard xml.parse() else { throw xml.parserError ?? URLError(.cannotParseResponse) }
            channels.append(contentsOf: itemParser.channels)
        }
        return Result(server: baseURL, channels: channels)
    }

    static func loadPage(
        server: String,
        token: String,
        configurationID: UUID,
        parentID: String?,
        startIndex: Int,
        limit: Int,
        searchTerm: String?
    ) async throws -> MetadataLibraryPage {
        let baseURL = try normalizedServer(server)
        let cleanSearch = searchTerm?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let channels: [Channel]
        if let parentID, !parentID.isEmpty {
            let path = parentID.hasPrefix("section:")
                ? "library/sections/\(parentID.dropFirst("section:".count))/all"
                : "library/metadata/\(parentID)/allLeaves"
            let url = baseURL.appendingPathComponent(path)
            channels = try await loadItems(
                url: url,
                baseURL: baseURL,
                token: token,
                configurationID: configurationID,
                sectionTitle: "Plex"
            )
        } else if !cleanSearch.isEmpty {
            var components = URLComponents(
                url: baseURL.appendingPathComponent("hubs/search"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [URLQueryItem(name: "query", value: cleanSearch)]
            guard let url = components?.url else { throw URLError(.badURL) }
            channels = try await loadItems(
                url: url,
                baseURL: baseURL,
                token: token,
                configurationID: configurationID,
                sectionTitle: "Plex"
            )
        } else {
            channels = try await loadLibrary(
                server: server,
                token: token,
                configurationID: configurationID
            ).channels
        }
        let filtered = channels.filter {
            $0.mediaServerItemType?.caseInsensitiveCompare("Season") != .orderedSame
        }
        let lower = max(0, min(startIndex, filtered.count))
        let upper = min(filtered.count, lower + max(1, limit))
        return MetadataLibraryPage(
            channels: Array(filtered[lower..<upper]),
            totalCount: filtered.count,
            nextStartIndex: upper
        )
    }

    static func loadCollections(server: String, token: String) async throws -> [MetadataLibraryCollection] {
        let baseURL = try normalizedServer(server)
        let data = try await request(baseURL.appendingPathComponent("library/sections"), token: token)
        let sectionParser = PlexSectionsParser()
        let parser = XMLParser(data: data)
        parser.delegate = sectionParser
        guard parser.parse() else { throw parser.parserError ?? URLError(.cannotParseResponse) }
        return sectionParser.sections
            .filter { $0.type == "movie" || $0.type == "show" }
            .map {
                MetadataLibraryCollection(
                    id: "section:\($0.key)",
                    name: $0.title,
                    collectionType: $0.type == "show" ? "tvshows" : "movies"
                )
            }
    }

    static func loadContinueWatching(
        server: String,
        token: String,
        configurationID: UUID,
        limit: Int
    ) async throws -> [MetadataContinueItem] {
        let baseURL = try normalizedServer(server)
        let paths = [
            "hubs/continueWatching/items",
            "hubs/home/continueWatching",
            "library/onDeck",
        ]
        var lastError: Error?
        for path in paths {
            do {
                var components = URLComponents(
                    url: baseURL.appendingPathComponent(path),
                    resolvingAgainstBaseURL: false
                )
                components?.queryItems = [
                    URLQueryItem(name: "includeGuids", value: "1"),
                    URLQueryItem(name: "X-Plex-Container-Start", value: "0"),
                    URLQueryItem(name: "X-Plex-Container-Size", value: String(min(max(1, limit), 30))),
                ]
                guard let url = components?.url else { throw URLError(.badURL) }
                let parser = try await metadataParser(
                    url: url,
                    baseURL: baseURL,
                    token: token,
                    configurationID: configurationID
                )
                return parser.channels.compactMap { channel in
                    guard let itemID = channel.tvgID,
                          let progress = parser.progressByItemID[itemID],
                          progress.positionSeconds > 0,
                          progress.durationSeconds > 0 else { return nil }
                    return MetadataContinueItem(
                        channel: channel,
                        positionSeconds: progress.positionSeconds,
                        durationSeconds: progress.durationSeconds
                    )
                }
                .prefix(limit)
                .map { $0 }
            } catch {
                lastError = error
            }
        }
        throw lastError ?? URLError(.cannotParseResponse)
    }

    static func loadSimilarItems(
        server: String,
        token: String,
        configurationID: UUID,
        itemID: String,
        limit: Int
    ) async throws -> [Channel] {
        let baseURL = try normalizedServer(server)
        let paths = [
            "library/metadata/\(itemID)/similar",
            "library/metadata/\(itemID)/related",
        ]
        var lastError: Error?
        for path in paths {
            do {
                var components = URLComponents(
                    url: baseURL.appendingPathComponent(path),
                    resolvingAgainstBaseURL: false
                )
                components?.queryItems = [
                    URLQueryItem(name: "X-Plex-Container-Size", value: String(min(max(1, limit), 100))),
                ]
                guard let url = components?.url else { throw URLError(.badURL) }
                let channels = try await loadItems(
                    url: url,
                    baseURL: baseURL,
                    token: token,
                    configurationID: configurationID,
                    sectionTitle: "Plex"
                )
                if !channels.isEmpty {
                    var seen = Set<String>()
                    return channels.filter {
                        guard let id = $0.tvgID, id != itemID else { return false }
                        return seen.insert(id).inserted
                    }.prefix(limit).map { $0 }
                }
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        return []
    }

    static func loadItemsForPerson(
        server: String,
        token: String,
        configurationID: UUID,
        personID: String,
        limit: Int
    ) async throws -> [Channel] {
        let baseURL = try normalizedServer(server)
        let data = try await request(baseURL.appendingPathComponent("library/sections"), token: token)
        let sectionParser = PlexSectionsParser()
        let parser = XMLParser(data: data)
        parser.delegate = sectionParser
        guard parser.parse() else { throw parser.parserError ?? URLError(.cannotParseResponse) }
        let sections = sectionParser.sections.filter { $0.type == "movie" || $0.type == "show" }

        var lastError: Error?
        for tag in ["actor", "director", "writer"] {
            var matches: [Channel] = []
            for section in sections where matches.count < limit {
                do {
                    var components = URLComponents(
                        url: baseURL.appendingPathComponent("library/sections/\(section.key)/all"),
                        resolvingAgainstBaseURL: false
                    )
                    components?.queryItems = [
                        URLQueryItem(name: tag, value: personID),
                        URLQueryItem(name: "X-Plex-Container-Start", value: "0"),
                        URLQueryItem(name: "X-Plex-Container-Size", value: String(min(max(1, limit), 100))),
                    ]
                    guard let url = components?.url else { continue }
                    matches.append(contentsOf: try await loadItems(
                        url: url,
                        baseURL: baseURL,
                        token: token,
                        configurationID: configurationID,
                        sectionTitle: section.title
                    ))
                } catch {
                    lastError = error
                }
            }
            if !matches.isEmpty {
                var seen = Set<String>()
                return matches.filter {
                    guard let id = $0.tvgID else { return false }
                    return seen.insert(id).inserted
                }.prefix(limit).map { $0 }
            }
        }
        if let lastError, sections.isEmpty { throw lastError }
        return []
    }

    static func loadDetails(server: String, token: String, itemID: String) async throws -> MetadataDetails {
        let baseURL = try normalizedServer(server)
        let url = baseURL.appendingPathComponent("library/metadata/\(itemID)")
        let parser = try await metadataParser(url: url, baseURL: baseURL, token: token, configurationID: UUID())
        guard let item = parser.firstItem else { throw URLError(.cannotParseResponse) }
        let duration = item["duration"].flatMap(Double.init).map { $0 / 1_000 }
        let media = parser.firstMedia
        let part = parser.firstPart
        let version = part.map { part in
            MetadataVersion(
                id: part["id"] ?? part["key"] ?? itemID,
                name: part["file"]?.split(separator: "/").last.map(String.init) ?? item["title"] ?? "Plex",
                container: media?["container"],
                sizeBytes: part["size"].flatMap(Int64.init),
                bitRate: media?["bitrate"].flatMap(Int.init).map { $0 * 1_000 },
                width: media?["width"].flatMap(Int.init),
                height: media?["height"].flatMap(Int.init),
                serverName: nil,
                serverConfigurationID: nil,
                serverItemID: itemID,
                serverKind: PlaylistConfigurationKind.legacyLibraryD.rawValue,
                dynamicRange: media?["videoDynamicRange"],
                frameRate: media?["videoFrameRate"].flatMap(Double.init),
                subtitleTracks: nil,
                audioTracks: nil
            )
        }
        return MetadataDetails(
            itemID: itemID,
            title: item["title"] ?? "Plex",
            overview: item["summary"],
            premiereDate: item["originallyAvailableAt"],
            productionYear: item["year"].flatMap(Int.init),
            communityRating: item["rating"].flatMap(Double.init),
            officialRating: item["contentRating"],
            genres: parser.genres,
            runtimeSeconds: duration,
            container: media?["container"],
            sizeBytes: part?["size"].flatMap(Int64.init),
            people: parser.people,
            studios: item["studio"].map { [$0] },
            streams: [],
            mediaVersions: version.map { [$0] }
        )
    }

    static func resolveStream(server: String, token: String, itemID: String) async throws -> URL {
        let baseURL = try normalizedServer(server)
        let url = baseURL.appendingPathComponent("library/metadata/\(itemID)")
        let parser = try await metadataParser(url: url, baseURL: baseURL, token: token, configurationID: UUID())
        guard let key = parser.firstPart?["key"],
              let rawURL = URL(string: key, relativeTo: baseURL)?.absoluteURL,
              var components = URLComponents(url: rawURL, resolvingAgainstBaseURL: false) else {
            throw IPTVConfigurationError.streamResolutionFailed
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "X-Plex-Token", value: token))
        components.queryItems = items
        guard let resolved = components.url else { throw IPTVConfigurationError.streamResolutionFailed }
        return resolved
    }

    static func reportPlayback(
        server: String,
        token: String,
        itemID: String,
        position: Double,
        duration: Double,
        isPaused: Bool,
        stopped: Bool
    ) async {
        guard let baseURL = try? normalizedServer(server), !itemID.isEmpty else { return }
        var components = URLComponents(
            url: baseURL.appendingPathComponent(":/timeline"),
            resolvingAgainstBaseURL: false
        )
        let milliseconds = Int64(max(0, position) * 1_000)
        let durationMilliseconds = Int64(max(0, duration) * 1_000)
        components?.queryItems = [
            URLQueryItem(name: "ratingKey", value: itemID),
            URLQueryItem(name: "key", value: "/library/metadata/\(itemID)"),
            URLQueryItem(name: "state", value: stopped ? "stopped" : (isPaused ? "paused" : "playing")),
            URLQueryItem(name: "time", value: String(milliseconds)),
            URLQueryItem(name: "playbackTime", value: String(milliseconds)),
            URLQueryItem(name: "duration", value: String(durationMilliseconds)),
            URLQueryItem(name: "context", value: "library"),
        ]
        guard let url = components?.url else { return }
        _ = try? await request(url, method: "POST", token: token)
    }

    static func setPlayed(
        server: String,
        token: String,
        itemID: String,
        played: Bool
    ) async -> Bool {
        guard let baseURL = try? normalizedServer(server), !itemID.isEmpty else { return false }
        var components = URLComponents(
            url: baseURL.appendingPathComponent(played ? ":/scrobble" : ":/unscrobble"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "key", value: itemID),
            URLQueryItem(name: "identifier", value: "com.plexapp.plugins.library"),
        ]
        guard let url = components?.url else { return false }
        do {
            _ = try await request(url, method: "POST", token: token)
            return true
        } catch {
            return false
        }
    }

    static func artworkData(server: String, token: String, itemID: String, landscape: Bool) async throws -> Data {
        let baseURL = try normalizedServer(server)
        let metadataURL = baseURL.appendingPathComponent("library/metadata/\(itemID)")
        let parser = try await metadataParser(
            url: metadataURL,
            baseURL: baseURL,
            token: token,
            configurationID: UUID()
        )
        guard let item = parser.firstItem,
              let path = landscape ? (item["art"] ?? item["thumb"]) : (item["thumb"] ?? item["art"]),
              let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw URLError(.fileDoesNotExist)
        }
        return try await request(url, token: token, accept: "image/*")
    }

    private static func loadItems(
        url: URL,
        baseURL: URL,
        token: String,
        configurationID: UUID,
        sectionTitle: String
    ) async throws -> [Channel] {
        let parser = try await metadataParser(
            url: url,
            baseURL: baseURL,
            token: token,
            configurationID: configurationID,
            sectionTitle: sectionTitle
        )
        return parser.channels
    }

    private static func metadataParser(
        url: URL,
        baseURL: URL,
        token: String,
        configurationID: UUID,
        sectionTitle: String = "Plex"
    ) async throws -> PlexItemsParser {
        let data = try await request(url, token: token)
        let itemParser = PlexItemsParser(
            baseURL: baseURL,
            token: token,
            configurationID: configurationID,
            sectionTitle: sectionTitle
        )
        let xml = XMLParser(data: data)
        xml.delegate = itemParser
        guard xml.parse() else { throw xml.parserError ?? URLError(.cannotParseResponse) }
        return itemParser
    }

    private static func firstReachableRoute(_ routes: [String], token: String) async -> String? {
        for route in routes {
            guard let baseURL = try? normalizedServer(route) else { continue }
            var request = URLRequest(url: baseURL.appendingPathComponent("identity"))
            applyHeaders(to: &request, token: token, accept: "application/xml")
            request.timeoutInterval = 5
            if let (_, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse,
               (200..<300).contains(http.statusCode) {
                return baseURL.absoluteString
            }
        }
        return nil
    }

    static func normalizedServer(_ value: String) throws -> URL {
        var raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw URLError(.badURL) }
        if !raw.contains("://") { raw = "http://" + raw }
        guard var components = URLComponents(string: raw),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host != nil else { throw URLError(.badURL) }
        if components.path.isEmpty { components.path = "/" }
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    private static func request(
        _ url: URL,
        method: String = "GET",
        token: String?,
        accept: String = "application/xml"
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        applyHeaders(to: &request, token: token, accept: accept)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
        return data
    }

    private static func applyHeaders(to request: inout URLRequest, token: String?, accept: String) {
        if let token { request.setValue(token, forHTTPHeaderField: "X-Plex-Token") }
        request.setValue("RovePlayer", forHTTPHeaderField: "X-Plex-Product")
        request.setValue("1.0", forHTTPHeaderField: "X-Plex-Version")
        request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue("iOS", forHTTPHeaderField: "X-Plex-Platform")
        request.setValue(accept, forHTTPHeaderField: "Accept")
    }
}

private final class PlexSectionsParser: NSObject, XMLParserDelegate {
    struct Section { let key: String; let title: String; let type: String }
    var sections: [Section] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "Directory",
              let key = attributeDict["key"],
              let title = attributeDict["title"],
              let type = attributeDict["type"] else { return }
        sections.append(Section(key: key, title: title, type: type))
    }
}

private final class PlexItemsParser: NSObject, XMLParserDelegate {
    private let baseURL: URL
    private let token: String
    private let configurationID: UUID
    private let sectionTitle: String
    private var current: [String: String]?
    private var currentPartKey: String?
    private var currentElement: String?
    private var currentMedia: [String: String]?
    private var currentPart: [String: String]?
    var channels: [Channel] = []
    var firstItem: [String: String]?
    var firstMedia: [String: String]?
    var firstPart: [String: String]?
    var genres: [String] = []
    var people: [MetadataCreditPerson] = []
    var progressByItemID: [String: (positionSeconds: Double, durationSeconds: Double)] = [:]

    init(baseURL: URL, token: String, configurationID: UUID, sectionTitle: String) {
        self.baseURL = baseURL
        self.token = token
        self.configurationID = configurationID
        self.sectionTitle = sectionTitle
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if (elementName == "Video" || elementName == "Directory"), current == nil,
           attributeDict["ratingKey"] != nil {
            current = attributeDict
            currentElement = elementName
            currentPartKey = nil
            currentMedia = nil
            currentPart = nil
        } else if elementName == "Media", current != nil, currentMedia == nil {
            currentMedia = attributeDict
        } else if elementName == "Part", current != nil, currentPartKey == nil {
            currentPartKey = attributeDict["key"]
            currentPart = attributeDict
        } else if elementName == "Genre", let tag = attributeDict["tag"], !genres.contains(tag) {
            genres.append(tag)
        } else if (elementName == "Role" || elementName == "Director"),
                  let name = attributeDict["tag"] {
            people.append(MetadataCreditPerson(
                id: attributeDict["id"] ?? "legacyLibraryD-person-\(people.count)-\(name)",
                imageItemID: nil,
                name: name,
                role: attributeDict["role"],
                type: elementName
            ))
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName == currentElement, let item = current,
              let itemID = item["ratingKey"] else {
            return
        }
        firstItem = firstItem ?? item
        firstMedia = firstMedia ?? currentMedia
        firstPart = firstPart ?? currentPart
        if let position = item["viewOffset"].flatMap(Double.init),
           let duration = item["duration"].flatMap(Double.init) {
            progressByItemID[itemID] = (position / 1_000, duration / 1_000)
        }
        let title = item["title"] ?? "Plex"
        let group = item["grandparentTitle"] ?? item["parentTitle"] ?? sectionTitle
        var artworkURL = item["thumb"].flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }
        if let rawArtworkURL = artworkURL,
           var components = URLComponents(url: rawArtworkURL, resolvingAgainstBaseURL: true) {
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "X-Plex-Token", value: token)]
            artworkURL = components.url
        }
        let placeholder = URL(string: "rove-legacyLibraryD://item/\(itemID)")!
        let rawType = item["type"]?.lowercased() ?? "video"
        let mediaType: String = switch rawType {
        case "show": "Series"
        case "episode": "Episode"
        case "movie": "Movie"
        case "season": "Season"
        default: rawType
        }
        channels.append(
            Channel(
                name: title,
                streamURL: placeholder,
                group: group,
                logoURL: artworkURL,
                tvgID: itemID,
                tvgName: item["grandparentTitle"] ?? title,
                httpHeaders: ["X-Plex-Token": token],
                resolver: .legacyLibraryD(configurationID: configurationID, itemID: itemID),
                playbackKind: .onDemand,
                productionYear: item["year"].flatMap(Int.init),
                communityRating: item["rating"].flatMap(Double.init),
                releaseDate: item["originallyAvailableAt"],
                playCount: item["viewCount"].flatMap(Int.init),
                runtimeSeconds: item["duration"].flatMap(Double.init).map { $0 / 1_000 },
                fileSize: currentPart?["size"].flatMap(Int64.init),
                container: currentMedia?["container"],
                mediaServerItemType: mediaType,
                mediaServerSeriesID: rawType == "episode"
                    ? (item["grandparentRatingKey"] ?? item["parentRatingKey"])
                    : nil,
                mediaServerPlayed: (item["viewCount"].flatMap(Int.init) ?? 0) > 0
            )
        )
        current = nil
        currentElement = nil
        currentPartKey = nil
        currentMedia = nil
        currentPart = nil
    }
}
#endif
