//  JoinRequestManagerSheet.swift  (S22)
//
//  Liquid Glass: the sheet `BroadcastView` presents this in *is* the platform's
//  glass, so this file paints no background and never restyles the presentation
//  — it only declares `.presentationDetents([.medium, .large])` so the detents
//  travel with the view. Everything inside the content column — the requests,
//  the participant switches — is opaque, because content is not glass.

import SwiftUI

// MARK: - Payload

/// The two lists this sheet manages: who is asking to come on stage, and who is
/// already on it.
struct JoinRequestManagerPayload: Sendable {
    var requests: [JoinRequest]
    var participants: [Participant]
}

// MARK: - Model

@MainActor
@Observable
final class JoinRequestManagerModel {
    private let dataSource: any DataSource

    let room: LiveRoom

    var state: LoadState<JoinRequestManagerPayload> = .loading

    init(room: LiveRoom, dataSource: any DataSource = MockDataSource.shared) {
        self.room = room
        self.dataSource = dataSource
    }

    // MARK: Loading

    func load() async {
        state = await LoadState.load {
            let requests = try await self.dataSource.joinRequests(roomID: self.room.id)
            let participants: [Participant]
            do {
                participants = try await self.dataSource.roomDetail(id: self.room.id).participants
            } catch DataSourceError.notFound {
                // A room the host has only just opened is not in the archive
                // yet: nobody is on stage with them.
                participants = []
            }
            return JoinRequestManagerPayload(requests: requests, participants: participants)
        }
    }

    // MARK: Derived

    var requestCount: Int { state.value?.requests.count ?? 0 }

    var participantCount: Int { state.value?.participants.count ?? 0 }

    /// A request can only be accepted while a performer slot is still free.
    var hasFreeSlot: Bool { participantCount < room.maxParticipants }

    // MARK: Behaviour

    /// Accepting moves someone from the queue onto the stage, where they wait
    /// until they start playing.
    func accept(_ request: JoinRequest) {
        guard case .loaded(var payload) = state else { return }
        payload.requests.removeAll { $0.id == request.id }
        payload.participants.append(Participant(artist: request.artist,
                                                role: request.role,
                                                state: .waiting))
        state = .loaded(payload)
    }

    func decline(_ request: JoinRequest) {
        guard case .loaded(var payload) = state else { return }
        payload.requests.removeAll { $0.id == request.id }
        state = .loaded(payload)
    }

    func setMuted(_ isMuted: Bool, for participant: Participant) {
        guard case .loaded(var payload) = state,
              let index = payload.participants.firstIndex(where: { $0.id == participant.id })
        else { return }
        payload.participants[index].isMuted = isMuted
        state = .loaded(payload)
    }

    func remove(_ participant: Participant) {
        guard case .loaded(var payload) = state else { return }
        payload.participants.removeAll { $0.id == participant.id }
        state = .loaded(payload)
    }
}

// MARK: - Sheet

struct JoinRequestManagerSheet: View {
    let room: LiveRoom

    @State private var model: JoinRequestManagerModel
    /// The participant a removal is being confirmed for, if any.
    @State private var removalTarget: Participant?

    init(room: LiveRoom) {
        self.init(room: room, model: JoinRequestManagerModel(room: room))
    }

    /// The injection seam previews use to pick a `MockDataSource` behaviour.
    init(room: LiveRoom, model: JoinRequestManagerModel) {
        self.room = room
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s48) {
                header

                switch model.state {
                case .loading:
                    loadingContent
                case .failed(let error):
                    ErrorStateView(error: error) {
                        Task { await model.load() }
                    }
                case .loaded(let payload):
                    requestSection(payload)
                    participantSection(payload)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s24)
            .padding(.bottom, Space.s48)
            .motion(value: model.requestCount)
            .motion(value: model.participantCount)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("참여자를 내보낼까요?",
                            isPresented: isConfirmingRemoval,
                            titleVisibility: .visible,
                            presenting: removalTarget) { participant in
            Button("내보내기", role: .destructive) { model.remove(participant) }
            Button("취소", role: .cancel) {}
        } message: { participant in
            Text("\(participant.artist.displayName)님이 무대에서 내려가고, 다시 시청자로 돌아가요.")
        }
        .task { await model.load() }
    }

    private var isConfirmingRemoval: Binding<Bool> {
        Binding(get: { removalTarget != nil },
                set: { if !$0 { removalTarget = nil } })
    }

    // MARK: - Header

