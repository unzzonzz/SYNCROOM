//  ExploreView.swift  (S2)
//
//  Liquid Glass: search on this screen is the platform's, not ours. `.searchable`
//  puts the field in the navigation bar where the system draws its glass, and
//  The field sits in the navigation bar drawer, always visible, as content
//  scrolls — which is why nothing here builds a `TextField` search bar. The scope
//  bar and the suggestion list come from the same system container, so the whole
//  content column below stays opaque and never competes with it.
//
//  Motion: the field's expand / minimise is the system's own animation and this
//  screen adds nothing on top of it. An `.animation` sitting above `.searchable`
//  — even one driven by a value derived from the query — re-drives the very
//  transition the search container is already running. The single animation
//  here is `.motion(value: model.recents)` on the
//  idle content column, because the recent-search list is the only thing this
//  screen animates itself.

import SwiftUI

@MainActor
@Observable
final class ExploreModel {
    private let dataSource: any DataSource

    var state: LoadState<ExploreFeed> = .loading

    /// The search field's text. The Search tab owns it, so the results screen,
    /// the scope bar and the suggestion list all read one source of truth.
    var query: String = ""
    var scope: SearchScope = .all

    /// Recent searches, held apart from `state` because rows are dismissed one
    /// at a time and cleared all at once.
    var recents: [RecentQuery] = []
    /// Completions offered while the field is being typed into.
    var suggestions: [RecentQuery] = []

    init(dataSource: any DataSource = MockDataSource.shared) {
        self.dataSource = dataSource
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A field holding nothing but spaces is still an idle field.
    var isSearching: Bool { !trimmedQuery.isEmpty }

    func load() async {
        state = await LoadState.load { try await self.dataSource.exploreFeed() }
        recents = state.value?.recent ?? []
    }

    func loadSuggestions() async {
        guard isSearching else {
            suggestions = []
            return
        }
        suggestions = (try? await dataSource.suggestions(for: trimmedQuery)) ?? []
    }

    /// Tapping a recent row re-runs it, by putting it back in the field.
    func recall(_ recent: RecentQuery) {
        query = recent.queryText
    }

    func remove(_ recent: RecentQuery) {
        recents.removeAll { $0.id == recent.id }
    }

    func clearRecents() {
        recents.removeAll()
    }
}

struct ExploreView: View {
    @Environment(AppRouter.self) private var router

    @State private var model: ExploreModel

    init(model: ExploreModel = ExploreModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model

        Group {
            if model.isSearching {
                SearchResultsView(query: model.trimmedQuery, scope: $model.scope)
            } else {
                idleContent
            }
        }
        // Nothing of ours animates the search field. A `.animation(nil, …)` here
        // does not merely decline to animate — it truncates the system's own
        // minimise transition, and the button loses the glass capsule it is
        // supposed to collapse into. `isSearching` also never changes during a
        // plain toggle (it tracks the query, not the focus), so there was
        // nothing to suppress in the first place. Deletions animate from
        // `loadedContent`, which is keyed on `recents`.
        .background(Palette.surface)
        .navigationTitle("탐색")
        .toolbarTitleDisplayMode(.large)
        // A drawer field that is always on screen, rather than one that collapses
        // to a toolbar button.
        //
        // `.searchToolbarBehavior(.minimize)` was the original choice, but its
        // dismiss transition is visibly broken and the break is Apple's, not
        // ours: a bare `List` + `.searchable` + `.minimize`, with none of this
        // screen's code, empties the field to a blank pill, flashes a stray
        // chevron, blanks the bar for ~0.15s and then pops the button in. There
        // is no API to tune that transition. A field that never collapses has no
        // transition to get wrong — and it matches the original Search artboard,
        // which draws the field permanently under the title.
        .searchable(text: $model.query, prompt: "아티스트, 라이브, 해시태그 등")
        .searchScopes($model.scope) {
            ForEach(SearchScope.allCases) { scope in
                Text(scope.label).tag(scope)
            }
        }
        .searchSuggestions {
            ForEach(model.suggestions) { suggestion in
                RecentQueryLabel(query: suggestion)
                    .searchCompletion(suggestion.queryText)
            }
        }
        .task { await model.load() }
        .task(id: model.query) { await model.loadSuggestions() }
    }

    // MARK: - Idle

