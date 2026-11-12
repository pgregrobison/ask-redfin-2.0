import Foundation

/// Inputs for the tour and prequal wizards.
nonisolated struct TourRequest: Codable, Sendable {
    let listingId: String?
    let address: String?
}

nonisolated struct MortgageRequest: Codable, Sendable {
    let listingId: String?
}
