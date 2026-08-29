//  ArtistProfileView.swift  (S20)
//
//  Liquid Glass: the trailing `ellipsis` lives in a real `.toolbar`, so the
//  system draws its glass capsule, and the actions behind it are a
//  `.confirmationDialog` — a system presentation with the platform's own
//  material — rather than a custom panel. The share and donation sheets go
//  through one `.sheet(item:)`. The content column, live banner included, is
//  opaque: it uses the `signalLive` fill, never a translucent pane.

import SwiftUI

/// The two things this screen can present. One slot, so they can never fight
/// over the same presentation.
enum ArtistProfileSheet: String, Identifiable, Sendable {
    case share, donation
    var id: String { rawValue }
}

@MainActor
@Observable
final class ArtistProfileModel {
    private let dataSource: any DataSource
    private let handle: String
    /// Local override of the fetched follow flag, so the toggle responds now
    /// and the next fetch still wins.
    private var followOverride: Bool?

    var state: LoadState<ProfileFeed> = .loading
    var isPresentingActions = false
    var sheet: ArtistProfileSheet?
    var toast: Toast?

    init(artist: Artist, dataSource: any DataSource = MockDataSource.shared) {
        self.handle = artist.handle
        self.dataSource = dataSource
    }

    var isFollowing: Bool {
        followOverride ?? state.value?.artist.isFollowing ?? false
    }

    func load() async {
        state = await LoadState.load { try await self.dataSource.profile(handle: self.handle) }
    }

    func reload() async {
        await load()
    }

    func toggleFollow() {
        followOverride = !isFollowing
    }

    func report() {
        toast = Toast(message: String(localized: "신고가 접수되었어요",
                                      comment: "Confirmation after reporting a profile"))
    }

    func block() {
        toast = Toast(message: String(localized: "차단했어요",
                                      comment: "Confirmation after blocking a profile"))
    }

    func confirmDonation(_ donation: Donation) {
        toast = Toast(message: String(localized: "\(Format.currency(donation.amount)) 후원을 보냈어요",
                                      comment: "Confirmation after sending a donation"))
    }
}

