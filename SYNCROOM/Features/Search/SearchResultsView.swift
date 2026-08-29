//  SearchResultsView.swift  (S14)
//
//  Liquid Glass: this screen deliberately owns none of it. It is rendered inside
//  ExploreView's `.searchable` container, so the search field and the scope bar
//  above it are the system's glass; everything here is content, and content in
//  this design system is opaque. The `더보기` action writes back to the scope
//  binding, which is how the system scope bar and these results stay in step.

import SwiftUI

@MainActor
@Observable
final class SearchResultsModel {
    private let dataSource: any DataSource

    /// How many of each kind the 전체 scope samples before 더보기 takes over.
    static let sampleSize = 3

    var state: LoadState<SearchResults> = .loading

    /// The scope the results *currently on screen* belong to.
    ///
    /// `scope` flips the moment the tab is tapped; the rows only change when the
    /// fetch lands a few hundred milliseconds later. Anything drawn from `scope`
    /// therefore changes on a different frame from the rows it belongs to —
    /// which is why the section headings used to vanish on their own, ahead of
    /// the content. This trails the results instead, so both move together.
    private(set) var loadedScope: SearchScope = .all

    /// Follow toggles made here. The fixture graph is immutable, so the change
    /// lives beside the results rather than inside them.
    private var followOverrides: [UUID: Bool] = [:]

    init(dataSource: any DataSource = MockDataSource.shared) {
        self.dataSource = dataSource
    }

    func load(query: String, scope: SearchScope) async {
        // The query changes on every keystroke. A short pause before asking
        // keeps the list from thrashing, and a pause cancelled by the next
        // keystroke leaves the previous results on screen instead of blanking
        // them out.
        do {
            try await Task.sleep(for: .milliseconds(180))
        } catch {
            return
        }
        let next = await LoadState.load {
            try await self.dataSource.search(query: query, scope: scope)
        }
        // Both in the same update, so the headings and the rows are one change.
        if case .loaded = next { loadedScope = scope }
        state = next
    }

    func isFollowing(_ artist: Artist) -> Bool {
        followOverrides[artist.id] ?? artist.isFollowing
    }

    func toggleFollow(_ artist: Artist) {
        followOverrides[artist.id] = !isFollowing(artist)
    }
}

struct SearchResultsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PlaybackController.self) private var playback

    let query: String
    @Binding var scope: SearchScope

    @State private var model: SearchResultsModel

    init(query: String,
         scope: Binding<SearchScope>,
         model: SearchResultsModel = SearchResultsModel()) {
        self.query = query
        _scope = scope
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView(.vertical) {
            switch model.state {
            case .loading:
                loadingContent
                    .transition(.opacity)
            case .failed(let error):
                ErrorStateView(error: error) {
                    Task { await model.load(query: query, scope: scope) }
                }
                .padding(.horizontal, Metric.screenMargin)
                .transition(.opacity)
            case .loaded(let found):
                if found.isEmpty {
                    noResults
                        .transition(.opacity)
                } else {
                    resultList(found)
                        .transition(.opacity)
                }
            }
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        // Keyed on the results, not on the scope. Changing scope only *starts* a
        // reload — the rows change a few hundred milliseconds later, once the
        // fetch returns. Animating on `scope` opened and closed a transaction
        // long before that, so the swap itself landed as a hard cut.
        .motion(value: model.state)
        .task(id: reloadKey) { await model.load(query: query, scope: scope) }
    }

    /// Both inputs in one identity, so a changed query and a changed scope each
    /// restart exactly one load.
    private var reloadKey: String { scope.rawValue + "\u{1}" + query }

    // MARK: - Results

    private func resultList(_ found: SearchResults) -> some View {
        VStack(alignment: .leading, spacing: Space.s48) {
            if !found.artists.isEmpty {
                section(title: "아티스트", narrowsTo: .artist, total: found.artists.count) {
                    ForEach(sampled(found.artists)) { artist in
                        artistRow(artist)
                    }
                }
            }
            if !found.rooms.isEmpty {
                section(title: "라이브", narrowsTo: .live, total: found.rooms.count) {
                    ForEach(sampled(found.rooms)) { room in
                        liveRow(room)
                    }
                }
            }
            if !found.hashtags.isEmpty {
                section(title: "해시태그", narrowsTo: .hashtag, total: found.hashtags.count) {
                    ForEach(sampled(found.hashtags)) { stat in
                        hashtagRow(stat)
                    }
                }
            }
        }
        .padding(.top, Space.s16)
        .padding(.bottom, Space.s48)
        .padding(.horizontal, Metric.screenMargin)
    }

    /// 전체 shows a sample of every kind; a single-kind scope shows all of it.
    ///
    /// Keyed on the loaded scope, not the selected one, so the sample size
    /// changes on the same frame as the rows it is sampling.
    private func sampled<T>(_ items: [T]) -> [T] {
        model.loadedScope == .all ? Array(items.prefix(SearchResultsModel.sampleSize)) : items
    }

    @ViewBuilder
    private func section<Rows: View>(title: LocalizedStringKey,
                                     narrowsTo target: SearchScope,
                                     total: Int,
                                     @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            // Only 전체 mixes kinds, so only 전체 needs a heading to tell them
            // apart. 더보기 narrows the scope — and it is hidden when the sample
            // already is everything, rather than shown doing nothing.
            if model.loadedScope == .all {
                Group {
                    if total > SearchResultsModel.sampleSize {
                        SectionHeader(title: title, actionTitle: "더보기") {
                            self.scope = target
                        }
                    } else {
                        SectionHeader(title: title)
                    }
                }
                .transition(.opacity)
            }
            VStack(alignment: .leading, spacing: Space.s24) {
                rows()
            }
        }
    }

    // MARK: - Rows

    private func artistRow(_ artist: Artist) -> some View {
        ArtistRow(artist: artist, showsHashtags: true) {
            FollowButton(isFollowing: model.isFollowing(artist)) {
                model.toggleFollow(artist)
            }
        }
        .contentShape(.rect)
        // The follow toggle is a control inside the row, so it takes its own
        // taps and the rest of the row opens the profile.
        .onTapGesture { router.openArtist(artist) }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "프로필 열기") { router.openArtist(artist) }
    }

    private func liveRow(_ room: LiveRoom) -> some View {
        Button {
            playback.watch(room)
        } label: {
            LiveRowCard(room: room)
        }
        .buttonStyle(.plain)
    }

    private func hashtagRow(_ stat: HashtagStat) -> some View {
        Button {
            router.openHashtag(stat.tag)
        } label: {
            HashtagResultRow(stat: stat)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Nothing found

    private var noResults: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            EmptyStateView(
                title: "'\(query)'에 대한 결과가 없어요",
                message: "이름의 일부만 넣어보거나, 아래 해시태그로 둘러보세요."
            )

            SectionHeader(title: "추천 해시태그")

            FlowLayout(spacing: Space.s8, lineSpacing: Space.s8) {
                ForEach(Fixtures.suggestedHashtags, id: \.self) { tag in
                    Button {
                        router.openHashtag(tag)
                    } label: {
                        HashtagChip(tag: tag)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.bottom, Space.s48)
    }

    // MARK: - Loading

    /// The row geometry that is arriving, redacted.
    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: Space.s24) {
            ForEach(Fixtures.recommendedArtists) { artist in
                ArtistRow(artist: artist, showsHashtags: true) {
                    FollowButton(isFollowing: false) {}
                }
            }
            LiveRowCard(room: Fixtures.chansRoom)
            LiveRowCard(room: Fixtures.longformRoom)
        }
        .padding(.top, Space.s16)
        .padding(.horizontal, Metric.screenMargin)
        .skeleton(true)
    }
}

