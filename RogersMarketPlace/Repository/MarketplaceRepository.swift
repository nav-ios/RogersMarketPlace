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
    private let now: () -> Date

    init(api: MarketplaceAPI, store: ListingsStore, now: @escaping () -> Date = Date.init) {
        self.api = api
        self.store = store
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
                              location: draft.location, imageURL: nil, localImageName: draft.localImageName, updatedAt: now(), syncStatus: .pending)
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

    /// Uploads every pending listing. Stops at the first connectivity error (they stay pending);
    /// any other error marks that listing `failed` and moves on. Returns how many were uploaded.
    @discardableResult
    func syncPending() async throws -> Int {
        var uploaded = 0
        for listing in try await store.fetchAll() where listing.syncStatus != .synced {
            do {
                var synced = try await api.upsert(listing)
                if let name = listing.localImageName, synced.imageURL == nil {
                    synced.imageURL = try await api.uploadImage(try Data(contentsOf: ImageStorage.fileURL(named: name)), for: listing.id)
                }
                try await store.save([synced])
                uploaded += 1
            } catch APIError.offline {
                throw APIError.offline
            } catch {
                var failed = listing
                failed.syncStatus = .failed
                try await store.save([failed])
            }
        }
        return uploaded
    }
}
