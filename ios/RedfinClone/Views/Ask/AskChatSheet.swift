import SwiftUI
import PhotosUI

/// The iOS Vision conversation sheet: native sheet with detents, glass
/// header (Chats menu, close), disclaimer, message log, working state,
/// suggestions, feedback and the input with the Add menu.
struct AskChatSheet: View {
    @Bindable var session: AskSession
    /// Highlights a home on the map when its address is tapped.
    let onHomeLink: (String) -> Void

    @FocusState private var inputFocused: Bool
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showCamera = false

    var body: some View {
        ZStack(alignment: .top) {
            log
            header
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomStack }
        .background(Nova.Color.bgPrimary)
        .presentationDetents([.fraction(0.88), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "askredfin", url.host == "home" else { return .systemAction }
            onHomeLink(url.lastPathComponent)
            return .handled
        })
        .sheet(isPresented: Binding(get: { session.feedbackFormEntry != nil }, set: { if !$0 { session.feedbackFormEntry = nil } })) {
            AskFeedbackForm { reasons, details in session.sendFeedback(reasons: reasons, details: details) }
        }
        .onChange(of: session.photoPickerRequested) { _, asked in
            if asked { session.photoPickerRequested = false; showPhotoPicker = true }
        }
        .sheet(isPresented: Binding(get: { session.handoff != nil }, set: { if !$0 { session.handoff = nil } })) {
            if let cta = session.handoff { AskHandoffSheet(session: session, cta: cta) }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoSelection, maxSelectionCount: 1, matching: .images)
        .onChange(of: photoSelection) { _, items in
            guard let item = items.first else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let att = AttachmentStore.saveImageData(data) {
                    try? await Task.sleep(for: .milliseconds(450))
                    session.send("Find homes that look like this", photo: att.fileURL)
                }
                photoSelection = []
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ChatCameraPicker(mode: .photo, onPicked: { att in
                showCamera = false
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    session.send("Find homes that look like this", photo: att.fileURL)
                }
            }, onCancel: { showCamera = false })
            .ignoresSafeArea()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Menu {
                Button { session.newChat() } label: { Label { Text("New chat") } icon: { Image("Nova/add_chat") } }
                Section("Chats") {
                    let rows = session.threadRows
                    if rows.isEmpty { Text("No previous chats yet.") }
                    ForEach(rows) { row in
                        Button {
                            if let t = row.thread { session.open(t) }
                        } label: {
                            Text(row.title)
                            Text(row.meta)
                        }
                        .disabled(row.isCurrent)
                    }
                }
            } label: {
                NovaIcon("menu", size: 24)
                    .foregroundStyle(Nova.Color.text)
                    .frame(width: 44, height: 44)
                    .novaGlass(in: Circle(), interactive: true)
            }
            .accessibilityLabel("Chats")
            .disabled(session.isBusy)
            Spacer()
            closeButton
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close) { session.isChatOpen = false } label: { NovaIcon("close", size: 20) }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
        } else {
            GlassActionButton(icon: "close", action: { session.isChatOpen = false }, nova: true)
                .accessibilityLabel("Close")
        }
    }

    // MARK: Log

    private var log: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Text(AskSession.disclaimer)
                        .font(Nova.Typography.caption12)
                        .foregroundStyle(Nova.Color.textSubtle)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Nova.Color.bgSecondary, in: RoundedRectangle(cornerRadius: Nova.Radius.field))
                    ForEach(session.entries) { entry in
                        AskEntryRow(session: session, entry: entry)
                            .id(entry.id)
                            .transition(.opacity.combined(with: .offset(y: 10)))
                    }
                    if session.isBusy {
                        AskWorkingView(steps: session.steps, current: session.stepIndex, showsSteps: session.showsStepper)
                            .id("working")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 72)
                .padding(.bottom, 16)
                .animation(Nova.Motion.easeOut(), value: session.entries.count)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: session.entries.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: session.isBusy) { _, _ in scrollToBottom(proxy) }
            .onChange(of: session.entries.last?.revealed) { _, revealed in
                proxy.scrollTo("bottom", anchor: .bottom)
                // Widgets slide in after the text finishes; follow them down.
                if revealed == nil {
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        scrollToBottom(proxy)
                    }
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: Nova.AskMotion.scrollDuration)) { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    // MARK: Bottom

    private var bottomStack: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if let ask = session.feedbackAsk {
                AskDarkToast {
                    Text("Thanks for letting us know.").font(Nova.Typography.body14)
                    Spacer(minLength: 8)
                    if ask.canUndo {
                        Button("Undo change") { session.undoLastChange() }.buttonStyle(.novaLink).foregroundStyle(.white)
                    }
                    Button("Tell us more") { session.tellUsMore() }.buttonStyle(.novaLink).foregroundStyle(.white)
                    Button { session.dismissFeedback() } label: { NovaIcon("close", size: 16) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss")
                }
                .transition(.opacity.combined(with: .offset(y: 24)))
            } else if session.thanksToast {
                AskDarkToast {
                    NovaIcon("check", size: 20)
                    Text("Thanks. This helps us improve Ask Redfin.").font(Nova.Typography.body14)
                    Spacer(minLength: 0)
                }
                .transition(.opacity.combined(with: .offset(y: 24)))
            } else if !session.isBusy && !session.isStreaming && !session.suggestions.isEmpty {
                suggestionChips
            }
            inputBar
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.42, dampingFraction: 0.75), value: session.feedbackAsk?.entryID)
        .animation(.spring(response: 0.42, dampingFraction: 0.75), value: session.thanksToast)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: session.suggestions)
    }

    private var suggestionChips: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(Array(session.suggestions.enumerated()), id: \.element) { i, s in
                Button { session.send(s) } label: {
                    HStack(spacing: 6) {
                        NovaIcon("star_shining", size: 16)
                        Text(s).font(Nova.Typography.label14).multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(Nova.Color.text)
                    .padding(.vertical, 6)
                }
                .modifier(GlassChipStyle())
                .transition(.opacity.combined(with: .offset(y: 12)).animation(.spring(response: 0.45, dampingFraction: 0.7).delay(Double(i) * 0.08)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var inputBar: some View {
        HStack(spacing: 4) {
            addMenu
                .opacity(inputFocused || session.isBusy ? 0 : 1)
                .scaleEffect(inputFocused || session.isBusy ? 0.6 : 1)
                .frame(width: inputFocused || session.isBusy ? 0 : 44)
            ZStack(alignment: .leading) {
                if session.isBusy, case .thinking(let step)? = session.barToast {
                    AskToastLabel(toast: .thinking(step))
                } else {
                    TextField(session.placeholders[0], text: $session.draft)
                        .font(Nova.Typography.body16)
                        .focused($inputFocused)
                        .submitLabel(.send)
                        .onSubmit { session.submitDraft() }
                        .disabled(session.isBusy)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.leading, inputFocused ? 12 : 0)
            AskSendButton(isVisible: !session.draft.trimmingCharacters(in: .whitespaces).isEmpty && !session.isBusy) {
                session.submitDraft()
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 56)
        .novaGlass(in: Capsule())
        .overlay { if session.isBusy { AskGlowRing() } }
        .animation(.easeOut(duration: 0.2), value: inputFocused)
        .animation(.easeOut(duration: 0.2), value: session.isBusy)
    }

    /// The "+" Add menu: photos, camera, inspiration and the Things to try catalog.
    private var addMenu: some View {
        Menu {
            Button { showPhotoPicker = true } label: { Label { Text("Add photos") } icon: { Image("Nova/add_photo_alternate") } }
            Button { showCamera = true } label: { Label { Text("Take a photo") } icon: { Image("Nova/photo_camera") } }
            Button { session.send("Find visual inspo") } label: { Label { Text("Find visual inspiration") } icon: { Image("Nova/image_search") } }
            Menu {
                ForEach(AskCatalog.groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.prompts, id: \.self) { p in
                            Button(p) { session.send(p) }
                        }
                    }
                }
            } label: {
                Label { Text("Things to try") } icon: { Image("Nova/book_open") }
            }
        } label: {
            NovaIcon("add", size: 24)
                .foregroundStyle(Nova.Color.text)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Add")
    }
}

// MARK: - Rows

private struct AskEntryRow: View {
    @Bindable var session: AskSession
    let entry: AskEntry

    var body: some View {
        switch entry.kind {
        case .user:
            VStack(alignment: .trailing, spacing: 8) {
                if let photo = entry.photo, let image = UIImage(contentsOfFile: photo.path) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 180, height: 135)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Your photo")
                }
                Text(entry.text)
                    .font(Nova.Typography.body16)
                    .foregroundStyle(Nova.Color.text)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Nova.Color.bgTertiary, in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 4, topTrailingRadius: 16))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 40)
        case .tool:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    NovaIcon(AskFormatting.toolIcon(entry.text), size: 16)
                    Text(entry.text).font(Nova.Typography.label14)
                }
                .foregroundStyle(Nova.Color.textSubtle)
                if entry.linksDreamHome {
                    Button { session.tapCTA(AskCTA(label: "Open My home", kind: .myHome)) } label: {
                        HStack(spacing: 6) {
                            NovaIcon("house", size: 16)
                            Text("Saved to your dream home").font(Nova.Typography.caption12).underline()
                        }
                        .foregroundStyle(Nova.Color.textSubtle)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 26)
                    .accessibilityHint("Opens My home")
                }
            }
        case .work:
            HStack(spacing: 10) {
                NovaIcon("check", size: 16)
                Text(entry.text).font(Nova.Typography.label14)
            }
            .foregroundStyle(Nova.Color.textSubtle)
        case .bot:
            VStack(alignment: .leading, spacing: 12) {
            Text(AskFormatting.attributed(entry.text, revealed: entry.revealed))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .overlay(alignment: .bottomTrailing) {
                    if let f = entry.feedback {
                        NovaIcon(f == .up ? "thumb_up_off_alt" : "thumb_down", size: 16)
                            .foregroundStyle(Nova.Color.textSubtle)
                            .offset(y: 18)
                            .accessibilityLabel(f == .up ? "Marked helpful" : "Marked not helpful")
                    }
                }
                // Feedback lives in the long-press menu (native over the prototype's row).
                .contextMenu {
                    if entry.revealed == nil && entry.text != AskSession.greeting {
                        Button { session.thumbsUp(entry.id) } label: { Label { Text("Helpful") } icon: { Image("Nova/thumb_up_off_alt") } }
                        Button { session.thumbsDown(entry.id) } label: { Label { Text("Not helpful") } icon: { Image("Nova/thumb_down") } }
                    }
                    Button { session.copy(entry.id) } label: { Label { Text("Copy") } icon: { Image("Nova/content_copy") } }
                    if entry.id == session.lastBotID && !session.isBusy {
                        Button { session.retry() } label: { Label { Text("Try again") } icon: { Image("Nova/refresh") } }
                    }
                }
            // Widgets appear once the reply has finished typing.
            if entry.revealed == nil && (!entry.homes.isEmpty || entry.widget != nil || entry.cta != nil) {
                AskAttachments(session: session, entry: entry)
            }
            }
            .animation(Nova.Motion.easeOut(), value: entry.revealed == nil)
        }
    }
}

