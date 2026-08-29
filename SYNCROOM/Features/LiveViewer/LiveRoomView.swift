//  LiveRoomView.swift  (S4)
//
//  Liquid Glass: the footage runs edge to edge — under the status bar, out to
//  both screen edges — and everything that reads on top of it is either system
//  glass or a scrim. The two ways out of the screen are two SEPARATE
//  `GlassEffectContainer` groups pinned to opposite edges: minimise (which keeps
//  the room playing in the mini player) on the left, leave and the more-menu on
//  the right. One capsule holding both would read as one control with two
//  halves, and these are opposite decisions.
//
//  Everything below the video is opaque content — the room block, the chat and
//  the input bar paint no material at all, and each carries its own
//  `Metric.screenMargin` so the video above them can stay full-bleed.
//
//  `RootView` presents this as a `.fullScreenCover`, so it covers the tab bar
//  and the mini player: this file must never draw either of them.

import SwiftUI
import UIKit

// MARK: - Stream

/// Whether footage is arriving yet. The room's data and its video are two
/// different connections, and the placeholder has to say which one is missing.
enum LiveRoomStreamPhase: Hashable, Sendable {
    case buffering
    case playing
}

/// The one panel the room can have open at a time, so two of them can never
/// fight over the same presentation.
enum LiveRoomSheet: String, Identifiable, Sendable {
    case participants, donation
    var id: String { rawValue }
}

/// Stable identities for the controls floating over the footage, so a group that
/// gains or loses a sibling cannot re-create the buttons beside it.
private enum LiveRoomControl: Hashable {
    case minimize, leave, more
}

// MARK: - Chat scrim

/// The SECOND — and last — sanctioned gradient in this app, after `StreamScrim`.
///
/// The design system says a scroll edge fades with
/// `.scrollEdgeEffectStyle(.soft, for: .top)`, never a gradient. That modifier
/// draws where a scroll view meets a *bar*, and this chat meets no bar: it sits
/// in the middle of the column, under an ordinary section heading, with content
/// above and below it. With nothing for the effect to attach to it renders
/// nothing, and the log stayed hard-cut at its top edge. So the fade is a
/// `LinearGradient` used as a **mask** — a mask removes coverage, where an
/// overlay would paint a tinted band that is wrong in one colour scheme or the
/// other. Nothing else in the app may reach for a gradient on this precedent.
struct ChatScrim: View {
    /// How much of the top edge dissolves.
    ///
    /// The log reserves this much scrollable room at its top (see the chat's
    /// `contentMargins`), so scrolling all the way up carries the oldest message
    /// *out* of the faded band. Without that the fade would sit over the first
    /// message permanently and it could never be read.
    static let height: CGFloat = Space.s32

    var height: CGFloat = ChatScrim.height