struct ArtistProfileView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PlaybackController.self) private var playback

    /// The artist we were pushed with. Enough to title the screen and to draw
    /// the skeleton before the fetch lands.
    let artist: Artist

    @State private var model: ArtistProfileModel

    init(artist: Artist, model: ArtistProfileModel? = nil) {
        self.artist = artist
        _model = State(initialValue: model ?? ArtistProfileModel(artist: artist))
    }

    var body: some View {
        ScrollView(.vertical) {
            switch model.state {
            case .loading:
                loadingContent
            case .failed(let error):
                ErrorStateView(error: error) {
                    Task { await model.reload() }
                }
                .padding(.horizontal, Metric.screenMargin)
            case .loaded(let feed):
                profileContent(feed)
            }
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .refreshable { await model.reload() }
        .navigationTitle(Text(verbatim: artist.displayName))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // A `Menu`, not a `.confirmationDialog`. On iOS 26 a dialog with
                // no source anchor is presented as a floating list that simply
                // appears — there is nothing for it to animate out of. A menu is
                // anchored to the control that opened it, so the system grows it
                // from the button and collapses it back.
                Menu {
                    Button("공유") { model.sheet = .share }
                    Button("신고") { model.report() }
                    Button("차단", role: .destructive) { model.block() }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("더 보기")
            }
        }
        .sheet(item: $model.sheet) { sheet in
            // The sheets own their detents.
            switch sheet {
            case .share:
                ShareProfileSheet(artist: model.state.value?.artist ?? artist)
            case .donation:
                if let room = model.state.value?.currentRoom {
                    DonationSheet(room: room) { donation in
                        model.confirmDonation(donation)
                    }
                }
            }
        }
        .toast($model.toast)
        .task { await model.load() }
    }

    // MARK: - Loaded

    private func profileContent(_ feed: ProfileFeed) -> some View {
        VStack(spacing: Space.s48) {
            VStack(spacing: Space.s32) {
                if let room = feed.currentRoom {
                    liveBanner(room)
                }

                ProfileIdentityBlock(artist: feed.artist)

                ProfileStatsRow(
                    artist: feed.artist,
                    onTapFollowers: { router.push(.follows(.followers, feed.artist)) },
                    onTapFollowing: { router.push(.follows(.following, feed.artist)) }
                )

                actions(feed)
            }

            pastBroadcastSection(feed.pastBroadcasts)
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .padding(.bottom, Space.s48)
    }

    /// The one place on this screen that carries the accent. "On air right now"
    /// is information, so it is a `signalLive` fill with `onSignal` text — not a
    /// tinted label floating on the surface.
    private func liveBanner(_ room: LiveRoom) -> some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text("지금 라이브 중")
                .typography(.metaStrong)
                .foregroundStyle(Palette.onSignal)

            Text(room.title)
                .typography(.cardTitle)
                .foregroundStyle(Palette.onSignal)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("시청하기") {
                playback.watch(room)
            }
            .buttonStyle(.syncFilled)
            .padding(.top, Space.s4)
        }
        .padding(Space.s20)
        .background(Palette.signalLive, in: .rect(cornerRadius: Radius.panel))
        .accessibilityElement(children: .contain)
    }

    /// Side by side while the labels fit; stacked once Dynamic Type makes them
    /// too wide to share a line.
    private func actions(_ feed: ProfileFeed) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s12) {
                followButton
                donateButton(feed)
            }
            VStack(spacing: Space.s12) {
                followButton
                donateButton(feed)
            }
        }
    }

    private var followButton: some View {
        Button(model.isFollowing ? "팔로잉" : "팔로우") {
            model.toggleFollow()
        }
        .buttonStyle(.syncFilled)
        .accessibilityAddTraits(model.isFollowing ? .isSelected : [])
        .motion(value: model.isFollowing)
    }

    /// A donation is sent into a room, so the action exists only while this
    /// artist is on air and taking them — hidden rather than shown disabled.
    @ViewBuilder
    private func donateButton(_ feed: ProfileFeed) -> some View {
        if let room = feed.currentRoom, room.acceptsDonation {
            Button("후원하기") {
                model.sheet = .donation
            }
            .buttonStyle(.syncFilled)
        }
    }

    private func pastBroadcastSection(_ broadcasts: [PastBroadcast]) -> some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            SectionHeader(title: "지난 방송")

            if broadcasts.isEmpty {
                EmptyStateView(title: "아직 지난 방송이 없어요")
            } else {
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: Space.s24) {
                    ForEach(broadcasts) { broadcast in
                        PastBroadcastTile(broadcast: broadcast)
                    }
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: Space.s12),
         GridItem(.flexible(), spacing: Space.s12)]
    }

    // MARK: - Loading

    /// The real layout, redacted. We already know the artist we were pushed
    /// with, so the skeleton is this profile's own geometry — with two tiles
    /// standing in for whatever archive arrives.
    private var loadingContent: some View {
        profileContent(
            ProfileFeed(artist: artist,
                        pastBroadcasts: Array(Fixtures.pastBroadcasts.prefix(2)),
                        currentRoom: nil)
        )
        .skeleton(true)
    }
}

// MARK: - Previews

private func previewArtistProfile(_ artist: Artist,
                                  _ behaviour: MockDataSource.Behaviour = .populated) -> some View {
    NavigationStack {
        ArtistProfileView(
            artist: artist,
            model: ArtistProfileModel(artist: artist,
                                      dataSource: MockDataSource(behaviour: behaviour))
        )
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewArtistProfile(Fixtures.seungchan).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewArtistProfile(Fixtures.seungchan).preferredColorScheme(.dark)
}

#Preview("지난 방송 없음") {
    previewArtistProfile(Fixtures.user)
}

#Preview("로딩") {
    previewArtistProfile(Fixtures.seungchan, .loading)
}

#Preview("빈 상태") {
    previewArtistProfile(Fixtures.seungchan, .empty)
}

#Preview("오류") {
    previewArtistProfile(Fixtures.seungchan, .failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewArtistProfile(Fixtures.longform)
        .environment(\.dynamicTypeSize, .accessibility3)
}
