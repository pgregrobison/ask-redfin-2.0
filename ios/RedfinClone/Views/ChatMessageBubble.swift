import SwiftUI

struct ChatMessageBubble: View {
    let message: ChatMessage
    let allListings: [Listing]
    let savedListingIDs: Set<String>
    let onToggleSave: (Listing) -> Void
    let onFeedback: (MessageFeedback) -> Void
    let onShowOnMap: ([Listing], SearchFilters?) -> Void
    let onListingTap: (Listing) -> Void
    var onNewChat: (() -> Void)? = nil
    var onFlowConfirmed: (String) -> Void = { _ in }
    @Binding var carouselScrollPosition: String?
    var zoomNamespace: Namespace.ID?

    var body: some View {
        if message.role == .user {
            userBubble
        } else if message.role == .assistant {
            assistantBubble
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                if let attachments = message.attachments, !attachments.isEmpty {
                    ChatAttachmentGrid(attachments: attachments)
                        .frame(maxWidth: 280)
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(Theme.Typography.body)
                        .lineSpacing(4)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.inset)
                        .clipShape(.rect(
                            topLeadingRadius: Theme.Radius.large,
                            bottomLeadingRadius: Theme.Radius.large,
                            bottomTrailingRadius: 6,
                            topTrailingRadius: Theme.Radius.large,
                            style: .continuous
                        ))
                }
            }
        }
        .padding(.leading, Theme.Spacing.md + Theme.Spacing.xl)
        .padding(.trailing, Theme.Spacing.md)
    }

    private var assistantBubble: some View {
        // Figma (node 395:999): message items within a received group stack at
        // 12pt gaps; the thumbs action bar sits 8pt below the last item.
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            assistantContent

            if message.role == .assistant && !message.content.isEmpty && !message.isStreaming {
                feedbackButtons
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: message.scriptedTourConfirmation)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: message.scriptedMortgageConfirmation)
    }

    private var assistantContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if !message.content.isEmpty {
                assistantContentText
                    .font(Theme.Typography.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding(.leading, Theme.Spacing.md)
                    .padding(.trailing, Theme.Spacing.md + Theme.Spacing.xl)
            }

            if let searchResults = message.searchResults, !searchResults.isEmpty {
                ChatListingCards(
                    listingIds: searchResults,
                    allListings: allListings,
                    savedListingIDs: savedListingIDs,
                    onToggleSave: onToggleSave,
                    filters: message.searchFilters,
                    onShowOnMap: onShowOnMap,
                    onListingTap: onListingTap,
                    scrolledListingID: $carouselScrollPosition,
                    zoomNamespace: zoomNamespace
                )
            }

            if let confirmation = message.scriptedTourConfirmation {
                ScriptedTourConfirmationCard(confirmation: confirmation, allListings: allListings)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let tourRequest = message.tourRequest {
                TourRequestButton(tourRequest: tourRequest, onCompleted: onFlowConfirmed)
            }

            if let confirmation = message.scriptedMortgageConfirmation {
                ScriptedMortgagePrequalCard(confirmation: confirmation)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let mortgageRequest = message.mortgageRequest {
                MortgageRequestButton(mortgageRequest: mortgageRequest, onCompleted: onFlowConfirmed)
            }

            if message.isStaleChatPrompt {
                StaleChatWidget(onNewChat: onNewChat ?? {})
            }

            if let route = message.tourDayRoute {
                TourRouteMapWidget(route: route, allListings: allListings, onStopTap: onListingTap)
            }

            if let stopListingId = message.tourDayCurrentStopId,
               let listing = allListings.first(where: { $0.id == stopListingId }),
               let stop = TourDayData.demoRoute.stops.first(where: { $0.listingId == stopListingId }) {
                TourDayStopCard(
                    listing: listing,
                    stopNumber: stop.id,
                    totalStops: TourDayData.demoRoute.stops.count,
                    time: stop.time,
                    onTap: { onListingTap(listing) }
                )
            }
        }
    }

    private var assistantContentText: Text {
        let raw = message.content
        guard raw.contains("{waveform}") else { return Text(raw) }
        let parts = raw.components(separatedBy: "{waveform}")
        var result = Text(parts[0])
        for i in 1..<parts.count {
            result = result
                + Text(Image(systemName: "waveform")).fontWeight(.semibold)
                + Text(parts[i])
        }
        return result
    }

    // Figma: 20px icons with a 12px visual gap between them. Icons sit in
    // 24pt frames (2pt overhang each side), so 8pt of stack spacing yields
    // the 12px visual gap.
    private var feedbackButtons: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button { onFeedback(.thumbsUp) } label: {
                Image(systemName: message.feedback == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 18, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(message.feedback == .thumbsUp ? .primary : Color.secondary.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle().inset(by: -8))
            }

            Button { onFeedback(.thumbsDown) } label: {
                Image(systemName: message.feedback == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 18, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(message.feedback == .thumbsDown ? .primary : Color.secondary.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle().inset(by: -8))
            }
        }
        .padding(.leading, Theme.Spacing.md)
    }
}
