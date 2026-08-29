//  FollowListView.swift  (S18)
//
//  Liquid Glass: the only glass here is the system's. `.searchable` puts the
//  filter field in the navigation bar where the platform draws it, and
//  The field sits in the navigation bar drawer, always visible, as the
//  list scrolls — which is why nothing builds a `TextField` search bar. The
//  segmented picker and the rows below it are content, and content is opaque.

import SwiftUI

// MARK: - Model

/// Both sides of the relationship, fetched together so switching the picker is
/// a filter over what is already here rather than a second wait.
struct FollowListPayload: Hashable, Sendable {
    var followers: [Artist]
    var following: [Artist]
}

@MainActor
@Observable
final class FollowListModel {
    private let dataSource: any DataSource
    private let artist: Artist

    var state: LoadState<FollowListPayload> = .loading
    var scope: FollowScope
    /// The `.searchable` field's text.
    var query: String = ""
    var toast: Toast?

    /// Follow toggles and removals made here. The fixture graph is immutable, so
    /// the changes live beside the results rather than inside them.
    private var followOverrides: [UUID: Bool] = [:]
    private var removed: Set<UUID> = []

    init(artist: Artist,
         scope: FollowScope,
         dataSource: any DataSource = MockDataSource.shared) {
        self.artist = artist
        self.scope = scope
        self.dataSource = dataSource
    }

    func load() async {
        state = await LoadState.load {
            FollowListPayload(
                followers: try await self.dataSource.followers(of: self.artist),
                following: try await self.dataSource.following(of: self.artist)
            )
        }
    }

    func reload() async {
        await load()
    }

    // MARK: Reading

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A field holding nothing but spaces is still an idle field.
    var isFiltering: Bool { !trimmedQuery.isEmpty }

    /// Everyone on the current side, before the search field narrows it.
    func people(_ payload: FollowListPayload) -> [Artist] {
        switch scope {
        case .followers: payload.followers.filter { !removed.contains($0.id) }
        case .following: payload.following
        }
    }

    /// The current side, narrowed by the search field.
    func filtered(_ payload: FollowListPayload) -> [Artist] {
        let all = people(payload)
        guard isFiltering else { return all }
        let needle = trimmedQuery
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(needle) || $0.handle.lowercased().contains(needle)
        }
    }

    // MARK: Writing

    /// Everyone on the 팔로잉 side is followed by definition, so that is the
    /// answer until this screen is told otherwise.
    func isFollowing(_ person: Artist) -> Bool {
        followOverrides[person.id] ?? true
    }

    func toggleFollow(_ person: Artist) {
        followOverrides[person.id] = !isFollowing(person)
    }

    func remove(_ person: Artist) {
        removed.insert(person.id)
        toast = Toast(message: String(localized: "팔로워에서 삭제했어요",
                                      comment: "Confirmation after removing a follower"))
    }
}

// MARK: - Screen

struct FollowListView: View {
    @Environment(AppRouter.self) private var router

    /// Whose list this is. Enough to title the screen and to label the picker
    /// before the fetch lands.
    let artist: Artist

    @State private var model: FollowListModel

