//  MyBroadcastsView.swift  (S3 → 내 라이브)
//
//  Liquid Glass: none is drawn here. The navigation bar the `NavigationStack`
//  supplies is the only glass on screen; the grid beneath it is content, so the
//  tiles stay opaque and carry no material, border or shadow of their own.

import SwiftUI

@MainActor
@Observable
final class MyBroadcastsModel {
    private let dataSource: any DataSource

    var state: LoadState<[PastBroadcast]> = .loading

    init(dataSource: any DataSource = MockDataSource.shared) {
        self.dataSource = dataSource
    }

    func load() async {
        state = await LoadState.load { try await self.dataSource.myBroadcasts() }
    }

    func reload() async {
        state = await LoadState.load { try await self.dataSource.myBroadcasts() }
    }
}

struct MyBroadcastsView: View {
    @Environment(AppRouter.self) private var router

    @State private var model: MyBroadcastsModel

    init(model: MyBroadcastsModel = MyBroadcastsModel()) {
        _model = State(initialValue: model)
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: Space.s12),
         GridItem(.flexible(), spacing: Space.s12)]
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
            case .loaded(let broadcasts):
                if broadcasts.isEmpty {
                    emptyContent
                } else {
                    loadedContent(broadcasts)
                }
            }
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .refreshable { await model.reload() }
        .navigationTitle("내 라이브")
        .task { await model.load() }
    }

    // MARK: - Loaded

    /// Tiles are not tappable: a saved broadcast has no player yet, and an
    /// affordance that leads nowhere is worse than none at all.
    private func loadedContent(_ broadcasts: [PastBroadcast]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Space.s32) {
            ForEach(broadcasts) { broadcast in
                PastBroadcastTile(broadcast: broadcast)
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .padding(.bottom, Space.s48)
    }

    // MARK: - Empty

    private var emptyContent: some View {
        EmptyStateView(
            title: "아직 지난 방송이 없어요",
            message: "라이브가 끝나면 다시 볼 수 있도록 여기에 저장돼요.",
            actionTitle: "라이브 시작"
        ) {
            router.startHosting()
        }
        .padding(.horizontal, Metric.screenMargin)
    }

    // MARK: - Loading

    /// The real grid geometry, redacted, so tiles arrive where the skeleton stood.
    private var loadingContent: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Space.s32) {
            ForEach(Fixtures.pastBroadcasts) { broadcast in
                PastBroadcastTile(broadcast: broadcast)
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .skeleton(true)
    }
}

// MARK: - Previews

private func previewMyBroadcasts(_ behaviour: MockDataSource.Behaviour) -> some View {
    NavigationStack {
        MyBroadcastsView(model: MyBroadcastsModel(dataSource: MockDataSource(behaviour: behaviour)))
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewMyBroadcasts(.populated).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewMyBroadcasts(.populated).preferredColorScheme(.dark)
}

#Preview("로딩") {
    previewMyBroadcasts(.loading)
}

#Preview("빈 상태") {
    previewMyBroadcasts(.empty)
}

#Preview("오류") {
    previewMyBroadcasts(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewMyBroadcasts(.populated).environment(\.dynamicTypeSize, .accessibility3)
}