    private var idleContent: some View {
        ScrollView(.vertical) {
            switch model.state {
            case .loading:
                loadingContent
            case .failed(let error):
                ErrorStateView(error: error) {
                    Task { await model.load() }
                }
                .padding(.horizontal, Metric.screenMargin)
            case .loaded(let feed):
                if model.recents.isEmpty, feed.recommended.isEmpty, feed.liveNow.isEmpty {
                    EmptyStateView(
                        title: "무엇을 찾고 계신가요?",
                        message: "아티스트 이름이나 해시태그로 검색하면 지금 열려 있는 라이브를 찾아드릴게요."
                    )
                    .padding(.horizontal, Metric.screenMargin)
                } else {
                    loadedContent(feed)
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await model.load() }
    }

    private func loadedContent(_ feed: ExploreFeed) -> some View {
        VStack(alignment: .leading, spacing: Space.s48) {
            // Header and rows are one conditional block carrying one transition,
            // so removing the last recent search reads as a single movement: the
            // whole block leaves while the shelves below close the gap. Split in
            // two — or with the transition on the rows alone — the header would
            // go first and leave the rows collapsing after it.
            if !model.recents.isEmpty {
                recentSection
                    .transition(.opacity)
            }
            if !feed.recommended.isEmpty {
                artistShelf(title: "추천 아티스트",
                            artists: feed.recommended,
                            showsLiveIndicator: false)
            }
            if !feed.liveNow.isEmpty {
                artistShelf(title: "라이브 중인 아티스트",
                            artists: feed.liveNow,
                            showsLiveIndicator: true)
            }
        }
        .padding(.top, Space.s16)
        .padding(.bottom, Space.s48)
        // Driven by the data rather than by the control that changed it: the
        // per-row X and 전체삭제 both only mutate `recents`, so both animate from
        // this one place — the section's own departure included.
        .motion(value: model.recents)
    }

    /// Artists and hashtags share one list and one row, because to the person
    /// typing they are the same thing: something they searched for before.
    ///
    /// The animation lives on the container in `loadedContent`, not here: this
    /// block is what appears and disappears, and a view cannot animate its own
    /// removal.
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            SectionHeader(title: "최근 검색어", actionTitle: "전체삭제") {
                model.clearRecents()
            }
            VStack(spacing: Space.s4) {
                ForEach(model.recents) { recent in
                    RecentQueryRow(
                        query: recent,
                        onSelect: { model.recall(recent) },
                        onRemove: { model.remove(recent) }
                    )
                }
            }
        }
        .padding(.horizontal, Metric.screenMargin)
    }

    private func artistShelf(title: LocalizedStringKey,
                             artists: [Artist],
                             showsLiveIndicator: Bool) -> some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            SectionHeader(title: title)
                .padding(.horizontal, Metric.screenMargin)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Space.s12) {
                    ForEach(artists) { artist in
                        Button {
                            router.openArtist(artist)
                        } label: {
                            ArtistCard(artist: artist, showsLiveIndicator: showsLiveIndicator)
                                .frame(width: Metric.artistCardWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, Metric.screenMargin, for: .scrollContent)
        }
    }

    // MARK: - Loading

    /// The real geometry, redacted, so what arrives lands where the skeleton was.
    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: Space.s48) {
            VStack(alignment: .leading, spacing: Space.s12) {
                SectionHeader(title: "최근 검색어")
                VStack(spacing: Space.s4) {
                    ForEach(Fixtures.recentQueries) { recent in
                        RecentQueryLabel(query: recent)
                            .frame(minHeight: Metric.tapTarget)
                    }
                }
            }
            .padding(.horizontal, Metric.screenMargin)

            artistShelf(title: "추천 아티스트",
                        artists: Fixtures.recommendedArtists,
                        showsLiveIndicator: false)
        }
        .padding(.top, Space.s16)
        .skeleton(true)
    }
}

// MARK: - Recent query row

/// The shared body of a recent search and a typing suggestion: a 32pt leading
/// slot, then the text that goes back into the field. An artist gets their
/// avatar there, a hashtag gets the `#` mark, so one row serves both kinds.
private struct RecentQueryLabel: View {
    let query: RecentQuery

    var body: some View {
        HStack(spacing: Space.s12) {
            leading
            Text(query.queryText)
                .typography(.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var leading: some View {
        switch query {
        case .artist(let artist):
            AvatarView(artist: artist, size: Metric.avatarM)
        case .hashtag:
            Text(verbatim: "#")
                .typography(.rowTitle)
                .foregroundStyle(Palette.inkChip)
                .frame(width: Metric.avatarM, height: Metric.avatarM)
                .background(Palette.surfaceRaised, in: .circle)
                .accessibilityHidden(true)
        }
    }
}

private struct RecentQueryRow: View {
    let query: RecentQuery
    var onSelect: () -> Void
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: Space.s8) {
            Button(action: onSelect) {
                RecentQueryLabel(query: query)
                    .frame(minHeight: Metric.tapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .typography(.metaStrong)
                    .foregroundStyle(Palette.inkTertiary)
                    .frame(width: Metric.tapTarget, height: Metric.tapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("검색어 삭제")
        }
    }
}

// MARK: - Previews

private func previewExplore(_ model: ExploreModel) -> some View {
    NavigationStack {
        ExploreView(model: model)
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

private func previewExplore(_ behaviour: MockDataSource.Behaviour) -> some View {
    previewExplore(ExploreModel(dataSource: MockDataSource(behaviour: behaviour)))
}

#Preview("기본 — 라이트") {
    previewExplore(.populated).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewExplore(.populated).preferredColorScheme(.dark)
}

private func previewSearching() -> some View {
    let model = ExploreModel(dataSource: MockDataSource(behaviour: .populated))
    model.query = "김승찬"
    return previewExplore(model)
}

#Preview("검색 중 — 라이트") {
    previewSearching().preferredColorScheme(.light)
}

#Preview("검색 중 — 다크") {
    previewSearching().preferredColorScheme(.dark)
}

#Preview("검색 중 — accessibility3") {
    previewSearching().environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("로딩") {
    previewExplore(.loading)
}

#Preview("빈 상태") {
    previewExplore(.empty)
}

#Preview("오류") {
    previewExplore(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewExplore(.populated).environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("최근 검색어 행", traits: .sizeThatFitsLayout) {
    VStack(spacing: Space.s4) {
        ForEach(Fixtures.recentQueries) { recent in
            RecentQueryRow(query: recent, onSelect: {}, onRemove: {})
        }
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
