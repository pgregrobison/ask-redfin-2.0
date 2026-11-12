import Foundation

/// Local house photos bundled in Resources/HousePhotos, used instead of remote
/// stock-photo URLs so listing photos load instantly and work offline (good
/// for recording demos). Add more files there and bump the range below.
enum HousePhotos {
    private static let extensions = ["jpg", "png"]

    /// Resolved `file://` URL strings for each local photo, resolved once.
    static let urls: [String] = (1...24).compactMap { i -> String? in
        let name = String(format: "house%02d", i)
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources/HousePhotos")
                ?? Bundle.main.url(forResource: name, withExtension: ext) {
                return url.absoluteString
            }
        }
        return nil
    }

    /// `count` photo URLs cycling through the local pool, starting at `offset`
    /// so nearby listings don't end up with identical photo sets.
    static func set(count: Int, offset: Int) -> [String] {
        guard !urls.isEmpty else { return [] }
        return (0..<count).map { urls[(offset + $0) % urls.count] }
    }

    /// A single local exterior photo, cycling through the pool by `index`
    /// (typically the listing's position). Used as the hero/first photo,
    /// paired with remote interior shots for the rest of a listing's gallery.
    static func url(_ index: Int) -> String {
        guard !urls.isEmpty else { return "" }
        return urls[index % urls.count]
    }

    /// Remote interior shots (living room, kitchen, primary bedroom, dining
    /// room) shared across listings — no local interior photos exist, only
    /// the uploaded front-of-home exterior set.
    static let interiorURLs: [String] = [
        "https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?w=800", // living room
        "https://images.unsplash.com/photo-1556909212-d5b604d0c90d?w=800",    // kitchen
        "https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf?w=800", // primary bedroom
        "https://images.unsplash.com/photo-1617806118233-18e1de247200?w=800"  // dining room
    ]
}
