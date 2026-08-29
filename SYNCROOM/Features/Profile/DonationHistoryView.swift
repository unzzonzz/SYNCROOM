//  DonationHistoryView.swift  (S3 → 후원 내역)
//
//  Liquid Glass: none is drawn here. The system navigation bar is the only glass
//  layer; the ledger below is content, so rows stay opaque and are grouped by
//  space alone — no cards, no rules, no fills.

import SwiftUI

@MainActor
@Observable
final class DonationHistoryModel {
    private let dataSource: any DataSource

    var state: LoadState<[DonationRecord]> = .loading

    init(dataSource: any DataSource = MockDataSource.shared) {
        self.dataSource = dataSource
    }

    func load() async {
        state = await LoadState.load { try await self.dataSource.donationHistory() }
    }

    func reload() async {
        state = await LoadState.load { try await self.dataSource.donationHistory() }
    }
}

struct DonationHistoryView: View {
    @Environment(AppRouter.self) private var router

    @State private var model: DonationHistoryModel

    init(model: DonationHistoryModel = DonationHistoryModel()) {
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
            case .loaded(let records):
                if records.isEmpty {
                    emptyContent
                } else {
                    loadedContent(records)
                }
            }
        }
        .background(Palette.surface)
        .scrollIndicators(.hidden)
        .refreshable { await model.reload() }
        .navigationTitle("후원 내역")
        .task { await model.load() }
    }

    // MARK: - Loaded

    private func loadedContent(_ records: [DonationRecord]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(records) { record in
                DonationRecordRow(record: record)
                    .padding(.vertical, Space.s12)

                if record.id != records.last?.id {
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
            title: "아직 후원 내역이 없어요",
            message: "라이브에서 주고받은 후원이 여기에 모여요.",
            actionTitle: "라이브 둘러보기"
        ) {
            router.tab = .home
        }
        .padding(.horizontal, Metric.screenMargin)
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: Space.s24) {
            ForEach(Fixtures.donationHistory) { record in
                DonationRecordRow(record: record)
            }
        }
        .padding(.horizontal, Metric.screenMargin)
        .padding(.top, Space.s16)
        .skeleton(true)
    }
}

// MARK: - Row

/// One entry in the ledger.
///
/// Direction is carried by a word — 보낸 후원 / 받은 후원 — and not by a colour:
/// in this design system colour is reserved for live, caution, success and
/// performing, and neither direction is any of those.
private struct DonationRecordRow: View {
    let record: DonationRecord

    private var directionLabel: LocalizedStringKey {
        record.isOutgoing ? "보낸 후원" : "받은 후원"
    }

    var body: some View {
        HStack(alignment: .top, spacing: Space.s12) {
            AvatarView(artist: record.counterpart, size: Metric.avatarM)

            VStack(alignment: .leading, spacing: Space.s4) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s12) {
                    NameLabel(artist: record.counterpart, style: .bodyStrong)
                    Spacer(minLength: Space.s8)
                    Text(Format.currency(record.amount))
                        .typography(.rowTitle)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .layoutPriority(1)
                }

                Text(verbatim: record.roomTitle)
                    .typography(.meta)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)

                metaLine
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(directionLabel))
        .accessibilityValue(Text(accessibilityValue))
    }

    /// Two adjacent `Text` views rather than one concatenated run: the direction
    /// and the time need different weights, and the line never wraps.
    private var metaLine: some View {
        HStack(spacing: Space.s4) {
            Text(directionLabel)
                .typography(.metaStrong)
                .foregroundStyle(Palette.ink)
            Text(verbatim: "·")
                .typography(.meta)
                .foregroundStyle(Palette.hairline)
            Text(Format.relative(record.sentAt))
                .typography(.meta)
                .foregroundStyle(Palette.inkSecondary)
        }
        .lineLimit(1)
    }

    private var accessibilityValue: String {
        record.counterpart.displayName + " · " + record.roomTitle + " · "
            + Format.currency(record.amount) + " · " + Format.relative(record.sentAt)
    }
}

// MARK: - Previews

private func previewDonationHistory(_ behaviour: MockDataSource.Behaviour) -> some View {
    NavigationStack {
        DonationHistoryView(
            model: DonationHistoryModel(dataSource: MockDataSource(behaviour: behaviour))
        )
    }
    .environment(AppRouter())
    .environment(SessionModel())
    .environment(PlaybackController())
    .environment(SettingsStore())
}

#Preview("기본 — 라이트") {
    previewDonationHistory(.populated).preferredColorScheme(.light)
}

#Preview("기본 — 다크") {
    previewDonationHistory(.populated).preferredColorScheme(.dark)
}

#Preview("로딩") {
    previewDonationHistory(.loading)
}

#Preview("빈 상태") {
    previewDonationHistory(.empty)
}

#Preview("오류") {
    previewDonationHistory(.failing)
}

#Preview("Dynamic Type — accessibility3") {
    previewDonationHistory(.populated).environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("행 — 보낸 후원과 받은 후원", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: Space.s24) {
        ForEach(Fixtures.donationHistory) { record in
            DonationRecordRow(record: record)
        }
    }
    .padding(Metric.screenMargin)
    .background(Palette.surface)
}
