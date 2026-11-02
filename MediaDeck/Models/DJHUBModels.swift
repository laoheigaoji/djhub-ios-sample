import Foundation

struct APIEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: Value
}

struct DramaListResponse: Decodable, Sendable {
    let data: [Drama]
    let meta: PageMetadata
}

struct DJHUBPagedResponse<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: [Value]
    let meta: PageMetadata
}

struct PageMetadata: Decodable, Sendable {
    let total: Int
    let page: Int
    let limit: Int
    let pages: Int
    let license: String?
}

struct Drama: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let originalTitle: String
    let year: String
    let releaseDate: String
    let status: String
    let score: Double
    let ratingCount: Int
    let popularity: Double
    let episodes: Int
    let publishedEpisodes: Int
    let minutes: Int
    let contentType: String
    let contentTypeLabel: String
    let genres: [String]
    let keywords: [String]
    let tagline: String
    let overview: String
    let platform: String
    let poster: String
    let cover: String
    let crew: [CrewMember]
    let source: DramaSource?
    let credits: DramaCredits?
    let images: DramaImages?
    let recommendations: [Drama]
    let badges: [DJHUBBadge]
    let companies: [DJHUBCompany]

    var bestArtworkURL: URL? {
        URL(string: images?.backdrop?.nonEmpty ?? cover.nonEmpty ?? images?.poster?.nonEmpty ?? poster)
    }

    var posterURL: URL? {
        URL(string: images?.poster?.nonEmpty ?? poster.nonEmpty ?? cover)
    }

    var displayYear: String {
        if !year.isEmpty { return year }
        return String(releaseDate.prefix(4))
    }

    var displayScore: String {
        score > 0 ? String(format: "%.1f", score) : "--"
    }

    var displayMetadata: String {
        [displayYear, episodes > 0 ? "\(episodes) 集" : "", contentTypeLabel, genres.first ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名短剧"
        originalTitle = try container.decodeIfPresent(String.self, forKey: .originalTitle) ?? ""
        year = container.decodeFlexibleOptionalString(forKey: .year) ?? ""
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        score = container.decodeFlexibleDouble(forKey: .score)
        ratingCount = container.decodeFlexibleInt(forKey: .ratingCount)
        popularity = container.decodeFlexibleDouble(forKey: .popularity)
        episodes = container.decodeFlexibleInt(forKey: .episodes)
        publishedEpisodes = container.decodeFlexibleInt(forKey: .publishedEpisodes)
        minutes = container.decodeFlexibleInt(forKey: .minutes)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType) ?? ""
        contentTypeLabel = try container.decodeIfPresent(String.self, forKey: .contentTypeLabel) ?? "短剧"
        genres = try container.decodeIfPresent([String].self, forKey: .genres) ?? []
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        tagline = try container.decodeIfPresent(String.self, forKey: .tagline) ?? ""
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? ""
        poster = try container.decodeIfPresent(String.self, forKey: .poster) ?? ""
        cover = try container.decodeIfPresent(String.self, forKey: .cover) ?? ""
        crew = try container.decodeIfPresent([CrewMember].self, forKey: .crew) ?? []
        source = try container.decodeIfPresent(DramaSource.self, forKey: .source)
        credits = try container.decodeIfPresent(DramaCredits.self, forKey: .credits)
        images = try container.decodeIfPresent(DramaImages.self, forKey: .images)
        recommendations = try container.decodeIfPresent([Drama].self, forKey: .recommendations) ?? []
        badges = try container.decodeIfPresent([DJHUBBadge].self, forKey: .badges) ?? []
        companies = try container.decodeIfPresent([DJHUBCompany].self, forKey: .companies) ?? []
    }

    init(id: String, title: String, originalTitle: String = "", year: String = "", releaseDate: String = "", status: String = "", score: Double = 0, ratingCount: Int = 0, popularity: Double = 0, episodes: Int = 0, publishedEpisodes: Int = 0, minutes: Int = 0, contentType: String = "", contentTypeLabel: String = "短剧", genres: [String] = [], keywords: [String] = [], tagline: String = "", overview: String = "", platform: String = "", poster: String = "", cover: String = "", crew: [CrewMember] = [], source: DramaSource? = nil, credits: DramaCredits? = nil, images: DramaImages? = nil, recommendations: [Drama] = [], badges: [DJHUBBadge] = [], companies: [DJHUBCompany] = []) {
        self.id = id
        self.title = title
        self.originalTitle = originalTitle
        self.year = year
        self.releaseDate = releaseDate
        self.status = status
        self.score = score
        self.ratingCount = ratingCount
        self.popularity = popularity
        self.episodes = episodes
        self.publishedEpisodes = publishedEpisodes
        self.minutes = minutes
        self.contentType = contentType
        self.contentTypeLabel = contentTypeLabel
        self.genres = genres
        self.keywords = keywords
        self.tagline = tagline
        self.overview = overview
        self.platform = platform
        self.poster = poster
        self.cover = cover
        self.crew = crew
        self.source = source
        self.credits = credits
        self.images = images
        self.recommendations = recommendations
        self.badges = badges
        self.companies = companies
    }
}