    /// The sheet's own title carries the count, which is why nothing below it
    /// repeats "참여 요청" as a section heading.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s12) {
            title
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            slotCount
        }
    }

    private var title: some View {
        Group {
            if model.requestCount > 0 {
                Text("참여 요청 \(Format.count(model.requestCount))")
            } else {
                Text("참여 요청")
            }
        }
        .typography(.roomTitle)
        .foregroundStyle(Palette.ink)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// `1/4` — how much of the stage is taken, so the host can see whether there
    /// is room before they accept. Two adjacent `Text` views, never a
    /// concatenation, which is deprecated on iOS 26.
    private var slotCount: some View {
        HStack(spacing: 0) {
            Text(verbatim: "\(model.participantCount)")
                .typography(.metaStrong)
                .foregroundStyle(Palette.ink)
            Text(verbatim: "/\(room.maxParticipants)")
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("참여 인원")
        .accessibilityValue(Text("\(room.maxParticipants)명 중 \(model.participantCount)명"))
    }

    // MARK: - Requests

    @ViewBuilder
    private func requestSection(_ payload: JoinRequestManagerPayload) -> some View {
        if payload.requests.isEmpty {
            EmptyStateView(title: "받은 참여 요청이 없어요",
                           message: "시청자가 참여를 신청하면 여기에서 수락할 수 있어요.")
        } else {
            VStack(alignment: .leading, spacing: Space.s32) {
                // The host needs to know why 수락 is missing, so a full stage is
                // said out loud rather than left as a silently absent button.
                if !model.hasFreeSlot {
                    InlineBanner(kind: .caution, message: "참여 자리가 모두 찼어요")
                }

                ForEach(payload.requests) { request in
                    JoinRequestManagerRequestRow(request: request,
                                                 canAccept: model.hasFreeSlot,
                                                 onAccept: { model.accept(request) },
                                                 onDecline: { model.decline(request) })
                }
            }
        }
    }

    // MARK: - Participants

    private func participantSection(_ payload: JoinRequestManagerPayload) -> some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            LiveSheetLabel(title: "현재 참여자")

            if payload.participants.isEmpty {
                EmptyStateView(title: "아직 함께하는 사람이 없어요",
                               message: "요청을 수락하면 참여자가 여기에 표시돼요.")
            } else {
                VStack(alignment: .leading, spacing: Space.s32) {
                    ForEach(payload.participants) { participant in
                        JoinRequestManagerParticipantRow(
                            participant: participant,
                            isMuted: Binding(get: { participant.isMuted },
                                             set: { model.setMuted($0, for: participant) }),
                            onRemove: { removalTarget = participant }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Loading

    /// The real geometry of both lists, redacted, so the rows arrive where the
    /// skeleton stood.
    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: Space.s48) {
            VStack(alignment: .leading, spacing: Space.s32) {
                ForEach(Fixtures.joinRequests) { request in
                    JoinRequestManagerRequestRow(request: request,
                                                 canAccept: true,
                                                 onAccept: {},
                                                 onDecline: {})
                }
            }

            VStack(alignment: .leading, spacing: Space.s16) {
                LiveSheetLabel(title: "현재 참여자")
                ForEach(Fixtures.participants) { participant in
                    JoinRequestManagerParticipantRow(participant: participant,
                                                     isMuted: .constant(false),
                                                     onRemove: {})
                }
            }
        }
        .skeleton(true)
    }
}

// MARK: - Rows

/// One pending request: who is asking, what they would play, the note they
/// attached, and the host's two answers.
private struct JoinRequestManagerRequestRow: View {
    let request: JoinRequest
    /// Accepting is impossible once every slot is taken, so the action goes away
    /// instead of standing there disabled.
    let canAccept: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            ArtistRow(artist: request.artist) {
                RoleChip(role: request.role)
            }

            Text(request.note)
                .typography(.body)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Space.s16) {
                if canAccept {
                    Button("수락", action: onAccept)
                        .buttonStyle(.syncFilled)
                }

                Button("거절", action: onDecline)
                    .buttonStyle(.syncQuiet)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Someone already on stage: the host can silence them, or send them back to
/// the audience.
private struct JoinRequestManagerParticipantRow: View {
    let participant: Participant
    @Binding var isMuted: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            ArtistRow(artist: participant.artist) {
                RoleChip(role: participant.role)
            }

            Toggle(isOn: $isMuted) {
                Text("마이크 음소거")
                    .typography(.meta)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Palette.ink)
            .frame(minHeight: Metric.tapTarget)

            Button("내보내기", action: onRemove)
                .buttonStyle(.syncDestructive)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

private func previewRequestManager(_ behaviour: MockDataSource.Behaviour = .populated,
                                   room: LiveRoom = Fixtures.chansRoom) -> some View {
    JoinRequestManagerSheet(
        room: room,
        model: JoinRequestManagerModel(room: room,
                                       dataSource: MockDataSource(behaviour: behaviour))
    )
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewRequestManager().preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewRequestManager().preferredColorScheme(.dark)
}

#Preview("로딩") {
    previewRequestManager(.loading)
}

#Preview("빈 상태") {
    previewRequestManager(.empty)
}

#Preview("오류") {
    previewRequestManager(.failing)
}

#Preview("자리가 모두 찬 방") {
    previewRequestManager(room: Fixtures.plainRoom)
}

#Preview("Dynamic Type — accessibility3") {
    previewRequestManager().environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("요청 · 참여자 행", traits: .sizeThatFitsLayout) {
    @Previewable @State var isMuted = false

    VStack(alignment: .leading, spacing: Space.s32) {
        JoinRequestManagerRequestRow(request: Fixtures.joinRequests[0],
                                     canAccept: true,
                                     onAccept: {},
                                     onDecline: {})
        JoinRequestManagerRequestRow(request: Fixtures.joinRequests[1],
                                     canAccept: false,
                                     onAccept: {},
                                     onDecline: {})
        JoinRequestManagerParticipantRow(participant: Fixtures.participants[0],
                                         isMuted: $isMuted,
                                         onRemove: {})
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
