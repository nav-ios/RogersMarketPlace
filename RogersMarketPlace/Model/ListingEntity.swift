//
//  ListingEntity.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import CoreData

/// Core Data row for a listing (see Marketplace.xcdatamodeld) and its mapping to `Listing`.
@objc(ListingEntity)
final class ListingEntity: NSManagedObject {
    static let entityName = "ListingEntity"

    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var listingDescription: String
    @NSManaged var price: NSDecimalNumber
    @NSManaged var category: String
    @NSManaged var location: String
    @NSManaged var imageURL: URL?
    @NSManaged var localImageName: String?
    @NSManaged var updatedAt: Date
    @NSManaged var isFavorite: Bool
    @NSManaged var syncStatus: String

    func update(from listing: Listing) {
        id = listing.id
        title = listing.title
        listingDescription = listing.description
        price = NSDecimalNumber(decimal: listing.price)
        category = listing.category
        location = listing.location
        imageURL = listing.imageURL
        localImageName = listing.localImageName
        updatedAt = listing.updatedAt
        isFavorite = listing.isFavorite
        syncStatus = listing.syncStatus.rawValue
    }

    var listing: Listing {
        Listing(id: id, title: title, description: listingDescription, price: price.decimalValue, category: category,
                location: location, imageURL: imageURL, localImageName: localImageName, updatedAt: updatedAt,
                isFavorite: isFavorite, syncStatus: SyncStatus(rawValue: syncStatus) ?? .pending)
    }
}
