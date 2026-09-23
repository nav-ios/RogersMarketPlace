//
//  ListingsStore.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import CoreData

protocol ListingsStore {
    /// Every listing, newest first.
    func fetchAll() async throws -> [Listing]
    /// Inserts or replaces by `id`.
    func save(_ listings: [Listing]) async throws
}

final class CoreDataListingsStore: ListingsStore {
    static let modelName = "Marketplace"

    private let container: NSPersistentContainer

    /// Pass `URL(fileURLWithPath: "/dev/null")` for an in-memory store (tests).
    init(storeURL: URL) throws {
        container = NSPersistentContainer(name: CoreDataListingsStore.modelName)
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
        var loadError: Error?
        container.loadPersistentStores { loadError = $1 }
        if let loadError { throw loadError }
    }

    func fetchAll() async throws -> [Listing] {
        try await container.performBackgroundTask { context in
            let request = NSFetchRequest<ListingEntity>(entityName: ListingEntity.entityName)
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            return try context.fetch(request).map(\.listing)
        }
    }

    func save(_ listings: [Listing]) async throws {
        try await container.performBackgroundTask { context in
            for listing in listings {
                let request = NSFetchRequest<ListingEntity>(entityName: ListingEntity.entityName)
                request.predicate = NSPredicate(format: "id == %@", listing.id as CVarArg)
                let entity = try context.fetch(request).first ?? ListingEntity(context: context)
                entity.update(from: listing)
            }
            try context.save()
        }
    }
}
