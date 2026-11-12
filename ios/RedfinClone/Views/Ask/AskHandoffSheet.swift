import SwiftUI

/// The iOS Vision handoff sheet: before you leave the chat for a tour,
/// Rocket Mortgage or an agent, it shows the home, what they'll see from your
/// search, and what happens next. Tour and Rocket continue into the existing
/// wizards; the agent call is requested right here.
struct AskHandoffSheet: View {
    @Bindable var session: AskSession
    let cta: AskCTA

    @Environment(\.dismiss) private var dismiss
    @State private var path: [Step] = []

    private enum Step: Hashable { case tourWizard, rocketWizard }

    private var listing: Listing? { cta.listingID.flatMap(session.listing) }
    private var search: SearchState { session.listings.search }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Full title as a heading; the nav bar is too narrow for "Get pre-approved…".
                    Text(title).font(.nova(24, .demibold)).foregroundStyle(Nova.Color.text)
                        .accessibilityAddTraits(.isHeader)
                    if let listing { homeSummary(listing) }
                    switch cta.kind {
                    case .rocket: payment
                    case .agent: agentCard
                    default: EmptyView()
                    }
                    shareBox
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { closeButton }
            }
            .safeAreaInset(edge: .bottom) { footer }
            .navigationDestination(for: Step.self) { step in
                wizard(step)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .font(Nova.Typography.body16)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Content

    private var title: String {
        switch cta.kind {
        case .tour: "Tour " + (listing?.address ?? "this home")
        case .rocket: "Get pre-approved with Rocket Mortgage"
        default: "Connect with a Redfin agent"
        }
    }

    private func homeSummary(_ x: Listing) -> some View {
        HStack(spacing: 12) {
            ListingPhoto(url: x.photos.first)
                .frame(width: 88, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(x.address).font(Nova.Typography.label16).foregroundStyle(Nova.Color.text)
                Text("\(x.formattedPrice) · \(x.beds) bd · \(x.bathsFormatted) ba · \(x.sqft > 0 ? x.sqft.formatted() : "—") sq ft")
                    .font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var payment: some View {
        let price = listing?.price ?? cta.price ?? search.filters.maxPrice
        let hoa = listing.map(HomeCatalog.hoa) ?? 0
        let e = AskRouter.payment(price: price, hoa: hoa)
        let cents = { (v: Double) in "$" + Int(v.rounded()).formatted() }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Estimated monthly payment").font(Nova.Typography.label16).foregroundStyle(Nova.Color.text)
            VStack(spacing: 8) {
                LabeledContent("Principal and interest", value: cents(e.pi))
                LabeledContent("Property taxes and insurance", value: cents(e.ti))
                if hoa > 0 { LabeledContent("HOA", value: cents(Double(hoa))) }
                Divider()
                LabeledContent {
                    Text(cents(e.total) + " a month").font(.nova(16, .demibold))
                } label: {
                    Text("Estimated total").font(.nova(16, .demibold))
                }
            }
            .foregroundStyle(Nova.Color.text)
            Text("For \(listing?.address ?? "your top price"), with \(cents(e.down)) down (20%) and a \(AskRouter.rateText) 30-year fixed rate. Your actual rate depends on your credit and the loan.")
                .font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle)
        }
    }

    private var agentCard: some View {
        HStack(spacing: 12) {
            Text("JL")
                .font(.nova(18, .demibold)).foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color(white: 0.067), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(AskRouter.agentName).font(Nova.Typography.label16).foregroundStyle(Nova.Color.text)
                Text("Redfin agent · " + (listing?.neighborhood ?? search.locations[0].replacingOccurrences(of: ", WA", with: "")))
                    .font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "Your agent will know": criteria, the search and saved homes.
    private var shareBox: some View {
        let favs = session.listings.savedListingIDs.count
        let lines = [
            search.criteria.isEmpty ? nil : "What matters to you: " + search.criteria.map { search.pillLabel(for: $0).lowercased() }.joined(separator: ", "),
            "Your search: " + search.locationPhrase + search.pricePhrase,
            favs > 0 ? (favs == 1 ? "1 saved home" : "\(favs) saved homes") : nil,
        ].compactMap { $0 }
        return VStack(alignment: .leading, spacing: 10) {
            Text(shareTitle).font(Nova.Typography.label14).foregroundStyle(Nova.Color.text)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    NovaIcon("check", size: 16).foregroundStyle(Nova.Color.text)
                    Text(line).font(Nova.Typography.body14).foregroundStyle(Nova.Color.text)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Nova.Color.bgSecondary, in: RoundedRectangle(cornerRadius: Nova.Radius.field))
    }

    private var shareTitle: String {
        switch cta.kind {
        case .tour: "Your agent will know"
        case .rocket: "What Rocket will see"
        default: "What \(AskRouter.agentFirst) will see"
        }
    }

    // MARK: Footer and actions

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(note).font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(ctaLabel, action: go)
                .buttonStyle(.nova(.primary))
        }
        .padding(EdgeInsets(top: 12, leading: 24, bottom: 8, trailing: 16))
        .background(.bar)
    }

    private var note: String {
        switch cta.kind {
        case .tour: "Free, with no obligation. A Redfin agent will confirm by text."
        case .rocket: "You’ll continue on Rocket Mortgage. Your Redfin search stays here."
        default: "\(AskRouter.agentFirst) usually calls back within an hour."
        }
    }

    private var ctaLabel: String {
        switch cta.kind {
        case .tour: "Request tour"
        case .rocket: "Continue to Rocket"
        default: "Request a call"
        }
    }

    private func go() {
        switch cta.kind {
        case .tour: path.append(.tourWizard)
        case .rocket: path.append(.rocketWizard)
        default:
            let favs = session.listings.savedListingIDs.count
            session.completeHandoff(cta, tool: "Requested a call from \(AskRouter.agentName)",
                                    reply: "\(AskRouter.agentFirst) will call you within the hour. They can see your search, your criteria" + (favs > 0 ? " and your saved homes" : "") + ", so you can pick up where you left off.")
            dismiss()
        }
    }

    @ViewBuilder
    private func wizard(_ step: Step) -> some View {
        switch step {
        case .tourWizard:
            TourBookingFlowView(tourRequest: TourRequest(listingId: listing?.id, address: listing?.address)) { summary in
                session.completeHandoff(cta, tool: "Requested a tour of \(listing?.address ?? "this home")", reply: summary)
                dismiss()
            }
        case .rocketWizard:
            MortgagePrequalFlowView(mortgageRequest: MortgageRequest(listingId: listing?.id)) { summary in
                session.completeHandoff(cta, tool: "Shared your search with Rocket Mortgage", reply: summary)
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close) { dismiss() } label: { NovaIcon("close", size: 20) }
        } else {
            Button { dismiss() } label: { NovaIcon("close", size: 20) }.accessibilityLabel("Close")
        }
    }
}
