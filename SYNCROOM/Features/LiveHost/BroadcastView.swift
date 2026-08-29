//  BroadcastView.swift  (S12)
//
//  Liquid Glass: every floating control here is real system glass. The status
//  readout and the end-broadcast button share ONE `GlassControlBar` — a single
//  `GlassEffectContainer` — so they blend as one group rather than two panes,
//  and the host's mic / camera / requests / settings controls sit in a second
//  bar at the foot of the footage. A `StreamScrim`, the one gradient this design
//  system allows, goes behind both so glass keeps its contrast on a bright
//  frame. Nothing below the stream is glass: the slot strip and the chat are
//  content, and content is opaque.

import SwiftUI
import UIKit

// MARK: - Payload

/// Everything the broadcast screen needs beyond the room it was handed.
struct BroadcastPayload: Sendable {
    var chat: [ChatMessage]
    var participants: [Participant]
    var requests: [JoinRequest]
    var summary: LiveSummary
}

/// One position in the host's performer strip.
enum BroadcastSlot: Identifiable, Sendable {
    case filled(Participant)
    /// The open slot, carrying how many people are waiting to be let in.
    case open(pending: Int)

    var id: String {
        switch self {
        case .filled(let participant): participant.id.uuidString
        case .open: "open"
        }
    }
}

// MARK: - Model

@MainActor
@Observable
final class BroadcastModel {
    private let dataSource: any DataSource

    let room: LiveRoom

    var state: LoadState<BroadcastPayload> = .loading

    /// The broadcast is already under way when this screen opens, so the clock
    /// starts at the airtime the fixture graph records and ticks on from there.
    private(set) var elapsed: TimeInterval = Fixtures.liveSummary.duration

    /// Handed to `onEnd`. Refreshed from the data source while the screen loads.
    private(set) var summary: LiveSummary = Fixtures.liveSummary

    /// Drives the meter on the performing slot.
    let audio = AudioLevelSource()

    // Host controls.
    var isMicMuted = false
    var isCameraOn = true
    var isAcceptingParticipants: Bool
    var acceptsDonation: Bool
    var showsChat = true

    // Presentation.
    var draft = ""
    var toast: Toast?
    var isConfirmingEnd = false
    var isPresentingRequests = false
    var isPresentingSettings = false

    /// The room's queued slot. `Fixtures.participants` carries only the
    /// performer, so the performer who is admitted but not yet playing is
    /// composed here from the same fixture cast — the host screen has to show a
    /// waiting slot beside a performing one.
    private static let queued = Participant(artist: Fixtures.brightWolf,
                                            role: .bass,
                                            state: .waiting)

    init(room: LiveRoom, dataSource: any DataSource = MockDataSource.shared) {
        self.room = room
        self.dataSource = dataSource
        self.isAcceptingParticipants = room.isAcceptingParticipants
        self.acceptsDonation = room.acceptsDonation
    }

    // MARK: Loading

    func load() async {
        state = await LoadState.load {
            let detail: RoomDetail
            do {
                detail = try await self.dataSource.roomDetail(id: self.room.id)
            } catch DataSourceError.notFound {
                // A room the host has only just opened is not in the archive
                // yet: it simply starts with no chat and no participants.
                detail = RoomDetail(room: self.room, chat: [], participants: [])
            }
            let requests = try await self.dataSource.joinRequests(roomID: self.room.id)
            let summary = try await self.dataSource.liveSummary(roomID: self.room.id)
            return BroadcastPayload(chat: detail.chat,
                                    participants: detail.participants,
                                    requests: requests,
                                    summary: summary)
        }
        if let payload = state.value {
            summary = payload.summary
        }
    }

    // MARK: Derived

    var pendingRequestCount: Int { state.value?.requests.count ?? 0 }