    var body: some View {
        VStack(spacing: 0) {
            // Only the alpha of these stops is read; `Palette.ink` is fully
            // opaque in both schemes, which is all a mask needs.
            LinearGradient(
                stops: [
                    .init(color: Palette.ink.opacity(0), location: 0),
                    .init(color: Palette.ink, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)

            Palette.ink
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Minimise transition

/// The id the presenting view matches this cover against, so that minimising
/// reads as one continuous zoom into the mini player rather than a dismiss
/// followed by a fade.
///
/// The matched *source* lives in the presenting view, which this file does not
/// own. Handing it over is two lines there:
/// `@Namespace private var liveRoomZoom`, then
/// `.matchedTransitionSource(id: LiveRoomTransition.sourceID, in: liveRoomZoom)`
/// on the mini player and `LiveRoomView(room: room, sourceNamespace:
/// liveRoomZoom)` in the cover. Until they land, `sourceNamespace` is `nil` and
/// the cover simply uses the default presentation — a zoom with no source
/// anywhere is worse than no zoom.
enum LiveRoomTransition {
    /// Only one room is ever being watched, so one id is enough.
    static let sourceID = "LiveRoomTransitionSource"
}

/// Applies the zoom only once a namespace has actually been handed over.
private struct LiveRoomZoomTransition: ViewModifier {
    let namespace: Namespace.ID?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let namespace {
            content.navigationTransition(.zoom(sourceID: LiveRoomTransition.sourceID,
                                               in: namespace))
        } else {
            content
        }
    }
}

// MARK: - Model

@MainActor
@Observable
final class LiveRoomModel {
    private let dataSource: any DataSource

    /// Everything that has to outlive this screen. It belongs to
    /// `PlaybackController`, not to the view: the cover is torn down when it is
    /// minimised, so anything held here would reload from scratch on the way
    /// back and minimising would be indistinguishable from leaving.
    private(set) var roomSession: LiveRoomSession

    var draft = ""
    var sheet: LiveRoomSheet?
    var toast: Toast?

    init(room: LiveRoom, dataSource: any DataSource = MockDataSource.shared) {
        self.roomSession = LiveRoomSession(room: room)
        self.dataSource = dataSource
    }

    var room: LiveRoom { roomSession.room }

    /// The chat log, its collapse state and its scroll position all live on the
    /// session; the model only forwards, so there is one copy of each.
    var state: LoadState<RoomDetail> {
        get { roomSession.detail }
        set { roomSession.detail = newValue }
    }

    var isChatHidden: Bool {
        get { roomSession.isChatHidden }
        set { roomSession.isChatHidden = newValue }
    }

    var chatAnchorID: UUID? {
        get { roomSession.chatAnchorID }
        set { roomSession.chatAnchorID = newValue }
    }

    /// Footage is buffering until the room's detail lands; a room that never
    /// connects never leaves this phase, which is exactly what it looks like.
    var stream: LiveRoomStreamPhase {
        state.value == nil ? .buffering : .playing
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Takes over the session the playback controller is already keeping for
    /// this room, if there is one. This is what makes re-expanding from the
    /// mini player continuous rather than a fresh visit.
    func adopt(_ session: LiveRoomSession?) {
        guard let session, session.room.id == roomSession.room.id else { return }
        roomSession = session
    }

    func load() async {
        // Already watching: the log, its position and the collapse state came
        // back with the session, so there is nothing to fetch.
        guard state.value == nil else { return }
        state = await LoadState.load { try await self.dataSource.roomDetail(id: self.room.id) }
    }

    func reload() async {
        state = await LoadState.load { try await self.dataSource.roomDetail(id: self.room.id) }
    }

    /// Appends the viewer's own message to the log they are reading.
    func send(as author: Artist) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, case .loaded(var detail) = state else { return }
        detail.chat.append(ChatMessage(authorHandle: author.handle,
                                       authorAvatarURL: author.avatarURL,
                                       text: text))
        state = .loaded(detail)
        draft = ""
    }

    func confirmDonation(_ donation: Donation) {
        toast = Toast(message: String(localized: "\(Format.currency(donation.amount)) 후원을 보냈어요",
                                      comment: "Confirmation after sending a donation"))
    }

    /// The answer to a tap on a 참여 신청 control that cannot do anything yet.
}

// MARK: - Screen

struct LiveRoomView: View {
    @Environment(AppRouter.self) private var router
    @Environment(SessionModel.self) private var session
    @Environment(PlaybackController.self) private var playback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    let room: LiveRoom

    /// Supplied by whoever presents the cover; see `LiveRoomTransition`.
    private let sourceNamespace: Namespace.ID?

    @State private var model: LiveRoomModel
    /// Focus on the chat draft, so a tap anywhere off the bar can release it.
    @FocusState private var isInputFocused: Bool
    /// What the ellipsis menu can put on screen.
    @State private var moreMenu = LiveMoreMenuModel()

    init(room: LiveRoom, sourceNamespace: Namespace.ID? = nil) {
        self.init(room: room,
                  model: LiveRoomModel(room: room),
                  sourceNamespace: sourceNamespace)
    }

    /// The injection seam previews use to pick a `MockDataSource` behaviour.
    init(room: LiveRoom, model: LiveRoomModel, sourceNamespace: Namespace.ID? = nil) {
        self.room = room
        self.sourceNamespace = sourceNamespace
        _model = State(initialValue: model)
    }

    /// How far down the stage has to travel before it counts as "put this away".
    /// Far enough that a stray touch on the video does not dismiss the screen.
    private static let minimizeDragDistance = Space.s80

    private var isEnded: Bool { room.status == .ended }

    /// Gets the cover out of the way so a push lands somewhere the viewer can
    /// see it. A live room keeps playing in the mini player; a finished one has
    /// no session left to keep.
    private func stepAside() {
        if isEnded {
            playback.stop()
        } else {
            playback.minimize()
        }
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            streamArea

            if isEnded {
                endedContent
            } else {
                liveContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.surface)
        // Tapping anything that is not the keyboard or the input bar puts the
        // keyboard away. `simultaneousGesture` so it never swallows a tap meant
        // for a control underneath it.
        .simultaneousGesture(
            TapGesture().onEnded { isInputFocused = false }
        )
        // The controls belong to the SCREEN's edge, not to the video's box. The
        // stream is full-bleed now, so hanging them off the root — which still
        // stops at the safe area — is what keeps them clear of the status bar
        // and square with the screen margin.
        .overlay(alignment: .top) { topControls }
        .safeAreaInset(edge: .bottom) {
            if !isEnded {
                inputBar
            }
        }
        .toast($model.toast, topInset: ToastInset.belowStreamControls)
        .persistentSystemOverlays(.hidden)
        .modifier(LiveRoomZoomTransition(namespace: sourceNamespace))
        .liveMoreMenu(model: moreMenu, room: room)
        .sheet(item: $model.sheet) { sheet in
            // Each sheet owns its own detents.
            switch sheet {
            case .participants:
                ParticipantListSheet(room: room)
            case .donation:
                DonationSheet(room: room) { donation in
                    model.confirmDonation(donation)
                }
            }
        }
        .task {
            model.adopt(playback.session)
            await model.load()
        }
        .onAppear {
            // Watching is a hands-off activity, so the screen must not sleep.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Stream

    /// Edge to edge: no horizontal inset at all, and the fill runs up under the
    /// status bar with `.ignoresSafeArea(edges: .top)`. The blocks below carry
    /// their own `Metric.screenMargin` instead.
    private var streamArea: some View {
        Rectangle()
            .fill(Palette.stream)
            .aspectRatio(Metric.stream, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: streamMaxHeight)
            // Paints the whole block, including the strip the status bar sits
            // over and the height the chat gives up when it collapses.
            .background { Palette.stream.ignoresSafeArea(edges: .top) }
            .overlay { streamCentre }
            .overlay(alignment: .top) {
                StreamScrim(edge: .top)
                    .frame(height: Space.s96)
            }
            .contentShape(.rect)
            .gesture(minimizeDrag)
            .accessibilityElement(children: .contain)
    }

    /// Collapsing the chat hands its height to the stage rather than leaving a
    /// hole in the column.
    private var streamMaxHeight: CGFloat? {
        guard model.isChatHidden else { return nil }
        return CGFloat.infinity
    }

    /// `fullScreenCover` has no dismiss gesture of its own, so this adds one
    /// rather than overriding one. It lives on the stage, not on the root, so it
    /// can never compete with the chat's own scrolling.
    private var minimizeDrag: some Gesture {
        DragGesture(minimumDistance: Space.s12)
            .onEnded { value in
                guard !isEnded,
                      value.translation.height > Self.minimizeDragDistance else { return }
                playback.minimize()
            }
    }

    @ViewBuilder
    private var streamCentre: some View {
        if isEnded {
            Text("방송이 종료되었어요")
                .typography(.sectionTitle)
                .foregroundStyle(Palette.onStream)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Metric.screenMargin)
        } else {
            switch model.stream {
            case .buffering:
                bufferingMark
            case .playing:
                stageMark
            }
        }
    }

    /// The host, ringed in the accent: the one thing on the stage while there is
    /// no real footage to draw.
    private var stageMark: some View {
        AvatarView(artist: room.host, size: Metric.avatarXL)
            .overlay {
                Circle().strokeBorder(Palette.signalLive, lineWidth: Space.s4)
            }
            .accessibilityHidden(true)
    }

    private var bufferingMark: some View {
        VStack(spacing: Space.s12) {
            ProgressView()
                .tint(Palette.onStream)
            Text("연결 중")
                .typography(.metaStrong)
                .foregroundStyle(Palette.onStream)
        }
        .accessibilityElement(children: .combine)
    }

    /// Minimise on the left, leaving and the more-menu on the right — two glass
    /// groups with the width of the screen between them.
    ///
    /// `chevron.down` and `X` are one glyph apart and mean opposite things:
    /// minimising keeps watching and hands the room to the mini player, leaving
    /// ends the session. The glyphs cannot carry that on their own, so the
    /// labels are load-bearing rather than a courtesy.
    private var topControls: some View {
        HStack(spacing: Space.s12) {
            if !isEnded {
                GlassControlBar {
                    GlassCircleButton(systemImage: "chevron.down", label: "최소화") {
                        playback.minimize()
                    }
                    .id(LiveRoomControl.minimize)
                }
            }

            Spacer(minLength: Space.s48)

            GlassControlBar {
                GlassCircleButton(systemImage: "xmark", label: "방 나가기") {
                    playback.stop()
                }
                .id(LiveRoomControl.leave)

                LiveMoreMenuButton(model: moreMenu)
                    .id(LiveRoomControl.more)
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s12)
    }

    // MARK: - Live

    @ViewBuilder
    private var liveContent: some View {
        roomInfo

        switch model.state {
        case .loading:
            loadingChat
        case .failed(let error):
            ErrorStateView(error: error) {
                Task { await model.reload() }
            }
            .padding(.horizontal, Metric.screenMargin)
            Spacer(minLength: 0)
        case .loaded(let detail):
            chatSection(detail.chat)
        }
    }

    private var roomInfo: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            VStack(alignment: .leading, spacing: Space.s4) {
                Text(room.title)
                    .typography(.roomTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                // A finished room has no one in it, so the counts would be a
                // line of zeroes — the meta line goes with the broadcast.
                if !isEnded {
                    RoomMetaLabel(participantCount: room.participantCount,
                                  viewerCount: room.viewerCount) {
                        model.sheet = .participants
                    }
                }
            }

            hostRow

            if !room.hashtags.isEmpty {
                HashtagChipRow(tags: room.hashtags)
            }

            // 참여 신청 is not here any more: it lives in the chat bar, beside
            // the other two things a viewer can send into the room.
            if isEnded {
                endedActions.padding(.top, Space.s8)
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hostRow: some View {
        Button {
            // The profile is pushed onto the stack *behind* this cover, so the
            // session gets out of the way first — otherwise the push would land
            // somewhere the viewer cannot see.
            stepAside()
            router.openArtist(room.host)
        } label: {
            // The tappable area stops at the name. Stretching it to the full
            // width meant a tap anywhere on that line — including the empty
            // half — opened a profile, which is not what the row looks like it
            // offers.
            HStack(spacing: Space.s12) {
                AvatarView(artist: room.host, size: Metric.avatarM)
                NameLabel(artist: room.host, style: .bodyStrong)
            }
            .frame(minHeight: Metric.tapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("탭하면 아티스트 프로필을 엽니다")
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chat

    private func chatSection(_ messages: [ChatMessage]) -> some View {
        // No spacing between the heading and the log: the log already reserves
        // `ChatScrim.height` of scrollable room at its top, and that reserved
        // room is exactly what the fade covers. Adding a gap on top of it pushed
        // the gradient far below the heading and left a dead band between them.
        // With the spacing removed the fade *is* the gap, which is both the
        // right amount of air and the conventional place for it.
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "실시간 채팅",
                          actionTitle: model.isChatHidden ? "보기" : "숨기기") {
                toggleChat()
            }
            .padding(.horizontal, Metric.screenMargin)

            // Collapsed, the log is not built at all: a message arriving while
            // the chat is hidden has nowhere to land, so it cannot move
            // anything on screen.
            if !model.isChatHidden {
                chatLog(messages)
            }
        }
        .padding(.top, Space.s20)
    }

    /// The collapse is a height change of the whole column — the stage grows
    /// into the space the log gives up — so it is animated once, here, rather
    /// than by each piece finding its own timing.
    private func toggleChat() {
        withAnimation(reduceMotion ? nil : Motion.standard) {
            model.isChatHidden.toggle()
        }
    }

    /// Where the log is scrolled to. Reading it back into the session is what
    /// puts the viewer at the same message after a minimise.
    private var chatAnchor: Binding<UUID?> {
        Binding(
            get: { model.chatAnchorID },
            set: { model.chatAnchorID = $0 }
        )
    }

    @ViewBuilder
    private func chatLog(_ messages: [ChatMessage]) -> some View {
        if messages.isEmpty {
            EmptyStateView(title: "아직 채팅이 없어요",
                           message: "가장 먼저 인사를 남겨보세요.")
                .padding(.horizontal, Metric.screenMargin)
            Spacer(minLength: 0)
        } else {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: Space.s16) {
                    ForEach(messages) { message in
                        ChatRow(message: message)
                            .id(message.id)
                    }
                }
                .scrollTargetLayout()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.s16)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.horizontal, Metric.screenMargin, for: .scrollContent)
            // Scrollable room the height of the fade, so the oldest message can
            // be scrolled clear of it instead of living under it.
            .contentMargins(.top, ChatScrim.height, for: .scrollContent)
            // Restores where the log was left, and records where it is now, so
            // minimising and re-expanding lands on the same message.
            .scrollPosition(id: chatAnchor, anchor: .bottom)
            .onChange(of: messages.last?.id) { _, newest in
                scrollToNewest(newest)
            }
            // Outermost, so every scroll modifier above still reaches the
            // scroll view itself. See `ChatScrim`: this log meets no bar, so
            // the platform's scroll edge effect has nothing to attach to.
            .mask { ChatScrim() }
        }
    }

    /// Brings a newly arrived message into view, still if Reduce Motion is on.
    private func scrollToNewest(_ id: ChatMessage.ID?) {
        guard let id else { return }
        if reduceMotion {
            model.chatAnchorID = id
        } else {
            withAnimation(Motion.quick) {
                model.chatAnchorID = id
            }
        }
    }

    // MARK: - Chat input

    /// `[텍스트 필드] [참여 신청] [후원] [전송]` — everything a viewer can send
    /// into the room, in one row, in the order they are reached for.
    ///
    /// The three controls are fixed 44pt targets, so at accessibility sizes they
    /// would squeeze the field down to a couple of characters. There they drop
    /// to their own line instead.
    private var inputBar: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .trailing, spacing: Space.s12) {
                    draftField
                    HStack(spacing: Space.s12) { inputActions }
                }
            } else {
                HStack(spacing: Space.s12) {
                    draftField
                    inputActions
                }
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.vertical, Space.s12)
        .background(Palette.surface)
    }

    private var draftField: some View {
        @Bindable var model = model

        // Single-line on purpose. With `axis: .vertical` the return key inserts a
        // newline and `.onSubmit` never fires, so the send key on the keyboard
        // did nothing but make the field taller.
        return TextField("메시지를 입력하세요...", text: $model.draft)
            .textFieldStyle(.plain)
            .focused($isInputFocused)
            .typography(.chatMessage)
            .foregroundStyle(Palette.ink)
            .submitLabel(.send)
            .onSubmit { model.send(as: session.currentUser) }
            .padding(.horizontal, Space.s16)
            .padding(.vertical, Space.s12)
            .frame(minHeight: Metric.controlM)
            .background(Palette.surfaceRaised, in: .capsule)
    }

    @ViewBuilder
    private var inputActions: some View {
        // A room that does not take donations has no gift to give.
        if room.acceptsDonation {
            Button {
                model.sheet = .donation
            } label: {
                inputGlyph("gift", tint: Palette.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("후원하기")
        }

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

    /// One round control in the chat bar. The tap target is the circle.
    private func inputGlyph(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .typography(.rowTitle)
            .foregroundStyle(tint)
            .frame(width: Metric.tapTarget, height: Metric.tapTarget)
            .background(Palette.surfaceRaised, in: .circle)
            .contentShape(.circle)
    }

    // MARK: - Ended

    /// A finished room keeps its identity block — the title, the host and the
    /// hashtags are why the viewer opened it — and swaps the whole chat for the
    /// two ways onward.
    private var endedContent: some View {
        VStack(spacing: 0) {
            roomInfo
            Spacer(minLength: 0)
        }
    }

    private var endedActions: some View {
        VStack(spacing: Space.s12) {
            Button("다시보기") {
                // The replay lives on the host's profile, behind this cover, so
                // the session ends before the push.
                playback.stop()
                router.openArtist(room.host)
            }
            .buttonStyle(.syncSolid)

            Button("홈으로") {
                playback.stop()
                router.tab = .home
            }
            .buttonStyle(.syncFilled)
        }
    }

    // MARK: - Loading

    /// The real chat geometry, redacted.
    private var loadingChat: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            SectionHeader(title: "실시간 채팅")
                .padding(.horizontal, Metric.screenMargin)

            VStack(alignment: .leading, spacing: Space.s16) {
                ForEach(Fixtures.chatLog) { message in
                    ChatRow(message: message)
                }
            }
            .padding(.horizontal, Metric.screenMargin)

            Spacer(minLength: 0)
        }
        .padding(.top, Space.s32)
        .skeleton(true)
    }
}

// MARK: - Previews

/// A room that is taking requests but has every performer slot filled — the
/// state 참여 신청 has to explain rather than hide.
private func previewFullRoom() -> LiveRoom {
    var room = Fixtures.chansRoom
    room.participantCount = room.maxParticipants
    return room
}

private func previewLiveRoom(_ behaviour: MockDataSource.Behaviour = .populated,
                             room: LiveRoom = Fixtures.chansRoom,
                             chatHidden: Bool = false) -> some View {
    let playback = PlaybackController()
    playback.watch(room)
    playback.session?.isChatHidden = chatHidden

    return LiveRoomView(room: room,
                        model: LiveRoomModel(room: room,
                                             dataSource: MockDataSource(behaviour: behaviour)))
        .environment(AppRouter())
        .environment(SessionModel())
        .environment(playback)
        .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewLiveRoom().preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewLiveRoom().preferredColorScheme(.dark)
}

#Preview("채팅 숨김 — 라이트") {
    previewLiveRoom(chatHidden: true).preferredColorScheme(.light)
}

#Preview("채팅 숨김 — 다크") {
    previewLiveRoom(chatHidden: true).preferredColorScheme(.dark)
}

#Preview("참여 마감 — 자리 가득") {
    previewLiveRoom(room: previewFullRoom())
}

#Preview("참여 신청 없는 방") {
    previewLiveRoom(room: Fixtures.longformRoom)
}

#Preview("로딩 — 버퍼링") {
    previewLiveRoom(.loading)
}

#Preview("빈 상태") {
    previewLiveRoom(.empty)
}

#Preview("오류") {
    previewLiveRoom(.failing)
}

#Preview("방송 종료") {
    previewLiveRoom(room: Fixtures.endedRoom)
}

#Preview("Dynamic Type — accessibility3") {
    previewLiveRoom().environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Dynamic Type — accessibility3 · 채팅 숨김") {
    previewLiveRoom(chatHidden: true).environment(\.dynamicTypeSize, .accessibility3)
}
