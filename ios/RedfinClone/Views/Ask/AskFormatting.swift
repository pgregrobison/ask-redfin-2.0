import SwiftUI

/// Reply text formatting from the prototype's `segsOf`: street addresses
/// become tappable links (askredfin://home/<id>), money, distances, sq ft,
/// transit scores and home counts render medium weight.
@MainActor
enum AskFormatting {
    private static let addressPattern: NSRegularExpression? = {
        let streets = Set(HomeCatalog.shared.listings.map(\.address)).sorted { $0.count > $1.count }
        guard !streets.isEmpty else { return nil }
        return try? NSRegularExpression(pattern: "(" + streets.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")")
    }()
    private static let boldPattern = try? NSRegularExpression(
        pattern: #"\$[\d,.]+[KM]?(?: a month)?|\b\d+(?:\.\d+)? mi\b|\b[\d,]+ sq ft\b|\btransit score(?: of)? \d+\b|\b\d+ of the \d+ (?:lower-priced )?homes\b|\b\d+ (?:homes?|short sales?|grocery stores?)\b"#,
        options: [.caseInsensitive]
    )
    private static let homeIDByStreet: [String: String] = Dictionary(
        HomeCatalog.shared.listings.map { ($0.address, $0.id) }, uniquingKeysWith: { a, _ in a }
    )

    /// The first `revealed` characters styled; the rest kept but clear so
    /// layout doesn't jump while streaming.
    static func attributed(_ text: String, revealed: Int? = nil) -> AttributedString {
        var out = AttributedString(text)
        out.font = Nova.Typography.body16
        out.foregroundColor = Nova.Color.text
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        boldPattern?.enumerateMatches(in: text, range: full) { m, _, _ in
            guard let m, let r = Range(m.range, in: text), let ar = Range(r, in: out) else { return }
            out[ar].font = .nova(16, .medium)
        }
        addressPattern?.enumerateMatches(in: text, range: full) { m, _, _ in
            guard let m, let r = Range(m.range, in: text), let ar = Range(r, in: out),
                  let id = homeIDByStreet[String(text[r])] else { return }
            out[ar].font = .nova(16, .medium)
            out[ar].underlineStyle = .single
            out[ar].link = URL(string: "askredfin://home/\(id)")
        }
        if let revealed, revealed < text.count {
            let start = text.index(text.startIndex, offsetBy: revealed)
            if let ar = Range(start..<text.endIndex, in: out) {
                out[ar].foregroundColor = .clear
                out[ar].underlineStyle = nil
            }
        }
        return out
    }

    /// Nova icon for a tool confirmation (the prototype's `TOOL_ICONS`).
    static func toolIcon(_ t: String) -> String {
        let rules: [(String, String)] = [
            (#"dream home"#, "house"), (#"^watch|^stopped watching"#, "notifications_active"), (#"photo"#, "image_search"),
            (#"^planned|stops for"#, "route"), (#"^compared"#, "compare_arrows"), (#"^hid "#, "visibility_off"), (#"square feet"#, "filter_handles"),
            (#"tour"#, "calendar_clock"), (#"rocket|pre-?approv"#, "mortgage"), (#"call from|agent"#, "real_estate_agent"),
            (#"restored|cleared your search|memory|opened your chat"#, "history"), (#"^undid"#, "refresh"), (#"helpful"#, "thumb_up_off_alt"),
            (#"feedback"#, "thumbs_up_down"), (#"^showing \d+ homes? like"#, "other_houses"), (#"walk time"#, "directions_walk"),
            (#"(drive|transit|bike) time"#, "route"), (#"^colou?red and sorted"#, "layers"), (#"saved search"#, "saved_search"),
            (#"dealbreaker"#, "close"), (#"must-have"#, "check_circle"), (#"“"#, "star_shining"), (#"short sale"#, "home_price_down"),
            (#"home type"#, "house"), (#"area|^added |^removed |moved your search|search to"#, "location"), (#"price"#, "attach_money"),
            (#"beds|baths"#, "bed"),
        ]
        for (p, icon) in rules where t.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil { return icon }
        if t.range(of: #"\bon [A-Z0-9]"#, options: .regularExpression) != nil { return "map" }
        return "filter_handles"
    }
}