    var slots: [BroadcastSlot] {
        guard let payload = state.value else { return [] }
        var slots = payload.participants.map(BroadcastSlot.filled)
        if !payload.participants.isEmpty {
            slots.append(.filled(Self.queued))
        }
        if isAcceptingParticipants, slots.count < room.maxParticipants {
            slots.append(.open(pending: payload.requests.count))
        }
        return slots
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Behaviour

    /// Ticks the on-air clock once a second for as long as the screen is up.
    func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            elapsed += 1
        }
    }

    /// Raises the donation that the screen demonstrates. The toast dismisses
    /// itself; `Toast` owns that timing.
    func announceDonation() async {
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled, acceptsDonation else { return }
        toast = Toast(
            message: String(localized: "\(Format.handle(Fixtures.silentEagle.handle))님이 \(Format.currency(10_000)) 후원!",
                            comment: "Toast raised when a viewer donates during a broadcast")
        )
    }

    func send(as author: Artist) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, case .loaded(var payload) = state else { return }
        payload.chat.append(ChatMessage(authorHandle: author.handle,
                                        authorAvatarURL: author.avatarURL,
                                        text: text))
        state = .loaded(payload)
        draft = ""
    }
}

// MARK: - Screen

struct BroadcastView: View {
    @Environment(SessionModel.self) private var session

    private let room: LiveRoom
    private let onEnd: (LiveSummary) -> Void

    @State private var model: BroadcastModel

    init(room: LiveRoom, onEnd: @escaping (LiveSummary) -> Void) {
        self.init(room: room, model: BroadcastModel(room: room), onEnd: onEnd)
    }

    /// The injection seam previews use to pick a `MockDataSource` behaviour.
    init(room: LiveRoom, model: BroadcastModel, onEnd: @escaping (LiveSummary) -> Void) {
        self.room = room
        self.onEnd = onEnd
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            streamArea

            switch model.state {
            case .loading:
                loadingContent
            case .failed(let error):
                ErrorStateView(error: error) {
                    Task { await model.load() }
                }
                .padding(.horizontal, Metric.screenMargin)
                Spacer(minLength: 0)
            case .loaded(let payload):
                loadedContent(payload)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.surface)
        .safeAreaInset(edge: .bottom) {
            if model.showsChat {
                inputBar
            }
        }
        .toast($model.toast, topInset: ToastInset.belowStreamControls)
        .persistentSystemOverlays(.hidden)
        .alert("방송을 종료할까요?", isPresented: $model.isConfirmingEnd) {
            Button("종료", role: .destructive) { onEnd(model.summary) }
            Button("취소", role: .cancel) {}
        } message: {
            Text("종료하면 시청자와의 연결이 끊기고 방송이 마무리돼요.")
        }
        .sheet(isPresented: $model.isPresentingRequests) {
            JoinRequestManagerSheet(room: room)
        }
        .sheet(isPresented: $model.isPresentingSettings) {
            BroadcastSettingsSheet(showsChat: $model.showsChat,
                                   isAcceptingParticipants: $model.isAcceptingParticipants,
                                   acceptsDonation: $model.acceptsDonation)
        }
        .task { await model.load() }
        .task { await model.runClock() }
        .task { await model.announceDonation() }
        .onAppear {
            // A host cannot tap the screen while they play, so it must not sleep.
            UIApplication.shared.isIdleTimerDisabled = true
            model.audio.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            model.audio.stop()
        }
    }

    // MARK: - Stream

    private var streamArea: some View {
        Rectangle()
            .fill(Palette.stream)
            .aspectRatio(Metric.stream, contentMode: .fit)
            .overlay(alignment: .top) {
                StreamScrim(edge: .top)
                    .frame(height: Space.s96)
            }
            .overlay(alignment: .bottom) {
                StreamScrim(edge: .bottom)
                    .frame(height: Space.s96)
            }
            .overlay(alignment: .top) {
                statusBar
                    .padding(.horizontal, Metric.screenMargin)
                    .padding(.top, Space.s12)
            }
            .overlay(alignment: .bottom) {
                hostControls
                    .padding(.bottom, Space.s16)
            }
            .accessibilityElement(children: .contain)
    }

    /// Live mark, on-air clock, viewer count and the end control — one glass
    /// group, because they are one thing: the state of the broadcast.
    private var statusBar: some View {
        GlassControlBar(spacing: Space.s12) {
            HStack(spacing: Space.s12) {
                LiveIndicator(size: .medium)

                Text(verbatim: Format.duration(model.elapsed))
                    .typography(.timer)
                    .foregroundStyle(Palette.onStream)

                Text("\(Format.count(room.viewerCount))명 시청중")
                    .typography(.metaStrong)
                    .foregroundStyle(Palette.onStream)
                    .lineLimit(1)
            }
            .padding(.horizontal, Space.s16)
            .padding(.vertical, Space.s12)
            .frame(minHeight: Metric.tapTarget)
            .glassEffect(.regular, in: .capsule)
            .accessibilityElement(children: .combine)

            Spacer(minLength: Space.s12)

            GlassCircleButton(systemImage: "stop.fill", label: "방송 종료", isActive: true) {
                model.isConfirmingEnd = true
            }
        }
    }

