import SwiftUI

struct ContentView: View {
    @State private var viewModel: ListingsViewModel
    @State private var session: AskSession
    @State private var debugSettings = DebugSettings()
    @State private var myHomeDraft = OTOSetupDraft()
    @State private var askRedfinContext = AskRedfinContextModel()
    @State private var selectedTab: AppTab = .find

    @State private var navigationPath = NavigationPath()
    @State private var forYouPath = NavigationPath()
    @State private var savedPath = NavigationPath()
    @State private var myHomePath = NavigationPath()
    @State private var myRedfinPath = NavigationPath()
    @State private var showDebugPanel: Bool = false
    @State private var showSplash: Bool = false
    @State private var splashChromeOpacity: Double = 1
    @State private var accessoryBarMidY: CGFloat = 0
    @Namespace private var zoomNamespace

    init() {
        let listings = ListingsViewModel()
        _viewModel = State(initialValue: listings)
        _session = State(initialValue: AskSession(listings: listings))
    }

    var body: some View {
        tabs
            .environment(\.askRedfinContext, askRedfinContext)
            .overlay(alignment: .top) {
                if selectedTab == .find && navigationPath.isEmpty {
                    Group {
                        if debugSettings.findChromeStyle == .searchBar {
                            FindTopBar(viewModel: viewModel, onAskTap: { session.openChat() })
                        } else {
                            FindPillBar(viewModel: viewModel)
                        }
                    }
                    .opacity(splashChromeOpacity)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .global).maxY
                    } action: { maxY in
                        viewModel.topChromeMaxY = maxY
                    }
                }
            }
            .overlay {
                if session.isComposing {
                    AskComposer(session: session)
                        .transition(.opacity)
                }
            }
            .animation(Nova.Motion.easeOut(), value: session.isComposing)
            .fullScreenCover(isPresented: $showSplash) {
                SplashScreenView(accessoryMidY: $accessoryBarMidY) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        splashChromeOpacity = 1
                    }
                }
                .ignoresSafeArea()
            }
            .tint(.primary)
            .onAppear {
                if !UserDefaults.standard.bool(forKey: "hasSeenIntro") {
                    UserDefaults.standard.set(true, forKey: "hasSeenIntro")
                    selectedTab = .find
                    splashChromeOpacity = 0
                    showSplash = true
                }
                viewModel.debugSettings = debugSettings
                session.onOpenMyHome = { selectedTab = .myHome }
            }
            .sheet(isPresented: $showDebugPanel) {
                DebugPanelView(
                    settings: debugSettings,
                    onPlaySplash: {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(350))
                            selectedTab = .find
                            splashChromeOpacity = 0
                            showSplash = true
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $viewModel.showChat) {
                AskChatSheet(session: session, onHomeLink: highlightHome)
            }
            .onChange(of: selectedTab) { _, _ in updateAskContextForTab() }
            .onChange(of: navigationPath.count) { _, _ in updateAskContextForTab() }
            .onChange(of: viewModel.notificationService.pendingCompassListingID) { _, newID in
                guard let listingID = newID else { return }
                viewModel.notificationService.pendingCompassListingID = nil
                viewModel.showChat = false
                navigationPath = NavigationPath()
                selectedTab = .find
                viewModel.showListView = false
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    if let listing = viewModel.listings.first(where: { $0.id == listingID }) {
                        viewModel.selectedListing = listing
                        viewModel.markSeen(listing)
                        viewModel.fitUserAndListing(listing)
                    } else {
                        viewModel.selectNearestCompassListing(to: nil)
                    }
                }
            }
    }

    // MARK: - Tabs

    /// The Ask bar lives in the iOS 26 tab bar accessory; before that (or with
    /// the "App nav" debug entrypoint) it sits above the native tab bar.
    private var usesAccessory: Bool {
        if #available(iOS 26.0, *) { return debugSettings.globalEntrypoint == .accessory }
        return false
    }

    private var showsAskBar: Bool { debugSettings.findChromeStyle == .classic }

    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 26.0, *), usesAccessory {
            tabView
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    if showsAskBar {
                        AccessoryAskBar(session: session)
                            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { if $0 > 0 { accessoryBarMidY = $0 } }
                    }
                }
        } else {
            tabView
        }
    }

    private var tabView: some View {
        TabView(selection: $selectedTab) {
            Tab(value: AppTab.find) {
                NavigationStack(path: $navigationPath) {
                    FindView(viewModel: viewModel, zoomNamespace: zoomNamespace, isActive: selectedTab == .find, onProfileTap: {}, onListingTap: { listing in
                        navigateToListing(listing)
                    }, accessoryMode: usesAccessory, hideProfileButton: true, hideListToggle: true)
                    .overlay(alignment: .bottom) {
                        AskReplyBubble(session: session)
                            .animation(Nova.Motion.easeOut(), value: session.bubbleText)
                    }
                    .safeAreaInset(edge: .bottom) {
                        if !usesAccessory && showsAskBar {
                            AskBar(session: session, standalone: true)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                        }
                    }
                    .navigationDestination(for: Listing.self) { listing in listingDetail(for: listing) }
                }
                .tint(.primary)
            } label: {
                Label(AppTab.find.title, image: AppTab.find.assetName)
            }
            Tab(value: AppTab.forYou) {
                NavigationStack(path: $forYouPath) {
                    ForYouView(viewModel: viewModel, zoomNamespace: zoomNamespace, isActive: selectedTab == .forYou, onProfileTap: {}, onListingTap: { listing in
                        viewModel.markSeen(listing)
                        forYouPath.append(listing)
                    }, hideProfileButton: true, ownsNavStack: true)
                    .navigationDestination(for: Listing.self) { listing in listingDetail(for: listing) }
                }
                .tint(.primary)
            } label: {
                Label(AppTab.forYou.title, image: AppTab.forYou.assetName)
            }
            Tab(value: AppTab.saved) {
                NavigationStack(path: $savedPath) {
                    SavedView(viewModel: viewModel, zoomNamespace: zoomNamespace, isActive: selectedTab == .saved, onProfileTap: {}, onListingTap: { listing in
                        viewModel.markSeen(listing)
                        savedPath.append(listing)
                    }, hideProfileButton: true, ownsNavStack: true)
                    .navigationDestination(for: Listing.self) { listing in listingDetail(for: listing) }
                }
                .tint(.primary)
            } label: {
                Label(AppTab.saved.title, image: AppTab.saved.assetName)
            }
            Tab(value: AppTab.myHome) {
                NavigationStack(path: $myHomePath) {
                    MyHomeView(isActive: selectedTab == .myHome, onProfileTap: {}, hideProfileButton: true, ownsNavStack: true, debugSettings: debugSettings, setupDraft: myHomeDraft)
                }
                .tint(.primary)
            } label: {
                Label(AppTab.myHome.title, image: AppTab.myHome.assetName)
            }
            Tab(value: AppTab.myRedfin) {
                NavigationStack(path: $myRedfinPath) {
                    MyRedfinView(isActive: selectedTab == .myRedfin, onProfileTap: { showDebugPanel = true }, ownsNavStack: true)
                }
                .tint(.primary)
            } label: {
                Label(AppTab.myRedfin.title, image: AppTab.myRedfin.assetName)
            }
        }
        .tint(Theme.Colors.brandRed)
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Detail

    @ViewBuilder
    private func listingDetail(for listing: Listing) -> some View {
        HybridDetailView(
            listing: listing,
            isSaved: viewModel.isSaved(listing),
            useZoomTransition: true,
            hideAskRedfinFAB: usesAccessory,
            onToggleSave: { viewModel.toggleSaved(listing) },
            onAskRedfin: { session.openChat() }
        )
        .toolbar(.hidden, for: .tabBar)
        .navigationTransition(.zoom(sourceID: listing.id, in: zoomNamespace))
    }

    // MARK: - Helpers

    /// Tapping an address in a reply: close the chat and point at the home.
    private func highlightHome(_ id: String) {
        guard let listing = viewModel.listings.first(where: { $0.id == id }) else { return }
        viewModel.showChat = false
        navigationPath = NavigationPath()
        selectedTab = .find
        viewModel.showListView = false
        viewModel.search.highlighted = [id]
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            viewModel.selectListing(listing)
        }
    }

    private func updateAskContextForTab() {
        // Don't override when a listing detail is on the stack — those views manage context themselves.
        guard navigationPath.isEmpty else { return }
        switch selectedTab {
        case .find:
            askRedfinContext.context = viewModel.showListView
                ? .default
                : (viewModel.selectedListing != nil ? .mapCard : .map)
        case .forYou:
            askRedfinContext.context = .forYou
        case .saved:
            askRedfinContext.context = .saved
        case .myHome:
            askRedfinContext.context = .myHome
        case .myRedfin:
            askRedfinContext.context = .myRedfin
        }
    }

    private func navigateToListing(_ listing: Listing) {
        viewModel.markSeen(listing)
        navigationPath.append(listing)
    }
}

/// The Ask bar inside the iOS 26 tab bar accessory; compact when the tab
/// bar minimizes inline.
@available(iOS 26.0, *)
private struct AccessoryAskBar: View {
    @Bindable var session: AskSession
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        AskBar(session: session, compact: placement == .inline)
    }
}
