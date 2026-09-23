//
//  ListingValidator.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import Foundation

enum ValidationError: LocalizedError, Equatable {
    case title, description, price, category, location

    var errorDescription: String? {
        switch self {
        case .title: return "Title must be 3 to 80 characters."
        case .description: return "Description can't be longer than 1000 characters."
        case .price: return "Price must be greater than zero and at most 1,000,000."
        case .category: return "Choose a category."
        case .location: return "Enter a location."
        }
    }
}

/// Trims the text fields and checks bounds before anything is saved or sent.
enum ListingValidator {
    static func validate(_ draft: ListingDraft) throws -> ListingDraft {
        var clean = draft
        clean.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.category = draft.category.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines)

        guard (3...80).contains(clean.title.count) else { throw ValidationError.title }
        guard clean.description.count <= 1000 else { throw ValidationError.description }
        guard draft.price > 0, draft.price <= 1_000_000 else { throw ValidationError.price }
        guard !clean.category.isEmpty else { throw ValidationError.category }
        guard !clean.location.isEmpty else { throw ValidationError.location }
        return clean
    }
}
