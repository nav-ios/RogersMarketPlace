//
//  ListingImageView.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import SwiftUI

/// Loads a downsampled image for the listing and drops the work when the view goes away.
struct ListingImageView: View {
    let listing: Listing
    let maxPixelSize: CGFloat

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task(id: listing.localImageName ?? listing.imageURL?.absoluteString) {
            image = await ImageStorage.thumbnail(for: listing, maxPixelSize: maxPixelSize)
        }
    }
}
