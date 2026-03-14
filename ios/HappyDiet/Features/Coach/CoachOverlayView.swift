//
//  CoachOverlayView.swift
//  HappyDiet
//
//  Full coach: status bar, chat bubbles, tasks, diet profile, tab-specific prompts, photo/mic.
//

import SwiftUI

struct CoachOverlayView: View {
    @Binding var isExpanded: Bool
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            if isExpanded {
                CoachPanelView(isExpanded: $isExpanded)
                    .frame(width: min(400, UIScreen.main.bounds.width * 0.9))
                    .transition(.move(edge: .trailing))
            }
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Theme.headerGradient)
                    .clipShape(Circle())
                    .shadow(color: Theme.accent.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .allowsHitTesting(true)
    }
}

struct CoachPanelView: View {
    @Binding var isExpanded: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dataStore: CoachDataStore
    @State private var client: LiveAPIClient?
    @State private var isConnected = false
    @State private var statusConn = "Disconnected"
    @State private var statusMic = "Mic off"
    @State private var statusCoach = "Coach idle"
    @State private var chatMessages: [(role: String, text: String)] = []
    @State private var inputText = ""
    @State private var showImagePicker = false
    @State private var showHeyCyanSheet = false
    @State private var audioPlayer: LivePCMPlayer?
    @State private var liveDelegate: CoachPanelDelegate?

    private var currentTabKey: String {
        switch appState.selectedTab {
        case 0: return "dashboard"
        case 1: return "diet"
        case 2: return "dashboard"
        case 3: return "analyze"
        case 4: return "dashboard"
        case 5: return "dashboard"
        default: return "dashboard"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ask your coach")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button { withAnimation { isExpanded = false } } label: {
                    Image(systemName: "minus")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding()
            .background(Theme.headerGradient)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Button(isConnected ? "Disconnect" : "Connect") {
                            if isConnected {
                                client?.disconnect()
                                isConnected = false
                                updateStatus("Disconnected", "Mic off", "Coach idle")
                            } else { connect() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                    }

                    if isConnected {
                        statusBar
                        HStack(spacing: 8) {
                            Button { showHeyCyanSheet = true } label: {
                                Label("Lenses", systemImage: "eyeglasses")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                            Button { showImagePicker = true } label: {
                                Label("Photo", systemImage: "photo.on.rectangle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                        }
                    }

                    chatBubbles
                    inputRow

                    if !dataStore.activeTasks.isEmpty {
                        taskChipsSection
                    }
                    predefinedTasksSection
                    dietProfileSection
                    quickPromptsSection
                }
                .padding()
            }
            .background(Theme.card)
        }
        .background(Theme.card)
        .shadow(color: .black.opacity(0.12), radius: 12, x: -4, y: 0)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .photoLibrary, onImagePicked: { img in
                showImagePicker = false
                handleImagePicked(img)
            }, onCancel: { showImagePicker = false })
        }
        .sheet(isPresented: $showHeyCyanSheet) {
            HeyCyanCaptureSheet(
                onImagePicked: { img in
                    showHeyCyanSheet = false
                    handleImagePicked(img)
                },
                onCancel: { showHeyCyanSheet = false }
            )
        }
        .onDisappear { client?.disconnect() }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            statusItem(dot: statusConn == "Connected", label: statusConn)
            statusItem(dot: statusMic == "Listening", label: statusMic)
            statusItem(dot: statusCoach == "Speaking", label: statusCoach)
        }
        .font(.caption2)
        .foregroundStyle(Theme.textMuted)
        .padding(8)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusItem(dot: Bool, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dot ? Theme.accent : Theme.gray.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(label)
        }
    }

    private var chatBubbles: some View {
        Group {
            if !chatMessages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(chatMessages.enumerated()), id: \.offset) { _, m in
                        HStack {
                            if m.role == "user" { Spacer(minLength: 40) }
                            Text(m.text)
                                .font(.subheadline)
                                .padding(10)
                                .background(m.role == "user" ? Theme.accent : Color(.tertiarySystemBackground))
                                .foregroundStyle(m.role == "user" ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            if m.role == "coach" { Spacer(minLength: 40) }
                        }
                    }
                }
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Type or speak…", text: $inputText)
                .textFieldStyle(.roundedBorder)
            Button("Send") { sendText() }
                .disabled(inputText.isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
    }

    private var taskChipsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tasks:")
                .font(.caption.bold())
            FlowLayout(spacing: 6) {
                ForEach(dataStore.activeTasks.prefix(5)) { t in
                    Button {
                        dataStore.toggleTaskDone(t)
                    } label: {
                        Text(t.task + (t.due.isEmpty ? "" : " (\(t.due))"))
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                }
            }
        }
    }

