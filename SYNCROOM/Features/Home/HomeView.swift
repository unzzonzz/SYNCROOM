//  HomeView.swift  (S1)
//
//  Liquid Glass: the navigation bar is a real `.toolbar`, so the system draws the
//  glass capsules around its items — nothing here paints a bar background. The
//  wordmark opts out of that shared background with
//  `.sharedBackgroundVisibility(.hidden)` because it is a mark, not a control,
//  while the two trailing buttons are split by `ToolbarSpacer(.fixed)` into two
//  separate glass groups: an inbox and a create action are different kinds of
//  thing and should not share one capsule.

import SwiftUI

@MainActor
@Observable
final class HomeModel {
    private let dataSource: any DataSource

    var state: LoadState<HomeFeed> = .loading
    /// Which hero slide is centred, for the position indicator.
    var heroIndex: Int = 0

    init(dataSource: any DataSource = MockDataSource.shared) {
        self.dataSource = dataSource
    }

    func load() async {
        state = await LoadState.load { try await self.dataSource.homeFeed() }
    }

    func reload() async {
        state = await LoadState.load { try await self.dataSource.homeFeed() }
    }
}

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(SessionModel.self) private var session
    @Environment(PlaybackController.self) private var playback

    @State private var model: HomeModel

    init(model: HomeModel = HomeModel()) {
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
                if feed.shelves.isEmpty {
                    EmptyStateView(
                        title: "아직 볼 라이브가 없어요",
                        message: "관심 있는 아티스트를 팔로우하면 라이브가 시작될 때 여기에 모아드릴게요.",
                        actionTitle: "아티스트 찾아보기"
                    ) {
                        router.tab = .search
                    }
                    .padding(.horizontal, Metric.screenMargin)
                } else {
                    loadedContent(feed)
                }
            }
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .refreshable { await model.reload() }
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Wordmark()
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.notifications)
                } label: {
                    Image(systemName: "bell")
                }
                .accessibilityLabel("알림")
                .badge(session.unreadNotifications)
            }

            // Two different kinds of action, so two separate glass groups.
            ToolbarSpacer(.fixed, placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.startHosting()
                } label: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                }
                .accessibilityLabel("라이브 시작")
            }
        }
        .task { await model.load() }
    }

    // MARK: - Loaded

    @ViewBuilder
    private func loadedContent(_ feed: HomeFeed) -> some View {
        VStack(alignment: .leading, spacing: Space.s48) {
            if !feed.hero.isEmpty {
                heroCarousel(feed.hero)
            }
            ForEach(feed.shelves) { shelf in
                shelfSection(shelf)
            }
        }
        .padding(.top, Space.s16)
        .padding(.bottom, Space.s48)
    }

    private func heroCarousel(_ slides: [HeroSlide]) -> some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: Space.s12) {
                    ForEach(slides) { slide in
                        Button {
                            playback.watch(slide.room)
                        } label: {
                            HeroBanner(room: slide.room)
                                .containerRelativeFrame(.horizontal)
                        }
                        .buttonStyle(.plain)
                        .id(slide.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, Metric.screenMargin, for: .scrollContent)
            .scrollPosition(id: heroSelection)
            .frame(maxWidth: .infinity)

            PageIndicator(count: slides.count, index: model.heroIndex)
                .padding(.horizontal, Metric.screenMargin)
        }
    }

    /// Bridges the scroll position back to an index for the bar indicator.
    private var heroSelection: Binding<UUID?> {
        Binding(
            get: {
                guard let feed = model.state.value, model.heroIndex < feed.hero.count else { return nil }
                return feed.hero[model.heroIndex].id
            },
            set: { newValue in
                guard let newValue, let feed = model.state.value,
                      let index = feed.hero.firstIndex(where: { $0.id == newValue }) else { return }
                model.heroIndex = index
            }
        )
    }

    private func shelfSection(_ shelf: HomeShelf) -> some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            SectionHeader(title: LocalizedStringKey(shelf.title))
                .padding(.horizontal, Metric.screenMargin)

            ScrollView(.horizontal) {
                // Not lazy: a `LazyHStack` takes its height from the cards it
                // has materialised, so a taller two-line-title card scrolling in
                // later is clipped to a height fixed by its shorter neighbours.
                // A shelf holds a handful of cards, so measuring them all up
                // front is what makes the row as tall as its tallest card.
                HStack(alignment: .top, spacing: Space.s12) {
                    ForEach(shelf.rooms) { room in
                        Button {
                            playback.watch(room)
                        } label: {
                            LiveCard(room: room) {
                                router.openArtist(room.host)
                            }
                            .frame(width: Metric.liveCardWidth)
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

    /// The real shelf geometry, redacted. `containerRelativeFrame` only resolves
    /// inside a scroll container, so the skeleton reuses `shelfSection` rather
    /// than laying cards out in a plain stack.
    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: Space.s48) {
            HeroBanner(room: Fixtures.plainRoom)
                .padding(.horizontal, Metric.screenMargin)
            ForEach(Fixtures.placeholderShelves) { shelf in
                shelfSection(shelf)
            }
        }
        .padding(.top, Space.s16)
        .skeleton(true)
    }
}

// MARK: - Previews

private func previewHome(_ behaviour: MockDataSource.Behaviour) -> some View {
    NavigationStack {
        HomeView(model: HomeModel(dataSource: MockDataSource(behaviour: behaviour)))
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewHome(.populated).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewHome(.populated).preferredColorScheme(.dark)
}

#Preview("로딩") {
    previewHome(.loading)
}

#Preview("빈 상태") {
    previewHome(.empty)
}

#Preview("오류") {
    previewHome(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewHome(.populated).environment(\.dynamicTypeSize, .accessibility3)
}
