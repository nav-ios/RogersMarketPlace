//
//  MockMarketplaceServer.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import Foundation

/// A mock REST API that runs inside the app. `URLSession` requests to `baseURL`
/// are answered here through a `URLProtocol`, so the real networking code is used.
///
///   POST /auth/token             → { "token": "..." }
///   GET  /listings               → [listing]                     (needs Authorization header)
///   PUT  /listings/{id}          → creates or updates; keeps the newer `updatedAt`
///   POST /listings/{id}/image    → { "imageURL": "..." }
///
/// Seeded from `listings.json`. State lives as long as the app runs, so a created
/// listing comes back on the next fetch, like a real server.
final class MockMarketplaceServer {
    static let baseURL = URL(string: "https://api.rogers-market.test/v1")!

    var isOnline = true              // false = every request fails, like airplane mode
    var latency: TimeInterval = 0.4

    private var listings: [String: [String: Any]] = [:]
    private let lock = NSLock()

    init(seedFromBundle: Bool = true) {
        guard seedFromBundle, let url = Bundle.main.url(forResource: "listings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        for item in items { listings[item["id"] as! String] = item }
    }

    var listingCount: Int { lock.lock(); defer { lock.unlock() }; return listings.count }

    /// A session whose requests to `baseURL` are handled by this server.
    func makeSession() -> URLSession {
        MockServerURLProtocol.server = self
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockServerURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    func handle(_ request: URLRequest) -> (status: Int, body: Any) {
        lock.lock(); defer { lock.unlock() }
        let path = request.url!.path.replacingOccurrences(of: MockMarketplaceServer.baseURL.path, with: "")
        let parts = path.split(separator: "/").map(String.init)
        let method = request.httpMethod ?? "GET"
        let body = request.httpBody ?? request.httpBodyStream.map(Data.init(reading:)) ?? Data()

        if method == "POST", path == "/auth/token" {
            return (200, ["token": "tok_" + UUID().uuidString])
        }
        guard request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer tok_") == true else {
            return (401, ["error": "Unauthorized"])
        }
        if method == "GET", path == "/listings" {
            return (200, listings.values.sorted { ($0["updatedAt"] as! String) > ($1["updatedAt"] as! String) })
        }
        if method == "PUT", parts.count == 2, parts[0] == "listings",
           let incoming = try? JSONSerialization.jsonObject(with: body) as? [String: Any], incoming["id"] as? String == parts[1] {
            // Last-write-wins: if the server already has a newer version, keep it and return it.
            if let current = listings[parts[1]], (current["updatedAt"] as! String) > (incoming["updatedAt"] as! String) {
                return (200, current)
            }
            let created = listings[parts[1]] == nil
            listings[parts[1]] = incoming
            return (created ? 201 : 200, incoming)
        }
        if method == "POST", parts.count == 3, parts[0] == "listings", parts[2] == "image", listings[parts[1]] != nil, !body.isEmpty {
            let imageURL = MockMarketplaceServer.baseURL.appendingPathComponent("images/\(parts[1]).jpg").absoluteString
            listings[parts[1]]?["imageURL"] = imageURL
            return (201, ["imageURL": imageURL])
        }
        return (404, ["error": "Not Found"])
    }
}

final class MockServerURLProtocol: URLProtocol {
    static var server: MockMarketplaceServer?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == MockMarketplaceServer.baseURL.host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let server = MockServerURLProtocol.server, let client else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + server.latency) {
            guard server.isOnline else {
                return client.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            }
            let (status, body) = server.handle(self.request)
            let response = HTTPURLResponse(url: self.request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: (try? JSONSerialization.data(withJSONObject: body)) ?? Data())
            client.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

private extension Data {
    /// `URLSession` hands a request body to a `URLProtocol` as a stream.
    init(reading stream: InputStream) {
        self.init()
        stream.open(); defer { stream.close() }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096); defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: 4096)
            guard read > 0 else { break }
            append(buffer, count: read)
        }
    }
}
