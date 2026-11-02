import Foundation

enum DJHUBError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidAPIKey
    case quotaExceeded(reset: String?)
    case notFound
    case server(status: Int)
    case invalidResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "请先在设置中填写 DJHUB API Key。"
        case .invalidAPIKey: return "API Key 无效或尚未获批。"
        case .quotaExceeded(let reset):
            return reset.map { "今日 API 额度已用完，将于 \($0) 重置。" } ?? "今日 API 额度已用完。"
        case .notFound: return "DJHUB 中没有找到这条短剧资料。"
        case .server(let status): return "DJHUB 服务暂时不可用（HTTP \(status)）。"
        case .invalidResponse: return "DJHUB 返回了无法识别的数据。"
        case .transport(let message): return "网络请求失败：\(message)"
        }
    }
}

struct APIValue<Value: Sendable>: Sendable {
    let value: Value
    let quota: APIQuota
}

final class DJHUBAPIClient: Sendable {
    static let baseURL = URL(string: "https://themdjhub.org")!

    private let session: URLSession
    private let keyProvider: @Sendable () -> String?

    init(session: URLSession = .shared, keyProvider: @escaping @Sendable () -> String?) {
        self.session = session
        self.keyProvider = keyProvider
    }

    func dramas(sort: String = "popular", limit: Int = 20, page: Int = 1, genre: String? = nil, contentType: String? = nil, query: String? = nil) async throws -> APIValue<DramaListResponse> {
        var items = [
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "limit", value: String(min(max(limit, 1), 200))),
            URLQueryItem(name: "page", value: String(max(page, 1)))
        ]
        if let genre, !genre.isEmpty { items.append(.init(name: "genre", value: genre)) }
        if let contentType, !contentType.isEmpty { items.append(.init(name: "content_type", value: contentType)) }
        if let query, !query.isEmpty { items.append(.init(name: "q", value: query)) }
        return try await request(path: "/openapi/v1/dramas", queryItems: items, as: DramaListResponse.self)
    }

    func drama(id: String) async throws -> APIValue<Drama> {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let result = try await request(path: "/openapi/v1/dramas/\(encoded)", as: APIEnvelope<Drama>.self)
        return APIValue(value: result.value.data, quota: result.quota)
    }

    func taxonomy() async throws -> APIValue<TaxonomyResponse> {
        let result = try await request(path: "/openapi/v1/metadata/categories", as: APIEnvelope<TaxonomyResponse>.self)
        return APIValue(value: result.value.data, quota: result.quota)
    }

    func popularPeople(page: Int = 1) async throws -> APIValue<PeopleResponse> {
        try await request(path: "/3/person/popular", queryItems: [.init(name: "page", value: String(max(page, 1)))], as: PeopleResponse.self)
    }

    func people(limit: Int = 20, page: Int = 1) async throws -> APIValue<DJHUBPagedResponse<DJHUBPerson>> {
        try await request(
            path: "/api/v1/people",
            queryItems: [
                .init(name: "limit", value: String(min(max(limit, 1), 100))),
                .init(name: "page", value: String(max(page, 1)))
            ],
            as: DJHUBPagedResponse<DJHUBPerson>.self
        )
    }

    func person(id: String) async throws -> APIValue<DJHUBPerson> {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let result = try await request(path: "/api/v1/people/\(encoded)", as: APIEnvelope<DJHUBPerson>.self)
        return APIValue(value: result.value.data, quota: result.quota)
    }

    func companies(limit: Int = 8, page: Int = 1) async throws -> APIValue<DJHUBPagedResponse<DJHUBCompany>> {
        try await request(
            path: "/api/v1/companies",
            queryItems: [
                .init(name: "limit", value: String(min(max(limit, 1), 100))),
                .init(name: "page", value: String(max(page, 1)))
            ],
            as: DJHUBPagedResponse<DJHUBCompany>.self
        )
    }

    func company(id: String) async throws -> APIValue<DJHUBCompany> {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let result = try await request(path: "/api/v1/companies/\(encoded)", as: APIEnvelope<DJHUBCompany>.self)
        return APIValue(value: result.value.data, quota: result.quota)
    }

    private func request<Value: Decodable & Sendable>(path: String, queryItems: [URLQueryItem] = [], as type: Value.Type) async throws -> APIValue<Value> {
        guard let key = keyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw DJHUBError.missingAPIKey
        }
        var components = URLComponents(url: Self.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw DJHUBError.invalidResponse }
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30)
        request.setValue(key, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw DJHUBError.invalidResponse }
            let quota = APIQuota(
                plan: http.value(forHTTPHeaderField: "x-mdj-plan") ?? "--",
                limit: http.value(forHTTPHeaderField: "x-ratelimit-limit") ?? "--",
                remaining: http.value(forHTTPHeaderField: "x-ratelimit-remaining") ?? "--",
                reset: http.value(forHTTPHeaderField: "x-ratelimit-reset") ?? "--"
            )
            switch http.statusCode {
            case 200..<300:
                do {
                    return APIValue(value: try JSONDecoder().decode(Value.self, from: data), quota: quota)
                } catch {
                    throw DJHUBError.invalidResponse
                }
            case 401, 403: throw DJHUBError.invalidAPIKey
            case 404: throw DJHUBError.notFound
            case 429: throw DJHUBError.quotaExceeded(reset: quota.reset == "--" ? nil : quota.reset)
            default: throw DJHUBError.server(status: http.statusCode)
            }
        } catch let error as DJHUBError {
            throw error
        } catch {
            throw DJHUBError.transport(error.localizedDescription)
        }
    }
}
