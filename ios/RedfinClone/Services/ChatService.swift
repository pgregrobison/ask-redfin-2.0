import Foundation

nonisolated enum DemoResponseType: Sendable {
    case listings(text: String, filters: SearchFilters, addNeighborhoods: Bool)
    case tour(text: String, request: TourRequest)
    case mortgage(text: String, request: MortgageRequest)
    case staleChat(text: String)
    case fallback(text: String)
}

@MainActor
class ChatService {

    func matchResponse(for input: String) -> DemoResponseType {
        let lower = input.lowercased()

        if lower.contains("stale chat") {
            return .staleChat(text: "It looks like this conversation has been quiet for a while. Want to pick up where you left off, or start fresh with something new?")
        }

        if lower.containsAny(["home", "house", "apartment", "condo", "listing", "find", "search", "property", "place", "buy", "bed", "br", "studio"]) {
            let filters = extractFilters(from: lower)
            let addNbhd = detectsAddNeighborhood(in: lower) && filters.neighborhoods != nil
            let text = buildListingsResponse(from: lower, filters: filters)
            return .listings(text: text, filters: filters, addNeighborhoods: addNbhd)
        }

        if lower.containsAny([
            "mortgage", "prequalified", "prequalify", "pre-qualified", "pre qualified", "preqalified",
            "preapproved", "pre-approved", "pre approved", "get approved",
            "afford", "loan", "financing", "my rate", "interest rate", "estimate my rate"
        ]) {
            let listingId = extractListingId(from: lower)
            let text = "Curious what you could afford? I can get you prequalified in a couple minutes."
            let request = MortgageRequest(listingId: listingId)
            return .mortgage(text: text, request: request)
        }

        if lower.containsAny(["tour", "schedule a tour", "tour a home", "tour this", "visit", "showing", "see the"]) {
            let address = extractAddress(from: lower)
            let listingId = extractListingId(from: lower)
            let text: String
            if let address {
                text = "Ready to see \(address) in person?"
            } else {
                text = "Ready to see this home in person?"
            }
            let request = TourRequest(listingId: listingId, address: address)
            return .tour(text: text, request: request)
        }

        let fallbacks = [
            "I can help you find homes or schedule tours in the NYC area. Try asking me something like \"show me homes in Brooklyn\" or \"find condos under $1M\"!",
            "I'm your NYC real estate assistant! Ask me to find homes, apartments, or condos — or I can help schedule a tour. What are you looking for?",
            "Looking for your next home? I can search listings across Manhattan, Brooklyn, Queens, and more. Just tell me what you're looking for!"
        ]
        return .fallback(text: fallbacks.randomElement()!)
    }

    nonisolated func searchListings(filters: SearchFilters) -> [Listing] {
        var results = MockData.listings

        if let minBeds = filters.minBeds { results = results.filter { $0.beds >= minBeds } }
        if let maxBeds = filters.maxBeds { results = results.filter { $0.beds <= maxBeds } }
        if let minBaths = filters.minBaths { results = results.filter { $0.baths >= minBaths } }
        if let maxBaths = filters.maxBaths { results = results.filter { $0.baths <= maxBaths } }
        if let minPrice = filters.minPrice { results = results.filter { $0.price >= minPrice } }
        if let maxPrice = filters.maxPrice { results = results.filter { $0.price <= maxPrice } }
        if let minSqft = filters.minSqft { results = results.filter { $0.sqft >= minSqft } }
        if let maxSqft = filters.maxSqft { results = results.filter { $0.sqft <= maxSqft } }
        if let propertyType = filters.propertyType { results = results.filter { $0.propertyType.lowercased() == propertyType.lowercased() } }
        if let isHotHome = filters.isHotHome, isHotHome { results = results.filter { $0.isHotHome } }
        if let neighborhoods = filters.neighborhoods, !neighborhoods.isEmpty {
            let keys = neighborhoods.map { $0.lowercased() }
            results = results.filter { listing in
                let nbhd = listing.neighborhood?.lowercased() ?? ""
                let city = listing.city.lowercased()
                return keys.contains(where: { k in nbhd == k || city == k || nbhd.contains(k) || city.contains(k) })
            }
        }

        return results
    }

    nonisolated func mergeFilters(current: SearchFilters, incoming: SearchFilters, addNeighborhoods: Bool) -> SearchFilters {
        var out = current
        if let v = incoming.minBeds { out.minBeds = v }
        if let v = incoming.maxBeds { out.maxBeds = v }
        if let v = incoming.minBaths { out.minBaths = v }
        if let v = incoming.maxBaths { out.maxBaths = v }
        if let v = incoming.minPrice { out.minPrice = v }
        if let v = incoming.maxPrice { out.maxPrice = v }
        if let v = incoming.minSqft { out.minSqft = v }
        if let v = incoming.maxSqft { out.maxSqft = v }
        if let v = incoming.propertyType { out.propertyType = v }
        if incoming.isHotHome == true { out.isHotHome = true }
        if let nbhds = incoming.neighborhoods, !nbhds.isEmpty {
            if addNeighborhoods {
                var combined = out.neighborhoods ?? []
                for n in nbhds where !combined.contains(n) { combined.append(n) }
                out.neighborhoods = combined
            } else {
                out.neighborhoods = nbhds
            }
        }
        return out
    }

    private func detectsAddNeighborhood(in input: String) -> Bool {
        let addPhrases = ["also ", "add ", "include ", "plus ", "and show", "and also", "as well"]
        return addPhrases.contains { input.contains($0) }
    }

