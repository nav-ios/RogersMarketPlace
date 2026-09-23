//
//  MarketplaceViewModel.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import Combine
import Foundation

@MainActor
final class MarketplaceViewModel: ObservableObject {
    @Published private(set) var listings = [Listing]()
    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published private(set) var errorMessage: String?
    @Published var searchText = ""
    @Published var showFavoritesOnly = false

    private let repository: MarketplaceRepository
    private let network: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()

    init(repository: MarketplaceRepository, network: NetworkMonitor) {
        self.repository = repository
        self.network = network

        // Background upload when connectivity returns.
        network.$isOnline
            .removeDuplicates()
            .filter { $0 }
            .receive(on: DispatchQueue.main)   // @Published emits before the value is set; sync on the next tick
            .sink { [weak self] _ in self?.sync() }
            .store(in: &cancellables)
    }

    var isOnline: Bool { network.isOnline }

    var visibleListings: [Listing] {
        listings.filter { listing in
            (!showFavoritesOnly || listing.isFavorite)
                && (searchText.isEmpty || listing.title.localizedCaseInsensitiveContains(searchText))
        }
    }

    var pendingCount: Int { listings.filter { $0.syncStatus != .synced }.count }

    var syncStatusText: String {
        if !isOnline { return pendingCount == 0 ? "Offline. You can keep browsing and creating listings." : "Offline. \(pendingCount) change\(pendingCount == 1 ? "" : "s") will sync when you're back online." }
        if isSyncing { return "Syncing…" }
        return pendingCount == 0 ? "All changes synced" : "\(pendingCount) change\(pendingCount == 1 ? "" : "s") waiting to sync"
    }

    func listing(_ id: UUID) -> Listing? { listings.first { $0.id == id } }

    /// Show what is on disk right away, upload anything still pending, then refresh from the API.
    func load() {
        Task {
            await reload()
            sync()
            await refresh()
        }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            try await repository.refresh()
            await reload()
        } catch {
            errorMessage = "Couldn't reach the marketplace. Showing your saved listings."
        }
        isLoading = false
    }

    func toggleFavorite(_ id: UUID) {
        Task {
            try? await repository.toggleFavorite(id)
            await reload()
        }
    }

    func create(_ draft: ListingDraft) async throws {
        try await repository.create(try ListingValidator.validate(draft))
        await reload()
        sync()
    }

    func update(_ id: UUID, with draft: ListingDraft) async throws {
        try await repository.update(id, with: try ListingValidator.validate(draft))
        await reload()
        sync()
    }

    func sync() {
        guard isOnline, !isSyncing, pendingCount > 0 else { return }
        isSyncing = true
        Task {
            try? await repository.syncPending()
            await reload()
            isSyncing = false
        }
    }

    private func reload() async {
        listings = (try? await repository.listings()) ?? []
    }
}
