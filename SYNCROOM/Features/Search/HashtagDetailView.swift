//  HashtagDetailView.swift  (S15)
//
//  Liquid Glass: the only glass here is the system navigation bar. The tag is a
//  real `navigationTitle` and the follow toggle is a real `.toolbar` item, so the
//  platform draws its capsule and nothing in this file paints a bar background.
//  The segmented picker underneath is a *content* control — it selects what the
//  grid shows — so it stays in the opaque content column with the cards.

import SwiftUI

/// The two ways to look at a hashtag: what is on air under it, and who works
/// under it. Named after the screen, because Swift has no per-folder namespaces.
enum HashtagDetailSegment: String, CaseIterable, Identifiable, Hashable, Sendable {
    case rooms, artists

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .rooms: "라이브 중"
        case .artists: "인기 아티스트"
        }
    }
}

@MainActor
@Observable
final class HashtagDetailModel {
    private let dataSource: any DataSource
    private let tag: String

    /// Local override of the fetched follow flag, so the toggle answers now and
    /// the next fetch still wins.
    private var followOverride: Bool?

    var state: LoadState<HashtagDetail> = .loading
    var segment: HashtagDetailSegment = .rooms

    init(tag: String, dataSource: any DataSource = MockDataSource.shared) {
        self.tag = tag
        self.dataSource = dataSource
    }

    var isFollowing: Bool {
        followOverride ?? state.value?.stat.isFollowing ?? false
    }

    func load() async {
        state = await LoadState.load { try await self.dataSource.hashtagDetail(tag: self.tag) }
    }

    func reload() async {
        await load()
    }

    func toggleFollow() {
        followOverride = !isFollowing
    }
}

struct HashtagDetailView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PlaybackController.self) private var playback

    /// The tag we were pushed with — enough to title the screen and to draw the
    /// skeleton before the fetch lands. Stored without the leading `#`.
    let tag: String

    @State private var model: HashtagDetailModel

    init(tag: String, model: HashtagDetailModel? = nil) {
        self.tag = tag
        _model = State(initialValue: model ?? HashtagDetailModel(tag: tag))
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
            case .loaded(let detail):
                detailContent(detail)
            }
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .refreshable { await model.reload() }
        .navigationTitle(Text(verbatim: Format.hashtag(tag)))
        .toolbarTitleDisplayMode(.large)
        .toolbar {
            // A toggle whose state we do not know yet is not a toggle, so it
            // arrives with the data rather than guessing 팔로우 and flipping.
            if model.state.value != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(model.isFollowing ? "팔로잉" : "팔로우") {
                        model.toggleFollow()
                    }
                    .accessibilityAddTraits(model.isFollowing ? .isSelected : [])
                    .motion(value: model.isFollowing)
                }
            }
        }
        .motion(value: model.segment)
        .task { await model.load() }
    }

    // MARK: - Content

    private func detailContent(_ detail: HashtagDetail) -> some View {
        VStack(alignment: .leading, spacing: Space.s32) {
            VStack(alignment: .leading, spacing: Space.s16) {
                summaryLine(detail.stat)
                segmentPicker
            }
            segmentContent(detail)
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .padding(.bottom, Space.s48)
    }

    /// How much is happening under the tag, in one line under the title.
    private func summaryLine(_ stat: HashtagStat) -> some View {
        Text(Format.hashtagSummary(liveCount: stat.liveCount, artistCount: stat.artistCount))
            .typography(.body)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var segmentPicker: some View {
        @Bindable var model = model

        return Picker(selection: $model.segment) {
            ForEach(HashtagDetailSegment.allCases) { segment in
                Text(segment.label).tag(segment)
            }
        } label: {
            Text("보기 방식")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder
    private func segmentContent(_ detail: HashtagDetail) -> some View {
        switch model.segment {
        case .rooms:
            if detail.liveRooms.isEmpty {
                EmptyStateView(
                    title: "지금 열려 있는 라이브가 없어요",
                    message: "이 해시태그로 라이브가 시작되면 여기에 모아드릴게요.",
                    actionTitle: "라이브 시작"
                ) {
                    router.startHosting()
                }
            } else {
                roomGrid(detail.liveRooms)
            }
        case .artists:
            if detail.topArtists.isEmpty {
                EmptyStateView(
                    title: "아직 이 해시태그를 쓰는 아티스트가 없어요",
                    message: "다른 해시태그로 둘러보면 비슷한 음악을 하는 사람들을 찾을 수 있어요."
                )
            } else {
                artistGrid(detail.topArtists)
            }
        }
    }

    // MARK: - Grids

    /// The column already gives each card a definite width, so — unlike a shelf —
    /// nothing here reaches for `containerRelativeFrame`.
    private func roomGrid(_ rooms: [LiveRoom]) -> some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: Space.s32) {
            ForEach(rooms) { room in
                Button {
                    playback.watch(room)
                } label: {
                    LiveCard(room: room) {
                        router.openArtist(room.host)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func artistGrid(_ artists: [Artist]) -> some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: Space.s24) {
            ForEach(artists) { artist in
                Button {
                    router.openArtist(artist)
                } label: {
                    ArtistCard(artist: artist, showsLiveIndicator: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: Space.s12),
         GridItem(.flexible(), spacing: Space.s12)]
    }

    // MARK: - Loading

    /// The real layout, redacted, so what arrives lands where the skeleton was —
    /// including the segment that is currently selected.
    private var loadingContent: some View {
        detailContent(
            HashtagDetail(stat: HashtagStat(tag: tag, liveCount: 0, artistCount: 0),
                          liveRooms: Fixtures.shelfRooms,
                          topArtists: Fixtures.recommendedArtists)
        )
        .skeleton(true)
    }
}

// MARK: - Previews

private func previewHashtag(_ tag: String = "R&B",
                            _ behaviour: MockDataSource.Behaviour = .populated,
                            segment: HashtagDetailSegment = .rooms) -> some View {
    let model = HashtagDetailModel(tag: tag, dataSource: MockDataSource(behaviour: behaviour))
    model.segment = segment
    return NavigationStack {
        HashtagDetailView(tag: tag, model: model)
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("라이브 중 — 라이트") {
    previewHashtag().preferredColorScheme(.light)
}

#Preview("라이브 중 — 다크") {
    previewHashtag().preferredColorScheme(.dark)
}

#Preview("인기 아티스트") {
    previewHashtag("피아노", segment: .artists)
}

#Preview("로딩") {
    previewHashtag("R&B", .loading)
}

// A tag with no fixture stat behind it, so the summary line and the empty grid
// agree with each other instead of counting rooms that are not there.
#Preview("빈 상태") {
    previewHashtag("드럼", .empty)
}

#Preview("빈 상태 — 인기 아티스트") {
    previewHashtag("드럼", .empty, segment: .artists)
}

#Preview("오류") {
    previewHashtag("R&B", .failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewHashtag().environment(\.dynamicTypeSize, .accessibility3)
}
