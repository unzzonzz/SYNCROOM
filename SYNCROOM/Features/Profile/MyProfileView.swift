//  MyProfileView.swift  (S3)
//
//  Liquid Glass: the only glass on this screen is the system's. The trailing
//  `ellipsis` sits in a real `.toolbar`, so the platform draws the glass capsule
//  around it and nothing here paints a bar background, and `ShareProfileSheet`
//  arrives through `.sheet`, whose material the system owns. Everything in the
//  content column — identity, stats, the paired buttons, the settings rows —
//  stays opaque, because content is never glass in this design system.

import SwiftUI

@MainActor
@Observable
final class MyProfileModel {
    private let dataSource: any DataSource

    var state: LoadState<ProfileFeed> = .loading
    /// The share sheet is presented state, not a pushed route.
    var isPresentingShare = false

    init(dataSource: any DataSource = MockDataSource.shared) {
        self.dataSource = dataSource
    }

    func load() async {
        state = await LoadState.load { try await self.dataSource.myProfile() }
    }

    func reload() async {
        await load()
    }
}

struct MyProfileView: View {
    @Environment(AppRouter.self) private var router
    @Environment(SessionModel.self) private var session

    @State private var model: MyProfileModel

    init(model: MyProfileModel = MyProfileModel()) {
        _model = State(initialValue: model)
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
        .navigationTitle("프로필")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.settings)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("설정")
            }
        }
        .sheet(isPresented: $model.isPresentingShare) {
            // The sheet's own root owns its detents.
            ShareProfileSheet(artist: model.state.value?.artist ?? session.currentUser)
        }
        .task { await model.load() }
    }

    // MARK: - Loaded

    private func profileContent(_ feed: ProfileFeed) -> some View {
        VStack(spacing: Space.s48) {
            // Identity, figures and the two actions read as one block, so they
            // sit closer together than the section that follows them.
            VStack(spacing: Space.s32) {
                ProfileIdentityBlock(artist: feed.artist)

                ProfileStatsRow(
                    artist: feed.artist,
                    onTapFollowers: { router.push(.follows(.followers, feed.artist)) },
                    onTapFollowing: { router.push(.follows(.following, feed.artist)) }
                )

                actions
            }

            infoSection
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .padding(.bottom, Space.s48)
    }

    /// Side by side while the labels fit; stacked once Dynamic Type makes them
    /// too wide to share a line.
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s12) {
                editButton
                shareButton
            }
            VStack(spacing: Space.s12) {
                editButton
                shareButton
            }
        }
    }

    private var editButton: some View {
        Button("프로필 수정") {
            router.push(.editProfile)
        }
        .buttonStyle(.syncFilled)
    }

    private var shareButton: some View {
        Button("프로필 공유") {
            model.isPresentingShare = true
        }
        .buttonStyle(.syncFilled)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            SectionHeader(title: "내 정보")

            // Titles alone: each row names a destination that needs no gloss, and
            // dropping the descriptions makes this a run of like-for-like rows,
            // which is where the platform hairline earns its place.
            // `SettingsRow`'s description stays optional — Settings still uses it.
            VStack(spacing: 0) {
                SettingsRow(title: "시청 기록") {
                    router.push(.watchHistory)
                }
                RowSeparator()
                SettingsRow(title: "내 라이브") {
                    router.push(.myBroadcasts)
                }
                RowSeparator()
                SettingsRow(title: "후원 내역") {
                    router.push(.donationHistory)
                }
            }
        }
    }

    // MARK: - Loading

    /// The real layout, redacted. We already know who is signed in, so the
    /// skeleton is this profile's own geometry rather than an invented one.
    private var loadingContent: some View {
        profileContent(
            ProfileFeed(artist: session.currentUser, pastBroadcasts: [], currentRoom: nil)
        )
        .skeleton(true)
    }
}

// MARK: - Shared profile pieces

// The identity block and the stats row are identical on S3 and S20, so they are
// defined once here and reused by `ArtistProfileView`.

/// Avatar, name with its verification mark, handle, hashtags — centred.
struct ProfileIdentityBlock: View {
    let artist: Artist

    var body: some View {
        VStack(spacing: Space.s16) {
            AvatarView(artist: artist, size: Metric.avatarXL)

            VStack(spacing: Space.s4) {
                NameLabel(artist: artist, style: .identityName, badgeSize: 20)
                Text(verbatim: Format.handle(artist.handle))
                    .typography(.body)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }

            if !artist.hashtags.isEmpty {
                HashtagChipRow(tags: artist.hashtags, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The two figures under the identity block, in equal columns.
struct ProfileStatsRow: View {
    let artist: Artist
    let onTapFollowers: () -> Void
    let onTapFollowing: () -> Void

    var body: some View {
        HStack(spacing: Space.s16) {
            ProfileStatColumn(title: "팔로워",
                              value: artist.followerCount,
                              action: onTapFollowers)
            ProfileStatColumn(title: "팔로잉",
                              value: artist.followingCount,
                              action: onTapFollowing)
        }
    }
}

/// One figure and its label. The Korean unit that `Format.count` appends ("만")
/// is split onto a smaller run so the number stays the dominant thing in the
/// column — two adjacent `Text` views rather than a deprecated `Text + Text`.
struct ProfileStatColumn: View {
    let title: LocalizedStringKey
    let value: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Space.s4) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(verbatim: parts.figure)
                        .typography(.displayStat)
                        .foregroundStyle(Palette.ink)
                    if !parts.unit.isEmpty {
                        Text(verbatim: parts.unit)
                            .typography(.displayUnit)
                            .foregroundStyle(Palette.ink)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)

                Text(title)
                    .typography(.chip)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Metric.tapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(Text(verbatim: Format.count(value)))
    }

    private var parts: (figure: String, unit: String) {
        ProfileStat.split(Format.count(value))
    }
}

/// Splits a formatted count into its digits and the unit that trails them —
/// `12만` → `12` + `만`, `8,304` → `8,304` + ``.
enum ProfileStat {
    static func split(_ text: String) -> (figure: String, unit: String) {
        guard let lastDigit = text.lastIndex(where: \.isNumber) else { return (text, "") }
        let boundary = text.index(after: lastDigit)
        return (String(text[...lastDigit]), String(text[boundary...]))
    }
}

// MARK: - Previews

private func previewMyProfile(_ behaviour: MockDataSource.Behaviour) -> some View {
    NavigationStack {
        MyProfileView(model: MyProfileModel(dataSource: MockDataSource(behaviour: behaviour)))
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewMyProfile(.populated).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewMyProfile(.populated).preferredColorScheme(.dark)
}

#Preview("로딩") {
    previewMyProfile(.loading)
}

#Preview("빈 상태") {
    previewMyProfile(.empty)
}

#Preview("오류") {
    previewMyProfile(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewMyProfile(.populated).environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("프로필 헤더 조각", traits: .sizeThatFitsLayout) {
    VStack(spacing: Space.s32) {
        ProfileIdentityBlock(artist: Fixtures.seungchan)
        ProfileStatsRow(artist: Fixtures.seungchan, onTapFollowers: {}, onTapFollowing: {})
        ProfileIdentityBlock(artist: Fixtures.longform)
        ProfileStatsRow(artist: Fixtures.longform, onTapFollowers: {}, onTapFollowing: {})
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
