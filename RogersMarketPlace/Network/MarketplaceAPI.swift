//
//  MarketplaceAPI.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import Foundation

enum APIError: Error {
    case offline
    case server(statusCode: Int)
}

protocol MarketplaceAPI {
    func fetchListings() async throws -> [Listing]
    /// Creates or updates. The server keeps whichever version is newer and returns it.
    func upsert(_ listing: Listing) async throws -> Listing
    func uploadImage(_ jpeg: Data, for listingID: UUID) async throws -> URL
}

/// Talks to the REST API with `URLSession`. The bearer token is kept in the Keychain
/// and fetched from `POST /auth/token` the first time it is needed.
final class APIClient: MarketplaceAPI {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: KeychainTokenStore
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL, session: URLSession, tokenStore: KeychainTokenStore) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func fetchListings() async throws -> [Listing] {
        try decoder.decode([Listing].self, from: try await send("GET", "listings"))
    }

    func upsert(_ listing: Listing) async throws -> Listing {
        let data = try await send("PUT", "listings/\(listing.id.uuidString)", body: try encoder.encode(listing))
        var synced = try decoder.decode(Listing.self, from: data)
        synced.isFavorite = listing.isFavorite          // favorites are local only
        synced.localImageName = listing.localImageName
        synced.syncStatus = .synced
        return synced
    }

    func uploadImage(_ jpeg: Data, for listingID: UUID) async throws -> URL {
        struct Upload: Decodable { let imageURL: URL }
        let data = try await send("POST", "listings/\(listingID.uuidString)/image", body: jpeg, contentType: "image/jpeg")
        return try decoder.decode(Upload.self, from: data).imageURL
    }

    private func send(_ method: String, _ path: String, body: Data? = nil, contentType: String = "application/json") async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if path != "auth/token" {
            request.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(status) else { throw APIError.server(statusCode: status) }
            return data
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw APIError.offline
        }
    }

    private func token() async throws -> String {
        if let token = tokenStore.token { return token }
        struct Token: Decodable { let token: String }
        let data = try await send("POST", "auth/token", body: try JSONSerialization.data(withJSONObject: ["deviceID": UUID().uuidString]))
        let token = try decoder.decode(Token.self, from: data).token
        try tokenStore.save(token)
        return token
    }
}
