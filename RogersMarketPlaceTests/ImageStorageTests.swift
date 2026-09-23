//
//  ImageStorageTests.swift
//  RogersMarketPlaceTests
//
//  Created by Navdeep Rana on 23/09/26.
//

import XCTest
@testable import RogersMarketPlace

final class ImageStorageTests: XCTestCase {

    func test_saveImage_writesShrunkJPEGAndReturnsItsName() throws {
        let name = try XCTUnwrap(ImageStorage.saveImage(makeImageData(width: 4000, height: 2000)))
        defer { try? FileManager.default.removeItem(at: ImageStorage.fileURL(named: name)) }

        let saved = try XCTUnwrap(UIImage(data: try Data(contentsOf: ImageStorage.fileURL(named: name))))
        XCTAssertEqual(saved.size, CGSize(width: 1600, height: 800))
    }

    func test_thumbnail_isDecodedAtTheRequestedSizeAndNeverUpscaled() async throws {
        let big = try XCTUnwrap(ImageStorage.saveImage(makeImageData(width: 1200, height: 600)))
        let small = try XCTUnwrap(ImageStorage.saveImage(makeImageData(width: 100, height: 80)))
        defer { [big, small].forEach { try? FileManager.default.removeItem(at: ImageStorage.fileURL(named: $0)) } }

        let bigThumb = await ImageStorage.thumbnail(for: listing(photo: big), maxPixelSize: 300)
        let smallThumb = await ImageStorage.thumbnail(for: listing(photo: small), maxPixelSize: 300)

        XCTAssertEqual(bigThumb?.size, CGSize(width: 300, height: 150))
        XCTAssertEqual(smallThumb?.size, CGSize(width: 100, height: 80))
    }

    private func listing(photo: String) -> Listing {
        Listing(id: UUID(), title: "t", description: "d", price: 1, category: "c", location: "l", imageURL: nil, localImageName: photo, updatedAt: Date())
    }
}
