//  ParticipantListSheet.swift  (S23)
//
//  Liquid Glass: a sheet *is* the platform's glass, so this file paints no
//  background of its own and never restyles the presentation — it only declares
//  `.presentationDetents([.medium, .large])` so the detents travel with the view
//  rather than living at whichever screen happens to present it. The roster
//  below is content, and content is opaque: rows are grouped by space, never by
//  cards or rules.

import SwiftUI

// MARK: - Model

@MainActor
@Observable
final class ParticipantListModel {

    private let dataSource: any DataSource

    let room: LiveRoom

    /// The performers only. The host holds the room rather than a slot, so they
    /// are not in this list.
    var state: LoadState<[Participant]> = .loading

    /// Follow toggles made inside the sheet. The fixture graph is immutable, so
    /// the override is what a row reads back.
    private var followOverrides: [UUID: Bool] = [:]

    init(room: LiveRoom, dataSource: any DataSource = MockDataSource.shared) {
        self.room = room
        self.dataSource = dataSource
    }

    /// The figure in the title. Falls back to the count the room was handed with,
    /// so the title does not jump when the roster lands.
    var participantCount: Int {
        state.value?.count ?? room.participantCount
    }

    func load() async {
        state = await LoadState.load {
            try await self.dataSource.roomDetail(id: self.room.id).participants
        }
    }

    func isFollowing(_ artist: Artist) -> Bool {
        followOverrides[artist.id] ?? artist.isFollowing
    }

    func toggleFollow(_ artist: Artist) {
        followOverrides[artist.id] = !isFollowing(artist)
    }
}

// MARK: - Screen

struct ParticipantListSheet: View {
    @Environment(SessionModel.self) private var session

    let room: LiveRoom

    @State private var model: ParticipantListModel

    init(room: LiveRoom) {
        self.init(room: room, model: ParticipantListModel(room: room))
    }

    /// The injection seam previews use to pick a `MockDataSource` behaviour.
    init(room: LiveRoom, model: ParticipantListModel) {
        self.room = room
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s32) {
                title
                hostSection
                participantSection
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s24)
            .padding(.bottom, Space.s48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await model.load() }
    }

    // MARK: - Title

    private var title: some View {
        Text("참여자 \(Format.count(model.participantCount))")
            .typography(.screenTitle)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Host

    /// The host is not one of the performer slots, so they are named separately
    /// above the roster instead of being counted into it.
    private var hostSection: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            LiveSheetLabel(title: "호스트")

            ParticipantListRow(artist: room.host,
                               isFollowing: model.isFollowing(room.host),
                               showsFollow: canFollow(room.host)) {
                model.toggleFollow(room.host)
            }
        }
    }

    // MARK: - Participants

    private var participantSection: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            LiveSheetLabel(title: "참여자")

            switch model.state {
            case .loading:
                loadingContent
            case .failed(let error):
                ErrorStateView(error: error) {
                    Task { await model.load() }
                }
            case .loaded(let participants):
                if participants.isEmpty {
                    emptyContent
                } else {
                    VStack(alignment: .leading, spacing: Space.s16) {
                        ForEach(participants) { participant in
                            row(participant)
                        }
                    }
                }
            }
        }
        .motion(value: model.participantCount)
    }

    private func row(_ participant: Participant) -> some View {
        ParticipantListRow(artist: participant.artist,
                           role: participant.role,
                           isFollowing: model.isFollowing(participant.artist),
                           showsFollow: canFollow(participant.artist)) {
            model.toggleFollow(participant.artist)
        }
    }

    /// Following yourself is not a thing, so the control is hidden on your own
    /// row rather than shown disabled.
    private func canFollow(_ artist: Artist) -> Bool {
        artist.id != session.currentUser.id
    }

    // MARK: - Empty

    private var emptyContent: some View {
        EmptyStateView(title: "아직 참여자가 없어요",
                       message: "호스트가 참여를 수락하면 여기에 표시돼요.")
    }

    // MARK: - Loading

    /// The real row geometry, redacted — the same shape the roster will arrive in.
    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            ForEach(Fixtures.participants) { participant in
                ParticipantListRow(artist: participant.artist,
                                   role: participant.role,
                                   isFollowing: false,
                                   showsFollow: true) {}
            }
        }
        .skeleton(true)
    }
}

// MARK: - Row

/// One person in the roster. The trailing slot carries what they play and
/// whether you follow them — the two things this sheet exists to show.
private struct ParticipantListRow: View {
    let artist: Artist
    /// `nil` for the host, who holds the room rather than a performer slot.
    var role: PerformerRole?
    let isFollowing: Bool
    let showsFollow: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        ArtistRow(artist: artist) {
            HStack(spacing: Space.s8) {
                if let role {
                    RoleChip(role: role)
                }
                if showsFollow {
                    FollowButton(isFollowing: isFollowing, action: onToggleFollow)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

private func previewParticipantList(_ behaviour: MockDataSource.Behaviour = .populated,
                                    room: LiveRoom = Fixtures.chansRoom) -> some View {
    ParticipantListSheet(
        room: room,
        model: ParticipantListModel(room: room,
                                    dataSource: MockDataSource(behaviour: behaviour))
    )
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewParticipantList().preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewParticipantList().preferredColorScheme(.dark)
}

#Preview("다른 사람의 방") {
    previewParticipantList(room: Fixtures.longformRoom)
}

#Preview("로딩") {
    previewParticipantList(.loading)
}

#Preview("빈 상태") {
    previewParticipantList(.empty)
}

#Preview("오류") {
    previewParticipantList(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewParticipantList().environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("행 — 호스트와 참여자", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s16) {
        ParticipantListRow(artist: Fixtures.seungchan,
                           isFollowing: false,
                           showsFollow: false) {}
        ParticipantListRow(artist: Fixtures.user,
                           role: .guitar,
                           isFollowing: false,
                           showsFollow: true) {}
        ParticipantListRow(artist: Fixtures.longform,
                           role: .drums,
                           isFollowing: true,
                           showsFollow: true) {}
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
