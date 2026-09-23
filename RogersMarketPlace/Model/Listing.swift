//
//  Listing.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import Foundation

enum SyncStatus: String, Codable {
    case synced   // matches the server
    case pending  // created or edited locally, waiting to be uploaded
    case failed   // last upload failed, will be retried
}

struct Listing: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var description: String
    var price: Decimal
    var category: String
    var location: String
    var imageURL: URL?
    var localImageName: String?   // photo attached on this device, uploaded during sync
    var updatedAt: Date
    var isFavorite = false          // local only, never sent to the server
    var syncStatus = SyncStatus.synced

    private enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, location, imageURL, updatedAt
    }
}

/// What the user types in the form. Validated by `ListingValidator` before it becomes a `Listing`.
struct ListingDraft: Equatable {
    var title: String
    var description: String
    var price: Decimal
    var category: String
    var location: String
    var localImageName: String?
}
