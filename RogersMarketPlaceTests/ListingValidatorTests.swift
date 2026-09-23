//
//  ListingValidatorTests.swift
//  RogersMarketPlaceTests
//
//  Created by Navdeep Rana on 23/09/26.
//

import XCTest
@testable import RogersMarketPlace

final class ListingValidatorTests: XCTestCase {

    func test_validate_trimsWhitespace() throws {
        let clean = try ListingValidator.validate(draft(title: "  iPhone 15  ", location: " Toronto "))

        XCTAssertEqual(clean.title, "iPhone 15")
        XCTAssertEqual(clean.location, "Toronto")
    }

    func test_validate_rejectsBadTitlesAndPrices() {
        XCTAssertThrowsError(try ListingValidator.validate(draft(title: "ab"))) { XCTAssertEqual($0 as? ValidationError, .title) }
        XCTAssertThrowsError(try ListingValidator.validate(draft(price: 0))) { XCTAssertEqual($0 as? ValidationError, .price) }
        XCTAssertThrowsError(try ListingValidator.validate(draft(price: 1_000_001))) { XCTAssertEqual($0 as? ValidationError, .price) }
    }

    func test_validate_rejectsMissingCategoryOrLocation() {
        XCTAssertThrowsError(try ListingValidator.validate(draft(category: " "))) { XCTAssertEqual($0 as? ValidationError, .category) }
        XCTAssertThrowsError(try ListingValidator.validate(draft(location: ""))) { XCTAssertEqual($0 as? ValidationError, .location) }
    }

    private func draft(title: String = "Valid title", price: Decimal = 10, category: String = "Electronics", location: String = "Toronto") -> ListingDraft {
        ListingDraft(title: title, description: "desc", price: price, category: category, location: location, localImageName: nil)
    }
}