/// Three bouncing dots, then (for slow requests) the step list with a
/// spinner on the current step.
struct AskWorkingView: View {
    let steps: [String]
    let current: Int
    let showsSteps: Bool
    @State private var bounce = false

    var body: some View {
        if showsSteps {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.prefix(current + 1).enumerated()), id: \.offset) { i, step in
                    HStack(spacing: 10) {
                        if i < current {
                            NovaIcon("check", size: 16).foregroundStyle(Nova.Color.textSubtle)
                        } else {
                            ProgressView().controlSize(.mini)
                        }
                        Text(step)
                            .font(Nova.Typography.label14)
                            .foregroundStyle(i < current ? Nova.Color.textSubtle : Nova.Color.text)
                    }
                    .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
            .animation(Nova.Motion.easeOut(), value: current)
            .accessibilityElement(children: .combine)
        } else {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Nova.Color.gray600)
                        .frame(width: 7, height: 7)
                        .offset(y: bounce ? -3 : 3)
                        .animation(.easeInOut(duration: Nova.AskMotion.dotCycle / 2).repeatForever().delay(Double(i) * Nova.AskMotion.dotStagger), value: bounce)
                }
            }
            .padding(.vertical, 6)
            .onAppear { bounce = true }
            .accessibilityLabel("Working")
        }
    }
}

