import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    static let defaultsKey = "tubo.language.preference.v1"

    // Match the localization order shown in App Store Connect. Simplified
    // Chinese is the app's primary localization, displayed there as unlocalized.
    case simplifiedChinese = "zh-Hans"
    case arabic = "ar"
    case odia = "or"
    case hindi = "hi"
    case polish = "pl"
    case danish = "da"
    case german = "de"
    case russian = "ru"
    case french = "fr"
    case frenchCanada = "fr-CA"
    case traditionalChinese = "zh-Hant"
    case finnish = "fi"
    case gujarati = "gu"
    case korean = "ko"
    case dutch = "nl"
    case catalan = "ca"
    case czech = "cs"
    case kannada = "kn"
    case croatian = "hr"
    case romanian = "ro"
    case marathi = "mr"
    case malayalam = "ml"
    case malay = "ms"
    case bangla = "bn"
    case norwegian = "no"
    case punjabi = "pa"
    case portugueseBrazil = "pt-BR"
    case portuguesePortugal = "pt-PT"
    case japanese = "ja"
    case swedish = "sv"
    case slovak = "sk"
    case slovenian = "sl"
    case telugu = "te"
    case tamil = "ta"
    case thai = "th"
    case turkish = "tr"
    case urdu = "ur"
    case ukrainian = "uk"
    case spanishMexico = "es-MX"
    case spanishSpain = "es"
    case hebrew = "he"
    case greek = "el"
    case hungarian = "hu"
    case italian = "it"
    case indonesian = "id"
    case englishAustralia = "en-AU"
    case englishCanada = "en-CA"
    case english = "en"
    case englishUnitedKingdom = "en-GB"
    case vietnamese = "vi"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var symbol: String {
        switch self {
        case .simplifiedChinese: "🇨🇳"
        case .traditionalChinese: "🇹🇼"
        case .english: "🇺🇸"
        case .englishAustralia: "🇦🇺"
        case .englishCanada: "🇨🇦"
        case .englishUnitedKingdom: "🇬🇧"
        case .arabic: "🇸🇦"
        case .bangla: "🇧🇩"
        case .catalan: "🇪🇸"
        case .croatian: "🇭🇷"
        case .czech: "🇨🇿"
        case .danish: "🇩🇰"
        case .dutch: "🇳🇱"
        case .finnish: "🇫🇮"
        case .french: "🇫🇷"
        case .frenchCanada: "🇨🇦"
        case .german: "🇩🇪"
        case .greek: "🇬🇷"
        case .gujarati, .hindi, .kannada, .malayalam, .marathi, .odia, .punjabi,
             .tamil, .telugu: "🇮🇳"
        case .hebrew: "🇮🇱"
        case .hungarian: "🇭🇺"
        case .indonesian: "🇮🇩"
        case .italian: "🇮🇹"
        case .japanese: "🇯🇵"
        case .korean: "🇰🇷"
        case .malay: "🇲🇾"
        case .norwegian: "🇳🇴"
        case .polish: "🇵🇱"
        case .portugueseBrazil: "🇧🇷"
        case .portuguesePortugal: "🇵🇹"
        case .romanian: "🇷🇴"
        case .russian: "🇷🇺"
        case .slovak: "🇸🇰"
        case .slovenian: "🇸🇮"
        case .spanishMexico: "🇲🇽"
        case .spanishSpain: "🇪🇸"
        case .swedish: "🇸🇪"
        case .thai: "🇹🇭"
        case .turkish: "🇹🇷"
        case .ukrainian: "🇺🇦"
        case .urdu: "🇵🇰"
        case .vietnamese: "🇻🇳"
        }
    }

    var displayName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .englishAustralia: "English (Australia)"
        case .englishCanada: "English (Canada)"
        case .englishUnitedKingdom: "English (UK)"
        case .arabic: "العربية"
        case .bangla: "বাংলা"
        case .catalan: "Català"
        case .croatian: "Hrvatski"
        case .czech: "Čeština"
        case .danish: "Dansk"
        case .dutch: "Nederlands"
        case .finnish: "Suomi"
        case .french: "Français"
        case .frenchCanada: "Français (Canada)"
        case .german: "Deutsch"
        case .greek: "Ελληνικά"
        case .gujarati: "ગુજરાતી"
        case .hebrew: "עברית"
        case .hindi: "हिन्दी"
        case .hungarian: "Magyar"
        case .indonesian: "Bahasa Indonesia"
        case .italian: "Italiano"
        case .japanese: "日本語"
        case .kannada: "ಕನ್ನಡ"
        case .korean: "한국어"
        case .malay: "Bahasa Melayu"
        case .malayalam: "മലയാളം"
        case .marathi: "मराठी"
        case .norwegian: "Norsk"
        case .odia: "ଓଡ଼ିଆ"
        case .polish: "Polski"
        case .portugueseBrazil: "Português (Brasil)"
        case .portuguesePortugal: "Português (Portugal)"
        case .punjabi: "ਪੰਜਾਬੀ"
        case .romanian: "Română"
        case .russian: "Русский"
        case .slovak: "Slovenčina"
        case .slovenian: "Slovenščina"
        case .spanishMexico: "Español (México)"
        case .spanishSpain: "Español (España)"
        case .swedish: "Svenska"
        case .tamil: "தமிழ்"
        case .telugu: "తెలుగు"
        case .thai: "ไทย"
        case .turkish: "Türkçe"
        case .ukrainian: "Українська"
        case .urdu: "اردو"
        case .vietnamese: "Tiếng Việt"
        }
    }

    static var current: AppLanguage {
        let rawValue = UserDefaults.standard.string(forKey: defaultsKey)
        return AppLanguage(rawValue: rawValue ?? "") ?? .simplifiedChinese
    }

    static func localized(_ key: String) -> String {
        let language = current
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return key }

        let localizedValue = bundle.localizedString(forKey: key, value: key, table: nil)
        if localizedValue.contains("⁇") {
            guard let englishPath = Bundle.main.path(
                forResource: AppLanguage.english.rawValue,
                ofType: "lproj"
            ), let englishBundle = Bundle(path: englishPath) else {
                return key
            }
            return englishBundle.localizedString(forKey: key, value: key, table: nil)
        }
        guard localizedValue == key,
              language != .simplifiedChinese,
              language != .traditionalChinese,
              let englishPath = Bundle.main.path(forResource: AppLanguage.english.rawValue, ofType: "lproj"),
              let englishBundle = Bundle(path: englishPath)
        else {
            return localizedValue
        }

        // New feature copy is added continuously. Keep an incomplete locale
        // coherent by falling back to English instead of exposing a Chinese key.
        return englishBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: localized(key), locale: current.locale, arguments: arguments)
    }
}

