//
//  MarketplaceRepository.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import Foundation

/// The offline-first rules live here:
/// - reads always come from the local store;
/// - every write is saved locally as `pending` first;
/// - `syncPending()` uploads pending listings (and their photos) when we are online;
///   the server keeps whichever version is newer (last-write-wins) and we store what it returns.
final class MarketplaceRepository {
    private let api: MarketplaceAPI
    private let store: ListingsStore
    private let imageStore: ImageStore
    private let now: () -> Date

    init(api: MarketplaceAPI, store: ListingsStore, imageStore: ImageStore, now: @escaping () -> Date = Date.init) {
        self.api = api
        self.store = store
        self.imageStore = imageStore
        self.now = now
    }

    func listings() async throws -> [Listing] {
        try await store.fetchAll()
    }

    /// Fetches from the API and merges into the store. A listing with local changes
    /// waiting to sync is never overwritten; otherwise the newer `updatedAt` wins.
    func refresh() async throws {
        let remote = try await api.fetchListings()
        let local = Dictionary(uniqueKeysWithValues: try await store.fetchAll().map { ($0.id, $0) })
        var changes = [Listing]()
        for var listing in remote {
            if let existing = local[listing.id] {
                guard existing.syncStatus == .synced, listing.updatedAt > existing.updatedAt else { continue }
                listing.isFavorite = existing.isFavorite
            }
            changes.append(listing)
        }
        if !changes.isEmpty { try await store.save(changes) }
    }

    @discardableResult
    func create(_ draft: ListingDraft) async throws -> Listing {
        let listing = Listing(id: UUID(), title: draft.title, description: draft.description, price: draft.price, category: draft.category,
                              location: draft.location, imageURL: nil, localImageName: draft.localImageName, updatedAt: now(),
                              isFavorite: false, syncStatus: .pending)
        try await store.save([listing])
        return listing
    }

    func update(_ id: UUID, with draft: ListingDraft) async throws {
        guard var listing = try await store.fetchAll().first(where: { $0.id == id }) else { return }
        listing.title = draft.title
        listing.description = draft.description
        listing.price = draft.price
        listing.category = draft.category
        listing.location = draft.location
        listing.localImageName = draft.localImageName ?? listing.localImageName
        listing.updatedAt = now()
        listing.syncStatus = .pending
        try await store.save([listing])
    }

    func toggleFavorite(_ id: UUID) async throws {
        guard var listing = try await store.fetchAll().first(where: { $0.id == id }) else { return }
        listing.isFavorite.toggle()
        try await store.save([listing])   // favorites are local only, no sync needed
    }
}