    init(artist: Artist, scope: FollowScope, model: FollowListModel? = nil) {
        self.artist = artist
        _model = State(initialValue: model ?? FollowListModel(artist: artist, scope: scope))
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s24) {
                scopePicker
                    .padding(.horizontal, Metric.screenMargin)

                content
            }
            .padding(.top, Space.s16)
            .padding(.bottom, Space.s48)
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await model.reload() }
        .navigationTitle(Text(verbatim: artist.displayName))
        .toolbarTitleDisplayMode(.inline)
        // A drawer field rather than the minimising one, for the reason spelled
        // out in `ExploreView`: the collapse transition is broken upstream and
        // there is no API to tune it. A field that never collapses cannot show
        // the fault.
        .searchable(text: $model.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "이름 또는 핸들 검색")
        .motion(value: model.scope)
        .toast($model.toast)
        .task { await model.load() }
    }

    /// The counts come from the profile that was pushed, so the picker reads
    /// "팔로워 12만 / 팔로잉 10" from the first frame instead of after the fetch.
    private var scopePicker: some View {
        Picker("팔로우 목록", selection: $model.scope) {
            Text("팔로워 \(Format.count(artist.followerCount))")
                .tag(FollowScope.followers)
            Text("팔로잉 \(Format.count(artist.followingCount))")
                .tag(FollowScope.following)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            loadingContent
        case .failed(let error):
            ErrorStateView(error: error) {
                Task { await model.reload() }
            }
            .padding(.horizontal, Metric.screenMargin)
        case .loaded(let payload):
            let shown = model.filtered(payload)
            if shown.isEmpty {
                emptyContent(hasAnyone: !model.people(payload).isEmpty)
                    .padding(.horizontal, Metric.screenMargin)
            } else {
                rows(shown)
            }
        }
    }

    private func rows(_ people: [Artist]) -> some View {
        LazyVStack(alignment: .leading, spacing: Space.s24) {
            ForEach(people) { person in
                row(person)
            }
        }
        .padding(.horizontal, Metric.screenMargin)
    }

    /// The trailing action is what each side is actually for: on 팔로잉 you stop
    /// following someone, on 팔로워 you remove them.
    private func row(_ person: Artist) -> some View {
        ArtistRow(artist: person) {
            switch model.scope {
            case .following:
                FollowButton(isFollowing: model.isFollowing(person)) {
                    model.toggleFollow(person)
                }
            case .followers:
                Button("삭제") {
                    model.remove(person)
                }
                .buttonStyle(.syncDestructive)
            }
        }
        .contentShape(.rect)
        // The trailing control takes its own taps; the rest of the row opens the
        // profile.
        .onTapGesture { router.openArtist(person) }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "프로필 열기") { router.openArtist(person) }
    }

    // MARK: - Empty

    /// Three different nothings: nobody on this side, or a filter that matched
    /// nobody. They are not the same message.
    @ViewBuilder
    private func emptyContent(hasAnyone: Bool) -> some View {
        if hasAnyone {
            EmptyStateView(
                title: "'\(model.trimmedQuery)'에 대한 결과가 없어요",
                message: "이름이나 핸들의 일부만 넣어보세요."
            )
        } else {
            switch model.scope {
            case .followers:
                EmptyStateView(
                    title: "아직 팔로워가 없어요",
                    message: "라이브를 시작하면 찾아온 사람들이 여기에 쌓여요."
                )
            case .following:
                EmptyStateView(
                    title: "아직 팔로우한 아티스트가 없어요",
                    message: "관심 있는 아티스트를 팔로우하면 여기에 모여요.",
                    actionTitle: "아티스트 찾아보기"
                ) {
                    router.tab = .search
                }
            }
        }
    }

    // MARK: - Loading

    /// The real row geometry, redacted, so what arrives lands where the skeleton
    /// stood.
    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: Space.s24) {
            ForEach(Fixtures.recommendedArtists) { person in
                ArtistRow(artist: person) {
                    FollowButton(isFollowing: true) {}
                }
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .skeleton(true)
    }
}

// MARK: - Previews

private func previewFollowList(_ scope: FollowScope,
                               artist: Artist = Fixtures.seungchan,
                               behaviour: MockDataSource.Behaviour = .populated) -> some View {
    NavigationStack {
        FollowListView(
            artist: artist,
            scope: scope,
            model: FollowListModel(artist: artist,
                                   scope: scope,
                                   dataSource: MockDataSource(behaviour: behaviour))
        )
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("팔로워 — 라이트") {
    previewFollowList(.followers).preferredColorScheme(.light)
}

#Preview("팔로워 — 다크") {
    previewFollowList(.followers).preferredColorScheme(.dark)
}

#Preview("팔로잉") {
    previewFollowList(.following)
}

#Preview("로딩") {
    previewFollowList(.followers, behaviour: .loading)
}

#Preview("빈 상태 — 팔로워") {
    previewFollowList(.followers, artist: Fixtures.user, behaviour: .empty)
}

#Preview("빈 상태 — 팔로잉") {
    previewFollowList(.following, artist: Fixtures.user, behaviour: .empty)
}

#Preview("오류") {
    previewFollowList(.followers, behaviour: .failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewFollowList(.followers, artist: Fixtures.longform)
        .environment(\.dynamicTypeSize, .accessibility3)
}