    private func extractFilters(from input: String) -> SearchFilters {
        var filters = SearchFilters()

        let bedroomPatterns: [(String, Int)] = [
            ("studio", 0), ("1 bed", 1), ("1 br", 1), ("1-bed", 1), ("one bed", 1),
            ("2 bed", 2), ("2 br", 2), ("2-bed", 2), ("two bed", 2),
            ("3 bed", 3), ("3 br", 3), ("3-bed", 3), ("three bed", 3),
            ("4 bed", 4), ("4 br", 4), ("4-bed", 4), ("four bed", 4),
            ("5 bed", 5), ("5 br", 5), ("5-bed", 5)
        ]
        for (pattern, beds) in bedroomPatterns {
            if input.contains(pattern) {
                filters.minBeds = beds
                break
            }
        }

        let bathPatterns: [(String, Double)] = [
            ("1 bath", 1), ("1 ba", 1), ("one bath", 1),
            ("2 bath", 2), ("2 ba", 2), ("two bath", 2),
            ("3 bath", 3), ("3 ba", 3), ("three bath", 3)
        ]
        for (pattern, baths) in bathPatterns {
            if input.contains(pattern) {
                filters.minBaths = baths
                break
            }
        }

        if input.contains("under 1m") || input.contains("under $1m") || input.contains("below 1m") {
            filters.maxPrice = 1_000_000
        } else if input.contains("under 2m") || input.contains("under $2m") || input.contains("below 2m") {
            filters.maxPrice = 2_000_000
        } else if input.contains("under 3m") || input.contains("under $3m") {
            filters.maxPrice = 3_000_000
        } else if input.contains("under 500") || input.contains("under $500") {
            filters.maxPrice = 500_000
        }

        if input.contains("condo") { filters.propertyType = "Condo" }
        else if input.contains("townhouse") { filters.propertyType = "Townhouse" }
        else if input.contains("co-op") || input.contains("coop") { filters.propertyType = "Co-op" }
        else if input.contains("loft") { filters.propertyType = "Loft" }

        if input.containsAny(["hot home", "hot listing", "trending", "popular"]) {
            filters.isHotHome = true
        }

        let neighborhoods: [(String, String)] = [
            ("upper west side", "Upper West Side"), ("upper west", "Upper West Side"), ("uws", "Upper West Side"),
            ("upper east side", "Upper East Side"), ("upper east", "Upper East Side"), ("ues", "Upper East Side"),
            ("hudson yards", "Hudson Yards"),
            ("hell's kitchen", "Hell's Kitchen"), ("hells kitchen", "Hell's Kitchen"),
            ("murray hill", "Murray Hill"),
            ("financial district", "Financial District"), ("fidi", "Financial District"),
            ("tribeca", "Tribeca"),
            ("soho", "SoHo"),
            ("west village", "West Village"),
            ("east village", "East Village"),
            ("midtown", "Midtown"),
            ("chelsea", "Chelsea"),
            ("harlem", "Harlem"),
            ("williamsburg", "Williamsburg"),
            ("bushwick", "Bushwick"),
            ("park slope", "Park Slope"),
            ("dumbo", "DUMBO"),
            ("long island city", "Long Island City"), ("lic", "Long Island City"),
            ("astoria", "Astoria"),
            ("brooklyn", "Brooklyn"),
            ("queens", "Queens"),
            ("manhattan", "Manhattan"),
            ("eastlake", "Eastlake"),
            ("seattle", "Seattle")
        ]
        var matched: [String] = []
        for (keyword, name) in neighborhoods {
            if input.contains(keyword) && !matched.contains(name) {
                matched.append(name)
            }
        }
        if !matched.isEmpty { filters.neighborhoods = matched }

        return filters
    }

    private func extractAddress(from input: String) -> String? {
        for listing in MockData.listings {
            if input.contains(listing.address.lowercased()) || input.contains(listing.city.lowercased()) {
                return listing.address
            }
        }
        return nil
    }

    private func extractListingId(from input: String) -> String? {
        for listing in MockData.listings {
            if input.contains(listing.address.lowercased()) || input.contains(listing.city.lowercased()) {
                return listing.id
            }
        }
        return nil
    }

    private func buildListingsResponse(from input: String, filters: SearchFilters) -> String {
        let results = searchListings(filters: filters)
        if results.isEmpty {
            return "I couldn't find any listings matching those criteria. Try broadening your search — for example, ask me to show all homes in NYC."
        }

        var parts: [String] = []
        if let beds = filters.minBeds { parts.append(beds == 0 ? "studios" : "\(beds)+ bedroom") }
        if let type = filters.propertyType { parts.append(type.lowercased() + "s") }
        if let neighborhoods = filters.neighborhoods { parts.append("in \(neighborhoods.joined(separator: " & "))") }
        if let maxPrice = filters.maxPrice {
            let fmt = maxPrice >= 1_000_000 ? "$\(maxPrice / 1_000_000)M" : "$\(maxPrice / 1000)K"
            parts.append("under \(fmt)")
        }
        if filters.isHotHome == true { parts.append("that are trending") }

        let count = results.count
        if parts.isEmpty {
            return "I found \(count) home\(count == 1 ? "" : "s") in NYC. Here's what's available:"
        }
        return "I found \(count) \(parts.joined(separator: " ")) home\(count == 1 ? "" : "s"). Take a look:"
    }
}

private extension String {
    func containsAny(_ keywords: [String]) -> Bool {
        let lower = self.lowercased()
        return keywords.contains { lower.contains($0) }
    }
}