enum ProxyType: String, Codable, CaseIterable, Identifiable, Sendable {
    case http
    case socks5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .http: "HTTP"
        case .socks5: "SOCKS5"
        }
    }
}

enum StreamResolver: Codable, Hashable, Sendable {
    case legacySourceA(configurationID: UUID, command: String)
    case legacyLibraryA(configurationID: UUID, itemID: String)
    case movieClaw(configurationID: UUID, itemID: String)
    case legacyLibraryB(configurationID: UUID, itemID: String)
    case legacyLibraryC(configurationID: UUID, itemID: String)
    case legacyLibraryD(configurationID: UUID, itemID: String)
}

/// Explicit media semantics for addresses whose URL does not reveal whether
/// they are a live stream or a seekable file (for example cloud-drive signed
/// download URLs). `nil` keeps the legacy URL-based detection for existing
/// playlists and persisted channels.
enum ChannelPlaybackKind: String, Codable, Hashable, Sendable {
    case live
    case onDemand
}

struct ClearKeyConfiguration: Codable, Hashable, Sendable {
    let keyIDHex: String
    let keyHex: String
}

enum RTSPTransportPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case automatic
    case tcp
    case udp
}

struct CatchupConfiguration: Codable, Hashable, Sendable {
    var mode: String?
    var source: String?
    var days: Int?
}

struct StreamProxyConfiguration: Codable, Hashable, Sendable {
    var type: ProxyType
    var host: String
    var port: Int
    var username: String?
    var password: String?

    var proxyURL: URL? {
        var components = URLComponents()
        components.scheme = type == .http ? "http" : "socks5"
        components.host = host
        components.port = port
        components.user = username?.isEmpty == false ? username : nil
        components.password = password?.isEmpty == false ? password : nil
        return components.url
    }
}

enum HLSProxyMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case automatic
    case always

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: AppLanguage.localized("关闭")
        case .automatic: AppLanguage.localized("自动")
        case .always: AppLanguage.localized("始终开启")
        }
    }
}

struct PlaybackBufferPolicy: Codable, Hashable, Sendable {
    var minimumDuration: Double?
    var skipInitialBuffer: Bool
    var multicastFCCEnabled: Bool

    init(
        minimumDuration: Double? = nil,
        skipInitialBuffer: Bool = false,
        multicastFCCEnabled: Bool = false
    ) {
        self.minimumDuration = minimumDuration
        self.skipInitialBuffer = skipInitialBuffer
        self.multicastFCCEnabled = multicastFCCEnabled
    }
}

struct ChannelMediaTechnicalInfo: Codable, Equatable, Sendable {
    let width: Int
    let height: Int
    let frameRate: Double?
    let audioChannelCount: Int?

    var resolutionText: String {
        "\(width)×\(height)"
    }

