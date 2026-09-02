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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if message.role == .user {
            userBubble
        } else if message.role == .assistant {
            assistantBubble
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 6) {
                if let attachments = message.attachments, !attachments.isEmpty {
                    ChatAttachmentGrid(attachments: attachments)
                        .frame(maxWidth: 280)
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(Theme.Typography.body)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs + 2)
                        .background(userBubbleBackground)
                        .clipShape(.rect(cornerRadius: Theme.Radius.chatBubble, style: .continuous))
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
            if !message.content.isEmpty {
                assistantContentText
                    .font(Theme.Typography.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, Theme.Spacing.md)
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

            if let tourRequest = message.tourRequest {
                TourRequestButton(tourRequest: tourRequest, onCompleted: onFlowConfirmed)
            }

            if let mortgageRequest = message.mortgageRequest {
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

            if message.role == .assistant && !message.content.isEmpty && !message.isStreaming {
                feedbackButtons
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var userBubbleBackground: Color {
        colorScheme == .dark
            ? Theme.Colors.Chat.userBubbleDark
            : Theme.Colors.Chat.userBubbleLight
    }

    private var feedbackButtons: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button { onFeedback(.thumbsUp) } label: {
                Image(systemName: message.feedback == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: Theme.IconSize.small, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(message.feedback == .thumbsUp ? .primary : Color.secondary.opacity(0.5))
                    .frame(width: Theme.IconSize.smallTap, height: Theme.IconSize.smallTap)
                    .contentShape(Rectangle())
            }

            Button { onFeedback(.thumbsDown) } label: {
                Image(systemName: message.feedback == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: Theme.IconSize.small, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(message.feedback == .thumbsDown ? .primary : Color.secondary.opacity(0.5))
                    .frame(width: Theme.IconSize.smallTap, height: Theme.IconSize.smallTap)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
}
