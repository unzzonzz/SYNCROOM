//  WatchHistoryView.swift  (S3 → 시청 기록)
//
//  Liquid Glass: nothing is drawn here. The only glass on the screen is the
//  system navigation bar the `NavigationStack` supplies, floating over an opaque
//  scrolling content column — rows are content, so they stay opaque and never
//  imitate the bar above them.

import SwiftUI

@MainActor
@Observable
final class WatchHistoryModel {
    private let dataSource: any DataSource

    var state: LoadState<[LiveRoom]> = .loading

    init(dataSource: any DataSource = MockDataSource.shared) {
        self.dataSource = dataSource
    }

    func load() async {
        state = await LoadState.load { try await self.dataSource.watchHistory() }
    }

    func reload() async {
        state = await LoadState.load { try await self.dataSource.watchHistory() }
    }
}

struct WatchHistoryView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PlaybackController.self) private var playback

    @State private var model: WatchHistoryModel

    init(model: WatchHistoryModel = WatchHistoryModel()) {
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
            case .loaded(let rooms):
                if rooms.isEmpty {
                    emptyContent
                } else {
                    loadedContent(rooms)
                }
            }
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .refreshable { await model.reload() }
        .navigationTitle("시청 기록")
        .task { await model.load() }
    }

    // MARK: - Loaded

    private func loadedContent(_ rooms: [LiveRoom]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rooms) { room in
                Button {
                    playback.watch(room)
                } label: {
                    LiveRowCard(room: room)
                        .padding(.vertical, Space.s12)
                }
                .buttonStyle(.plain)

                if room.id != rooms.last?.id {
                    RowSeparator()
                }
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .padding(.bottom, Space.s48)
    }

    // MARK: - Empty

    private var emptyContent: some View {
        EmptyStateView(
            title: "아직 시청 기록이 없어요",
            message: "라이브를 보고 나면 여기에 순서대로 쌓여요.",
            actionTitle: "라이브 둘러보기"
        ) {
            router.tab = .home
        }
        .padding(.horizontal, Metric.screenMargin)
    }

    // MARK: - Loading

    /// The real row geometry, redacted, so what arrives lands in the same place
    /// the skeleton stood.
    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: Space.s24) {
            ForEach(Fixtures.watchHistory) { room in
                LiveRowCard(room: room)
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .skeleton(true)
    }
}

// MARK: - Previews

private func previewWatchHistory(_ behaviour: MockDataSource.Behaviour) -> some View {
    NavigationStack {
        WatchHistoryView(model: WatchHistoryModel(dataSource: MockDataSource(behaviour: behaviour)))
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewWatchHistory(.populated).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewWatchHistory(.populated).preferredColorScheme(.dark)
}

#Preview("로딩") {
    previewWatchHistory(.loading)
}

#Preview("빈 상태") {
    previewWatchHistory(.empty)
}

#Preview("오류") {
    previewWatchHistory(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewWatchHistory(.populated).environment(\.dynamicTypeSize, .accessibility3)
}
