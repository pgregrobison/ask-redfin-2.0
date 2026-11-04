import Foundation
import CoreLocation

nonisolated struct Listing: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let price: Int
    let address: String
    let city: String
    let neighborhood: String?
    let state: String
    let zip: String
    let beds: Int
    let baths: Double
    let sqft: Int
    let latitude: Double
    let longitude: Double
    let photos: [String]
    let description: String
    let yearBuilt: Int
    let lotSize: String
    let propertyType: String
    let isHotHome: Bool
    let tags: [String]
    let daysOnMarket: Int
    let hoaDues: String
    let buyerAgentFee: String
    var isListedByRedfin: Bool = false
    var isCompassComingSoon: Bool = false
    /// Prototype-derived details for catalog homes (`HomeCatalog`); nil for fixtures.
    var facts: HomeFacts? = nil

    init(
        id: String,
        price: Int,
        address: String,
        city: String,
        neighborhood: String? = nil,
        state: String,
        zip: String,
        beds: Int,
        baths: Double,
        sqft: Int,
        latitude: Double,
        longitude: Double,
        photos: [String],
        description: String,
        yearBuilt: Int,
        lotSize: String,
        propertyType: String,
        isHotHome: Bool,
        tags: [String],
        daysOnMarket: Int,
        hoaDues: String,
        buyerAgentFee: String,
        isListedByRedfin: Bool = false,
        isCompassComingSoon: Bool = false,
        facts: HomeFacts? = nil
    ) {
        self.id = id
        self.price = price
        self.address = address
        self.city = city
        self.neighborhood = neighborhood
        self.state = state
        self.zip = zip
        self.beds = beds
        self.baths = baths
        self.sqft = sqft
        self.latitude = latitude
        self.longitude = longitude
        self.photos = photos
        self.description = description
        self.yearBuilt = yearBuilt
        self.lotSize = lotSize
        self.propertyType = propertyType
        self.isHotHome = isHotHome
        self.tags = tags
        self.daysOnMarket = daysOnMarket
        self.hoaDues = hoaDues
        self.buyerAgentFee = buyerAgentFee
        self.isListedByRedfin = isListedByRedfin
        self.isCompassComingSoon = isCompassComingSoon
        self.facts = facts
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var fullAddress: String {
        "\(address), \(city), \(state) \(zip)"
    }

    var formattedPrice: String {
        if price >= 1_000_000 {
            // Two decimals with trailing zeros dropped, like the prototype ($1.25M, $1.3M, $1M).
            let hundredths = (Double(price) / 10_000).rounded() / 100
            return "$\(hundredths.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)))M"
        } else {
            let thousands = price / 1000
            return "$\(thousands)K"
        }
    }

    var formattedFullPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }

    var pricePerSqFt: Int {
        guard sqft > 0 else { return 0 }
        return price / sqft
    }

    var bathsFormatted: String {
        if baths == Double(Int(baths)) {
            return "\(Int(baths))"
        }
        return "\(baths)"
    }

    var viewsCount: Int {
        Int.random(in: 200...800)
    }

    var favoritesCount: Int {
        Int.random(in: 5...30)
    }

    var shareText: String {
        "\(fullAddress) - \(formattedFullPrice)"
    }

    var primaryBadge: HomeCardBadge? {
        if daysOnMarket > 0 && daysOnMarket <= 14 {
            return .daysAgo(daysOnMarket)
        } else if isHotHome {
            return .hot
        } else if isCompassComingSoon {
            return .compassComingSoon
        } else if isListedByRedfin {
            return .listedByRedfin
        }
        return nil
    }
}
