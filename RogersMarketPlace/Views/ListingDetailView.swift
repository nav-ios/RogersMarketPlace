//
//  ListingDetailView.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import SwiftUI

struct ListingDetailView: View {
    let listingID: UUID
    @ObservedObject var viewModel: MarketplaceViewModel

    @State private var showEditForm = false

    var body: some View {
        if let listing = viewModel.listing(listingID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ListingImageView(listing: listing, maxPixelSize: 1200)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    Text(listing.title).font(.title2.bold()).accessibilityIdentifier("details-title")
                    Text(listing.price, format: .currency(code: AppConfig.currencyCode)).font(.title3.bold())
                    Text("\(listing.category) · \(listing.location)").font(.subheadline).foregroundStyle(.secondary)
                    if listing.syncStatus != .synced {
                        Text(listing.syncStatus == .pending ? "Pending sync" : "Sync failed, will retry").font(.caption.bold()).foregroundStyle(.orange)
                    }
                    Text(listing.description)
                }
                .padding()
            }
            .navigationTitle("Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { viewModel.toggleFavorite(listing.id) } label: {
                        Image(systemName: listing.isFavorite ? "heart.fill" : "heart")
                    }
                    Button("Edit") { showEditForm = true }.accessibilityIdentifier("edit-listing-button")
                }
            }
            .sheet(isPresented: $showEditForm) {
                ListingFormView(listing: listing, viewModel: viewModel)
            }
        } else {
            ContentUnavailableView("Listing not found", systemImage: "shippingbox")
        }
    }
}
