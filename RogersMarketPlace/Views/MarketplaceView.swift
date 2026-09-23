//
//  MarketplaceView.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import SwiftUI

struct MarketplaceView: View {
    @ObservedObject var viewModel: MarketplaceViewModel

    @State private var showCreateForm = false
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                syncStatusBar
                content
            }
            .navigationTitle("Marketplace")
            .searchable(text: $viewModel.searchText, prompt: "Search listings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { viewModel.showFavoritesOnly.toggle() } label: {
                        Image(systemName: viewModel.showFavoritesOnly ? "heart.fill" : "heart")
                    }
                    .accessibilityIdentifier("favorites-toggle")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreateForm = true } label: { Image(systemName: "plus") }
                        .accessibilityIdentifier("create-listing-button")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                ListingDetailView(listingID: id, viewModel: viewModel)
            }
            .sheet(isPresented: $showCreateForm) {
                ListingFormView(listing: nil, viewModel: viewModel)
            }
        }
        .task { viewModel.load() }
    }

    private var syncStatusBar: some View {
        let pending = viewModel.pendingCount > 0 || !viewModel.isOnline
        return HStack(spacing: 8) {
            Image(systemName: !viewModel.isOnline ? "wifi.slash" : pending ? "clock" : "checkmark.icloud")
            Text(viewModel.syncStatusText).font(.footnote)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .foregroundStyle(pending ? Color.orange : Color.green)
        .background((pending ? Color.orange : Color.green).opacity(0.12))
        .accessibilityIdentifier("sync-status")
        .accessibilityLabel(viewModel.syncStatusText)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.listings.isEmpty && viewModel.isLoading {
            ProgressView("Loading listings…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.visibleListings.isEmpty {
            ContentUnavailableView("No Listings", systemImage: "shippingbox", description: Text("Pull to refresh or tap + to create one."))
        } else {
            ScrollView {
                if let message = viewModel.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                }
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.visibleListings) { listing in
                        NavigationLink(value: listing.id) {
                            ListingRow(listing: listing) { viewModel.toggleFavorite(listing.id) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("listing-card")
                    }
                }
                .padding(16)
            }
            .refreshable { await viewModel.refresh() }
        }
    }
}