// MARK: - Hashtag row

/// A hashtag as a search result: the tag, and how much is happening under it.
private struct HashtagResultRow: View {
    let stat: HashtagStat

    var body: some View {
        HStack(spacing: Space.s12) {
            Text(verbatim: "#")
                .typography(.rowTitle)
                .foregroundStyle(Palette.inkChip)
                .frame(width: Metric.avatarM, height: Metric.avatarM)
                .background(Palette.surfaceRaised, in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.s4) {
                Text(Format.hashtag(stat.tag))
                    .typography(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(Format.liveCount(stat.liveCount))
                    .typography(.meta)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: Metric.tapTarget)
        .contentShape(.rect)
    }
}

// MARK: - Previews

private func previewResults(query: String,
                            scope: Binding<SearchScope>,
                            behaviour: MockDataSource.Behaviour) -> some View {
    NavigationStack {
        SearchResultsView(
            query: query,
            scope: scope,
            model: SearchResultsModel(dataSource: MockDataSource(behaviour: behaviour))
        )
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("전체 — 라이트") {
    @Previewable @State var scope: SearchScope = .all
    previewResults(query: "HASHTAG", scope: $scope, behaviour: .populated)
        .preferredColorScheme(.light)
}

#Preview("전체 — 다크") {
    @Previewable @State var scope: SearchScope = .all
    previewResults(query: "HASHTAG", scope: $scope, behaviour: .populated)
        .preferredColorScheme(.dark)
}

#Preview("아티스트 범위") {
    @Previewable @State var scope: SearchScope = .artist
    previewResults(query: "김승찬", scope: $scope, behaviour: .populated)
}

#Preview("해시태그 범위") {
    @Previewable @State var scope: SearchScope = .hashtag
    previewResults(query: "피아노", scope: $scope, behaviour: .populated)
}

#Preview("결과 없음") {
    @Previewable @State var scope: SearchScope = .all
    previewResults(query: "김승찬", scope: $scope, behaviour: .empty)
}

#Preview("로딩") {
    @Previewable @State var scope: SearchScope = .all
    previewResults(query: "김승찬", scope: $scope, behaviour: .loading)
}

#Preview("오류") {
    @Previewable @State var scope: SearchScope = .all
    previewResults(query: "김승찬", scope: $scope, behaviour: .failing)
}

#Preview("Dynamic Type — accessibility3") {
    @Previewable @State var scope: SearchScope = .all
    previewResults(query: "HASHTAG", scope: $scope, behaviour: .populated)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("해시태그 행", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s24) {
        ForEach(Fixtures.hashtagStats) { stat in
            HashtagResultRow(stat: stat)
        }
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
