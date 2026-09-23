//
//  ListingRow.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import SwiftUI

struct ListingRow: View {
    let listing: Listing
    let onFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ListingImageView(listing: listing, maxPixelSize: 300)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button(action: onFavorite) {
                    Image(systemName: listing.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(listing.isFavorite ? .red : .primary)
                        .padding(7)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityIdentifier("favorite-button")
            }
            Text(listing.title).font(.subheadline.weight(.semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            Text(listing.price, format: .currency(code: AppConfig.currencyCode)).font(.subheadline.bold())
            HStack {
                Text(listing.location).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if listing.syncStatus != .synced {
                    Text(listing.syncStatus == .pending ? "Pending" : "Failed")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2), in: Capsule())
                        .accessibilityIdentifier("sync-badge")
                }
            }
        }
    }
}