    var playbackDetailText: String {
        var components: [String] = []
        if let frameRate, frameRate > 0 {
            let rounded = frameRate.rounded()
            let value = abs(frameRate - rounded) < 0.05
                ? String(Int(rounded))
                : String(format: "%.1f", frameRate)
            components.append("\(value)FPS")
        }
        if let audioChannelCount {
            switch audioChannelCount {
            case 1: components.append(AppLanguage.localized("单声道"))
            case 2: components.append(AppLanguage.localized("立体"))
            default:
                components.append(
                    "\(audioChannelCount)\(AppLanguage.localized("声道数单位"))"
                )
            }
        }
        return components.joined(separator: " · ")
    }
}

struct Channel: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var streamURL: URL
    var group: String
    var logoURL: URL?
    var tvgID: String?
    var tvgName: String?
    /// 播放该频道时需要携带的 HTTP 请求头。常见于带 Referer、Cookie
    /// 或指定 User-Agent 的个人订阅源。
    var httpHeaders: [String: String]
    /// MPEG-DASH Common Encryption key declared by a user-provided playlist.
    /// This is playback metadata, not an HTTP header, so it must never be sent
    /// to the manifest or segment server.
    var clearKey: ClearKeyConfiguration?
    /// 需要在播放前向服务端换取临时播放地址的频道（例如 Stalker Portal）。
    var resolver: StreamResolver?
    /// 运行时字段：ClearKey DASH 清单预处理后，保存原始远端地址。
    /// 断线重连时必须重新获取清单，不能复用临时目录里的旧 MPD。
    var preparedFromURL: URL?
    var fusionVideoURL: URL?
    var fusionAudioURL: URL?
    var audioDelayMilliseconds: Int?
    var videoDelayMilliseconds: Int?
    var catchup: CatchupConfiguration?
    var proxyOverride: StreamProxyConfiguration?
    var hlsProxyMode: HLSProxyMode
    /// Runtime-only state used to release a prepared loopback route.
    var hlsProxySessionID: String?
    var rtspTransport: RTSPTransportPreference?
    var rtspRedirectDetectionEnabled: Bool?
    var bufferPolicy: PlaybackBufferPolicy?
    var playbackKind: ChannelPlaybackKind?
    var productionYear: Int?
    var communityRating: Double?
    var criticRating: Double?
    var officialRating: String?
    var dateAdded: String?
    var releaseDate: String?
    var playCount: Int?
    var lastPlayedDate: String?
    var runtimeSeconds: TimeInterval?
    var fileSize: Int64?
    var container: String?
    var mediaServerItemType: String?
    var mediaServerSeriesID: String?
    /// Selected Emby MediaSource for a user-chosen resource version.
    var mediaServerSourceID: String?
    /// User state returned by the owning media server. Local overrides remain
    /// authoritative after the user changes either value in RovePlayer.
    var mediaServerFavorite: Bool?
    var mediaServerPlayed: Bool?

    var isJellyfinItem: Bool {
        if case .legacyLibraryA = resolver { return true }
        return false
    }

    var isMovieClawItem: Bool {
        if case .movieClaw = resolver { return true }
        return false
    }

    var isEmbyItem: Bool {
        if case .legacyLibraryB = resolver { return true }
        return false
    }

    var isFeiniuVideoItem: Bool {
        if case .legacyLibraryC = resolver { return true }
        return false
    }

    var isPlexItem: Bool {
        if case .legacyLibraryD = resolver { return true }
        return false
    }

    var isMediaServerItem: Bool {
        isJellyfinItem || isMovieClawItem || isEmbyItem || isFeiniuVideoItem || isPlexItem
    }
    var isMediaServerSeries: Bool {
        guard let rawType = mediaServerItemType?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawType.isEmpty else { return false }
        // Feiniu has returned both the canonical "Series" value and the
        // legacy TV/container aliases. Treat all of them as a browseable
        // series so cached entries do not jump straight into playback.
        switch rawType.lowercased() {
        case "series", "season", "tv", "tvshow", "show", "directory", "folder":
            return true
        default:
            return false
        }
    }
    var isMediaServerEpisode: Bool {
        if mediaServerItemType?.caseInsensitiveCompare("Episode") == .orderedSame {
            return true
        }
        // Feiniu's item/list endpoint can label an episode as `Video` while
        // still returning its parent GUID. Reuse that relationship so the
        // shared detail page opens the parent series instead of exposing the
        // raw filename as a movie title.
        guard isFeiniuVideoItem,
              !isMediaServerSeries,
              let parentID = mediaServerSeriesID,
              !parentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let rawType = mediaServerItemType?.lowercased() ?? ""
        return rawType == "video" || rawType == "file" || rawType.isEmpty
    }

    var mediaServerTitle: String? {
        if isJellyfinItem { return "Jellyfin" }
        if isMovieClawItem { return "MovieClaw" }
        if isEmbyItem { return "Emby" }
        if isFeiniuVideoItem { return AppLanguage.localized("旧版资料库") }
        if isPlexItem { return "Plex" }
        return nil
    }

    var isExplicitlyOnDemand: Bool {
        playbackKind == .onDemand || isMediaServerItem || streamURL.isFileURL
    }

    init(
        id: UUID = UUID(),
        name: String,
        streamURL: URL,
        group: String = "未分组",
        logoURL: URL? = nil,
        tvgID: String? = nil,
        tvgName: String? = nil,
        httpHeaders: [String: String] = [:],
        clearKey: ClearKeyConfiguration? = nil,
        resolver: StreamResolver? = nil,
        preparedFromURL: URL? = nil,
        fusionVideoURL: URL? = nil,
        fusionAudioURL: URL? = nil,
        audioDelayMilliseconds: Int? = nil,
        videoDelayMilliseconds: Int? = nil,
        catchup: CatchupConfiguration? = nil,
        proxyOverride: StreamProxyConfiguration? = nil,
        hlsProxyMode: HLSProxyMode = .off,
        hlsProxySessionID: String? = nil,
        rtspTransport: RTSPTransportPreference? = nil,
        rtspRedirectDetectionEnabled: Bool? = nil,
        bufferPolicy: PlaybackBufferPolicy? = nil,
        playbackKind: ChannelPlaybackKind? = nil,
        productionYear: Int? = nil,
        communityRating: Double? = nil,
        criticRating: Double? = nil,
        officialRating: String? = nil,
        dateAdded: String? = nil,
        releaseDate: String? = nil,
        playCount: Int? = nil,
        lastPlayedDate: String? = nil,
        runtimeSeconds: TimeInterval? = nil,
        fileSize: Int64? = nil,
        container: String? = nil,
        mediaServerItemType: String? = nil,
        mediaServerSeriesID: String? = nil,
        mediaServerSourceID: String? = nil,
        mediaServerFavorite: Bool? = nil,
        mediaServerPlayed: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.group = group.isEmpty ? "未分组" : group
        self.logoURL = logoURL
        self.tvgID = tvgID
        self.tvgName = tvgName
        self.httpHeaders = httpHeaders
        self.clearKey = clearKey
        self.resolver = resolver
        self.preparedFromURL = preparedFromURL
        self.fusionVideoURL = fusionVideoURL
        self.fusionAudioURL = fusionAudioURL
        self.audioDelayMilliseconds = audioDelayMilliseconds
        self.videoDelayMilliseconds = videoDelayMilliseconds
        self.catchup = catchup
        self.proxyOverride = proxyOverride
        self.hlsProxyMode = hlsProxyMode
        self.hlsProxySessionID = hlsProxySessionID
        self.rtspTransport = rtspTransport
        self.rtspRedirectDetectionEnabled = rtspRedirectDetectionEnabled
        self.bufferPolicy = bufferPolicy
        self.playbackKind = playbackKind
        self.productionYear = productionYear
        self.communityRating = communityRating
        self.criticRating = criticRating
        self.officialRating = officialRating
        self.dateAdded = dateAdded
        self.releaseDate = releaseDate
        self.playCount = playCount
        self.lastPlayedDate = lastPlayedDate
        self.runtimeSeconds = runtimeSeconds
        self.fileSize = fileSize
        self.container = container
        self.mediaServerItemType = mediaServerItemType
        self.mediaServerSeriesID = mediaServerSeriesID
        self.mediaServerSourceID = mediaServerSourceID
        self.mediaServerFavorite = mediaServerFavorite
        self.mediaServerPlayed = mediaServerPlayed
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, streamURL, group, logoURL, tvgID, tvgName, httpHeaders, clearKey, resolver
        case fusionVideoURL, fusionAudioURL, audioDelayMilliseconds, videoDelayMilliseconds
        case catchup, proxyOverride, hlsProxyMode, rtspTransport, rtspRedirectDetectionEnabled, bufferPolicy
        case playbackKind, productionYear, communityRating, criticRating, officialRating
        case dateAdded, releaseDate, playCount, lastPlayedDate, runtimeSeconds, fileSize, container
        case mediaServerItemType, mediaServerSeriesID, mediaServerSourceID
        case mediaServerFavorite, mediaServerPlayed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        streamURL = try container.decode(URL.self, forKey: .streamURL)
        group = try container.decodeIfPresent(String.self, forKey: .group) ?? "未分组"
        logoURL = try container.decodeIfPresent(URL.self, forKey: .logoURL)
        tvgID = try container.decodeIfPresent(String.self, forKey: .tvgID)
        tvgName = try container.decodeIfPresent(String.self, forKey: .tvgName)
        httpHeaders = try container.decodeIfPresent([String: String].self, forKey: .httpHeaders) ?? [:]
        clearKey = try container.decodeIfPresent(ClearKeyConfiguration.self, forKey: .clearKey)
        resolver = try container.decodeIfPresent(StreamResolver.self, forKey: .resolver)
        preparedFromURL = nil
        fusionVideoURL = try container.decodeIfPresent(URL.self, forKey: .fusionVideoURL)
        fusionAudioURL = try container.decodeIfPresent(URL.self, forKey: .fusionAudioURL)
        audioDelayMilliseconds = try container.decodeIfPresent(Int.self, forKey: .audioDelayMilliseconds)
        videoDelayMilliseconds = try container.decodeIfPresent(Int.self, forKey: .videoDelayMilliseconds)
        catchup = try container.decodeIfPresent(CatchupConfiguration.self, forKey: .catchup)
        proxyOverride = try container.decodeIfPresent(StreamProxyConfiguration.self, forKey: .proxyOverride)
        hlsProxyMode = try container.decodeIfPresent(HLSProxyMode.self, forKey: .hlsProxyMode) ?? .off
        hlsProxySessionID = nil
        rtspTransport = try container.decodeIfPresent(RTSPTransportPreference.self, forKey: .rtspTransport)
        rtspRedirectDetectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .rtspRedirectDetectionEnabled)
        bufferPolicy = try container.decodeIfPresent(PlaybackBufferPolicy.self, forKey: .bufferPolicy)
        playbackKind = try container.decodeIfPresent(ChannelPlaybackKind.self, forKey: .playbackKind)
        productionYear = try container.decodeIfPresent(Int.self, forKey: .productionYear)
        communityRating = try container.decodeIfPresent(Double.self, forKey: .communityRating)
        criticRating = try container.decodeIfPresent(Double.self, forKey: .criticRating)
        officialRating = try container.decodeIfPresent(String.self, forKey: .officialRating)
        dateAdded = try container.decodeIfPresent(String.self, forKey: .dateAdded)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount)
        lastPlayedDate = try container.decodeIfPresent(String.self, forKey: .lastPlayedDate)
        runtimeSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .runtimeSeconds)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        self.container = try container.decodeIfPresent(String.self, forKey: .container)
        mediaServerItemType = try container.decodeIfPresent(String.self, forKey: .mediaServerItemType)
        mediaServerSeriesID = try container.decodeIfPresent(String.self, forKey: .mediaServerSeriesID)
        mediaServerSourceID = try container.decodeIfPresent(String.self, forKey: .mediaServerSourceID)
        mediaServerFavorite = try container.decodeIfPresent(Bool.self, forKey: .mediaServerFavorite)
        mediaServerPlayed = try container.decodeIfPresent(Bool.self, forKey: .mediaServerPlayed)
    }
}

