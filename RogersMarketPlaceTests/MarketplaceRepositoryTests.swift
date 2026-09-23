//
//  MarketplaceRepositoryTests.swift
//  RogersMarketPlaceTests
//
//  Created by Navdeep Rana on 23/09/26.
//

import XCTest
@testable import RogersMarketPlace

/// Runs the real stack (Core Data in memory, Keychain, URLSession → mock server).
final class MarketplaceRepositoryTests: XCTestCase {
    private var server: MockMarketplaceServer!
    private var repository: MarketplaceRepository!
    private var imageStore: ImageStore!
    private var now = Date(timeIntervalSince1970: 1_790_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        server = MockMarketplaceServer(seedFromBundle: false)
        server.latency = 0
        let session = server.makeSession()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("repository-tests-images")
        try? FileManager.default.removeItem(at: directory)
        imageStore = try ImageStore(directory: directory, session: session)
        let tokenStore = KeychainTokenStore(service: "com.navios.tests")
        tokenStore.delete()
        let api = RemoteMarketplaceAPI(baseURL: MockMarketplaceServer.baseURL, session: session, tokenStore: tokenStore)
        let store = try CoreDataListingsStore(storeURL: URL(fileURLWithPath: "/dev/null"))
        repository = MarketplaceRepository(api: api, store: store, imageStore: imageStore, now: { self.now })
    }

    func test_create_savesListingAsPendingWithoutTouchingTheServer() async throws {
        server.isOnline = false

        let created = try await repository.create(draft(title: "Road bike"))

        let listings = try await repository.listings()
        XCTAssertEqual(listings, [created])
        XCTAssertEqual(created.syncStatus, .pending)
        XCTAssertEqual(server.listingCount, 0)
    }

    func test_refresh_mergesServerListingsKeepingPendingEditsAndFavorites() async throws {
        let listing = try await repository.create(draft(title: "Desk"))
        _ = try await api().upsert(listing)
        try await repository.toggleFavorite(listing.id)

        // Server has a newer version of the synced listing → it replaces ours, favorite kept.
        now = now.addingTimeInterval(60)
        _ = try await api().upsert(with(listing, title: "Desk (price drop)"))
        // A second listing is edited locally and still pending → refresh must not overwrite it.
        let pending = try await repository.create(draft(title: "Lamp"))
        _ = try await api().upsert(pending)
        try await repository.update(pending.id, with: draft(title: "Lamp (local edit)"))
        _ = try await api().upsert(with(pending, title: "Lamp (server edit)"))

        try await repository.refresh()

        let listings = Dictionary(uniqueKeysWithValues: try await repository.listings().map { ($0.id, $0) })
        XCTAssertEqual(listings[listing.id]?.title, "Desk (price drop)")
        XCTAssertEqual(listings[listing.id]?.isFavorite, true)
        XCTAssertEqual(listings[pending.id]?.title, "Lamp (local edit)")
        XCTAssertEqual(listings[pending.id]?.syncStatus, .pending)
    }

    // MARK: - Helpers

    private func draft(title: String, photo: String? = nil) -> ListingDraft {
        ListingDraft(title: title, description: "desc", price: 42, category: "Furniture", location: "Toronto", localImageName: photo)
    }

    private func with(_ listing: Listing, title: String) -> Listing {
        var copy = listing
        copy.title = title
        copy.updatedAt = Date().addingTimeInterval(5)   // clearly newer than anything the server stamped
        return copy
    }

    private func api() -> MarketplaceAPI {
        RemoteMarketplaceAPI(baseURL: MockMarketplaceServer.baseURL, session: server.makeSession(), tokenStore: KeychainTokenStore(service: "com.navios.tests"))
    }
}

func makeImageData(width: Int, height: Int) -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).jpegData(withCompressionQuality: 0.9) { context in
        UIColor.systemTeal.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}
