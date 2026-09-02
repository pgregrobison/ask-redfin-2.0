import SwiftUI
import PhotosUI

struct AskRedfinView: View {
    @Bindable var chatViewModel: ChatViewModel
    let allListings: [Listing]
    let savedListingIDs: Set<String>
    let onToggleSave: (Listing) -> Void
    let onDismiss: () -> Void
    let onShowOnMap: ([Listing], SearchFilters?) -> Void
    let onListingTap: (Listing) -> Void
    var mapFocusActive: Bool = false
    @Binding var selectedDetent: PresentationDetent
    var zoomNamespace: Namespace.ID? = nil
    @FocusState private var isInputFocused: Bool
    @State private var scrollToTopTrigger: String?
    @State private var scrollToBottomTrigger: String?
    @State private var hasRestoredScroll: Bool = false
    @State private var photoLibrarySelection: [PhotosPickerItem] = []
    @State private var showPhotoLibrary: Bool = false
    @State private var cameraMode: ChatCameraPicker.Mode? = nil

    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        ZStack(alignment: .bottom) {
            messageList
            inputFooter
        }
        .background(Theme.Colors.background)
        .environment(\.horizontalSizeClass, .regular)
        .presentationDragIndicator(.visible)
        .presentationDetents(mapFocusActive ? [.fraction(0.7), .large] : [.large], selection: $selectedDetent)
        .presentationContentInteraction(mapFocusActive && selectedDetent != .large ? .resizes : .scrolls)
        .presentationBackgroundInteraction(mapFocusActive ? .enabled(upThrough: .fraction(0.7)) : .automatic)
    }

    private var headerBar: some View {
        HStack {
            threadSwitcherMenu
            Spacer()
            GlassActionButton(icon: "xmark", action: onDismiss)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Theme.Colors.background, location: 0),
                    .init(color: Theme.Colors.background.opacity(0.6), location: 0.4),
                    .init(color: Theme.Colors.background.opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.bottom, -Theme.Spacing.lg)
            .allowsHitTesting(false),
            alignment: .top
        )
    }

    @ViewBuilder
    private var threadSwitcherMenu: some View {
        if #available(iOS 26.0, *) {
            threadSwitcherMenuContent
                .glassEffect(in: .capsule)
        } else {
            threadSwitcherMenuContent
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var threadSwitcherMenuContent: some View {
        Menu {
            Button {
                chatViewModel.createNewThread()
            } label: {
                Label("New Chat", systemImage: "plus.bubble")
            }

            if !chatViewModel.threads.isEmpty {
                Divider()
                ForEach(chatViewModel.threads) { thread in
                    Button {
                        chatViewModel.switchToThread(thread.id)
                    } label: {
                        HStack {
                            Text(thread.title)
                            if thread.id == chatViewModel.activeThreadId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xxs + 2) {
                if chatViewModel.isTourDayThread {
                    Image(systemName: "car")
                        .font(.system(size: Theme.Spacing.sm, weight: .semibold))
                }
                Text(truncatedTitle)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: Theme.Spacing.xs + 2, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .frame(height: Theme.ButtonSize.minHeight)
            .padding(.horizontal, Theme.Spacing.sm + 2)
        }
        .tint(.primary)
    }

    private var isEmptyChat: Bool {
        chatViewModel.activeMessages.filter { $0.role == .user }.isEmpty
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    Color.clear.frame(height: 0)

                    if isEmptyChat {
                        NewChatEmptyStateView(
                            lastFilters: chatViewModel.lastSessionFilters,
                            onSuggestionTap: { prompt in
                                chatViewModel.inputText = prompt
                                chatViewModel.sendMessage()
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    } else {
                        chatTitleHeader
                        ForEach(chatViewModel.activeMessages) { message in
                            ChatMessageBubble(
                                message: message,
                                allListings: allListings,
                                savedListingIDs: savedListingIDs,
                                onToggleSave: onToggleSave,
                                onFeedback: { feedback in
                                    chatViewModel.setFeedback(feedback, for: message.id)
                                },
                                onShowOnMap: onShowOnMap,
                                onListingTap: onListingTap,
                                onNewChat: { chatViewModel.createNewThread() },
                                onFlowConfirmed: { text in chatViewModel.postFlowConfirmation(text) },
                                carouselScrollPosition: Binding(
                                    get: { chatViewModel.carouselScrollPositions[message.id] },
                                    set: { chatViewModel.carouselScrollPositions[message.id] = $0 }
                                ),
                                zoomNamespace: zoomNamespace
                            )
                            .id(message.id)
                        }

                        ThinkingIndicator(label: chatViewModel.thinkingState.label)
                            .opacity(chatViewModel.thinkingState != .none ? 1 : 0)
                            .frame(height: chatViewModel.thinkingState != .none ? nil : 0)
                            .clipped()
                            .animation(.easeInOut(duration: 0.25), value: chatViewModel.thinkingState)
                            .id("thinking")
                    }

                    Color.clear
                        .frame(height: currentBottomSpacerHeight)
                        .id("bottom-spacer")
                }
                .animation(.easeInOut(duration: 0.25), value: isEmptyChat)
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.md)
            }
            .contentMargins(.top, 0)
            .contentMargins(.bottom, chatViewModel.isVoiceModeActive ? 220 : 72)
            .safeAreaInset(edge: .top, spacing: 0) {
                headerBar
            }
            .scrollDisabled(mapFocusActive && selectedDetent != .large)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                guard !hasRestoredScroll else { return }
                hasRestoredScroll = true
                if let threadId = chatViewModel.activeThreadId,
                   let savedId = chatViewModel.scrollPositions[threadId] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        proxy.scrollTo(savedId, anchor: .bottom)
                    }
                } else if let lastId = chatViewModel.activeMessages.last?.id {
                    // No saved scroll position yet (e.g. a freshly seeded demo
                    // thread) — jump straight to the bottom of the thread.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onDisappear {
                saveCurrentScrollPosition()
                hasRestoredScroll = false
            }
            .onChange(of: scrollToTopTrigger) { _, targetId in
                guard let targetId else { return }
                scrollToTopTrigger = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        proxy.scrollTo(targetId, anchor: .top)
                    }
                }
            }
            .onChange(of: chatViewModel.voiceScrollToTopId) { _, targetId in
                guard let targetId else { return }
                chatViewModel.voiceScrollToTopId = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        proxy.scrollTo(targetId, anchor: .top)
                    }
                }
            }
            .onChange(of: scrollToBottomTrigger) { _, targetId in
                guard let targetId else { return }
                scrollToBottomTrigger = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo(targetId, anchor: .bottom)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .chatWidgetFieldFocused)) { notification in
                guard let msgID = notification.userInfo?["messageID"] as? String else { return }
                scrollToBottomTrigger = msgID
            }
            .onChange(of: chatViewModel.activeThreadId) { oldId, _ in
                if let oldId, let lastVisible = chatViewModel.threads.first(where: { $0.id == oldId })?.messages.last?.id {
                    chatViewModel.scrollPositions[oldId] = lastVisible
                }
                if let threadId = chatViewModel.activeThreadId {
                    chatViewModel.bottomSpacerHeights[threadId] = 0
                }
                if let currentId = chatViewModel.activeThreadId, let savedId = chatViewModel.scrollPositions[currentId] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        proxy.scrollTo(savedId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var chatTitleHeader: some View {
        HStack(spacing: Theme.Spacing.xs + 2) {
            Image(systemName: "sparkle")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Ask Redfin")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xs)
    }

    private var canSend: Bool {
        !chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !chatViewModel.pendingAttachments.isEmpty
    }

    private var showAttachButton: Bool {
        isInputFocused && !chatViewModel.isVoiceModeActive
    }

    private var inputFooter: some View {
        VStack(spacing: 0) {
            if chatViewModel.isVoiceModeActive {
                InlineVoiceOrb(isListening: !chatViewModel.isVoiceMuted)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                    .padding(.bottom, Theme.Spacing.sm)
            }

            if !chatViewModel.pendingAttachments.isEmpty {
                ChatAttachmentPreviewTray(
                    attachments: chatViewModel.pendingAttachments,
                    onRemove: { att in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            chatViewModel.removePendingAttachment(att)
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            inputBar
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: chatViewModel.isVoiceModeActive)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: chatViewModel.pendingAttachments.count)
        .background(
            ChatPhotoLibraryPicker(
                selection: $photoLibrarySelection,
                isPresented: $showPhotoLibrary,
                onPicked: { items in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        chatViewModel.addPendingAttachments(items)
                    }
                }
            )
        )
        .fullScreenCover(item: $cameraMode) { mode in
            ChatCameraPicker(
                mode: mode,
                onPicked: { att in
                    cameraMode = nil
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        chatViewModel.addPendingAttachment(att)
                    }
                },
                onCancel: { cameraMode = nil }
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var attachMenuButton: some View {
        Menu {
            Button {
                cameraMode = .photo
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
            Button {
                cameraMode = .video
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("Record Video", systemImage: "video")
            }
            Button {
                showPhotoLibrary = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            attachMenuLabel
        }
        .menuOrder(.fixed)
        .tint(.primary)
    }

    @ViewBuilder
    private var attachMenuLabel: some View {
        let icon = Image(systemName: "plus")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: Theme.ButtonSize.circleSize, height: Theme.ButtonSize.circleSize)
            .contentShape(Circle())
        if #available(iOS 26.0, *) {
            icon.glassEffect(.regular.interactive(), in: .circle)
        } else {
            icon.background(.ultraThinMaterial, in: Circle())
        }
    }

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if showAttachButton {
                attachMenuButton
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3).combined(with: .opacity),
                        removal: .scale(scale: 0.3).combined(with: .opacity)
                    ))
            }

            TextField("Ask or search anything", text: $chatViewModel.inputText, axis: .vertical)
                .font(Theme.Typography.body)
                .lineSpacing(7)
                .frame(minHeight: 24)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .task {
                    if chatViewModel.focusInputOnAppear {
                        chatViewModel.focusInputOnAppear = false
                        isInputFocused = true
                    }
                }
                .disabled(chatViewModel.isVoiceModeActive)
                .opacity(chatViewModel.isVoiceModeActive ? 0.4 : 1)
                .onSubmit {
                    sendAndScroll()
                }
                .padding(.leading, Theme.Spacing.md)
                .padding(.trailing, chatViewModel.isVoiceModeActive ? Theme.Spacing.sm : 54)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    inputBackground
                )
                .overlay(alignment: .bottomTrailing) {
                    if !chatViewModel.isVoiceModeActive {
                        HStack(spacing: 4) {
                            if chatViewModel.thinkingState != .none {
                                Button {
                                    chatViewModel.stopStreaming()
                                } label: {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Theme.Colors.invertedPrimary)
                                        .frame(width: Theme.ButtonSize.circleSize, height: Theme.ButtonSize.circleSize)
                                        .background(Color.primary)
                                        .clipShape(Circle())
                                }
                                .transition(.scale.combined(with: .opacity))
                            } else if canSend {
                                Button {
                                    sendAndScroll()
                                } label: {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: Theme.ButtonSize.iconSize, weight: .bold))
                                        .foregroundStyle(Theme.Colors.invertedPrimary)
                                        .frame(width: Theme.ButtonSize.circleSize, height: Theme.ButtonSize.circleSize)
                                        .background(Color.primary)
                                        .clipShape(Circle())
                                }
                                .transition(.scale.combined(with: .opacity))
                            } else {
                                Button {
                                    isInputFocused = false
                                    chatViewModel.activateVoiceMode()
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } label: {
                                    Image(systemName: "waveform")
                                        .font(.system(size: Theme.ButtonSize.iconSize, weight: .bold))
                                        .foregroundStyle(Theme.Colors.invertedPrimary)
                                        .frame(width: Theme.ButtonSize.circleSize, height: Theme.ButtonSize.circleSize)
                                        .background(Color.primary)
                                        .clipShape(Circle())
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canSend)
                        .animation(.easeInOut(duration: 0.15), value: chatViewModel.thinkingState != .none)
                        .padding(.trailing, 2)
                        .padding(.bottom, 2)
                    }
                }

            if chatViewModel.isVoiceModeActive {
                Button {
                    chatViewModel.toggleVoiceMute()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: chatViewModel.isVoiceMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(chatViewModel.isVoiceMuted ? .white : .primary)
                        .frame(width: Theme.ButtonSize.circleSize, height: Theme.ButtonSize.circleSize)
                        .background(chatViewModel.isVoiceMuted ? Color.red : Theme.Colors.fill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))

                Button {
                    chatViewModel.deactivateVoiceMode()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.invertedPrimary)
                        .frame(width: Theme.ButtonSize.circleSize, height: Theme.ButtonSize.circleSize)
                        .background(Color.primary)
                        .clipShape(Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: chatViewModel.isVoiceModeActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chatViewModel.isVoiceMuted)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: showAttachButton)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xs)
    }

    @ViewBuilder
    private var inputBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: Theme.Colors.Chat.inputCornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(in: .capsule)
        } else {
            RoundedRectangle(cornerRadius: Theme.Colors.Chat.inputCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private var truncatedTitle: String {
        let title = chatViewModel.activeThread?.title ?? "Ask Redfin"
        if title.count > 15 {
            return String(title.prefix(15)) + "…"
        }
        return title
    }

    private var currentBottomSpacerHeight: CGFloat {
        guard let threadId = chatViewModel.activeThreadId else { return 0 }
        return chatViewModel.bottomSpacerHeights[threadId] ?? 0
    }

    private func saveCurrentScrollPosition() {
        guard let threadId = chatViewModel.activeThreadId,
              let lastMsgId = chatViewModel.activeMessages.last?.id else { return }
        chatViewModel.scrollPositions[threadId] = lastMsgId
    }

    private func sendAndScroll() {
        let willSendText = chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !willSendText.isEmpty else { return }
        isInputFocused = false
        chatViewModel.sendMessage()
        guard let lastUserMsg = chatViewModel.activeMessages.last(where: { $0.role == .user }) else { return }

        let msgId = lastUserMsg.id
        if let threadId = chatViewModel.activeThreadId {
            chatViewModel.bottomSpacerHeights[threadId] = UIScreen.main.bounds.height
        }
        scrollToTopTrigger = msgId
    }
}