enum M3UPlaylistExporter {
    nonisolated static func snapshot(for channels: [Channel]) -> String {
        var lines = ["#EXTM3U"]
        lines.reserveCapacity(channels.count * 2 + 1)
        for channel in channels {
            let name = channel.name.replacingOccurrences(of: "\n", with: " ")
            let group = channel.group.replacingOccurrences(of: "\"", with: "'")
            let logo = channel.logoURL?.absoluteString
                .replacingOccurrences(of: "\"", with: "%22") ?? ""
            let tvgID = channel.tvgID?
                .replacingOccurrences(of: "\"", with: "'") ?? ""
            let tvgName = channel.tvgName?
                .replacingOccurrences(of: "\"", with: "'") ?? ""
            lines.append(
                "#EXTINF:-1 tvg-id=\"\(tvgID)\" tvg-name=\"\(tvgName)\" "
                    + "tvg-logo=\"\(logo)\" group-title=\"\(group)\",\(name)"
            )
            lines.append(channel.streamURL.absoluteString)
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

enum PlaylistConfigurationKind: String, Codable, CaseIterable, Sendable {
    case subscription
    case rss
    case single
    case local
    case aggregate
    case legacySourceB
    case legacySourceA
    case legacyLibraryA
    case movieClaw
    case legacyLibraryB
    case zspaceVideo
    case legacyLibraryC
    case legacyLibraryD
    case legacySourceC

    var title: String {
        switch self {
        case .subscription: AppLanguage.localized("订阅配置")
        case .rss: AppLanguage.localized("RSS 视频订阅")
        case .single: AppLanguage.localized("单频道")
        case .local: AppLanguage.localized("本地配置")
        case .aggregate: AppLanguage.localized("聚合配置")
        case .legacySourceB: "Xtream Codes"
        case .legacySourceA: "Stalker Portal"
        case .legacyLibraryA: "Jellyfin"
        case .movieClaw: "MovieClaw"
        case .legacyLibraryB: "Emby"
        case .zspaceVideo: AppLanguage.localized("极影视")
        case .legacyLibraryC: AppLanguage.localized("旧版资料库")
        case .legacyLibraryD: "Plex"
        case .legacySourceC: "WebDAV"
        }
    }

    var systemImage: String {
        switch self {
        case .subscription: "link"
        case .rss: "dot.radiowaves.left.and.right"
        case .single: "play.rectangle.fill"
        case .local: "doc"
        case .aggregate: "square.stack.3d.up.fill"
        case .legacySourceB: "server.rack"
        case .legacySourceA: "network"
        case .legacyLibraryA: "play.rectangle.on.rectangle.fill"
        case .movieClaw: "movieclapper.fill"
        case .legacyLibraryB: "play.square.stack.fill"
        case .zspaceVideo: "externaldrive.fill"
        case .legacyLibraryC: "film.stack.fill"
        case .legacyLibraryD: "chevron.right.square.fill"
        case .legacySourceC: "externaldrive.connected.to.line.below"
        }
    }

    var brandImage: String? {
        switch self {
        case .legacyLibraryA: "JellyfinLogo"
        case .movieClaw: "MovieClawLogo"
        case .legacyLibraryB: "EmbyLogo"
        case .zspaceVideo: "ZSpaceLogo"
        case .legacyLibraryC: "FeiniuVideoLogo"
        case .legacyLibraryD: nil
        default: nil
        }
    }

    var usesMediaLibraryBrowser: Bool {
        isJellyfinCompatible || isEmbyCompatible || self == .legacyLibraryC || self == .legacyLibraryD
    }

    var isJellyfinCompatible: Bool {
        self == .legacyLibraryA || self == .movieClaw
    }

    /// 极影视 exposes the same media API as Emby but keeps a distinct source
    /// identity so its branding and default connection settings are preserved.
    var isEmbyCompatible: Bool {
        self == .legacyLibraryB || self == .zspaceVideo
    }

    /// CarPlay search currently shares the Emby flow and the handset input
    /// sheet. Keep the capability explicit so adding it for Feiniu does not
    /// silently change Jellyfin's existing navigation surface.
    var supportsCarPlayMediaSearch: Bool {
        isEmbyCompatible || self == .legacyLibraryC || self == .legacyLibraryD
    }

    var usesWebDAVBrowser: Bool {
        self == .legacySourceC
    }
}

enum LegacyListStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic
    case shelves

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: AppLanguage.localized("经典列表")
        case .shelves: AppLanguage.localized("媒体分区")
        }
    }
}

