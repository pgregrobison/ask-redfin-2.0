import Foundation
import CoreLocation

/// Search areas from the prototype's `regions.json` (cities, ZIPs,
/// neighborhoods, a school district), plus a buffered hull around the
/// listings of every other neighborhood in the data.
nonisolated final class SearchRegions: Sendable {
    static let shared = SearchRegions(listings: HomeCatalog.shared.listings)

    /// A place you can pick in the location search.
    struct Place: Hashable, Sendable {
        let name: String
        let kind: String
        /// Nova icon name.
        let icon: String
    }

    /// One outer ring of `[latitude, longitude]` points (holes aren't used in the data).
    struct Polygon: Sendable {
        let ring: [CLLocationCoordinate2D]
        let minLat: Double, maxLat: Double, minLng: Double, maxLng: Double

        init(ring: [CLLocationCoordinate2D]) {
            self.ring = ring
            minLat = ring.map(\.latitude).min() ?? 0
            maxLat = ring.map(\.latitude).max() ?? 0
            minLng = ring.map(\.longitude).min() ?? 0
            maxLng = ring.map(\.longitude).max() ?? 0
        }

        func contains(_ p: CLLocationCoordinate2D) -> Bool {
            guard p.latitude >= minLat, p.latitude <= maxLat, p.longitude >= minLng, p.longitude <= maxLng else { return false }
            var inside = false
            var j = ring.count - 1
            for i in ring.indices {
                let a = ring[i], b = ring[j]
                if (a.latitude > p.latitude) != (b.latitude > p.latitude),
                   p.longitude < (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude {
                    inside.toggle()
                }
                j = i
            }
            return inside
        }

        var area: Double { (maxLat - minLat) * (maxLng - minLng) }

        /// Bounding-box containment, like the prototype's `inside(a, b)`.
        func isInside(_ other: Polygon) -> Bool {
            let e = 1e-4
            return minLat >= other.minLat - e && minLng >= other.minLng - e && maxLat <= other.maxLat + e && maxLng <= other.maxLng + e
        }
    }

    static let defaultLocation = "Seattle, WA"
    static let basePlaces: [Place] = [
        Place(name: "Seattle, WA", kind: "City", icon: "apartment"),
        Place(name: "Ballard", kind: "Neighborhood in Seattle", icon: "house"),
        Place(name: "Fremont", kind: "Neighborhood in Seattle", icon: "house"),
        Place(name: "Phinney Ridge", kind: "Neighborhood in Seattle", icon: "house"),
        Place(name: "Green Lake", kind: "Neighborhood in Seattle", icon: "house"),
        Place(name: "Capitol Hill", kind: "Neighborhood in Seattle", icon: "house"),
        Place(name: "Queen Anne", kind: "Neighborhood in Seattle", icon: "house"),
        Place(name: "98103", kind: "ZIP code", icon: "map"),
        Place(name: "98105", kind: "ZIP code", icon: "map"),
        Place(name: "Shoreline, WA", kind: "City", icon: "apartment"),
        Place(name: "Bellevue, WA", kind: "City", icon: "apartment"),
        Place(name: "Kirkland, WA", kind: "City", icon: "apartment"),
        Place(name: "Seattle Public Schools", kind: "School district", icon: "school"),
    ]

    let polygons: [String: Polygon]
    /// Every searchable place: the prototype's list, then data neighborhoods.
    let places: [Place]

    init(listings: [Listing]) {
        var polys = Self.loadPolygons()
        var places = Self.basePlaces

        // Neighborhoods without a polygon get the listings' convex hull, buffered 0.35 km.
        var byHood: [String: [CLLocationCoordinate2D]] = [:]
        for l in listings {
            guard let hood = l.neighborhood, hood.lowercased() != "seattle", polys[hood] == nil else { continue }
            byHood[hood, default: []].append(l.coordinate)
        }
        for hood in byHood.keys.sorted() {
            let pts = byHood[hood]!
            guard pts.count >= 2 else { continue }
            polys[hood] = Polygon(ring: Self.bufferedHull(pts, km: 0.35))
            if !places.contains(where: { $0.name == hood }) {
                places.append(Place(name: hood, kind: "Neighborhood in Seattle", icon: "house"))
            }
        }
        polygons = polys
        self.places = places
    }

    /// Resolves loose names ("seattle", "Bellevue") to a place name ("Seattle, WA").
    func canonicalName(_ name: String) -> String {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        if let exact = places.first(where: { $0.name.lowercased() == key }) { return exact.name }
        if let city = places.first(where: { $0.name.lowercased() == key + ", wa" }) { return city.name }
        return name
    }

    /// Homes inside any of the given areas. Unknown names fall back to
    /// matching the listing's neighborhood or city; no matches means everywhere.
    func pool(_ listings: [Listing], locations: [String]) -> [Listing] {
        let polys = locations.compactMap { polygons[$0] }
        let loose = locations.filter { polygons[$0] == nil }.map { $0.lowercased() }
        guard !polys.isEmpty || !loose.isEmpty else { return listings }
        let matched = listings.filter { l in
            polys.contains { $0.contains(l.coordinate) }
                || loose.contains { $0 == l.neighborhood?.lowercased() || $0 == l.city.lowercased() }
        }
        return polys.isEmpty && matched.isEmpty ? listings : matched
    }

    /// Adding a place drops any current area it sits inside or that sits
    /// inside it ("Ballard" replaces "Seattle, WA"), like the prototype's `planLoc`.
    func adding(_ name: String, to locations: [String]) -> [String] {
        guard !locations.contains(name) else { return locations }
        guard let new = polygons[name] else { return locations + [name] }
        return locations.filter { l in
            guard let p = polygons[l] else { return true }
            return !(new.isInside(p) || p.isInside(new))
        } + [name]
    }

    /// Bounding box of the given areas as (minLat, maxLat, minLng, maxLng).
    func bounds(of locations: [String]) -> (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double)? {
        let polys = locations.compactMap { polygons[$0] }
        guard !polys.isEmpty else { return nil }
        return (polys.map(\.minLat).min()!, polys.map(\.maxLat).max()!, polys.map(\.minLng).min()!, polys.map(\.maxLng).max()!)
    }

    /// The smallest area that contains all of `locations`, for "show more homes".
    func widerArea(than locations: [String]) -> String? {
        let current = locations.compactMap { polygons[$0] }
        guard !current.isEmpty else { return nil }
        return polygons
            .filter { name, poly in
                name != "Seattle Public Schools" && !locations.contains(name) && current.allSatisfy { $0.isInside(poly) && !($0.area == poly.area) }
            }
            .min { $0.value.area < $1.value.area }?
            .key
    }

    // MARK: - Loading

    private static func loadPolygons() -> [String: Polygon] {
        guard let url = Bundle.main.url(forResource: "regions", withExtension: "json")
                ?? Bundle.main.url(forResource: "regions", withExtension: "json", subdirectory: "Resources/Data"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
        else { return [:] }
        var out: [String: Polygon] = [:]
        for (name, geo) in json {
            guard let rings = geo["coordinates"] as? [[[Double]]], let outer = rings.first else { continue }
            let ring = outer.compactMap { p in p.count >= 2 ? CLLocationCoordinate2D(latitude: p[1], longitude: p[0]) : nil }
            if ring.count >= 3 { out[name] = Polygon(ring: ring) }
        }
        return out
    }

    /// Convex hull of the points, grown outward by `km` (a 16-gon around each
    /// hull point, re-hulled), approximating turf's `buffer(convex(...))`.
    private static func bufferedHull(_ pts: [CLLocationCoordinate2D], km: Double) -> [CLLocationCoordinate2D] {
        let dLat = km / 111.32
        var grown: [CLLocationCoordinate2D] = []
        for p in convexHull(pts) {
            let dLng = km / (111.32 * cos(p.latitude * .pi / 180))
            for k in 0..<16 {
                let a = Double(k) / 16 * 2 * .pi
                grown.append(CLLocationCoordinate2D(latitude: p.latitude + dLat * sin(a), longitude: p.longitude + dLng * cos(a)))
            }
        }
        return convexHull(grown)
    }

    /// Andrew's monotone chain.
    private static func convexHull(_ pts: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        let p = pts.sorted { ($0.longitude, $0.latitude) < ($1.longitude, $1.latitude) }
        guard p.count > 2 else { return p }
        func cross(_ o: CLLocationCoordinate2D, _ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
            (a.longitude - o.longitude) * (b.latitude - o.latitude) - (a.latitude - o.latitude) * (b.longitude - o.longitude)
        }
        var lower: [CLLocationCoordinate2D] = [], upper: [CLLocationCoordinate2D] = []
        for q in p {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], q) <= 0 { lower.removeLast() }
            lower.append(q)
        }
        for q in p.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], q) <= 0 { upper.removeLast() }
            upper.append(q)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }
}
