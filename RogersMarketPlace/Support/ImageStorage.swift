//
//  ImageStorage.swift
//  RogersMarketPlace
//
//  Created by Navdeep Rana on 23/09/26.
//

import UIKit

/// Saves attached photos to disk and produces thumbnails for the UI.
/// Thumbnails are decoded at the size the view asks for and kept in an
/// `NSCache` capped at 40 MB, so scrolling 200 listings never holds
/// full-size bitmaps in memory.
enum ImageStorage {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 40 * 1024 * 1024
        return cache
    }()

    private static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func fileURL(named name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// Writes the picked photo (shrunk to 1600 px) and returns its file name.
    static func saveImage(_ data: Data) -> String? {
        guard let image = UIImage(data: data)?.preparingThumbnail(of: fitting(data, to: 1600)),
              let jpeg = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: fileURL(named: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    /// Thumbnail for a listing: local photo if there is one, otherwise the remote image.
    static func thumbnail(for listing: Listing, maxPixelSize: CGFloat) async -> UIImage? {
        let key = "\(listing.localImageName ?? listing.imageURL?.absoluteString ?? "")-\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        var data: Data?
        if let name = listing.localImageName {
            data = try? Data(contentsOf: fileURL(named: name))
        } else if let url = listing.imageURL {
            data = try? await URLSession.shared.data(from: url).0
        }
        guard let data, let image = UIImage(data: data)?.preparingThumbnail(of: fitting(data, to: maxPixelSize)) else { return nil }

        cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        return image
    }

    /// Size with the longest side at most `maxPixelSize`, never upscaled.
    private static func fitting(_ data: Data, to maxPixelSize: CGFloat) -> CGSize {
        let size = UIImage(data: data)?.size ?? CGSize(width: maxPixelSize, height: maxPixelSize)
        let scale = min(1, maxPixelSize / max(size.width, size.height))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