struct DJHUBPerson: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let avatar: String
    let biography: String
    let knownForDepartment: String
    let popularity: Double
    let works: [Drama]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未知演员"
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar) ?? ""
        biography = try container.decodeIfPresent(String.self, forKey: .biography) ?? ""
        knownForDepartment = try container.decodeIfPresent(String.self, forKey: .knownForDepartment) ?? "Acting"
        popularity = container.decodeFlexibleDouble(forKey: .popularity)
        works = try container.decodeIfPresent([Drama].self, forKey: .works) ?? []
    }
}

struct DJHUBCompany: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let logo: String
    let description: String
    let country: String
    let homepage: String
    let role: String
    let workCount: Int
    let works: [Drama]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未知出品商"
        logo = try container.decodeIfPresent(String.self, forKey: .logo) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        country = try container.decodeIfPresent(String.self, forKey: .country) ?? ""
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage) ?? ""
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "producer"
        workCount = container.decodeFlexibleInt(forKey: .workCount)
        works = try container.decodeIfPresent([Drama].self, forKey: .works) ?? []
    }
}

struct DJHUBBadge: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let groupID: String
    let name: String
    let imageURL: String

    private enum CodingKeys: String, CodingKey {
        case id, name
        case groupID = "groupId"
        case imageURL = "imageUrl"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        groupID = try container.decodeIfPresent(String.self, forKey: .groupID) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "短剧"
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL) ?? ""
    }
}

struct CrewMember: Codable, Hashable, Sendable {
    let name: String
    let role: String
}

struct DramaSource: Codable, Hashable, Sendable {
    let id: String?
    let name: String?
    let url: String?
    let collectedAt: String?
}

struct DramaCredits: Codable, Hashable, Sendable {
    let cast: [Credit]
    let crew: [Credit]
}

struct Credit: Codable, Identifiable, Hashable, Sendable {
    let id: String?
    let name: String
    let avatar: String?
    let characterName: String?
    let department: String?
    let job: String?

    var stableID: String { id ?? "\(name)-\(characterName ?? job ?? "")" }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleOptionalString(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未知演员"
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        characterName = try container.decodeIfPresent(String.self, forKey: .characterName)
        department = try container.decodeIfPresent(String.self, forKey: .department)
        job = try container.decodeIfPresent(String.self, forKey: .job)
    }

    var identifiableID: String { stableID }
}

extension Credit {
    var idValue: String { stableID }
}

struct DramaImages: Codable, Hashable, Sendable {
    let poster: String?
    let backdrop: String?
    let posters: [MediaItem]
    let backdrops: [MediaItem]
    let stills: [MediaItem]
    let logos: [MediaItem]
}

struct MediaItem: Codable, Identifiable, Hashable, Sendable {
    let id: String?
    let url: String
    let thumbnailUrl: String?
    let title: String?
    let width: Int?
    let height: Int?

    var stableID: String { id ?? url }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleOptionalString(forKey: .id)
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        width = container.decodeFlexibleOptionalInt(forKey: .width)
        height = container.decodeFlexibleOptionalInt(forKey: .height)
    }
}

struct TaxonomyResponse: Decodable, Sendable {
    let contentTypes: [TaxonomyItem]
    let genres: [TaxonomyItem]

    init(contentTypes: [TaxonomyItem], genres: [TaxonomyItem]) {
        self.contentTypes = contentTypes
        self.genres = genres
    }
}

struct TaxonomyItem: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String?
    let name: String
    let categoryGroup: String?
    let sortOrder: Int?

    private enum CodingKeys: String, CodingKey {
        case id, slug, name, categoryGroup, sortOrder
    }

    init(
        id: String,
        slug: String? = nil,
        name: String,
        categoryGroup: String? = nil,
        sortOrder: Int? = nil
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.categoryGroup = categoryGroup
        self.sortOrder = sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        name = try container.decode(String.self, forKey: .name)
        categoryGroup = try container.decodeIfPresent(String.self, forKey: .categoryGroup)
        sortOrder = container.decodeFlexibleOptionalInt(forKey: .sortOrder)
    }
}

struct APIQuota: Equatable, Sendable {
    let plan: String
    let limit: String
    let remaining: String
    let reset: String
}

struct PeopleResponse: Decodable, Sendable {
    let page: Int
    let results: [Person]
}

struct Person: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let profilePath: String?
    let knownForDepartment: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
    }

    var avatarURL: URL? {
        guard let profilePath, !profilePath.isEmpty else { return nil }
        if profilePath.hasPrefix("http") { return URL(string: profilePath) }
        return URL(string: "https://themdjhub.org/t/p/w185\(profilePath.hasPrefix("/") ? profilePath : "/\(profilePath)")")
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        throw DecodingError.valueNotFound(String.self, .init(codingPath: codingPath + [key], debugDescription: "Expected a string-compatible value"))
    }

    func decodeFlexibleOptionalString(forKey key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) -> Int {
        decodeFlexibleOptionalInt(forKey: key) ?? 0
    }

    func decodeFlexibleOptionalInt(forKey key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key) { return Int(value) }
        if let value = try? decode(String.self, forKey: key) { return Int(value) }
        return nil
    }

    func decodeFlexibleDouble(forKey key: Key) -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? decode(String.self, forKey: key) { return Double(value) ?? 0 }
        return 0
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