struct RoveServerIconSelection: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case preset
        case remote
        case local
    }

    var kind: Kind
    var value: String?
}

enum RoveServerPreloadPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case inherit
    case off
    case memory
    case disk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inherit: "跟随全局"
        case .off: "关闭"
        case .memory: "内存"
        case .disk: "磁盘"
        }
    }
}

struct RoveLibraryNotificationPreferences: Codable, Hashable, Sendable {
    var movies = false
    var series = false
    var episodes = false

    var isEnabled: Bool { movies || series || episodes }
}

struct PlaylistConfiguration: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var kind: PlaylistConfigurationKind
    var channels: [Channel]
    /// Complete item count reported by a paged media server. `channels` may
    /// intentionally contain only the first page.
    var totalItemCount: Int? = nil
    var sourceAddress: String?
    var username: String?
    var mediaServerUserID: String? = nil
    /// 仅用于表单传递；持久化时写入可同步钥匙串，不进入配置 JSON/iCloud 文件。
    var password: String? = nil
    var macAddress: String?
    var memberIDs: [UUID]
    var epgURLs: [URL]
    var updatedAt: Date
    /// Configurations imported from an approved web deep link are intentionally
    /// read-only in the app. Optional keeps older saved/iCloud configurations
    /// decodable without a migration.
    var isWebImportProtected: Bool? = nil
    /// Optional expiry carried by a `tubo://import` link. Keeping it optional
    /// preserves decoding compatibility with configurations saved by older builds.
    var expirationDate: Date? = nil
    var requestHeaders: [String: String] = [:]
    var proxy: StreamProxyConfiguration? = nil
    var hlsProxyMode: HLSProxyMode = .off
    var rtspTransport: RTSPTransportPreference? = nil
    var rtspRedirectDetectionEnabled: Bool? = nil
    var bufferPolicy: PlaybackBufferPolicy? = nil
    /// Subscription-only background refresh settings. Optional dates keep
    /// older saved configurations backward compatible.
    var automaticRefreshEnabled: Bool = false
    var automaticRefreshInterval: TimeInterval = 8 * 60 * 60
    var lastAutomaticRefreshAt: Date? = nil
    /// Category names hidden by the user for this source. Channels remain in
    /// the saved configuration so a refresh or a later restore is lossless.
    var hiddenChannelGroups: Set<String> = []
    /// Per-source CarPlay presentation. Older configurations decode as the
    /// existing classic grid so adding the alternative style is non-breaking.
    var legacyListStyle: LegacyListStyle = .classic
    /// Alternate endpoints for a media server. The active endpoint remains in
    /// `sourceAddress`; this list lets the user switch routes without retyping.
    var serverRoutes: [String] = []
    /// Optional display names for alternate endpoints. The address remains the
    /// stable key so older configurations and routes without a label continue
    /// to work unchanged.
    var serverRouteNames: [String: String] = [:]
    /// Privacy mode hides server statistics in the source grid while keeping
    /// the connection available to the media library.
    var isPrivateServer: Bool = false
    /// Per-server presentation and playback preferences. Optional/defaulted
    /// fields keep configurations written by older builds decodable.
    var serverIcon: RoveServerIconSelection? = nil
    var serverRemark: String? = nil
    /// Name reported by Emby/Jellyfin from System/Info/Public. This remains
    /// separate from the user's optional card remark.
    var serverReportedName: String? = nil
    /// Ask an Emby-compatible server extension for its published alternate
    /// domains before probing or playing. Older configurations default off.
    var automaticallyFetchBackupRoutes = false
    var automaticallySelectBestServerRoute = false
    var preloadPreference: RoveServerPreloadPreference = .inherit
    var libraryNotifications = RoveLibraryNotificationPreferences()

    var isExpired: Bool {
        expirationDate.map { Date() >= $0 } ?? false
    }

    var expirationStatusText: String? {
        if isWebImportProtected == true, expirationDate == nil {
            return AppLanguage.localized("永久有效")
        }
        guard let expirationDate else { return nil }
        let value = Self.expirationDateText(expirationDate)
        return isExpired
            ? AppLanguage.localizedFormat("源已到期 · %@", value)
            : AppLanguage.localizedFormat("有效期至 %@", value)
    }

    static func expirationDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = AppLanguage.current.locale
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, channels, totalItemCount, sourceAddress, username, mediaServerUserID, macAddress
        case memberIDs, epgURLs, updatedAt, isWebImportProtected, expirationDate
        case requestHeaders, proxy, hlsProxyMode, rtspTransport, rtspRedirectDetectionEnabled, bufferPolicy
        case automaticRefreshEnabled, automaticRefreshInterval, lastAutomaticRefreshAt
        case hiddenChannelGroups, legacyListStyle, serverRoutes, serverRouteNames, isPrivateServer
        case serverIcon, serverRemark, serverReportedName, automaticallyFetchBackupRoutes, automaticallySelectBestServerRoute, preloadPreference, libraryNotifications
    }

    init(
        id: UUID = UUID(),
        name: String,
        kind: PlaylistConfigurationKind,
        channels: [Channel] = [],
        totalItemCount: Int? = nil,
        sourceAddress: String? = nil,
        username: String? = nil,
        mediaServerUserID: String? = nil,
        password: String? = nil,
        macAddress: String? = nil,
        memberIDs: [UUID] = [],
        epgURLs: [URL] = [],
        updatedAt: Date = Date(),
        isWebImportProtected: Bool = false,
        expirationDate: Date? = nil,
        requestHeaders: [String: String] = [:],
        proxy: StreamProxyConfiguration? = nil,
        hlsProxyMode: HLSProxyMode = .off,
        rtspTransport: RTSPTransportPreference? = nil,
        rtspRedirectDetectionEnabled: Bool? = nil,
        bufferPolicy: PlaybackBufferPolicy? = nil,
        automaticRefreshEnabled: Bool = false,
        automaticRefreshInterval: TimeInterval = 8 * 60 * 60,
        lastAutomaticRefreshAt: Date? = nil,
        hiddenChannelGroups: Set<String> = [],
        legacyListStyle: LegacyListStyle = .classic,
        serverRoutes: [String] = [],
        serverRouteNames: [String: String] = [:],
        isPrivateServer: Bool = false,
        serverIcon: RoveServerIconSelection? = nil,
        serverRemark: String? = nil,
        serverReportedName: String? = nil,
        automaticallyFetchBackupRoutes: Bool = false,
        automaticallySelectBestServerRoute: Bool = false,
        preloadPreference: RoveServerPreloadPreference = .inherit,
        libraryNotifications: RoveLibraryNotificationPreferences = .init()
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.channels = channels
        self.totalItemCount = totalItemCount
        self.sourceAddress = sourceAddress
        self.username = username
        self.mediaServerUserID = mediaServerUserID
        self.password = password
        self.macAddress = macAddress
        self.memberIDs = memberIDs
        self.epgURLs = epgURLs
        self.updatedAt = updatedAt
        self.isWebImportProtected = isWebImportProtected ? true : nil
        self.expirationDate = expirationDate
        self.requestHeaders = requestHeaders
        self.proxy = proxy
        self.hlsProxyMode = hlsProxyMode
        self.rtspTransport = rtspTransport
        self.rtspRedirectDetectionEnabled = rtspRedirectDetectionEnabled
        self.bufferPolicy = bufferPolicy
        self.automaticRefreshEnabled = automaticRefreshEnabled
        self.automaticRefreshInterval = max(15 * 60, automaticRefreshInterval)
        self.lastAutomaticRefreshAt = lastAutomaticRefreshAt
        self.hiddenChannelGroups = Set(
            hiddenChannelGroups
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        self.legacyListStyle = legacyListStyle
        self.serverRoutes = serverRoutes
        self.serverRouteNames = serverRouteNames
        self.isPrivateServer = isPrivateServer
        self.serverIcon = serverIcon
        self.serverRemark = serverRemark
        self.serverReportedName = serverReportedName
        self.automaticallyFetchBackupRoutes = automaticallyFetchBackupRoutes
        self.automaticallySelectBestServerRoute = automaticallySelectBestServerRoute
        self.preloadPreference = preloadPreference
        self.libraryNotifications = libraryNotifications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(PlaylistConfigurationKind.self, forKey: .kind)
        channels = try container.decodeIfPresent([Channel].self, forKey: .channels) ?? []
        totalItemCount = try container.decodeIfPresent(Int.self, forKey: .totalItemCount)
        sourceAddress = try container.decodeIfPresent(String.self, forKey: .sourceAddress)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        mediaServerUserID = try container.decodeIfPresent(String.self, forKey: .mediaServerUserID)
        password = nil
        macAddress = try container.decodeIfPresent(String.self, forKey: .macAddress)
        memberIDs = try container.decodeIfPresent([UUID].self, forKey: .memberIDs) ?? []
        epgURLs = try container.decodeIfPresent([URL].self, forKey: .epgURLs) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        isWebImportProtected = try container.decodeIfPresent(Bool.self, forKey: .isWebImportProtected)
        expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
        requestHeaders = try container.decodeIfPresent([String: String].self, forKey: .requestHeaders) ?? [:]
        proxy = try container.decodeIfPresent(StreamProxyConfiguration.self, forKey: .proxy)
        hlsProxyMode = try container.decodeIfPresent(HLSProxyMode.self, forKey: .hlsProxyMode) ?? .off
        rtspTransport = try container.decodeIfPresent(RTSPTransportPreference.self, forKey: .rtspTransport)
        rtspRedirectDetectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .rtspRedirectDetectionEnabled)
        bufferPolicy = try container.decodeIfPresent(PlaybackBufferPolicy.self, forKey: .bufferPolicy)
        automaticRefreshEnabled = try container.decodeIfPresent(Bool.self, forKey: .automaticRefreshEnabled) ?? false
        automaticRefreshInterval = max(
            15 * 60,
            try container.decodeIfPresent(TimeInterval.self, forKey: .automaticRefreshInterval)
                ?? (8 * 60 * 60)
        )
        lastAutomaticRefreshAt = try container.decodeIfPresent(Date.self, forKey: .lastAutomaticRefreshAt)
        hiddenChannelGroups = Set(
            (try container.decodeIfPresent(Set<String>.self, forKey: .hiddenChannelGroups) ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        legacyListStyle = try container.decodeIfPresent(
            LegacyListStyle.self,
            forKey: .legacyListStyle
        ) ?? .classic
        serverRoutes = try container.decodeIfPresent([String].self, forKey: .serverRoutes) ?? []
        serverRouteNames = try container.decodeIfPresent([String: String].self, forKey: .serverRouteNames) ?? [:]
        isPrivateServer = try container.decodeIfPresent(Bool.self, forKey: .isPrivateServer) ?? false
        serverIcon = try container.decodeIfPresent(RoveServerIconSelection.self, forKey: .serverIcon)
        serverRemark = try container.decodeIfPresent(String.self, forKey: .serverRemark)
        serverReportedName = try container.decodeIfPresent(String.self, forKey: .serverReportedName)
        automaticallyFetchBackupRoutes = try container.decodeIfPresent(
            Bool.self,
            forKey: .automaticallyFetchBackupRoutes
        ) ?? false
        automaticallySelectBestServerRoute = try container.decodeIfPresent(
            Bool.self,
            forKey: .automaticallySelectBestServerRoute
        ) ?? false
        preloadPreference = try container.decodeIfPresent(
            RoveServerPreloadPreference.self,
            forKey: .preloadPreference
        ) ?? .inherit
        libraryNotifications = try container.decodeIfPresent(
            RoveLibraryNotificationPreferences.self,
            forKey: .libraryNotifications
        ) ?? .init()
    }
}