    private var predefinedTasksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add task:")
                .font(.caption.bold())
            FlowLayout(spacing: 6) {
                ForEach(Array(PREDEFINED_TASKS.enumerated()), id: \.offset) { _, t in
                    Button("+ \(t.task)") {
                        dataStore.addTask(t.task, due: t.due)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.15))
                    .foregroundStyle(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private var dietProfileSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("My diet profile:")
                .font(.caption.bold())
            FlowLayout(spacing: 6) {
                ForEach(DIET_PROFILES) { p in
                    Button(p.label) {
                        dataStore.toggleProfile(p.id)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(dataStore.isProfileSelected(p.id) ? Theme.accentMuted : Color(.tertiarySystemBackground))
                    .foregroundStyle(dataStore.isProfileSelected(p.id) ? Theme.accent : Theme.textMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private var quickPromptsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick prompts:")
                .font(.caption.bold())
            ForEach(COACH_PROMPTS[currentTabKey] ?? COACH_PROMPTS["dashboard"] ?? [], id: \.self) { prompt in
                Button {
                    inputText = prompt
                } label: {
                    Text(prompt)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func updateStatus(_ conn: String, _ mic: String, _ coach: String) {
        statusConn = conn
        statusMic = mic
        statusCoach = coach
    }

    private func connect() {
        updateStatus("Connecting…", "Mic off", "Coach idle")
        let c = LiveAPIClient()
        let delegate = CoachPanelDelegate(onEvent: { event in
            Task { @MainActor in handleEvent(event) }
        })
        liveDelegate = delegate
        client = c
        let ctx = buildCoachContext()
        c.connect(context: ctx)
    }

    private func buildCoachContext() -> [String: Any] {
        var ctx: [String: Any] = [:]
        if let rules = UserDefaults.standard.string(forKey: "happydiet_rules"), !rules.isEmpty {
            ctx["rules"] = rules
        }
        if !dataStore.dietProfileIds.isEmpty {
            let labels = DIET_PROFILES.filter { dataStore.dietProfileIds.contains($0.id) }.map(\.label)
            ctx["profile"] = labels.joined(separator: "; ")
        }
        let tasksStr = dataStore.activeTasks.map { $0.task + ($0.due.isEmpty ? "" : " (\($0.due))") }.joined(separator: "\n")
        if !tasksStr.isEmpty { ctx["tasks"] = tasksStr }
        let weightStr = dataStore.weightEntries.prefix(7).map { "\($0.date): \($0.kg) kg\($0.note.isEmpty ? "" : " (\($0.note))")" }.joined(separator: "\n")
        if !weightStr.isEmpty { ctx["weight"] = weightStr }
        if dataStore.targets.targetWeight != nil || dataStore.targets.targetDate != nil {
            var tg: [String] = []
            if !dataStore.targets.goal.isEmpty { tg.append("Goal: \(dataStore.targets.goal)") }
            if let w = dataStore.targets.targetWeight { tg.append("Target: \(w) kg") }
            if let d = dataStore.targets.targetDate { tg.append("By \(d)") }
            ctx["targets"] = tg.joined(separator: ". ")
        }
        return ctx
    }

    private func handleEvent(_ event: LiveAPIEvent) {
        switch event {
        case .connected:
            isConnected = true
            updateStatus("Connected", "Mic off", "Coach idle")
        case .disconnected(let reason):
            isConnected = false
            updateStatus(reason ?? "Disconnected", "Mic off", "Coach idle")
        case .setupComplete:
            isConnected = true
            updateStatus("Connected", "Mic off", "Coach idle")
            chatMessages.append(("coach", "Hey! I'm your diet coach. Ask me anything — why certain foods are off limits, how you're doing, or share a meal photo. I'll reply in text and voice."))
            if let img = appState.consumePendingImageForCoach(), let b64 = img.toJPEGBase64() {
                client?.sendImage(base64: b64)
                chatMessages.append(("user", "[sent meal photo]"))
            }
        case .text(let s):
            chatMessages.append(("coach", s))
        case .audio(let data):
            updateStatus(statusConn, statusMic, "Speaking")
            playPCM(data)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                updateStatus(self.statusConn, self.statusMic, "Coach idle")
            }
        case .turnComplete: break
        case .interrupted:
            chatMessages.append(("coach", "[interrupted]"))
        case .error(let msg):
            updateStatus("Error", "Mic off", "Coach idle")
            chatMessages.append(("coach", "Error: \(msg)"))
        }
    }

    private func sendText() {
        guard !inputText.isEmpty else { return }
        client?.sendText(inputText)
        chatMessages.append(("user", inputText))
        inputText = ""
    }

    private func handleImagePicked(_ image: UIImage) {
        guard let base64 = image.toJPEGBase64() else { return }
        client?.sendImage(base64: base64)
        chatMessages.append(("user", "[sent meal photo]"))
    }

    private func playPCM(_ data: Data) {
        audioPlayer?.stop()
        let player = LivePCMPlayer()
        audioPlayer = player
        player.play(data: data)
    }
}

private final class CoachPanelDelegate: LiveAPIClientDelegate {
    let onEvent: (LiveAPIEvent) -> Void
    init(onEvent: @escaping (LiveAPIEvent) -> Void) { self.onEvent = onEvent }
    func liveClient(_ client: LiveAPIClient, didReceive event: LiveAPIEvent) { onEvent(event) }
}

// MARK: - Flow Layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, p) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
