//  FollowSuggestionsView.swift  (S8)
//
//  Liquid Glass: none is drawn here. The flow's `NavigationStack` supplies the
//  one glass bar on screen; the grid beneath it is content, so the cells carry no
//  material, border or shadow, and the two closing actions sit on an opaque
//  `.safeAreaInset` rather than on a pane pretending to be glass.

import SwiftUI

// MARK: - Model

@MainActor
@Observable
final class FollowSuggestionsModel {
    private let dataSource: any DataSource

    var state: LoadState<[Artist]> = .loading
    /// Who the newcomer has followed so far, by artist id. Seeded from the
    /// loaded artists so a suggestion that is already followed comes back on.
    private(set) var followed: Set<UUID> = []

    init(dataSource: any DataSource = MockDataSource.shared) {
        self.dataSource = dataSource
    }

    func load() async {
        state = await LoadState.load { try await self.dataSource.onboardingSuggestions() }
        if let artists = state.value {
            followed = Set(artists.filter { $0.isFollowing }.map { $0.id })
        }
    }

    func isFollowing(_ artist: Artist) -> Bool { followed.contains(artist.id) }

    func toggleFollow(_ artist: Artist) {
        if followed.contains(artist.id) {
            followed.remove(artist.id)
        } else {
            followed.insert(artist.id)
        }
    }
}

// MARK: - Screen

struct FollowSuggestionsView: View {
    @Environment(SessionModel.self) private var session

    @State private var model: FollowSuggestionsModel

    init(model: FollowSuggestionsModel = FollowSuggestionsModel()) {
        _model = State(initialValue: model)
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: Space.s16),
         GridItem(.flexible(), spacing: Space.s16)]
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Space.s32) {
                intro

                switch model.state {
                case .loading:
                    loadingContent
                case .failed(let error):
                    ErrorStateView(error: error) {
                        Task { await model.load() }
                    }
                case .loaded(let artists):
                    if artists.isEmpty {
                        emptyContent
                    } else {
                        grid(artists)
                    }
                }
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Space.s16)
            .padding(.bottom, Space.s48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .navigationTitle("추천 아티스트")
        // The only way back from here is forward: a social sign-in lands on this
        // step without passing through the profile step, so a back button would
        // push the newcomer into a screen they never saw. "건너뛰기" is the exit.
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            AuthStepFooter {
                Button("시작하기") { session.stage = .signedIn }
                    .buttonStyle(.syncSolid)

                Button("건너뛰기") { session.stage = .signedIn }
                    .buttonStyle(.syncQuiet)
            }
        }
        .task { await model.load() }
    }

    // MARK: - Intro

    private var intro: some View {
        Text("팔로우해두면 이 아티스트가 라이브를 시작할 때 알려드려요.")
            .typography(.body)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Loaded

    private func grid(_ artists: [Artist]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Space.s32) {
            ForEach(artists) { artist in
                FollowSuggestionCell(artist: artist,
                                     isFollowing: model.isFollowing(artist)) {
                    model.toggleFollow(artist)
                }
            }
        }
        .motion(value: model.followed)
    }

    // MARK: - Empty

    /// No action here: the footer already carries the only two ways on from this
    /// screen, and repeating one of them would be a third button saying the same
    /// thing.
    private var emptyContent: some View {
        EmptyStateView(
            title: "추천할 아티스트를 찾지 못했어요",
            message: "나중에 탐색 탭에서 관심 있는 아티스트를 찾아볼 수 있어요."
        )
    }

    // MARK: - Loading

    /// The real grid geometry, redacted, so the cells arrive where the skeleton
    /// stood rather than shifting the footer.
    private var loadingContent: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Space.s32) {
            ForEach(Fixtures.allArtists.prefix(4)) { artist in
                FollowSuggestionCell(artist: artist, isFollowing: false) {}
            }
        }
        .skeleton(true)
    }
}

// MARK: - Cell

/// One suggestion. Left-aligned on the same margin as everything else — a grid
/// position is not a reason to centre a name or wrap it in a card.
private struct FollowSuggestionCell: View {
    let artist: Artist
    let isFollowing: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            AvatarView(artist: artist, size: Metric.avatarL)

            VStack(alignment: .leading, spacing: Space.s8) {
                NameLabel(artist: artist, style: .cardTitle)

                if !artist.hashtags.isEmpty {
                    HashtagChipRow(tags: artist.hashtags, maxLines: 1)
                }
            }

            FollowButton(isFollowing: isFollowing, action: onToggle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

private func previewFollowSuggestions(_ behaviour: MockDataSource.Behaviour) -> some View {
    NavigationStack {
        FollowSuggestionsView(
            model: FollowSuggestionsModel(dataSource: MockDataSource(behaviour: behaviour))
        )
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewFollowSuggestions(.populated).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewFollowSuggestions(.populated).preferredColorScheme(.dark)
}

#Preview("로딩") {
    previewFollowSuggestions(.loading)
}

#Preview("빈 상태") {
    previewFollowSuggestions(.empty)
}

#Preview("오류") {
    previewFollowSuggestions(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewFollowSuggestions(.populated).environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("추천 셀", traits: .sizeThatFitsLayout) {
    @Previewable @State var isFollowing = false
    HStack(alignment: .top, spacing: Space.s16) {
        FollowSuggestionCell(artist: Fixtures.seungchan, isFollowing: isFollowing) {
            isFollowing.toggle()
        }
        FollowSuggestionCell(artist: Fixtures.longform, isFollowing: true) {}
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