/// Dark feedback toast (`gray-800`, radius 12).
private struct AskDarkToast<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) { content() }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(Color(white: 0.067), in: RoundedRectangle(cornerRadius: Nova.Radius.field))
    }
}

/// Suggestion chips as native glass buttons.
private struct GlassChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass).buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            content.buttonStyle(.bordered).buttonBorderShape(.roundedRectangle(radius: 16)).tint(Nova.Color.text)
        }
    }
}

/// "What went wrong?" as a native sheet.
private struct AskFeedbackForm: View {
    let onSend: ([String], String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reasons: [String] = []
    @State private var details = ""

    private static let options = ["Not accurate", "Not helpful", "Didn't answer my question", "Something else"]

    var body: some View {
        NavigationStack {
            Form {
                Section("What went wrong?") {
                    ForEach(Self.options, id: \.self) { r in
                        Button {
                            if let i = reasons.firstIndex(of: r) { reasons.remove(at: i) } else { reasons.append(r) }
                        } label: {
                            HStack {
                                Text(r).foregroundStyle(Nova.Color.text)
                                Spacer()
                                if reasons.contains(r) { NovaIcon("check", size: 20).foregroundStyle(Nova.Color.text) }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
                Section {
                    TextField("Add details (optional)", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .font(Nova.Typography.body16)
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send feedback") { onSend(reasons, details) }
                        .disabled(reasons.isEmpty && details.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The prototype's "Things to try" catalog.
enum AskCatalog {
    struct Group { let title: String; let prompts: [String] }

    static let groups: [Group] = [
        Group(title: "Search area", prompts: ["Add Ballard", "Switch the search to Fremont", "Show more homes"]),
        Group(title: "Criteria", prompts: ["Make quiet street a must-have", "Dealbreaker: a busy street", "Make large yard a nice-to-have", "Homes with a garage and a fireplace"]),
        Group(title: "Recommendations", prompts: ["Which one fits me best?", "Homes like the top match"]),
        Group(title: "Travel time", prompts: ["Within a 20 min drive of South Lake Union", "15 min walk to Green Lake"]),
        Group(title: "Ask about homes", prompts: ["Does the cheapest one have a garage?", "Which of these are short sales?", "Which has the best transit score?", "Which cheaper homes are in good condition?", "What’s the average HOA for condos?", "Homes on Phinney Ave N"]),
        Group(title: "Sort and analyze", prompts: ["Sort by distance to grocery stores", "Closest to Green Lake first", "Sort by price per sq ft", "Closest to schools"]),
        Group(title: "Tours, agents and financing", prompts: ["Schedule a tour of the top match", "Can I afford the top match?", "Talk to a Redfin agent"]),
        Group(title: "Guardrails", prompts: ["Is this a safe neighborhood?", "Which is best for families?", "Is the cheapest one a good deal?"]),
        Group(title: "Memory", prompts: ["Pick up where I left off", "Start fresh"]),
    ]
}
