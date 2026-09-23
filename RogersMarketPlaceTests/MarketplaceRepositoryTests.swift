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
    private var now = Date(timeIntervalSince1970: 1_790_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        server = MockMarketplaceServer(seedFromBundle: false)
        server.latency = 0
        let session = server.makeSession()
        let tokenStore = KeychainTokenStore(service: "com.navios.tests")
        tokenStore.delete()
        let api = APIClient(baseURL: MockMarketplaceServer.baseURL, session: session, tokenStore: tokenStore)
        let store = try CoreDataListingsStore(storeURL: URL(fileURLWithPath: "/dev/null"))
        repository = MarketplaceRepository(api: api, store: store, now: { self.now })
    }

    func test_create_savesListingAsPendingWithoutTouchingTheServer() async throws {
        server.isOnline = false

        let created = try await repository.create(draft(title: "Road bike"))

        let listings = try await repository.listings()
        XCTAssertEqual(listings, [created])
        XCTAssertEqual(created.syncStatus, .pending)
        XCTAssertEqual(server.listingCount, 0)
    }

    func test_syncPending_offlineThrowsAndKeepsListingPending() async throws {
        server.isOnline = false
        try await repository.create(draft(title: "Road bike"))

        do {
            try await repository.syncPending()
            XCTFail("Expected an offline error")
        } catch APIError.offline {}

        let status = try await repository.listings().first?.syncStatus
        XCTAssertEqual(status, .pending)
        XCTAssertEqual(server.listingCount, 0)
    }

    func test_syncPending_uploadsListingAndPhotoWhenBackOnline() async throws {
        server.isOnline = false
        let photo = try XCTUnwrap(ImageStorage.saveImage(makeImageData(width: 1200, height: 900)))
        let created = try await repository.create(draft(title: "Road bike", photo: photo))

        server.isOnline = true
        let uploaded = try await repository.syncPending()

        XCTAssertEqual(uploaded, 1)
        XCTAssertEqual(server.listingCount, 1)
        let synced = try await repository.listings().first
        XCTAssertEqual(synced?.syncStatus, .synced)
        XCTAssertEqual(synced?.imageURL?.lastPathComponent, created.id.uuidString + ".jpg")
    }

    func test_refresh_mergesServerListingsKeepingPendingEditsAndFavorites() async throws {
        let listing = try await repository.create(draft(title: "Desk"))
        try await repository.syncPending()
        try await repository.toggleFavorite(listing.id)

        // Server has a newer version of the synced listing → it replaces ours, favorite kept.
        now = now.addingTimeInterval(60)
        _ = try await api().upsert(with(listing, title: "Desk (price drop)"))
        // A second listing is edited locally and still pending → refresh must not overwrite it.
        let pending = try await repository.create(draft(title: "Lamp"))
        try await repository.syncPending()
        try await repository.update(pending.id, with: draft(title: "Lamp (local edit)"))
        _ = try await api().upsert(with(pending, title: "Lamp (server edit)"))

        try await repository.refresh()

        let listings = Dictionary(uniqueKeysWithValues: try await repository.listings().map { ($0.id, $0) })
        XCTAssertEqual(listings[listing.id]?.title, "Desk (price drop)")
        XCTAssertEqual(listings[listing.id]?.isFavorite, true)
        XCTAssertEqual(listings[pending.id]?.title, "Lamp (local edit)")
        XCTAssertEqual(listings[pending.id]?.syncStatus, .pending)
    }

    func test_syncPending_conflict_localEditNewerWins() async throws {
        let listing = try await repository.create(draft(title: "Desk"))
        try await repository.syncPending()
        _ = try await api().upsert(with(listing, title: "Edited on another device"))   // stamped now + 5 s

        now = Date().addingTimeInterval(120)                                                         // our edit is newer
        try await repository.update(listing.id, with: draft(title: "My newer edit"))
        try await repository.syncPending()

        let local = try await repository.listings().first?.title
        let remote = try await api().fetchListings().first?.title
        XCTAssertEqual(local, "My newer edit")
        XCTAssertEqual(remote, "My newer edit")
    }

    func test_syncPending_conflict_serverNewerWins() async throws {
        let listing = try await repository.create(draft(title: "Desk"))
        try await repository.syncPending()
        try await repository.toggleFavorite(listing.id)

        now = Date().addingTimeInterval(-120)                                                        // our edit is older
        try await repository.update(listing.id, with: draft(title: "My older edit"))
        _ = try await api().upsert(with(listing, title: "Edited on another device"))   // stamped now + 5 s
        try await repository.syncPending()

        let synced = try await repository.listings().first
        XCTAssertEqual(synced?.title, "Edited on another device")
        XCTAssertEqual(synced?.syncStatus, .synced)
        XCTAssertEqual(synced?.isFavorite, true)
    }

    func test_syncPending_marksListingFailedOnServerErrorAndContinues() async throws {
        let bad = try await repository.create(draft(title: "Bad photo", photo: "missing.jpg"))
        let good = try await repository.create(draft(title: "Good"))

        let uploaded = try await repository.syncPending()

        let listings = Dictionary(uniqueKeysWithValues: try await repository.listings().map { ($0.id, $0) })
        XCTAssertEqual(uploaded, 1)
        XCTAssertEqual(listings[bad.id]?.syncStatus, .failed)
        XCTAssertEqual(listings[good.id]?.syncStatus, .synced)
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
        APIClient(baseURL: MockMarketplaceServer.baseURL, session: server.makeSession(), tokenStore: KeychainTokenStore(service: "com.navios.tests"))
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