    private var hostControls: some View {
        GlassControlBar {
            GlassCircleButton(systemImage: model.isMicMuted ? "mic.slash.fill" : "mic.fill",
                              label: model.isMicMuted ? "마이크 켜기" : "마이크 음소거",
                              isActive: model.isMicMuted) {
                model.isMicMuted.toggle()
            }

            GlassCircleButton(systemImage: model.isCameraOn ? "video.fill" : "video.slash.fill",
                              label: model.isCameraOn ? "카메라 끄기" : "카메라 켜기",
                              isActive: !model.isCameraOn) {
                model.isCameraOn.toggle()
            }

            GlassCircleButton(systemImage: "person.badge.plus", label: "참여 요청") {
                model.isPresentingRequests = true
            }
            .badge(model.pendingRequestCount)

            GlassCircleButton(systemImage: "slider.horizontal.3", label: "방송 설정") {
                model.isPresentingSettings = true
            }
        }
        .motion(value: model.isMicMuted)
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ payload: BroadcastPayload) -> some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            slotStrip
                .padding(.top, Space.s16)

            if model.showsChat {
                chatList(payload.chat)
            } else {
                Spacer(minLength: 0)
            }
        }
        .motion(value: model.showsChat)
    }

    private var slotStrip: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Space.s12) {
                ForEach(model.slots) { slot in
                    switch slot {
                    case .filled(let participant):
                        ParticipantSlotView(participant: participant, level: model.audio.level)
                    case .open(let pending):
                        OpenSlotButton(pending: pending) {
                            model.isPresentingRequests = true
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Metric.screenMargin, for: .scrollContent)
        .motion(value: model.pendingRequestCount)
    }

    @ViewBuilder
    private func chatList(_ messages: [ChatMessage]) -> some View {
        if messages.isEmpty {
            EmptyStateView(title: "아직 채팅이 없어요",
                           message: "시청자가 남긴 메시지가 여기에 표시돼요.")
                .padding(.horizontal, Metric.screenMargin)
            Spacer(minLength: 0)
        } else {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: Space.s16) {
                    ForEach(messages) { message in
                        ChatRow(message: message)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.s16)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .contentMargins(.horizontal, Metric.screenMargin, for: .scrollContent)
        }
    }

    // MARK: - Chat input

    private var inputBar: some View {
        @Bindable var model = model

        return HStack(spacing: Space.s12) {
            TextField("메시지 보내기", text: $model.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .typography(.chatMessage)
                .foregroundStyle(Palette.ink)
                .submitLabel(.send)
                .onSubmit { model.send(as: session.currentUser) }
                .padding(.horizontal, Space.s16)
                .padding(.vertical, Space.s12)
                .frame(minHeight: Metric.controlM)
                .background(Palette.surfaceRaised, in: .capsule)

            Button {
                model.send(as: session.currentUser)
            } label: {
                Image(systemName: "arrow.up")
                    .typography(.rowTitle)
                    .foregroundStyle(model.canSend ? Palette.surface : Palette.inkTertiary)
                    .frame(width: Metric.tapTarget, height: Metric.tapTarget)
                    .background(model.canSend ? Palette.ink : Palette.surfaceRaised, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(!model.canSend)
            .accessibilityLabel("보내기")
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.vertical, Space.s12)
        .background(Palette.surface)
    }

    // MARK: - Loading

    /// The real geometry of the strip and the chat, redacted.
    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Space.s12) {
                    ForEach(Fixtures.participants) { participant in
                        ParticipantSlotView(participant: participant, level: 0)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, Metric.screenMargin, for: .scrollContent)
            .padding(.top, Space.s16)

            VStack(alignment: .leading, spacing: Space.s16) {
                ForEach(Fixtures.chatLog) { message in
                    ChatRow(message: message)
                }
            }
            .padding(.horizontal, Metric.screenMargin)

            Spacer(minLength: 0)
        }
        .skeleton(true)
    }
}

// MARK: - Slots

/// A performer slot. Performing is a meaningful state, so it takes the signal
/// fill and an input meter; waiting stays on the ink ramp.
private struct ParticipantSlotView: View {
    let participant: Participant
    let level: Double

    private var isPerforming: Bool { participant.state == .performing }

    var body: some View {
        HStack(spacing: Space.s12) {
            AvatarView(artist: participant.artist, size: Metric.avatarM)

            VStack(alignment: .leading, spacing: Space.s4) {
                NameLabel(artist: participant.artist, style: .metaStrong)

                HStack(spacing: Space.s8) {
                    stateMark
                    if isPerforming {
                        AudioLevelMeter(level: level, height: Space.s4)
                            .frame(width: Space.s64)
                    }
                }
            }
        }
        .padding(.horizontal, Space.s12)
        .padding(.vertical, Space.s8)
        .frame(minHeight: Metric.tapTarget)
        .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.panel))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stateMark: some View {
        if let signal = participant.state.signal {
            Text(participant.state.label)
                .typography(.chip)
                .foregroundStyle(Palette.onSignal)
                .padding(.horizontal, Space.s8)
                .padding(.vertical, Space.s4)
                .background(signal, in: .capsule)
        } else {
            Text(participant.state.label)
                .typography(.chip)
                .foregroundStyle(Palette.inkSecondary)
        }
    }
}

/// The open slot. It is the way into the join-request queue, so it says how many
/// people are in it.
private struct OpenSlotButton: View {
    let pending: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if pending > 0 {
                    Text("+ 참여 대기 \(pending)명")
                } else {
                    Text("+ 빈 자리")
                }
            }
            .typography(.metaStrong)
            .foregroundStyle(Palette.inkSecondary)
            .lineLimit(1)
            .padding(.horizontal, Space.s16)
            .padding(.vertical, Space.s12)
            .frame(minHeight: Metric.tapTarget)
            .background(Palette.surfaceRaised, in: .rect(cornerRadius: Radius.panel))
            .contentShape(.rect(cornerRadius: Radius.panel))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings sheet

/// The three switches that change what the room does while it is on air. Each
/// one is backed by a field of the room itself — nothing here is decoration.
private struct BroadcastSettingsSheet: View {
    @Binding var showsChat: Bool
    @Binding var isAcceptingParticipants: Bool
    @Binding var acceptsDonation: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s32) {
                Text("방송 설정")
                    .typography(.screenTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                row("실시간 채팅 보기", "끄면 방송 화면에서 채팅이 사라져요.", $showsChat)
                row("참여 요청 받기", "끄면 새로운 참여 요청을 받지 않아요.", $isAcceptingParticipants)
                row("후원 받기", "끄면 후원 알림이 화면에 뜨지 않아요.", $acceptsDonation)
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.vertical, Space.s32)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func row(_ title: LocalizedStringKey,
                     _ description: LocalizedStringKey,
                     _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: Space.s4) {
                Text(title)
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                Text(description)
                    .typography(.meta)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(Palette.ink)
    }
}

// MARK: - Previews

private func previewBroadcast(_ behaviour: MockDataSource.Behaviour) -> some View {
    BroadcastView(room: Fixtures.chansRoom,
                  model: BroadcastModel(room: Fixtures.chansRoom,
                                        dataSource: MockDataSource(behaviour: behaviour))) { _ in }
        .environment(AppRouter())
        .environment(SessionModel())
        .environment(PlaybackController())
        .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewBroadcast(.populated).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewBroadcast(.populated).preferredColorScheme(.dark)
}

#Preview("로딩") {
    previewBroadcast(.loading)
}

#Preview("빈 상태") {
    previewBroadcast(.empty)
}

#Preview("오류") {
    previewBroadcast(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewBroadcast(.populated).environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("참여 슬롯", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s12) {
        ParticipantSlotView(participant: Fixtures.participants[0], level: 0.62)
        ParticipantSlotView(participant: Participant(artist: Fixtures.brightWolf,
                                                     role: .bass,
                                                     state: .waiting),
                            level: 0)
        OpenSlotButton(pending: 2) {}
        OpenSlotButton(pending: 0) {}
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}

#Preview("방송 설정") {
    @Previewable @State var showsChat = true
    @Previewable @State var acceptsRequests = true
    @Previewable @State var acceptsDonation = true

    BroadcastSettingsSheet(showsChat: $showsChat,
                           isAcceptingParticipants: $acceptsRequests,
                           acceptsDonation: $acceptsDonation)
}
