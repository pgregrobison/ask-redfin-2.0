import SwiftUI

struct ContentView: View {
    @State private var viewModel = ListingsViewModel()
    @State private var chatViewModel = ChatViewModel()
    @State private var debugSettings = DebugSettings()
    @State private var myHomeDraft = OTOSetupDraft()
    @State private var askRedfinContext = AskRedfinContextModel()
    @State private var selectedTab: AppTab = .find

    @State private var navigationPath = NavigationPath()
    @State private var forYouPath = NavigationPath()
    @State private var savedPath = NavigationPath()
    @State private var myHomePath = NavigationPath()
    @State private var myRedfinPath = NavigationPath()
    @State private var showTabBar: Bool = true
    @State private var stickyMinimized: Bool = false
    @State private var pendingMapListings: [Listing]?
    @State private var pendingNeighborhoodFocus: [String]?
    @State private var chatDetent: PresentationDetent = .large
    @State private var showDebugPanel: Bool = false
    @State private var showSplash: Bool = false
    @State private var splashChromeOpacity: Double = 1
    @State private var accessoryBarMidY: CGFloat = 0
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var zoomNamespace

    var body: some View {
        rootLayout
            .environment(\.askRedfinContext, askRedfinContext)
            .overlay(alignment: .top) {
                if selectedTab == .find && navigationPath.isEmpty {
                    Group {
                        if debugSettings.findChromeStyle == .searchBar {
                            FindTopBar(viewModel: viewModel, onAskTap: { viewModel.showChat = true })
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
            chatViewModel.debugSettings = debugSettings
            chatViewModel.currentFindFiltersProvider = { [weak viewModel] in
                viewModel?.currentSearchFilters ?? SearchFilters()
            }
            chatViewModel.requestTourDayNotificationHandler = {
                presentFakeTourDayBanner()
            }
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
                },
                onRestartScriptedFlow: {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        restartScriptedDemo()
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.showChat, onDismiss: {
            let nbhds = pendingNeighborhoodFocus
            pendingNeighborhoodFocus = nil
            if let listings = pendingMapListings {
                pendingMapListings = nil
                if let nbhds, !nbhds.isEmpty {
                    viewModel.fitNeighborhoods(nbhds)
                } else {
                    viewModel.fitListings(listings)
                }
            }
            chatDetent = .large
        }) {
            AskRedfinView(
                chatViewModel: chatViewModel,
                allListings: viewModel.listings,
                savedListingIDs: viewModel.savedListingIDs,
                onToggleSave: { listing in viewModel.toggleSaved(listing) },
                onDismiss: {
                    viewModel.showChat = false
                },
                onShowOnMap: { listings, _ in
                    pendingMapListings = listings
                    selectedTab = .find
                    viewModel.showListView = false
                    viewModel.dismissOverlay()
                    viewModel.showChat = false
                },
                onListingTap: { listing in
                    viewModel.showChat = false
                    viewModel.markSeen(listing)
                    navigationPath.append(listing)
                },
                mapFocusActive: isMapFocusEligible,
                selectedDetent: $chatDetent,
                zoomNamespace: zoomNamespace
            )
        }
        .onChange(of: chatViewModel.searchResultsJustArrived) { _, results in
            guard let results, !results.isEmpty else { return }

            if isMapFocusEligible {
                chatViewModel.searchResultsJustArrived = nil
                chatViewModel.searchFiltersJustArrived = nil
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    chatDetent = .fraction(0.7)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    viewModel.fitListings(results, sheetFraction: 0.7)
                }
                return
            }
        }
        .onChange(of: selectedTab) { _, _ in
            updateAskContextForTab()
        }
        .onChange(of: navigationPath.count) { _, _ in
            updateAskContextForTab()
        }
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

    @ViewBuilder
    private var rootLayout: some View {
        if useAccessoryLayout, #available(iOS 26.0, *) {
            accessoryLayout
        } else {
            appNavLayout
        }
    }

    private var useAccessoryLayout: Bool {
        debugSettings.globalEntrypoint == .accessory
    }

    private var appNavLayout: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                tabContent

                if showTabBar {
                    CustomTabBar(selectedTab: $selectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(.keyboard)
            .onChange(of: viewModel.isCardVisible) { _, visible in
                withAnimation(.easeInOut(duration: 0.25)) {
                    showTabBar = !visible
                }
            }
            .navigationDestination(for: Listing.self) { listing in
                listingDetail(for: listing)
            }
        }
    }

    @available(iOS 26.0, *)
    private var accessoryLayout: some View {
        TabView(selection: tabSelectionBinding) {
            Tab(value: AppTab.find) {
                NavigationStack(path: $navigationPath) {
                    FindView(viewModel: viewModel, zoomNamespace: zoomNamespace, isActive: selectedTab == .find, onProfileTap: {}, onListingTap: { listing in
                        navigateToListing(listing)
                    }, showShimmer: mapShimmerActive, accessoryMode: true, hideProfileButton: true, hideListToggle: true)
                    .navigationDestination(for: Listing.self) { listing in
                        listingDetail(for: listing)
                    }
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
                    .navigationDestination(for: Listing.self) { listing in
                        listingDetail(for: listing)
                    }
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
                    .navigationDestination(for: Listing.self) { listing in
                        listingDetail(for: listing)
                    }
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
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Theme.Colors.brandRed)
        .tabViewBottomAccessory {
            // Only shown for the `.classic` top chrome — `.searchBar`'s
            // `FindTopBar` already has its own inline Ask button, so a
            // bottom accessory bar would be redundant.
            if debugSettings.findChromeStyle == .classic {
                AskRedfinAccessoryBar {
                    chatViewModel.focusInputOnAppear = true
                    viewModel.showChat = true
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).midY
                } action: { midY in
                    if midY > 0 { accessoryBarMidY = midY }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: viewModel.isCardVisible) { _, visible in
            if visible { stickyMinimized = true }
        }
        .onChange(of: viewModel.showListView) { _, showing in
            if showing { stickyMinimized = false }
        }
        .onChange(of: navigationPath.count) { _, count in
            if count == 0 { stickyMinimized = false }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            FindView(viewModel: viewModel, zoomNamespace: zoomNamespace, isActive: selectedTab == .find, onProfileTap: { showDebugPanel = true }, onListingTap: { listing in
                navigateToListing(listing)
            }, showShimmer: mapShimmerActive, hideProfileButton: debugSettings.findChromeStyle == .classic, hideListToggle: true)
            .animation(.easeInOut(duration: 0.25), value: mapShimmerActive)
            .opacity(selectedTab == .find ? 1 : 0)
            .allowsHitTesting(selectedTab == .find)

            ForYouView(viewModel: viewModel, zoomNamespace: zoomNamespace, isActive: selectedTab == .forYou, onProfileTap: { showDebugPanel = true }) { listing in
                navigateToListing(listing)
            }
            .opacity(selectedTab == .forYou ? 1 : 0)
            .allowsHitTesting(selectedTab == .forYou)

            SavedView(viewModel: viewModel, zoomNamespace: zoomNamespace, isActive: selectedTab == .saved, onProfileTap: { showDebugPanel = true }) { listing in
                navigateToListing(listing)
            }
            .opacity(selectedTab == .saved ? 1 : 0)
            .allowsHitTesting(selectedTab == .saved)

            MyHomeView(isActive: selectedTab == .myHome, onProfileTap: { showDebugPanel = true }, debugSettings: debugSettings, setupDraft: myHomeDraft)
                .opacity(selectedTab == .myHome ? 1 : 0)
                .allowsHitTesting(selectedTab == .myHome)

            // Its gear opens the debug panel (Find's profile button gave way to the pill bar).
            MyRedfinView(isActive: selectedTab == .myRedfin, onProfileTap: { showDebugPanel = true })
                .opacity(selectedTab == .myRedfin ? 1 : 0)
                .allowsHitTesting(selectedTab == .myRedfin)
        }
    }

    @ViewBuilder
    private func listingDetail(for listing: Listing) -> some View {
        let detail = detailView(for: listing)
            .toolbar(.hidden, for: .tabBar)
            .onAppear { withAnimation(.easeOut(duration: 0.2)) { showTabBar = false } }
            .onDisappear { if !viewModel.isCardVisible { withAnimation(.easeOut(duration: 0.2)) { showTabBar = true } } }

        detail.navigationTransition(.zoom(sourceID: listing.id, in: zoomNamespace))
    }

    @ViewBuilder
    private func detailView(for listing: Listing) -> some View {
        let hideFAB = debugSettings.globalEntrypoint == .accessory
        HybridDetailView(
            listing: listing,
            isSaved: viewModel.isSaved(listing),
            useZoomTransition: true,
            hideAskRedfinFAB: hideFAB,
            onToggleSave: { viewModel.toggleSaved(listing) },
            onAskRedfin: { viewModel.showChat = true }
        )
    }

    private var mapShimmerActive: Bool {
        false
    }

    private var isMapFocusEligible: Bool {
        debugSettings.searchBehavior == .mapFocus
            && selectedTab == .find
            && !viewModel.showListView
    }

    private var shouldMinimizeAccessory: Bool {
        guard selectedTab == .find,
              !viewModel.showListView,
              navigationPath.isEmpty else { return false }
        return stickyMinimized
    }

    @available(iOS 26.0, *)
    private var tabSelectionBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                stickyMinimized = false
                selectedTab = newValue
            }
        )
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

    private func presentFakeTourDayBanner() {
        // Slight delay so the user sees the banner appear after sending the message.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            TourDayBannerWindow.shared.present(onTap: { handleFakeTourDayTap() })
        }
    }

    private func handleFakeTourDayTap() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            navigationPath = NavigationPath()
            selectedTab = .find
            viewModel.showListView = false
            if !viewModel.showChat {
                viewModel.showChat = true
            }
            try? await Task.sleep(for: .milliseconds(400))
            chatViewModel.startTourDay()
        }
    }

    /// Debug-only: resets the seed thread to its pristine starting state and
    /// reopens chat, so `AskRedfinView.onAppear` runs the autoplay script
    /// again from the top — no relaunch needed. See `DebugPanelView`.
    private func restartScriptedDemo() {
        chatViewModel.resetToSeedThread()
        navigationPath = NavigationPath()
        selectedTab = .find
        viewModel.showListView = false
        viewModel.dismissOverlay()
        viewModel.showChat = true
    }
}
